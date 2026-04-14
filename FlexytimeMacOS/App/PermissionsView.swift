import SwiftUI

/// AltTab-style permissions onboarding view
/// Pattern: Accessibility required, Screen Recording can be skipped
struct PermissionsView: View {
    @StateObject private var permissionChecker = PermissionChecker()
    var onAllGranted: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            permissionCards
            footerSection
        }
        .padding(30)
        .frame(width: 480, height: 400)
        .onAppear { permissionChecker.startMonitoring() }
        .onDisappear { permissionChecker.stopMonitoring() }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image("MenuBarIcon")
                .resizable()
                .frame(width: 48, height: 48)

            Text("Flexytime needs permissions")
                .font(.title2)
                .fontWeight(.semibold)
        }
    }

    private var permissionCards: some View {
        VStack(spacing: 12) {
            PermissionCard(
                icon: "accessibility",
                title: "Accessibility",
                description: "Required to read active window titles",
                status: permissionChecker.accessibilityStatus,
                buttonTitle: "Open Accessibility Preferences...",
                action: { PermissionsManager.openAccessibilitySettings() }
            )

            PermissionCard(
                icon: "screen.recording",
                title: "Screen Recording",
                description: "Required for complete window detection",
                status: permissionChecker.screenRecordingStatus,
                buttonTitle: "Open Screen Recording Settings...",
                action: { PermissionsManager.requestOrOpenScreenRecording() },
                skipAction: { permissionChecker.skipScreenRecording() }
            )
        }
    }

    private var footerSection: some View {
        Group {
            if permissionChecker.canProceed {
                Button("Continue") { onAllGranted() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            } else {
                Text("Grant the permissions above to continue")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Permission Status

enum PermissionStatus {
    case granted
    case notGranted
    case skipped

    var label: String {
        switch self {
        case .granted: return "Allowed"
        case .notGranted: return "Not allowed"
        case .skipped: return "Skipped"
        }
    }

    var color: Color {
        switch self {
        case .granted: return .green
        case .notGranted: return .red
        case .skipped: return .orange
        }
    }

    var isResolved: Bool { self != .notGranted }
}

// MARK: - Permission Card

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let buttonTitle: String
    let action: () -> Void
    var skipAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 16) {
            iconView
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    statusBadge
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(status == .granted)

                if let skipAction, status == .notGranted {
                    skipCheckbox(skipAction)
                }
            }
        }
        .padding(16)
        .background(status.color.opacity(0.1))
        .cornerRadius(10)
    }

    private func skipCheckbox(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "forward.fill")
                    .font(.caption2)
                Text("Skip — window titles may be incomplete")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var iconView: some View {
        Image(systemName: iconSystemName)
            .font(.system(size: 24))
            .foregroundColor(status.color)
            .frame(width: 40, height: 40)
    }

    private var iconSystemName: String {
        switch icon {
        case "accessibility": return "figure.stand"
        case "screen.recording": return "rectangle.inset.filled.on.rectangle"
        default: return "questionmark.circle"
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(status.label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(status.color)
        }
    }
}

// MARK: - Permission Checker

class PermissionChecker: ObservableObject {
    @Published var accessibilityStatus: PermissionStatus = .notGranted
    @Published var screenRecordingStatus: PermissionStatus = .notGranted

    private var timer: Timer?

    /// Both permissions must be resolved (granted or skipped) to proceed
    var canProceed: Bool {
        accessibilityStatus.isResolved && screenRecordingStatus.isResolved
    }

    func skipScreenRecording() {
        UserDefaults.standard.set(true, forKey: "screenRecordingSkipped")
        screenRecordingStatus = .skipped
    }

    func startMonitoring() {
        checkPermissions()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPermissions() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let accessibility = PermissionsManager.hasAccessibilityPermission
            let screenRec = PermissionsManager.hasScreenRecordingPermission
            let skipped = UserDefaults.standard.bool(forKey: "screenRecordingSkipped")
            DispatchQueue.main.async {
                self?.accessibilityStatus = accessibility ? .granted : .notGranted
                if screenRec {
                    self?.screenRecordingStatus = .granted
                } else if skipped {
                    self?.screenRecordingStatus = .skipped
                } else {
                    self?.screenRecordingStatus = .notGranted
                }
            }
        }
    }
}

// MARK: - Preview

struct PermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsView(onAllGranted: {})
    }
}
