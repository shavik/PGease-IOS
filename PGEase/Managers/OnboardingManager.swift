import Foundation
import SwiftUI
import LocalAuthentication

// MARK: - Supporting Types

struct TemplateComponents {
    let biometricType: String
    let deviceIdentifier: String
    let timestamp: String
    let biometricCharacteristics: String
    let salt: String
    
    init(biometricType: String = "", deviceIdentifier: String = "", timestamp: String = "", biometricCharacteristics: String = "", salt: String = "") {
        self.biometricType = biometricType
        self.deviceIdentifier = deviceIdentifier
        self.timestamp = timestamp
        self.biometricCharacteristics = biometricCharacteristics
        self.salt = salt
    }
}

class OnboardingManager: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var studentInfo: StudentInfo?
    @Published var staffInfo: StaffInfo?
    @Published var isOnboardingComplete = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    // Onboarding state
    @Published var inviteCode: String = ""
    @Published var deviceId: String = ""
    @Published var biometricData: BiometricData?
    @Published var accessStatus: String = "PENDING"
    @Published var userType: UserType = .student // STUDENT or STAFF
    
    private let apiManager = APIManager.shared
    private let biometricAuthManager = BiometricAuthManager()
    private let webAuthnManager = WebAuthnManager()
    
    init() {
        generateDeviceId()
        checkExistingOnboarding()
    }
    
    // MARK: - Device Management
    
    private func generateDeviceId() {
        if let existingId = UserDefaults.standard.string(forKey: "deviceId") {
            deviceId = existingId
        } else {
            deviceId = UUID().uuidString
            UserDefaults.standard.set(deviceId, forKey: "deviceId")
        }
    }
    
    private func checkExistingOnboarding() {
        if let studentId = UserDefaults.standard.string(forKey: "studentId") {
            // Student is already onboarded, check status
            Task {
                await checkOnboardingStatus(studentId: studentId)
            }
        }
    }
    
    // MARK: - Onboarding Flow
    
    func startOnboarding() {
        currentStep = .enterInviteCode
        errorMessage = nil
    }
    
    func enterInviteCode(_ code: String) {
        inviteCode = code.uppercased()
        currentStep = .linkingDevice
    }
    
    func linkDevice() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            if userType == .student {
                // Student onboarding
                let response = try await apiManager.linkDevice(
                    inviteCode: inviteCode,
                    deviceId: deviceId
                )
                
                await MainActor.run {
                    self.studentInfo = response.data.student
                    self.accessStatus = response.data.accessStatus
                    self.isLoading = false
                    
                    // Save student ID and user type
                    UserDefaults.standard.set(response.data.student.id, forKey: "studentId")
                    UserDefaults.standard.set("STUDENT", forKey: "userType")
                    
                    // Move to next step based on access status
                    switch response.data.accessStatus {
                    case "PENDING_BIOMETRIC":
                        self.currentStep = .setupBiometric
                    case "ACTIVE":
                        self.completeOnboarding()
                    default:
                        self.currentStep = .waitingForApproval
                    }
                }
            } else {
                // Staff onboarding
                let response = try await apiManager.linkStaffDevice(
                    inviteCode: inviteCode,
                    deviceId: deviceId
                )
                
                await MainActor.run {
                    self.staffInfo = response.data.staff
                    self.accessStatus = response.data.accessStatus
                    self.isLoading = false
                    
                    // Save staff ID and user type
                    UserDefaults.standard.set(response.data.staff.id, forKey: "staffId")
                    UserDefaults.standard.set("STAFF", forKey: "userType")
                    
                    // Move to next step based on access status
                    switch response.data.accessStatus {
                    case "PENDING_BIOMETRIC":
                        self.currentStep = .setupBiometric
                    case "ACTIVE":
                        self.completeOnboarding()
                    default:
                        self.currentStep = .waitingForApproval
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func setupBiometric() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // ✅ NEW: Register WebAuthn passkey (works for ALL user types)
            let userId: String?
            
            if userType == .student {
                userId = studentInfo?.id
            } else {
                userId = staffInfo?.id
            }
            
            guard let userId = userId else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "User ID not found"
                }
                return
            }
            
            // ✅ Register passkey with Face ID/Touch ID
            let success = await webAuthnManager.registerPasskey(
                userId: userId,
                deviceName: UIDevice.current.name
            )
            
            if success {
                await MainActor.run {
                    self.isLoading = false
                    
                    // Save WebAuthn setup
                    UserDefaults.standard.set(true, forKey: "webAuthnSetupComplete")
                    UserDefaults.standard.set(userId, forKey: "userId")
                    
                    // Check if approval is needed (for STUDENT/STAFF)
                    if userType == .student || userType == .staff {
                        self.currentStep = .waitingForApproval
                        self.accessStatus = "PENDING_APPROVAL"
                    } else {
                        // Managers/Admins are auto-approved
                        self.accessStatus = "ACTIVE"
                        self.completeOnboarding()
                    }
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to setup biometric authentication"
                }
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func checkOnboardingStatus(studentId: String) async {
        do {
            let response = try await apiManager.getBiometricStatus(studentId: studentId)
            
            await MainActor.run {
                self.accessStatus = response.data.accessStatus
                
                if response.data.accessStatus == "ACTIVE" {
                    self.completeOnboarding()
                } else if response.data.accessStatus == "PENDING_APPROVAL" {
                    self.currentStep = .waitingForApproval
                }
            }
            
        } catch {
            print("Failed to check onboarding status: \(error)")
        }
    }
    
    func completeOnboarding() {
        currentStep = .completed
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
    }
    
    func resetOnboarding() {
        currentStep = .welcome
        studentInfo = nil
        isOnboardingComplete = false
        errorMessage = nil
        inviteCode = ""
        biometricData = nil
        accessStatus = "PENDING"
        
        // Clear stored data
        UserDefaults.standard.removeObject(forKey: "studentId")
        UserDefaults.standard.removeObject(forKey: "biometricSetupComplete")
        UserDefaults.standard.removeObject(forKey: "onboardingComplete")
    }
    
    // MARK: - Biometric Verification
    
    /// Verifies if the current user matches the enrolled biometric signature (Server-side verification)
    func verifyBiometricIdentity(studentId: String, location: LocationData? = nil) async -> (isVerified: Bool, confidence: Double, error: String?) {
        // Generate current verification signature
        let verificationSignature = generateVerificationSignature()
        
        do {
            // Send verification signature to server for comparison
            let response = try await apiManager.verifyBiometric(
                studentId: studentId,
                verificationTemplate: verificationSignature,
                deviceId: deviceId,
                location: location,
                checkInMethod: "BIOMETRIC_VERIFICATION"
            )
            
            print("🔐 Server-Side Biometric Signature Verification:")
            print("   Response: \(response)")
            print("   Verified: \(response.verified)")
            print("   Confidence: \(response.confidence ?? 0)%")
            
            return (
                isVerified: response.verified,
                confidence: response.confidence ?? 0.0,
                error: response.error
            )
            
        } catch {
            print("🔐 Biometric Verification Error: \(error.localizedDescription)")
            return (
                isVerified: false,
                confidence: 0.0,
                error: error.localizedDescription
            )
        }
    }
    
    // MARK: - Helper Methods
    
    // MARK: - Biometric Template Generation
    
    /// Generates a public signature during enrollment (stored permanently)
    private func generateEnrollmentSignature() -> String {
        let biometricType = biometricAuthManager.biometricType
        let deviceId = deviceId
        let studentId = studentInfo?.id ?? ""
        
        // Generate biometric hash (simulated - in production, use actual biometric data)
        let biometricHash = generateBiometricHash(
            biometricType: biometricType,
            deviceId: deviceId,
            studentId: studentId
        )
        
        // Generate device signature (consistent for this device)
        let deviceSignature = generateDeviceSignature(deviceId: deviceId)
        
        // Generate student signature (consistent for this student)
        let studentSignature = generateStudentSignature(studentId: studentId)
        
        // Generate enrollment signature (consistent for this enrollment - no timestamp!)
        let enrollmentSignature = generateEnrollmentSignature(
            biometricHash: biometricHash,
            deviceId: deviceId,
            studentId: studentId
        )
        
        // Combine all signatures
        let publicSignature = "SIG_\(deviceSignature)_\(studentSignature)_\(enrollmentSignature)_\(biometricHash)"
        
        return publicSignature
    }
    
    /// Generates a verification signature for comparison (generated each time)
    private func generateVerificationSignature() -> String {
        let biometricType = biometricAuthManager.biometricType
        let deviceId = deviceId
        let studentId = studentInfo?.id ?? ""
        
        // Generate biometric hash (simulated - in production, use actual biometric data)
        let biometricHash = generateBiometricHash(
            biometricType: biometricType,
            deviceId: deviceId,
            studentId: studentId
        )
        
        // Generate device signature (should match enrollment)
        let deviceSignature = generateDeviceSignature(deviceId: deviceId)
        
        // Generate student signature (should match enrollment)
        let studentSignature = generateStudentSignature(studentId: studentId)
        
        // Generate verification signature (consistent - no timestamp!)
        let verificationSignature = generateVerificationSignature(
            biometricHash: biometricHash,
            deviceId: deviceId,
            studentId: studentId
        )
        
        // Combine all signatures
        let publicSignature = "SIG_\(deviceSignature)_\(studentSignature)_\(verificationSignature)_\(biometricHash)"
        
        return publicSignature
    }
    
    /// Compares enrollment template with verification template
    private func compareBiometricTemplates(
        enrollmentTemplate: String,
        verificationTemplate: String
    ) -> Double {
        // Parse both templates
        let enrollmentComponents = parseTemplate(enrollmentTemplate)
        let verificationComponents = parseTemplate(verificationTemplate)
        
        // Compare device identifiers (must match)
        guard enrollmentComponents.deviceIdentifier == verificationComponents.deviceIdentifier else {
            return 0.0 // Different device
        }
        
        // Compare biometric characteristics
        let biometricSimilarity = compareBiometricCharacteristics(
            enrollment: enrollmentComponents.biometricCharacteristics,
            verification: verificationComponents.biometricCharacteristics
        )
        
        // Compare biometric types
        let typeMatch = enrollmentComponents.biometricType == verificationComponents.biometricType ? 1.0 : 0.0
        
        // Calculate overall similarity (weighted)
        return (biometricSimilarity * 0.8) + (typeMatch * 0.2)
    }
    
    // MARK: - Public Signature Generation Functions
    
    private func generateBiometricHash(biometricType: LABiometryType, deviceId: String, studentId: String) -> String {
        // Generate a consistent biometric hash based on device and student
        // In production, this would use actual biometric data from Face ID/Touch ID
        let biometricData = "\(biometricType.rawValue)_\(deviceId)_\(studentId)_BIOMETRIC_PGEASE"
        return generateSHA256Hash(biometricData)
    }
    
    private func generateDeviceSignature(deviceId: String) -> String {
        // Generate device signature (consistent for this device)
        let deviceData = "\(deviceId)_PGEASE_DEVICE_SIGNATURE"
        return generateSHA256Hash(deviceData)
    }
    
    private func generateStudentSignature(studentId: String) -> String {
        // Generate student signature (consistent for this student)
        let studentData = "\(studentId)_PGEASE_STUDENT_SIGNATURE"
        return generateSHA256Hash(studentData)
    }
    
    private func generateEnrollmentSignature(biometricHash: String, deviceId: String, studentId: String) -> String {
        // Generate enrollment signature (consistent for this enrollment)
        let enrollmentData = "ENROLL_\(biometricHash)_\(deviceId)_\(studentId)_PGEASE"
        return generateSHA256Hash(enrollmentData)
    }
    
    private func generateVerificationSignature(biometricHash: String, deviceId: String, studentId: String) -> String {
        // Generate verification signature (consistent for this user/device)
        let verificationData = "VERIFY_\(biometricHash)_\(deviceId)_\(studentId)_PGEASE"
        return generateSHA256Hash(verificationData)
    }
    
    private func generateSHA256Hash(_ input: String) -> String {
        // Generate SHA-256 hash (in production, use proper crypto library)
        let data = input.data(using: .utf8) ?? Data()
        
        // Simple hash function (replace with proper SHA-256 in production)
        var hash = 0
        for byte in data {
            hash = ((hash << 5) &- hash) &+ Int(byte)
        }
        
        // Generate 8-character hex hash
        return String(format: "%08X", abs(hash))
    }
    
    private func generateBiometricCharacteristics(for biometricType: LABiometryType) -> String {
        // Generate consistent biometric characteristics based on device and user
        // In a real implementation, this would be based on actual biometric data
        
        switch biometricType {
        case .faceID:
            // Simulate face characteristics (consistent for same person on same device)
            let faceHash = generateFaceCharacteristics()
            return "FACE_\(faceHash)"
        case .touchID:
            // Simulate fingerprint characteristics
            let fingerprintHash = generateFingerprintCharacteristics()
            return "FINGER_\(fingerprintHash)"
        case .none:
            return "NONE_00000000"
        @unknown default:
            return "UNKNOWN_00000000"
        }
    }
    
    private func generateFaceCharacteristics() -> String {
        // Generate consistent face characteristics based on device ID
        // In reality, this would be based on actual facial recognition data
        let deviceHash = generateDeviceIdentifier(deviceId: deviceId)
        let faceData = "\(deviceHash)_FACE_CHARACTERISTICS"
        
        var hash = 0
        for byte in faceData.data(using: .utf8) ?? Data() {
            hash = ((hash << 5) &- hash) &+ Int(byte)
        }
        
        return String(format: "%08X", abs(hash))
    }
    
    private func generateFingerprintCharacteristics() -> String {
        // Generate consistent fingerprint characteristics based on device ID
        let deviceHash = generateDeviceIdentifier(deviceId: deviceId)
        let fingerprintData = "\(deviceHash)_FINGERPRINT_CHARACTERISTICS"
        
        var hash = 0
        for byte in fingerprintData.data(using: .utf8) ?? Data() {
            hash = ((hash << 5) &- hash) &+ Int(byte)
        }
        
        return String(format: "%08X", abs(hash))
    }
    
    private func generateEnrollmentSalt() -> String {
        // Generate a consistent salt for enrollment (stored with template)
        let saltData = "\(deviceId)_ENROLLMENT_SALT_PGEASE"
        
        var hash = 0
        for byte in saltData.data(using: .utf8) ?? Data() {
            hash = ((hash << 5) &- hash) &+ Int(byte)
        }
        
        return String(format: "%08X", abs(hash))
    }
    
    private func generateVerificationSalt() -> String {
        // Generate a random salt for verification (changes each time)
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let saltLength = 12
        var salt = ""
        
        for _ in 0..<saltLength {
            let randomIndex = Int.random(in: 0..<characters.count)
            let character = characters[characters.index(characters.startIndex, offsetBy: randomIndex)]
            salt.append(character)
        }
        
        return salt
    }
    
    private func parseTemplate(_ template: String) -> TemplateComponents {
        // Parse template components from encoded template
        guard let decodedTemplate = decodeBiometricTemplate(template) else {
            return TemplateComponents()
        }
        
        let components = decodedTemplate.components(separatedBy: "_")
        
        return TemplateComponents(
            biometricType: components.first ?? "",
            deviceIdentifier: components.count > 1 ? components[1] : "",
            timestamp: components.count > 2 ? components[2] : "",
            biometricCharacteristics: components.count > 3 ? components[3] : "",
            salt: components.count > 4 ? components[4] : ""
        )
    }
    
    private func compareBiometricCharacteristics(
        enrollment: String,
        verification: String
    ) -> Double {
        // Compare biometric characteristics
        // In a real implementation, this would use sophisticated biometric matching algorithms
        
        if enrollment == verification {
            return 1.0 // Perfect match
        }
        
        // Check if they're from the same device/user (similar characteristics)
        let enrollmentPrefix = String(enrollment.prefix(8))
        let verificationPrefix = String(verification.prefix(8))
        
        if enrollmentPrefix == verificationPrefix {
            return 0.95 // Very high similarity (same device, slight variations)
        }
        
        return 0.0 // No match
    }
    
    private func decodeBiometricTemplate(_ encodedTemplate: String) -> String? {
        // Decode the obfuscated template
        guard let obfuscatedData = Data(base64Encoded: encodedTemplate),
              let obfuscatedString = String(data: obfuscatedData, encoding: .utf8) else {
            return nil
        }
        
        // Reverse the obfuscation
        let obfuscationKey = "PGEASE_BIOMETRIC_2024"
        var decoded = ""
        
        for (index, character) in obfuscatedString.enumerated() {
            let keyIndex = index % obfuscationKey.count
            let keyChar = obfuscationKey[obfuscationKey.index(obfuscationKey.startIndex, offsetBy: keyIndex)]
            let keyValue = Int(keyChar.asciiValue ?? 0)
            let charValue = Int(character.asciiValue ?? 0)
            let decodedValue = (charValue - keyValue + 256) % 256
            decoded.append(Character(UnicodeScalar(decodedValue)!))
        }
        
        // Decode from base64
        guard let finalData = Data(base64Encoded: decoded),
              let finalString = String(data: finalData, encoding: .utf8) else {
            return nil
        }
        
        return finalString
    }
    
    private func generateQualityScore(for biometricType: LABiometryType) -> Int {
        // Generate quality score based on biometric type and device capabilities
        switch biometricType {
        case .faceID:
            // Face ID typically has high quality scores
            return Int.random(in: 85...98)
        case .touchID:
            // Touch ID has good quality scores
            return Int.random(in: 80...95)
        case .none:
            return 0
        @unknown default:
            return 50
        }
    }
    
    private func generateSecuritySalt() -> String {
        // Generate a random security salt
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let saltLength = 16
        var salt = ""
        
        for _ in 0..<saltLength {
            let randomIndex = Int.random(in: 0..<characters.count)
            let character = characters[characters.index(characters.startIndex, offsetBy: randomIndex)]
            salt.append(character)
        }
        
        return salt
    }
    
    private func encodeBiometricTemplate(_ template: String) -> String {
        // Encode the template (simulating biometric data encryption)
        guard let data = template.data(using: .utf8) else {
            return ""
        }
        
        // Base64 encode the template data
        let base64String = data.base64EncodedString()
        
        // Add additional obfuscation layer
        let obfuscated = obfuscateTemplate(base64String)
        
        return obfuscated
    }
    
    private func obfuscateTemplate(_ template: String) -> String {
        // Simple obfuscation (in production, use proper encryption)
        let obfuscationKey = "PGEASE_BIOMETRIC_2024"
        var obfuscated = ""
        
        for (index, character) in template.enumerated() {
            let keyIndex = index % obfuscationKey.count
            let keyChar = obfuscationKey[obfuscationKey.index(obfuscationKey.startIndex, offsetBy: keyIndex)]
            let keyValue = Int(keyChar.asciiValue ?? 0)
            let charValue = Int(character.asciiValue ?? 0)
            let obfuscatedValue = (charValue + keyValue) % 256
            obfuscated.append(Character(UnicodeScalar(obfuscatedValue)!))
        }
        
        return obfuscated.data(using: .utf8)?.base64EncodedString() ?? ""
    }
    
    // Added new helper method as instructed
    private func generateDeviceIdentifier(deviceId: String) -> String {
        // Generate a consistent identifier for the device (hash)
        return generateSHA256Hash(deviceId)
    }
    
    // MARK: - Computed Properties
    
    var isStudentOnboarded: Bool {
        return UserDefaults.standard.bool(forKey: "onboardingComplete")
    }
    
    var currentStudentId: String? {
        return UserDefaults.standard.string(forKey: "studentId")
    }
    
    var isBiometricSetupComplete: Bool {
        return UserDefaults.standard.bool(forKey: "biometricSetupComplete")
    }
    
    // MARK: - User Type
    
    // ✅ Expanded UserType enum to support all 8 roles
    enum UserType: String, CaseIterable {
        case student = "STUDENT"
        case staff = "STAFF"
        case manager = "MANAGER"
        case warden = "WARDEN"
        case accountant = "ACCOUNTANT"
        case pgAdmin = "PGADMIN"
        case vendor = "VENDOR"
        case appAdmin = "APPADMIN"
        
        var displayName: String {
            switch self {
            case .student: return "Student"
            case .staff: return "Staff"
            case .manager: return "Manager"
            case .warden: return "Warden"
            case .accountant: return "Accountant"
            case .pgAdmin: return "PG Admin"
            case .vendor: return "Vendor"
            case .appAdmin: return "App Admin"
            }
        }
        
        var requiresApproval: Bool {
            // Only STUDENT and STAFF need manager approval
            return self == .student || self == .staff
        }
        
        var canHaveMultiplePGs: Bool {
            // Only PGADMIN and VENDOR can be associated with multiple PGs
            return self == .pgAdmin || self == .vendor
        }
    }
}

// MARK: - Onboarding Steps

enum OnboardingStep: CaseIterable {
    case welcome
    case enterInviteCode
    case linkingDevice
    case setupBiometric
    case waitingForApproval
    case completed
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to PGEase"
        case .enterInviteCode:
            return "Enter Invite Code"
        case .linkingDevice:
            return "Linking Device"
        case .setupBiometric:
            return "Setup Biometric Auth"
        case .waitingForApproval:
            return "Waiting for Approval"
        case .completed:
            return "Onboarding Complete"
        }
    }
    
    var description: String {
        switch self {
        case .welcome:
            return "Get started with secure room access"
        case .enterInviteCode:
            return "Enter the invite code provided by your PG manager"
        case .linkingDevice:
            return "Linking your device to your account..."
        case .setupBiometric:
            return "Setup biometric authentication for secure access"
        case .waitingForApproval:
            return "Your manager will approve your access shortly"
        case .completed:
            return "You can now use all PGEase features"
        }
    }
}

