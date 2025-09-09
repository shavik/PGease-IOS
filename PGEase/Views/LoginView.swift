import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject var biometricAuthManager: BiometricAuthManager
    @State private var showingSettings = false
    @State private var isAuthenticating = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App Logo/Icon
                VStack(spacing: 20) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text("QR Face Scanner")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("Secure QR Code Scanning with Face Detection")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Biometric Authentication Section
                VStack(spacing: 20) {
                    if biometricAuthManager.isBiometricAvailable {
                        // Biometric authentication available
                        VStack(spacing: 15) {
                            Image(systemName: biometricAuthManager.biometricType == .faceID ? "faceid" : "touchid")
                                .font(.system(size: 60))
                                .foregroundColor(.green)

                            Text("Use \(biometricAuthManager.biometricTypeDescription)")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Quick and secure access to your app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Login Button
                        Button(action: authenticateUser) {
                            HStack {
                                if isAuthenticating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: biometricAuthManager.biometricType == .faceID ? "faceid" : "touchid")
                                }
                                Text(isAuthenticating ? "Authenticating..." : "Login with \(biometricAuthManager.biometricTypeDescription)")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(isAuthenticating)
                        .padding(.horizontal)

                    } else {
                        // Biometric authentication not available
                        VStack(spacing: 15) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)

                            Text("Biometric Authentication Unavailable")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("This device doesn't support Face ID or Touch ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Fallback login option
                        Button(action: {
                            // For demo purposes, allow access without biometrics
                            print("🔐 Manual login button tapped")
                            biometricAuthManager.isAuthenticated = true
                            print("🔐 Manual login: isAuthenticated set to \(biometricAuthManager.isAuthenticated)")
                        }) {
                            Text("Continue Without Biometrics")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()

                // Settings and Help
                VStack(spacing: 15) {
                    Button(action: { showingSettings = true }) {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("Settings")
                        }
                        .foregroundColor(.secondary)
                    }

                    if let errorMessage = biometricAuthManager.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSettings) {
            BiometricSettingsView()
        }
        .onAppear {
            // Auto-authenticate if biometrics are enabled and available
            if biometricAuthManager.isBiometricEnabled && biometricAuthManager.isBiometricAvailable {
                authenticateUser()
            }
        }
    }

    private func authenticateUser() {
        isAuthenticating = true
        print("🔐 Starting biometric authentication...")

        Task {
            let success = await biometricAuthManager.authenticateUser(reason: "Login to QR Face Scanner")

            await MainActor.run {
                isAuthenticating = false
                print("🔐 Authentication result: \(success)")
                print("🔐 Current auth state: \(biometricAuthManager.isAuthenticated)")

                if success {
                    biometricAuthManager.setBiometricEnabled(true)
                    print("🔐 Biometric enabled, authentication state: \(biometricAuthManager.isAuthenticated)")
                }
            }
        }
    }
}

struct BiometricSettingsView: View {
    @EnvironmentObject var biometricAuthManager: BiometricAuthManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Biometric Authentication") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(biometricAuthManager.isBiometricAvailable ? "Available" : "Not Available")
                            .foregroundColor(biometricAuthManager.isBiometricAvailable ? .green : .red)
                    }

                    if biometricAuthManager.isBiometricAvailable {
                        HStack {
                            Text("Type")
                            Spacer()
                            Text(biometricAuthManager.biometricTypeDescription)
                                .foregroundColor(.secondary)
                        }

                        Toggle("Enable \(biometricAuthManager.biometricTypeDescription)", isOn: Binding(
                            get: { biometricAuthManager.isBiometricEnabled },
                            set: { biometricAuthManager.setBiometricEnabled($0) }
                        ))

                        Toggle("Require for App Access", isOn: Binding(
                            get: { biometricAuthManager.requiresAuthentication },
                            set: { biometricAuthManager.setRequiresAuthentication($0) }
                        ))

                        Toggle("Re-authenticate on Background", isOn: Binding(
                            get: { biometricAuthManager.shouldReauthenticateOnBackground },
                            set: { biometricAuthManager.setReauthenticateOnBackground($0) }
                        ))
                    }
                }

                Section("Information") {
                    Text("Biometric data is stored securely on your device and is never shared with the app or transmitted over the network.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Biometric Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
