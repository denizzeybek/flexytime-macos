import Foundation

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
            FlexLog.warning("ActivityCollector already running", category: .services)
            return
        }

        isRunning = true
        startPolling()

        FlexLog.info("ActivityCollector started", category: .app)
        FlexLog.info("User: \(SystemInfo.username) | Machine: \(SystemInfo.machineName)", category: .app)
        FlexLog.info("Host: \(configuration.serviceHost)", category: .app)
    }

    func stop() {
        isRunning = false
        pollingTimer?.invalidate()
        pollingTimer = nil
        FlexLog.info("ActivityCollector stopped", category: .app)
    }

    // MARK: - Private Methods

    private func startPolling() {
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
            return
        }

        let now = Date()

        // Extract URL only for browser apps
        let newURL = urlExtractor.extractURL(appName: window.appName)
        window.url = newURL

        if activeView == nil {
            let seconds = idleDetector.secondsSinceLastInput()
            if seconds < configuration.idleThreshold {
                currentURL = newURL
                createView(window: window)
            }
        } else if activeView?.processName != window.appName {
            FlexLog.info("App changed: \(activeView?.processName ?? "?") -> \(window.appName)", category: .services)
            closeActiveView(at: now)
            currentURL = newURL
            createView(window: window)
        } else if urlExtractor.isBrowser(appName: window.appName) && newURL != currentURL {
            FlexLog.info("URL changed: \(currentURL?.prefix(40) ?? "nil") -> \(newURL?.prefix(40) ?? "nil")", category: .services)
            closeActiveView(at: now)
            currentURL = newURL
            createView(window: window)
        }
    }

    /// V1: on_input_timed_event() - AFK check every 15s
    private func onInputTimedEvent() {
        let seconds = idleDetector.secondsSinceLastInput()
        guard seconds >= configuration.idleThreshold else { return }
        guard activeView != nil else { return }

        FlexLog.info("AFK detected (\(Int(seconds))s idle)", category: .services)
        let lastInput = Date().addingTimeInterval(-seconds)
        closeActiveView(at: lastInput)
        currentURL = nil
    }

    /// V1: on_window_timed_event() - sync every 60s
    private func onWindowTimedEvent() {
        let viewsToSync = views
        views.removeAll()

        guard !viewsToSync.isEmpty else { return }

        // Log views being synced
        var summary = "SYNC \(viewsToSync.count) view(s):"
        for view in viewsToSync {
            let dur = Int(view.expireTime.timeIntervalSince(view.time))
            summary += " [\(view.processName) \(dur)s]"
        }
        FlexLog.info(summary, category: .services)

        let usage = createUsagePayload(views: viewsToSync, dataType: .input)

        Task {
            await apiClient.sendUsage(usage)
        }
    }

    /// V1: on_calendar_timed_event() - 15 minute ping
    private func onCalendarTimedEvent() {
        FlexLog.info("Calendar ping (15min)", category: .services)

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
