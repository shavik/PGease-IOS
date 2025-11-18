import Foundation
import AuthenticationServices
import SwiftUI

/// Universal WebAuthn Manager for all user types
/// Handles passkey registration and authentication using Face ID/Touch ID
class WebAuthnManager: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let apiManager = APIManager.shared
    private var registrationContinuation: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialRegistration, Error>?
    private var assertionContinuation: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialAssertion, Error>?
    private var presentationAnchor: ASPresentationAnchor?
    
    // MARK: - Registration (Onboarding)
    
    /// Register a new passkey for the user
    /// Works for ALL user types (STUDENT, STAFF, MANAGER, etc.)
    func registerPasskey(userId: String, deviceName: String) async -> Bool {
        do {
            await MainActor.run { isLoading = true }
            
            print("🔐 [WebAuthn] Starting registration for userId: \(userId)")
            
            // Step 1: Get registration options from server
            print("📡 [WebAuthn] Calling /webauthn/registration/options...")
            let registrationOptionsResponse = try await apiManager.getWebAuthnRegistrationOptions(
                userId: userId,
                deviceName: deviceName
            )
            let options = registrationOptionsResponse.options
            print("✅ [WebAuthn] Received options - Challenge: \(options.challenge.prefix(20))...")
            print("✅ [WebAuthn] RP ID: \(options.rp.id)")
            print("✅ [WebAuthn] User ID: \(options.user.id.prefix(20))...")
            
            // Step 2: Create credential with Face ID/Touch ID
            print("📱 [WebAuthn] Creating credential with Face ID/Touch ID...")
            let credential = try await createCredential(options: options)
            print("✅ [WebAuthn] Credential created successfully")
            print("✅ [WebAuthn] Credential ID: \(credential.credentialID.base64URLEncodedString().prefix(20))...")
            
            // Step 3: Send credential to server for verification
            print("📡 [WebAuthn] Calling /webauthn/registration/verify...")
            let verified = try await apiManager.verifyWebAuthnRegistration(
                userId: userId,
                credential: credential,
                deviceName: deviceName
            )
            print("✅ [WebAuthn] Verification result: \(verified)")
            
            await MainActor.run {
                self.isLoading = false
                if verified {
                    self.successMessage = "Passkey registered successfully"
                    print("🎉 [WebAuthn] Registration complete!")
                }
            }
            
            return verified
            
        } catch {
            print("❌ [WebAuthn] Registration failed: \(error)")
            print("❌ [WebAuthn] Error details: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    // MARK: - Authentication (Check-In/Out)
    
    /// Authenticate user with passkey
    /// Works for ALL user types (STUDENT, STAFF, MANAGER, etc.)
    /// Returns credential ID if successful
    func authenticate(userId: String) async -> String? {
        do {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
                successMessage = nil
            }
            
            // Step 1: Get authentication options from server
            let authenticationOptionsResponse = try await apiManager.getWebAuthnAuthenticationOptions(userId: userId)
            let options = authenticationOptionsResponse.options
            print("📡 [WebAuthn] Received authentication options for userId: \(userId)")
            print("📡 [WebAuthn] Allow credentials: \(options.allowCredentials?.map { $0.id } ?? [])")
            
            // Step 2: Authenticate with Face ID/Touch ID
            let assertion = try await getAssertion(options: options)
            let credentialId = assertion.credentialID.base64URLEncodedString()
            print("✅ [WebAuthn] Assertion credential ID: \(credentialId)")
            
            // Step 3: Verify with server
            let result = try await apiManager.verifyWebAuthnAuthentication(
                userId: userId,
                assertion: assertion
            )
            print("📡 [WebAuthn] Server verification credential ID: \(result.credentialId)")
            
            await MainActor.run {
                self.isLoading = false
                self.successMessage = "Authentication successful"
            }
            
            return result.credentialId
            
        } catch {
            await MainActor.run {
                self.isLoading = false

                if let nsError = error as NSError?,
                   nsError.domain == ASAuthorizationError.errorDomain,
                   nsError.code == ASAuthorizationError.Code.notInteractive.rawValue {
                    self.errorMessage = "Biometric prompt was cancelled. Please try again."
                } else if let authError = error as? ASAuthorizationError {
                    switch authError.code {
                    case .canceled:
                        self.errorMessage = "Authentication was cancelled."
                    case .failed:
                        self.errorMessage = "Biometric verification failed."
                    case .invalidResponse, .notHandled, .unknown:
                        self.errorMessage = error.localizedDescription
                    case .notInteractive:
                        self.errorMessage = "Biometric prompt could not be displayed. Please retry."
                    @unknown default:
                        self.errorMessage = error.localizedDescription
                    }
                } else {
                    self.errorMessage = error.localizedDescription
                }
            }
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func createCredential(options: RegistrationOptions) async throws -> ASAuthorizationPlatformPublicKeyCredentialRegistration {
        
        print("🔑 [WebAuthn] Decoding challenge and user ID...")
        guard let challengeData = Data(base64URLEncoded: options.challenge) else {
            print("❌ [WebAuthn] Failed to decode challenge")
            throw WebAuthnError.invalidChallenge
        }
        print("✅ [WebAuthn] Challenge decoded: \(challengeData.count) bytes")
        
        guard let userIDData = Data(base64URLEncoded: options.user.id) else {
            print("❌ [WebAuthn] Failed to decode user ID")
            throw WebAuthnError.invalidChallenge
        }
        print("✅ [WebAuthn] User ID decoded: \(userIDData.count) bytes")
        
        print("🔑 [WebAuthn] Creating credential provider with RP ID: \(options.rp.id)")
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.rp.id)
        
        print("🔑 [WebAuthn] Creating registration request...")
        let request = provider.createCredentialRegistrationRequest(
            challenge: challengeData,
            name: options.user.name,
            userID: userIDData
        )
        
        request.userVerificationPreference = .required
        print("✅ [WebAuthn] Request created with userVerification: required")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.registrationContinuation = continuation
            
            print("🎬 [WebAuthn] Creating ASAuthorizationController...")
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            
            print("🎬 [WebAuthn] Performing authorization request...")
            DispatchQueue.main.async {
                controller.performRequests()
                print("✅ [WebAuthn] performRequests() called")
            }
        }
    }
    
    private func getAssertion(options: AuthenticationOptions) async throws -> ASAuthorizationPlatformPublicKeyCredentialAssertion {
        
        guard let challengeData = Data(base64URLEncoded: options.challenge) else {
            throw WebAuthnError.invalidChallenge
        }
        
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.rpId)
        
        let request = provider.createCredentialAssertionRequest(challenge: challengeData)
        request.userVerificationPreference = .required
        
        return try await withCheckedThrowingContinuation { continuation in
            self.assertionContinuation = continuation
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            
            DispatchQueue.main.async {
                controller.performRequests()
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension WebAuthnManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("✅ [WebAuthn] Authorization completed successfully")
        
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            print("✅ [WebAuthn] Received registration credential")
            print("✅ [WebAuthn] Credential ID: \(credential.credentialID.base64URLEncodedString().prefix(20))...")
            registrationContinuation?.resume(returning: credential)
            registrationContinuation = nil
        }
        
        if let assertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            print("✅ [WebAuthn] Received assertion credential")
            assertionContinuation?.resume(returning: assertion)
            assertionContinuation = nil
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ [WebAuthn] Authorization failed with error")
        print("❌ [WebAuthn] Error domain: \((error as NSError).domain)")
        print("❌ [WebAuthn] Error code: \((error as NSError).code)")
        print("❌ [WebAuthn] Error description: \(error.localizedDescription)")
        print("❌ [WebAuthn] Error: \(error)")
        
        registrationContinuation?.resume(throwing: error)
        assertionContinuation?.resume(throwing: error)
        
        registrationContinuation = nil
        assertionContinuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension WebAuthnManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        print("🪟 Getting presentation anchor...")
        
        // Method 1: Get key window from active scene
        let activeScenes = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
        
        if let windowScene = activeScenes.first,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            print("✅ Using key window from active scene")
            return window
        }
        
        // Method 2: Get any key window from any scene
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            print("✅ Using key window from any scene")
            return window
        }
        
        // Method 3: Fallback to deprecated method (iOS 12 compatibility)
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            print("✅ Using key window (deprecated method)")
            return window
        }
        
        // Method 4: Get first window that's visible
        if let window = UIApplication.shared.windows.first(where: { !$0.isHidden }) {
            print("⚠️ Using first visible window")
            return window
        }
        
        // Last resort: return first window
        print("❌ WARNING: Using fallback window")
        return UIApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}

// MARK: - Supporting Types

struct RegistrationOptions: Codable {
    let challenge: String
    let rp: RelyingParty
    let user: UserInfo
    let pubKeyCredParams: [PubKeyCredParam]
    let timeout: Int?
    let excludeCredentials: [CredentialDescriptor]?
    let authenticatorSelection: AuthenticatorSelection?
    let attestation: String?
    
    struct RelyingParty: Codable {
        let id: String
        let name: String
    }
    
    struct UserInfo: Codable {
        let id: String
        let name: String
        let displayName: String
    }
    
    struct PubKeyCredParam: Codable {
        let type: String
        let alg: Int
    }
    
    struct CredentialDescriptor: Codable {
        let type: String
        let id: String
        let transports: [String]?
    }
    
    struct AuthenticatorSelection: Codable {
        let authenticatorAttachment: String?
        let requireResidentKey: Bool?
        let residentKey: String?
        let userVerification: String?
    }
}

struct AuthenticationOptions: Codable {
    let challenge: String
    let rpId: String
    let timeout: Int?
    let allowCredentials: [CredentialDescriptor]?
    let userVerification: String?
    
    struct CredentialDescriptor: Codable {
        let type: String
        let id: String
        let transports: [String]?
    }
}

struct WebAuthnVerificationResult: Codable {
    let success: Bool
    let verified: Bool
    let credentialId: String
    let user: UserInfo
    
    struct UserInfo: Codable {
        let id: String
        let name: String
        let email: String
        let role: String
    }
}

enum WebAuthnError: Error, LocalizedError {
    case invalidChallenge
    case registrationFailed
    case authenticationFailed
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidChallenge:
            return "Invalid challenge data"
        case .registrationFailed:
            return "Failed to register passkey"
        case .authenticationFailed:
            return "Failed to authenticate with passkey"
        case .userCancelled:
            return "User cancelled the operation"
        }
    }
}

// MARK: - Data Extension for Base64URL

extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        self.init(base64Encoded: base64)
    }
    
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

