import Foundation
import os.log

/// V1-compatible activity collector
/// Timing: 1s polling, 15s AFK check, 60s sync, 15min calendar
/// Event logic: New event ONLY when ProcessName changes (NOT title)
final class ActivityCollector {

    // MARK: - Properties

    private let windowTracker = WindowTracker()
    private let idleDetector = IdleDetector()
    private let urlExtractor = BrowserURLExtractor()
    private let apiClient: APIClient
    private let configuration: Configuration
    private let logger = Logger.services

    private var pollingTimer: Timer?
    private var timerCounter = 0
    private var views: [ViewEvent] = []
    private var activeView: ViewEvent?
    private var currentURL: String?
    private var isRunning = false

    // MARK: - Initialization

    init(configuration: Configuration) {
        self.configuration = configuration
        self.apiClient = APIClient(configuration: configuration)
        self.idleDetector.idleThreshold = configuration.idleThreshold
    }

    // MARK: - Public Methods

    func start() {
        guard !isRunning else {
            logger.warning("ActivityCollector already running")
            return
        }

        isRunning = true
        startPolling()
        logger.info("ActivityCollector started")

        // Debug: Print system info on startup
        if configuration.isDebugMode {
            logger.info("=== DEBUG MODE ENABLED ===")
            logger.info("Username: \(SystemInfo.username)")
            logger.info("MachineName: \(SystemInfo.machineName)")
            logger.info("IP Address: \(SystemInfo.ipAddress)")
            logger.info("UserPath: \(SystemInfo.userPath)")
            logger.info("ServiceHost: \(self.configuration.serviceHost)")
            logger.info("ServiceKey: \(self.configuration.serviceKey?.prefix(8) ?? "NOT SET")...")
            logger.info("===========================")
        }
    }

    func stop() {
        isRunning = false
        pollingTimer?.invalidate()
        pollingTimer = nil
        logger.info("ActivityCollector stopped")
    }

    // MARK: - Private Methods

    private func startPolling() {
        // V1: 1 second polling interval
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.pollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.onTimerTick()
        }
    }

    /// V1-compatible timer logic from main.py on_timed_event
    private func onTimerTick() {
        timerCounter += 1

        // Every 1 second: activity event
        activityEvent()

        // Every 15 seconds: AFK check
        if timerCounter % 15 == 0 {
            onInputTimedEvent()
        }

        // Every 60 seconds: sync views
        if timerCounter % 60 == 0 {
            onWindowTimedEvent()
        }

        // Every 15 minutes (900s): calendar ping
        if timerCounter % 900 == 0 {
            onCalendarTimedEvent()
            timerCounter = 0
        }
    }

    /// V1: activity_event() - creates new view on ProcessName or URL change
    private func activityEvent() {
        guard var window = windowTracker.getCurrentWindow() else {
            logger.debug("Unable to fetch window, trying again on next poll")
            return
        }

        let now = Date()

        // Extract URL only for browser apps (performance: skip for non-browsers)
        let newURL = urlExtractor.extractURL(appName: window.appName)
        window.url = newURL

        // Debug: Log every window poll
        if configuration.isDebugMode && timerCounter % 5 == 0 {
            let urlSnippet = newURL.map { String($0.prefix(60)) } ?? "n/a"
            logger.info("📍 \(window.appName) | \(window.windowTitle.prefix(40)) | \(urlSnippet)")
        }

        if activeView == nil {
            let seconds = idleDetector.secondsSinceLastInput()
            logger.info("activeView is None - seconds: \(Int(seconds))")
            if seconds < configuration.idleThreshold {
                currentURL = newURL
                createView(window: window)
            }
        } else if activeView?.processName != window.appName {
            // V1: Create new view when ProcessName changes
            logger.info("🔄 App changed: \(self.activeView?.processName ?? "") → \(window.appName)")
            closeActiveView(at: now)
            currentURL = newURL
            createView(window: window)
        } else if urlExtractor.isBrowser(appName: window.appName) && newURL != currentURL {
            // NEW: Create new view when URL changes in same browser (V1 Windows behavior)
            logger.info("🌐 URL changed: \(self.currentURL?.prefix(40) ?? "nil") → \(newURL?.prefix(40) ?? "nil")")
            closeActiveView(at: now)
            currentURL = newURL
            createView(window: window)
        }
        // Title change alone does NOT create new event
    }

    /// V1: on_input_timed_event() - AFK check every 15s
    private func onInputTimedEvent() {
        logger.info("input event")

        let seconds = idleDetector.secondsSinceLastInput()
        guard seconds >= configuration.idleThreshold else { return }
        guard activeView != nil else { return }

        logger.info("AFK")
        let lastInput = Date().addingTimeInterval(-seconds)
        closeActiveView(at: lastInput)
        currentURL = nil
    }

    /// V1: on_window_timed_event() - sync every 60s
    private func onWindowTimedEvent() {
        logger.info("⏱️ Sync event (60s)")

        let viewsToSync = views
        views.removeAll()

        guard !viewsToSync.isEmpty else {
            logger.debug("No views to sync")
            return
        }

        // Debug: Log all views being synced
        print("═══ 📤 SYNCING \(viewsToSync.count) VIEW(S) @ \(Date()) ═══")
        for (index, view) in viewsToSync.enumerated() {
            let dur = Int(view.expireTime.timeIntervalSince(view.time))
            let url = view.properties["URL"] ?? "n/a"
            print("  [\(index + 1)] \(view.processName) | \(dur)s | URL: \(url)")
        }

        let usage = createUsagePayload(views: viewsToSync, dataType: .input)

        Task {
            await apiClient.sendUsage(usage)
        }
    }

    /// V1: on_calendar_timed_event() - 15 minute ping
    private func onCalendarTimedEvent() {
        logger.info("calendar event")

        let usage = createUsagePayload(views: nil, dataType: .calendar)

        Task {
            await apiClient.sendUsage(usage)
        }
    }

    // MARK: - Helper Methods

    /// V1: create_view() — includes URL in Properties for browser apps
    private func createView(window: WindowTracker.WindowInfo) {
        let now = Date()
        let expireTime = now.addingTimeInterval(configuration.idleThreshold)

        var properties: [String: String] = [:]
        if let url = window.url {
            properties["URL"] = url
        }

        activeView = ViewEvent(
            processName: window.appName,
            title: window.windowTitle,
            time: now,
            expireTime: expireTime,
            properties: properties
        )
    }

    /// Close the active view and add to views list
    private func closeActiveView(at time: Date) {
        guard var view = activeView else { return }

        view.expireTime = time
        let duration = time.timeIntervalSince(view.time)

        // V1: Only add views with duration > 1 second
        if duration > 1 {
            views.append(view)
        }

        activeView = nil
    }

    /// Create V1-compatible usage payload
    private func createUsagePayload(
        views: [ViewEvent]?,
        dataType: UsageDataType
    ) -> UsagePayload {
        UsagePayload(
            deviceType: .mac,
            version: configuration.appVersion,
            username: SystemInfo.username,
            machineName: SystemInfo.machineName,
            ipAddress: SystemInfo.ipAddress,
            dataType: dataType,
            recordDate: Date(),
            views: views,
            calendar: nil
        )
    }
}
