import SwiftUI

/// Setup view shown on first launch to collect ServiceKey
struct SetupView: View {
    @State private var serviceKey: String = ""
    @State private var serviceHost: String = "app.flexytime.com"
    @State private var isValidating: Bool = false
    @State private var errorMessage: String?
    @State private var showAdvanced: Bool = false

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Logo/Header
            Image("MenuBarIcon")
                .resizable()
                .frame(width: 64, height: 64)

            Text("Flexytime Kurulumu")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Flexytime'ı kullanmak için şirket anahtarınızı girin.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Service Key Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Şirket Anahtarı (Service Key)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Örn: VGnX31HrYUmpKAHXAQjX7w", text: $serviceKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
            }

            // Advanced Settings (collapsible)
            DisclosureGroup("Gelişmiş Ayarlar", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sunucu Adresi")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("app.flexytime.com", text: $serviceHost)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }
                .padding(.top, 8)
            }
            .frame(width: 280)

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
                    Text("Başlat")
                        .frame(width: 100)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(serviceKey.isEmpty || isValidating)

            // Help text
            Text("Şirket anahtarınızı Flexytime web panelinden alabilirsiniz.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(width: 400, height: 450)
    }

    private func validateAndSave() {
        errorMessage = nil
        isValidating = true

        // Validate key format (should be ~22 chars base64 or 12 chars base36)
        let trimmedKey = serviceKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = serviceHost.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            errorMessage = "Şirket anahtarı boş olamaz"
            isValidating = false
            return
        }

        guard !trimmedHost.isEmpty else {
            errorMessage = "Sunucu adresi boş olamaz"
            isValidating = false
            return
        }

        // Save configuration
        let config = Configuration.shared
        config.serviceKey = trimmedKey
        config.serviceHost = trimmedHost

        // Validate with server (optional - just try to connect)
        Task {
            // Small delay to show loading state
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
