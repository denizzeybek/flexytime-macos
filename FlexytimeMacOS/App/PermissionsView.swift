import SwiftUI

/// AltTab-style permissions onboarding view
struct PermissionsView: View {
    @StateObject private var permissionChecker = PermissionChecker()
    var onAllGranted: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerSection

            // Permission Cards
            VStack(spacing: 12) {
                PermissionCard(
                    icon: "screen.recording",
                    iconColor: .green,
                    title: "Screen Recording",
                    description: "This permission is needed to read window names",
                    isGranted: permissionChecker.hasScreenRecording,
                    buttonTitle: "Open Screen Recording Settings...",
                    action: { PermissionsManager.requestOrOpenScreenRecording() }
                )

                PermissionCard(
                    icon: "accessibility",
                    iconColor: .blue,
                    title: "Accessibility",
                    description: "This permission is needed to read window titles",
                    isGranted: permissionChecker.hasAccessibility,
                    buttonTitle: "Open Accessibility Preferences...",
                    action: { PermissionsManager.openAccessibilitySettings() }
                )
            }

            // Continue button (only enabled when all permissions granted)
            if permissionChecker.allPermissionsGranted {
                Button("Continue") {
                    onAllGranted()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                VStack(spacing: 4) {
                    Text("Grant all permissions above to continue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Note: You may need to quit and reopen the app after granting permissions")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
        }
        .padding(30)
        .frame(width: 480, height: 380)
        .onAppear {
            // Reset the flag if permission not granted - so popup can show again
            PermissionsManager.resetScreenRecordingFlagIfNeeded()
            permissionChecker.startMonitoring()
        }
        .onDisappear {
            permissionChecker.stopMonitoring()
        }
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
}

// MARK: - Permission Card

struct PermissionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isGranted: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            iconView

            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
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
                .disabled(isGranted)
            }
        }
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(10)
    }

    private var iconView: some View {
        Image(systemName: iconSystemName)
            .font(.system(size: 24))
            .foregroundColor(iconColor)
            .frame(width: 40, height: 40)
    }

    private var iconSystemName: String {
        switch icon {
        case "accessibility":
            return "figure.stand"
        case "screen.recording":
            return "rectangle.inset.filled.on.rectangle"
        default:
            return "questionmark.circle"
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isGranted ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(isGranted ? "Allowed" : "Not allowed")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isGranted ? .green : .red)
        }
    }

    private var backgroundColor: Color {
        if isGranted {
            return Color.green.opacity(0.1)
        } else {
            return Color.red.opacity(0.1)
        }
    }
}

// MARK: - Permission Checker (Observable)

class PermissionChecker: ObservableObject {
    @Published var hasAccessibility: Bool = false
    @Published var hasScreenRecording: Bool = false

    private var timer: Timer?

    var allPermissionsGranted: Bool {
        hasAccessibility && hasScreenRecording
    }

    func startMonitoring() {
        // Initial check
        checkPermissions()

        // Poll every 1 second for changes
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPermissions() {
        DispatchQueue.main.async { [weak self] in
            let accessibility = PermissionsManager.hasAccessibilityPermission
            let screenRec = PermissionsManager.hasScreenRecordingPermission
            self?.hasAccessibility = accessibility
            self?.hasScreenRecording = screenRec
        }
    }
}

// MARK: - Preview

struct PermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsView(onAllGranted: {})
    }
}
