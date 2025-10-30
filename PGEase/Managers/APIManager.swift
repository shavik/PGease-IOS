import Foundation
import SwiftUI
import AuthenticationServices

class APIManager: ObservableObject {
    static let shared = APIManager()
    
    // Base URL for your backend API
    private let baseURL = "https://pg-ease.vercel.app/api"
    
    private init() {}
    
    // MARK: - Generic API Request Method
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        responseType: T.Type
    ) async throws -> T {
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add body if provided
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Onboarding APIs
    
    // Link device with invite code
    func linkDevice(inviteCode: String, deviceId: String) async throws -> LinkDeviceResponse {
        let body = [
            "inviteCode": inviteCode,
            "deviceId": deviceId
        ]
        
        return try await makeRequest(
            endpoint: "/onboarding/link-device",
            method: .POST,
            body: body,
            responseType: LinkDeviceResponse.self
        )
    }
    
    // Setup biometric authentication
    func setupBiometric(
        studentId: String,
        biometricData: BiometricData,
        deviceId: String
    ) async throws -> BiometricSetupResponse {
        let body: [String: Any] = [
            "studentId": studentId,
            "biometricData": [
                "method": biometricData.method,
                "template": biometricData.template,
                "metadata": [
                    "quality": biometricData.quality,
                    "attempts": biometricData.attempts
                ]
            ],
            "deviceId": deviceId
        ]
        
        return try await makeRequest(
            endpoint: "/onboarding/biometric-setup",
            method: .POST,
            body: body,
            responseType: BiometricSetupResponse.self
        )
    }
    
    // Check biometric status
    func getBiometricStatus(studentId: String) async throws -> BiometricStatusResponse {
        return try await makeRequest(
            endpoint: "/onboarding/biometric-setup?studentId=\(studentId)",
            method: .GET,
            responseType: BiometricStatusResponse.self
        )
    }
    
    // MARK: - Biometric Verification
    
    func verifyBiometric(
        studentId: String,
        verificationTemplate: String,
        deviceId: String,
        location: LocationData? = nil,
        checkInMethod: String = "BIOMETRIC_VERIFICATION"
    ) async throws -> BiometricVerificationResponse {
        let body: [String: Any] = [
            "studentId": studentId,
            "verificationTemplate": verificationTemplate,
            "deviceId": deviceId,
            "checkInMethod": checkInMethod,
            "location": location != nil ? [
                "latitude": location!.latitude,
                "longitude": location!.longitude,
                "accuracy": location!.accuracy
            ] : nil
        ]
        
        return try await makeRequest(
            endpoint: "/biometric/verify",
            method: .POST,
            body: body,
            responseType: BiometricVerificationResponse.self
        )
    }
    
    func getVerificationStatus(studentId: String) async throws -> VerificationStatusResponse {
        return try await makeRequest(
            endpoint: "/biometric/verify?studentId=\(studentId)",
            method: .GET,
            responseType: VerificationStatusResponse.self
        )
    }
    
    // MARK: - Check-in/out APIs (Updated with userType support)
    
    func checkIn(
        userType: String,
        userId: String,
        method: CheckInMethod,
        nfcTagId: String? = nil,
        webAuthnCredentialId: String? = nil, // ✅ NEW: WebAuthn proof
        location: LocationData? = nil,
        biometricVerified: Bool = false, // Keep for backward compatibility
        deviceId: String? = nil
    ) async throws -> CheckInOutResponse {
        var body: [String: Any] = [
            "userType": userType,
            "userId": userId, // ✅ NEW: Universal user ID
            "method": method.rawValue,
            "biometricVerified": biometricVerified
        ]
        
        // Add userId based on userType (for backward compatibility)
        if userType == "STUDENT" {
            body["studentId"] = userId
        } else if userType == "STAFF" {
            body["staffId"] = userId
        }
        
        if let nfcTagId = nfcTagId {
            body["nfcTagId"] = nfcTagId
        }
        
        if let webAuthnCredentialId = webAuthnCredentialId {
            body["webAuthnCredentialId"] = webAuthnCredentialId // ✅ NEW: WebAuthn proof
        }
        
        if let deviceId = deviceId {
            body["deviceId"] = deviceId
        }
        
        if let location = location {
            body["latitude"] = location.latitude
            body["longitude"] = location.longitude
        }
        
        return try await makeRequest(
            endpoint: "/check-in-out/checkin",
            method: .POST,
            body: body,
            responseType: CheckInOutResponse.self
        )
    }
    
    func checkOut(
        userType: String,
        userId: String,
        method: CheckInMethod,
        nfcTagId: String? = nil,
        webAuthnCredentialId: String? = nil, // ✅ NEW: WebAuthn proof
        location: LocationData? = nil,
        biometricVerified: Bool = false, // Keep for backward compatibility
        deviceId: String? = nil
    ) async throws -> CheckInOutResponse {
        var body: [String: Any] = [
            "userType": userType,
            "userId": userId, // ✅ NEW: Universal user ID
            "method": method.rawValue,
            "biometricVerified": biometricVerified
        ]
        
        // Add userId based on userType (for backward compatibility)
        if userType == "STUDENT" {
            body["studentId"] = userId
        } else if userType == "STAFF" {
            body["staffId"] = userId
        }
        
        if let nfcTagId = nfcTagId {
            body["nfcTagId"] = nfcTagId
        }
        
        if let webAuthnCredentialId = webAuthnCredentialId {
            body["webAuthnCredentialId"] = webAuthnCredentialId // ✅ NEW: WebAuthn proof
        }
        
        if let deviceId = deviceId {
            body["deviceId"] = deviceId
        }
        
        if let location = location {
            body["latitude"] = location.latitude
            body["longitude"] = location.longitude
        }
        
        return try await makeRequest(
            endpoint: "/check-in-out/checkout",
            method: .POST,
            body: body,
            responseType: CheckInOutResponse.self
        )
    }
    
    // MARK: - Staff Onboarding APIs
    
    func linkStaffDevice(inviteCode: String, deviceId: String) async throws -> LinkStaffDeviceResponse {
        let body = [
            "inviteCode": inviteCode,
            "deviceId": deviceId
        ]
        
        return try await makeRequest(
            endpoint: "/staff/onboarding/link-device",
            method: .POST,
            body: body,
            responseType: LinkStaffDeviceResponse.self
        )
    }
    
    func setupStaffBiometric(
        staffId: String,
        biometricData: BiometricData,
        deviceId: String
    ) async throws -> BiometricSetupResponse {
        let body: [String: Any] = [
            "staffId": staffId,
            "biometricData": [
                "method": biometricData.method,
                "template": biometricData.template,
                "metadata": [
                    "quality": biometricData.quality,
                    "attempts": biometricData.attempts
                ]
            ],
            "deviceId": deviceId
        ]
        
        return try await makeRequest(
            endpoint: "/staff/onboarding/biometric-setup",
            method: .POST,
            body: body,
            responseType: BiometricSetupResponse.self
        )
    }
    
    func getStaffBiometricStatus(staffId: String) async throws -> BiometricStatusResponse {
        return try await makeRequest(
            endpoint: "/staff/onboarding/biometric-setup?staffId=\(staffId)",
            method: .GET,
            responseType: BiometricStatusResponse.self
        )
    }
    
    // MARK: - Deboarding APIs
    
    func deboardStudent(
        studentId: String,
        deboardDate: String,
        reason: String?
    ) async throws -> DeboardResponse {
        var body: [String: Any] = [
            "studentId": studentId,
            "deboardDate": deboardDate
        ]
        
        if let reason = reason {
            body["reason"] = reason
        }
        
        return try await makeRequest(
            endpoint: "/student/deboard",
            method: .POST,
            body: body,
            responseType: DeboardResponse.self
        )
    }
    
    func deboardStaff(
        staffId: String,
        terminationDate: String,
        reason: String?
    ) async throws -> DeboardResponse {
        var body: [String: Any] = [
            "staffId": staffId,
            "terminationDate": terminationDate
        ]
        
        if let reason = reason {
            body["reason"] = reason
        }
        
        return try await makeRequest(
            endpoint: "/staff/deboard",
            method: .POST,
            body: body,
            responseType: DeboardResponse.self
        )
    }
    
    // MARK: - Multi-PG Management APIs
    
    // Get all PGs for a user
    func getUserPGs(userId: String) async throws -> UserPGsResponse {
        return try await makeRequest(
            endpoint: "/user/pgs?userId=\(userId)",
            method: .GET,
            responseType: UserPGsResponse.self
        )
    }
    
    // Switch user's active PG
    func switchPG(userId: String, pgId: String) async throws -> SwitchPGResponse {
        let body = [
            "userId": userId,
            "pgId": pgId
        ]
        
        return try await makeRequest(
            endpoint: "/user/switch-pg",
            method: .POST,
            body: body,
            responseType: SwitchPGResponse.self
        )
    }
    
    // MARK: - User/Member Management APIs
    
    // Create a new user (MANAGER, WARDEN, ACCOUNTANT, STAFF, STUDENT)
    func createUser(
        name: String,
        email: String,
        phone: String?,
        role: String,
        pgId: String,
        createdBy: String
    ) async throws -> CreateUserResponse {
        let body: [String: Any] = [
            "name": name,
            "email": email,
            "phone": phone ?? "",
            "role": role,
            "pgId": pgId,
            "createdBy": createdBy
        ]
        
        return try await makeRequest(
            endpoint: "/users/create",
            method: .POST,
            body: body,
            responseType: CreateUserResponse.self
        )
    }
    
    // Generate invite for any user
    func generateInvite(userId: String, createdBy: String) async throws -> GenerateInviteResponse {
        let body: [String: Any] = [
            "userId": userId,
            "createdBy": createdBy
        ]
        
        return try await makeRequest(
            endpoint: "/users/generate-invite",
            method: .POST,
            body: body,
            responseType: GenerateInviteResponse.self
        )
    }
    
    // Get invite status for a user
    func getUserInviteStatus(userId: String) async throws -> InviteStatusResponse {
        return try await makeRequest(
            endpoint: "/users/generate-invite?userId=\(userId)",
            method: .GET,
            responseType: InviteStatusResponse.self
        )
    }
    
    // List all users/members for a PG
    func listUsers(pgId: String, role: String? = nil) async throws -> UsersListResponse {
        var endpoint = "/pg/\(pgId)/users"
        if let role = role {
            endpoint += "?role=\(role)"
        }
        
        return try await makeRequest(
            endpoint: endpoint,
            method: .GET,
            responseType: UsersListResponse.self
        )
    }
    
    // MARK: - NFC Tag Management APIs
    
    func generateNFCTag(roomId: String, pgId: String) async throws -> GenerateNFCTagResponse {
        let body = [
            "roomId": roomId,
            "pgId": pgId
        ]
        
        return try await makeRequest(
            endpoint: "/nfc-tags/generate",
            method: .POST,
            body: body,
            responseType: GenerateNFCTagResponse.self
        )
    }
    
    func confirmTagLocked(tagId: String) async throws -> ConfirmTagLockedResponse {
        let body = [
            "tagId": tagId
        ]
        
        return try await makeRequest(
            endpoint: "/nfc-tags/confirm-locked",
            method: .POST,
            body: body,
            responseType: ConfirmTagLockedResponse.self
        )
    }
    
    func listNFCTags(pgId: String, status: String? = nil, roomId: String? = nil) async throws -> NFCTagsListResponse {
        var endpoint = "/nfc-tags/list?pgId=\(pgId)"
        
        if let status = status {
            endpoint += "&status=\(status)"
        }
        
        if let roomId = roomId {
            endpoint += "&roomId=\(roomId)"
        }
        
        return try await makeRequest(
            endpoint: endpoint,
            method: .GET,
            responseType: NFCTagsListResponse.self
        )
    }
    
    func updateNFCTag(
        tagId: String,
        roomId: String? = nil,
        status: String? = nil
    ) async throws -> UpdateNFCTagResponse {
        var body: [String: Any] = [
            "tagId": tagId
        ]
        
        if let roomId = roomId {
            body["roomId"] = roomId
        }
        
        if let status = status {
            body["status"] = status
        }
        
        return try await makeRequest(
            endpoint: "/nfc-tags/update",
            method: .PUT,
            body: body,
            responseType: UpdateNFCTagResponse.self
        )
    }
    
    func getTagPassword(tagId: String) async throws -> TagPasswordResponse {
        return try await makeRequest(
            endpoint: "/nfc-tags/password?tagId=\(tagId)",
            method: .GET,
            responseType: TagPasswordResponse.self
        )
    }
    
    func deactivateNFCTag(
        tagId: String,
        status: String,
        reason: String?
    ) async throws -> DeactivateNFCTagResponse {
        var body: [String: Any] = [
            "tagId": tagId,
            "status": status
        ]
        
        if let reason = reason {
            body["reason"] = reason
        }
        
        return try await makeRequest(
            endpoint: "/nfc-tags/deactivate",
            method: .PUT,
            body: body,
            responseType: DeactivateNFCTagResponse.self
        )
    }
    
    // MARK: - WebAuthn APIs (Universal for all user types)
    
    func getWebAuthnRegistrationOptions(
        userId: String,
        deviceName: String
    ) async throws -> RegistrationOptionsResponse {
        let body = [
            "userId": userId,
            "deviceName": deviceName
        ]
        
        return try await makeRequest(
            endpoint: "/webauthn/registration/options",
            method: .POST,
            body: body,
            responseType: RegistrationOptionsResponse.self
        )
    }
    
    func verifyWebAuthnRegistration(
        userId: String,
        credential: ASAuthorizationPlatformPublicKeyCredentialRegistration,
        deviceName: String
    ) async throws -> Bool {
        // Convert credential to JSON format
        let credentialJSON: [String: Any] = [
            "id": credential.credentialID.base64URLEncodedString(),
            "rawId": credential.credentialID.base64URLEncodedString(),
            "type": "public-key",
            "response": [
                "clientDataJSON": credential.rawClientDataJSON.base64URLEncodedString(),
                "attestationObject": credential.rawAttestationObject?.base64URLEncodedString() ?? "",
                "transports": ["internal"]
            ]
        ]
        
        let body: [String: Any] = [
            "userId": userId,
            "credential": credentialJSON,
            "deviceName": deviceName
        ]
        
        let response: WebAuthnVerifyResponse = try await makeRequest(
            endpoint: "/webauthn/registration/verify",
            method: .POST,
            body: body,
            responseType: WebAuthnVerifyResponse.self
        )
        
        return response.verified
    }
    
    func getWebAuthnAuthenticationOptions(userId: String) async throws -> AuthenticationOptionsResponse {
        let body = ["userId": userId]
        
        return try await makeRequest(
            endpoint: "/webauthn/authentication/options",
            method: .POST,
            body: body,
            responseType: AuthenticationOptionsResponse.self
        )
    }
    
    func verifyWebAuthnAuthentication(
        userId: String,
        assertion: ASAuthorizationPlatformPublicKeyCredentialAssertion
    ) async throws -> WebAuthnAuthResult {
        // Convert assertion to JSON format
        let assertionJSON: [String: Any] = [
            "id": assertion.credentialID.base64URLEncodedString(),
            "rawId": assertion.credentialID.base64URLEncodedString(),
            "type": "public-key",
            "response": [
                "clientDataJSON": assertion.rawClientDataJSON.base64URLEncodedString(),
                "authenticatorData": assertion.rawAuthenticatorData.base64URLEncodedString(),
                "signature": assertion.signature.base64URLEncodedString(),
                "userHandle": assertion.userID?.base64URLEncodedString() ?? ""
            ]
        ]
        
        let body: [String: Any] = [
            "userId": userId,
            "credential": assertionJSON
        ]
        
        return try await makeRequest(
            endpoint: "/webauthn/authentication/verify",
            method: .POST,
            body: body,
            responseType: WebAuthnAuthResult.self
        )
    }
}

// MARK: - HTTP Methods
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .networkError:
            return "Network error occurred"
        }
    }
}

// MARK: - Data Models

struct LinkDeviceResponse: Codable {
    let success: Bool
    let data: LinkDeviceData
    let message: String
}

struct LinkDeviceData: Codable {
    let student: StudentInfo
    let deviceId: String
    let linkedAt: String
    let accessStatus: String
}

struct StudentInfo: Codable {
    let id: String
    let name: String
    let email: String?
    let phoneNumber: String?
    let room: RoomInfo?
    let pg: PGInfo
}

struct RoomInfo: Codable {
    let id: String
    let number: String
    let type: String
}

struct PGInfo: Codable {
    let id: String
    let name: String
    let address: String?
}

struct BiometricSetupResponse: Codable {
    let success: Bool
    let data: BiometricSetupData
    let message: String
}

struct BiometricSetupData: Codable {
    let student: StudentInfo
    let biometric: BiometricInfo
    let accessStatus: String
    let nextStep: String
}

struct BiometricInfo: Codable {
    let enabled: Bool
    let method: String
    let setupAt: String
}

struct BiometricStatusResponse: Codable {
    let success: Bool
    let data: BiometricStatusData
}

struct BiometricStatusData: Codable {
    let biometricEnabled: Bool
    let biometricMethod: String?
    let biometricSetupAt: String?
    let accessStatus: String
}

struct CheckInOutResponse: Codable {
    let success: Bool
    let data: CheckInOutData
    let message: String
}

struct CheckInOutData: Codable {
    let studentId: String
    let type: String
    let method: String
    let timestamp: String
    let location: LocationInfo?
}

// MARK: - Biometric Verification Response Models

struct BiometricVerificationResponse: Codable {
    let success: Bool
    let verified: Bool
    let confidence: Double?
    let data: BiometricVerificationData?
    let error: String?
    let message: String?
}

struct BiometricVerificationData: Codable {
    let studentId: String
    let studentName: String
    let room: RoomInfo?
    let pg: PGInfo
    let verificationMetadata: VerificationMetadata
}

struct VerificationMetadata: Codable {
    let confidence: Double
    let similarity: Double
    let deviceMatch: Bool
    let biometricType: String
    let verificationMethod: String
    let timestamp: String
    let ipAddress: String?
    let userAgent: String?
}

struct VerificationStatusResponse: Codable {
    let success: Bool
    let data: VerificationStatusData
}

struct VerificationStatusData: Codable {
    let studentId: String
    let studentName: String
    let biometricEnabled: Bool
    let accessStatus: String
    let biometricMethod: String?
    let biometricSetupAt: String?
    let recentVerifications: [RecentVerification]
}

struct RecentVerification: Codable {
    let action: String
    let timestamp: String
    let confidence: Double?
    let success: Bool
}

struct LocationInfo: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
}

// MARK: - Input Models

struct BiometricData {
    let method: String
    let template: String
    let quality: Int
    let attempts: Int
}

struct LocationData {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
}

enum CheckInMethod: String, CaseIterable {
    case nfcTag = "NFC_TAG"
    case qrCode = "QR_CODE"
    case manualManager = "MANUAL_MANAGER"
    case geofenceAuto = "GEOFENCE_AUTO"
}

// MARK: - Staff Response Models

struct LinkStaffDeviceResponse: Codable {
    let success: Bool
    let data: LinkStaffDeviceData
    let message: String
}

struct LinkStaffDeviceData: Codable {
    let staff: StaffInfo
    let deviceId: String
    let linkedAt: String
    let accessStatus: String
}

struct StaffInfo: Codable {
    let id: String
    let name: String
    let email: String?
    let phoneNumber: String?
    let role: String
    let pg: PGInfo
}

// MARK: - Deboarding Response Models

struct DeboardResponse: Codable {
    let success: Bool
    let message: String
    let data: DeboardData?
}

struct DeboardData: Codable {
    let studentId: String?
    let staffId: String?
    let deboardedAt: String?
    let terminatedAt: String?
    let historyRecordId: String?
}

// MARK: - NFC Tag Response Models

struct GenerateNFCTagResponse: Codable {
    let success: Bool
    let message: String
    let data: GenerateNFCTagData
}

struct GenerateNFCTagData: Codable {
    let tag: NFCTagInfo
    let tagUUID: String
    let writePassword: String
    let room: RoomInfo
    let pg: PGInfo
}

struct NFCTagInfo: Codable {
    let id: String
    let tagId: String
    let pgId: String
    let roomId: String?
    let status: String
    let passwordSet: Bool
    let lastScannedAt: String?
    let createdAt: String
    let updatedAt: String?
    let room: RoomInfo?
}

struct ConfirmTagLockedResponse: Codable {
    let success: Bool
    let message: String
    let data: ConfirmTagLockedData
}

struct ConfirmTagLockedData: Codable {
    let tagId: String
    let passwordSet: Bool
    let status: String
}

struct NFCTagsListResponse: Codable {
    let success: Bool
    let data: [NFCTagInfo]
    let total: Int
}

struct UpdateNFCTagResponse: Codable {
    let success: Bool
    let message: String
    let data: NFCTagInfo
}

struct TagPasswordResponse: Codable {
    let success: Bool
    let data: TagPasswordData
}

struct TagPasswordData: Codable {
    let tagId: String
    let password: String
    let passwordSet: Bool
}

struct DeactivateNFCTagResponse: Codable {
    let success: Bool
    let message: String
    let data: DeactivateNFCTagData
}

struct DeactivateNFCTagData: Codable {
    let tagId: String
    let status: String
    let roomNumber: String?
    let reason: String?
    let deactivatedAt: String
}

// MARK: - WebAuthn Response Models

struct RegistrationOptionsResponse: Codable {
    let success: Bool
    let options: RegistrationOptions
}

struct WebAuthnVerifyResponse: Codable {
    let success: Bool
    let verified: Bool
    let message: String
    let data: WebAuthnCredentialData?
    
    struct WebAuthnCredentialData: Codable {
        let credentialId: String
        let deviceName: String?
        let createdAt: String
    }
}

struct AuthenticationOptionsResponse: Codable {
    let success: Bool
    let options: AuthenticationOptions
}

struct WebAuthnAuthResult: Codable {
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

// MARK: - Multi-PG Response Models

struct UserPGsResponse: Codable {
    let success: Bool
    let data: UserPGsData
    
    struct UserPGsData: Codable {
        let userId: String
        let userName: String
        let email: String
        let role: String
        let isAppAdmin: Bool
        let primaryPg: PrimaryPG?
        let pgs: [UserPG]
        let totalPGs: Int
    }
    
    struct PrimaryPG: Codable {
        let id: String
        let name: String
    }
}

struct UserPG: Codable, Identifiable {
    let id: String
    let name: String
    let address: String?
    let status: String
    let role: String
    let isPrimary: Bool
    let isActive: Bool
    let joinedAt: String?
    let accessType: String?
}

struct SwitchPGResponse: Codable {
    let success: Bool
    let message: String
    let data: SwitchPGData?
    
    struct SwitchPGData: Codable {
        let userId: String
        let newPgId: String
        let newPgName: String
        let previousPgId: String?
        let switchedAt: String
    }
}

// MARK: - User/Member Management Response Models

struct CreateUserResponse: Codable {
    let success: Bool
    let userId: String
    let message: String
    let requiresInvite: Bool
    let userRole: String
}

struct GenerateInviteResponse: Codable {
    let success: Bool
    let data: InviteData
    let message: String
    
    struct InviteData: Codable {
        let inviteCode: String
        let qrCode: String
        let deepLink: String
        let expiresAt: String
        let user: InviteUser
    }
    
    struct InviteUser: Codable {
        let id: String
        let name: String
        let email: String
        let role: String
    }
}

struct InviteStatusResponse: Codable {
    let success: Bool
    let hasInvite: Bool
    let data: InviteStatusData?
    let message: String?
    
    struct InviteStatusData: Codable {
        let inviteCode: String
        let qrCode: String?
        let deepLink: String?
        let expiresAt: String
        let usedAt: String?
        let isExpired: Bool
        let isUsed: Bool
        let user: InviteUser
    }
    
    struct InviteUser: Codable {
        let id: String
        let name: String
        let email: String
        let role: String
    }
}

struct UsersListResponse: Codable {
    let success: Bool
    let users: [UserListItem]
    let count: Int
}

struct UserListItem: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let phone: String?
    let role: String
    let status: String
    let accessStatus: String?
    let inviteStatus: InviteStatus?
    let createdAt: String
    let updatedAt: String
}

struct InviteStatus: Codable {
    let hasInvite: Bool
    let inviteCode: String?
    let isUsed: Bool
    let isExpired: Bool
    let expiresAt: String?
}

