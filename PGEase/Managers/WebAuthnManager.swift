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
            
            // Step 1: Get registration options from server
            let registrationOptionsResponse = try await apiManager.getWebAuthnRegistrationOptions(
                userId: userId,
                deviceName: deviceName
            )
            let options = registrationOptionsResponse.options
            
            // Step 2: Create credential with Face ID/Touch ID
            let credential = try await createCredential(options: options)
            
            // Step 3: Send credential to server for verification
            let verified = try await apiManager.verifyWebAuthnRegistration(
                userId: userId,
                credential: credential,
                deviceName: deviceName
            )
            
            await MainActor.run {
                self.isLoading = false
                if verified {
                    self.successMessage = "Passkey registered successfully"
                }
            }
            
            return verified
            
        } catch {
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
            await MainActor.run { isLoading = true }
            
            // Step 1: Get authentication options from server
            let authenticationOptionsResponse = try await apiManager.getWebAuthnAuthenticationOptions(userId: userId)
            let options = authenticationOptionsResponse.options
            
            // Step 2: Authenticate with Face ID/Touch ID
            let assertion = try await getAssertion(options: options)
            
            // Step 3: Verify with server
            let result = try await apiManager.verifyWebAuthnAuthentication(
                userId: userId,
                assertion: assertion
            )
            
            await MainActor.run {
                self.isLoading = false
                self.successMessage = "Authentication successful"
            }
            
            return result.credentialId
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func createCredential(options: RegistrationOptions) async throws -> ASAuthorizationPlatformPublicKeyCredentialRegistration {
        
        guard let challengeData = Data(base64URLEncoded: options.challenge),
              let userIDData = Data(base64URLEncoded: options.user.id) else {
            throw WebAuthnError.invalidChallenge
        }
        
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.rp.id)
        
        let request = provider.createCredentialRegistrationRequest(
            challenge: challengeData,
            name: options.user.name,
            userID: userIDData
        )
        
        request.userVerificationPreference = .required
        
        return try await withCheckedThrowingContinuation { continuation in
            self.registrationContinuation = continuation
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            
            DispatchQueue.main.async {
                controller.performRequests()
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
        
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            registrationContinuation?.resume(returning: credential)
            registrationContinuation = nil
        }
        
        if let assertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            assertionContinuation?.resume(returning: assertion)
            assertionContinuation = nil
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        registrationContinuation?.resume(throwing: error)
        assertionContinuation?.resume(throwing: error)
        
        registrationContinuation = nil
        assertionContinuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension WebAuthnManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return presentationAnchor ?? ASPresentationAnchor()
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

