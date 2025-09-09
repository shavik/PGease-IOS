import Foundation
import LocalAuthentication
import SwiftUI

class BiometricAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var biometricType: LABiometryType = .none
    @Published var isBiometricAvailable = false
    @Published var errorMessage: String?

    private let context = LAContext()

    init() {
        checkBiometricAvailability()
    }

    // Check what biometric authentication is available
    func checkBiometricAvailability() {
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isBiometricAvailable = true
            biometricType = context.biometryType
        } else {
            isBiometricAvailable = false
            if let error = error {
                errorMessage = error.localizedDescription
            }
        }
    }

    // Get user-friendly description of biometric type
    var biometricTypeDescription: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .none:
            return "None"
        @unknown default:
            return "Unknown"
        }
    }

    // Authenticate user with biometrics
    func authenticateUser(reason: String = "Authenticate to access the app") async -> Bool {
        print("🔐 BiometricAuthManager: Starting authentication...")
        print("🔐 BiometricAuthManager: Current auth state: \(isAuthenticated)")

        guard isBiometricAvailable else {
            print("🔐 BiometricAuthManager: Biometric not available")
            await MainActor.run {
                errorMessage = "Biometric authentication is not available"
            }
            return false
        }

        return await withCheckedContinuation { continuation in
            print("🔐 BiometricAuthManager: Evaluating biometric policy...")
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                Task { @MainActor in
                    print("🔐 BiometricAuthManager: Policy evaluation result: \(success)")
                    if let error = error {
                        print("🔐 BiometricAuthManager: Error: \(error.localizedDescription)")
                    }

                    if success {
                        print("🔐 BiometricAuthManager: Authentication successful, setting isAuthenticated to true")
                        DispatchQueue.main.async {
                            self.isAuthenticated = true
                            self.errorMessage = nil
                            print("🔐 BiometricAuthManager: isAuthenticated is now: \(self.isAuthenticated)")
                        }
                        continuation.resume(returning: true)
                    } else {
                        print("🔐 BiometricAuthManager: Authentication failed, setting isAuthenticated to false")
                        DispatchQueue.main.async {
                            self.isAuthenticated = false
                            if let error = error {
                                self.errorMessage = self.getErrorMessage(for: error)
                            }
                        }
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    // Logout user
    func logout() {
        isAuthenticated = false
        errorMessage = nil
    }

    // Get user-friendly error message
    private func getErrorMessage(for error: Error) -> String {
        let laError = error as? LAError

        switch laError?.code {
        case .userCancel:
            return "Authentication was cancelled"
        case .userFallback:
            return "User chose to use passcode"
        case .biometryNotAvailable:
            return "Biometric authentication is not available"
        case .biometryNotEnrolled:
            return "No biometric data enrolled"
        case .biometryLockout:
            return "Biometric authentication is locked out"
        case .invalidContext:
            return "Invalid authentication context"
        case .notInteractive:
            return "Authentication requires user interaction"
        default:
            return "Authentication failed: \(error.localizedDescription)"
        }
    }

    // Check if biometric authentication is required for app access
    var requiresAuthentication: Bool {
        // You can customize this based on your app's security requirements
        return UserDefaults.standard.bool(forKey: "requireBiometricAuth")
    }

    // Set whether biometric authentication is required
    func setRequiresAuthentication(_ required: Bool) {
        UserDefaults.standard.set(required, forKey: "requireBiometricAuth")
    }

    // Check if user has enabled biometric authentication
    var isBiometricEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "biometricAuthEnabled")
    }

    // Enable or disable biometric authentication
    func setBiometricEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "biometricAuthEnabled")
    }

    // Check if app should re-authenticate after backgrounding
    var shouldReauthenticateOnBackground: Bool {
        return UserDefaults.standard.bool(forKey: "reauthenticateOnBackground")
    }

    // Set whether app should re-authenticate after backgrounding
    func setReauthenticateOnBackground(_ should: Bool) {
        UserDefaults.standard.set(should, forKey: "reauthenticateOnBackground")
    }

    // Handle app entering background
    func appDidEnterBackground() {
        if shouldReauthenticateOnBackground && isAuthenticated {
            isAuthenticated = false
        }
    }
}
