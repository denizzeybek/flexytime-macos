import SwiftUI
import AppKit

/// Setup view shown on first launch to collect ServiceKey
struct SetupView: View {
    @State private var serviceKey: String = ""
    @State private var isValidating: Bool = false
    @State private var errorMessage: String?
    @State private var autoFilled: Bool = false

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Logo/Header
            Image("MenuBarIcon")
                .resizable()
                .frame(width: 64, height: 64)

            Text("Flexytime Setup")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Enter your company key to start using Flexytime.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Service Key Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Service Key")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("e.g. VGnX31HrYUmpKAHXAQjX7w", text: $serviceKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)

                if autoFilled {
                    Text("Auto-filled from clipboard")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }

            // Error Message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Submit Button
            Button(action: validateAndSave) {
                if isValidating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 100)
                } else {
                    Text("Start")
                        .frame(width: 100)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(serviceKey.isEmpty || isValidating)

            // Help text
            Text("You can find your service key in the Flexytime web panel.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(width: 400, height: 420)
        .onAppear {
            checkClipboardForServiceKey()
        }
    }

    private func checkClipboardForServiceKey() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string) else { return }
        let trimmed = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 10, trimmed.count <= 50 else { return }

        // Service keys are base64-like: alphanumeric + / + = (no spaces or special chars)
        let allowedChars = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "+/=_-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else { return }

        serviceKey = trimmed
        autoFilled = true
    }

    private func validateAndSave() {
        errorMessage = nil
        isValidating = true

        let trimmedKey = serviceKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            errorMessage = "Service key cannot be empty"
            isValidating = false
            return
        }

        // Save ServiceKey to config file
        Configuration.shared.serviceKey = trimmedKey

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)

            await MainActor.run {
                isValidating = false
                onComplete()
            }
        }
    }
}

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView(onComplete: {})
    }
}
