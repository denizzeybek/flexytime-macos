import SwiftUI

/// Menu bar dropdown view showing status and controls
struct MenuBarView: View {
    @State private var isTracking = true
    @State private var lastSyncTime: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            statusSection
            Divider()
            controlsSection
            Divider()
            footerSection
        }
    }

    // MARK: - View Components

    private var statusSection: some View {
        Group {
            HStack {
                Circle()
                    .fill(isTracking ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(isTracking ? "Tracking Active" : "Tracking Paused")
            }

            if let syncTime = lastSyncTime {
                Text("Last sync: \(syncTime.timeAgoDisplay())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var controlsSection: some View {
        Group {
            Button(isTracking ? "Pause Tracking" : "Resume Tracking") {
                isTracking.toggle()
                // TODO: Implement actual pause/resume
            }
        }
    }

    private var footerSection: some View {
        Group {
            Button("Quit Flexytime") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView()
    }
}
