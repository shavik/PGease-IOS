import Foundation
import SwiftUI

/// Manager for authentication and role-based access control
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: CurrentUser?
    @Published var userRole: UserRole = .student
    @Published var errorMessage: String?
    
    private let apiManager = APIManager.shared
    
    // MARK: - User Role
    
    enum UserRole: String {
        case student = "STUDENT"
        case staff = "STAFF"
        case manager = "MANAGER"
        case warden = "WARDEN"
        case accountant = "ACCOUNTANT"
        case pgAdmin = "PGADMIN"
        case vendor = "VENDOR"
        
        var displayName: String {
            switch self {
            case .student: return "Student"
            case .staff: return "Staff"
            case .manager: return "Manager"
            case .warden: return "Warden"
            case .accountant: return "Accountant"
            case .pgAdmin: return "PG Admin"
            case .vendor: return "Vendor"
            }
        }
        
        // Role-based permissions
        var canManageStudents: Bool {
            return [.manager, .pgAdmin, .warden].contains(self)
        }
        
        var canManageStaff: Bool {
            return [.manager, .pgAdmin].contains(self)
        }
        
        var canManageNFCTags: Bool {
            return [.manager, .pgAdmin].contains(self)
        }
        
        var canViewReports: Bool {
            return [.manager, .pgAdmin, .warden, .accountant].contains(self)
        }
        
        var canManageRooms: Bool {
            return [.manager, .pgAdmin].contains(self)
        }
        
        var canManageFinances: Bool {
            return [.accountant, .pgAdmin].contains(self)
        }
        
        var canAccessCheckIn: Bool {
            return [.student, .staff].contains(self)
        }
    }
    
    // MARK: - Current User
    
    struct CurrentUser: Codable {
        let id: String
        let name: String
        let email: String?
        let phoneNumber: String?
        let role: String
        let pgId: String
        let pgName: String
        let profileId: String? // StudentProfile or StaffProfile ID
        let roomNumber: String?
        let deviceId: String?
        let biometricSetup: Bool
        let accessStatus: String
    }
    
    // MARK: - Initialization
    
    init() {
        loadSavedUser()
    }
    
    // MARK: - Authentication
    
    func loadSavedUser() {
        // Load user from UserDefaults
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(CurrentUser.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = true
            self.userRole = UserRole(rawValue: user.role) ?? .student
        }
    }
    
    func saveUser(_ user: CurrentUser) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "currentUser")
            self.currentUser = user
            self.isAuthenticated = true
            self.userRole = UserRole(rawValue: user.role) ?? .student
        }
    }
    
    func logout() {
        // Clear all user data
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "studentId")
        UserDefaults.standard.removeObject(forKey: "staffId")
        UserDefaults.standard.removeObject(forKey: "userType")
        UserDefaults.standard.removeObject(forKey: "deviceId")
        UserDefaults.standard.removeObject(forKey: "biometricSetupComplete")
        UserDefaults.standard.removeObject(forKey: "isCheckedIn")
        
        self.currentUser = nil
        self.isAuthenticated = false
        self.userRole = .student
    }
    
    // MARK: - Role Detection
    
    func detectUserRole() -> UserRole {
        if let userType = UserDefaults.standard.string(forKey: "userType") {
            return UserRole(rawValue: userType) ?? .student
        }
        
        // Fallback: check if studentId or staffId exists
        if UserDefaults.standard.string(forKey: "studentId") != nil {
            return .student
        } else if UserDefaults.standard.string(forKey: "staffId") != nil {
            // For staff, we need to determine their specific role
            // This would typically come from the API
            return .staff
        }
        
        return .student
    }
    
    func updateUserRole(_ role: UserRole) {
        self.userRole = role
        UserDefaults.standard.set(role.rawValue, forKey: "userType")
    }
    
    // MARK: - Fetch User Profile
    
    func fetchUserProfile() async {
        do {
            let userType = detectUserRole()
            
            if userType == .student {
                guard let studentId = UserDefaults.standard.string(forKey: "studentId") else {
                    await MainActor.run {
                        self.errorMessage = "Student ID not found"
                    }
                    return
                }
                
                // Fetch student profile from API
                // let response = try await apiManager.getStudentProfile(studentId: studentId)
                // Update currentUser with response data
                
            } else {
                guard let staffId = UserDefaults.standard.string(forKey: "staffId") else {
                    await MainActor.run {
                        self.errorMessage = "Staff ID not found"
                    }
                    return
                }
                
                // Fetch staff profile from API
                // let response = try await apiManager.getStaffProfile(staffId: staffId)
                // Update currentUser with response data
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Permission Checks
    
    func hasPermission(for feature: AppFeature) -> Bool {
        switch feature {
        case .checkIn:
            return userRole.canAccessCheckIn
        case .manageStudents:
            return userRole.canManageStudents
        case .manageStaff:
            return userRole.canManageStaff
        case .manageNFCTags:
            return userRole.canManageNFCTags
        case .viewReports:
            return userRole.canViewReports
        case .manageRooms:
            return userRole.canManageRooms
        case .manageFinances:
            return userRole.canManageFinances
        }
    }
    
    // MARK: - App Features
    
    enum AppFeature {
        case checkIn
        case manageStudents
        case manageStaff
        case manageNFCTags
        case viewReports
        case manageRooms
        case manageFinances
    }
    
    // MARK: - Session Validation
    
    func validateSession() async -> Bool {
        // Check if device is still linked and active
        guard let deviceId = UserDefaults.standard.string(forKey: "deviceId") else {
            return false
        }
        
        // Validate with backend
        // This would call an API endpoint to verify the session
        // For now, just check if user data exists
        return currentUser != nil
    }
    
    // MARK: - Deboarding Check
    
    func checkDeboardingStatus() async -> Bool {
        // Check if user has been deboarded
        // This would call an API endpoint to check status
        // Return true if user is still active, false if deboarded
        return true
    }
}

// MARK: - View Extension for Role-Based Access

extension View {
    func requiresRole(_ role: AuthManager.UserRole) -> some View {
        self.modifier(RoleRequirementModifier(requiredRole: role))
    }
    
    func requiresPermission(_ feature: AuthManager.AppFeature) -> some View {
        self.modifier(PermissionRequirementModifier(requiredFeature: feature))
    }
}

struct RoleRequirementModifier: ViewModifier {
    @EnvironmentObject var authManager: AuthManager
    let requiredRole: AuthManager.UserRole
    
    func body(content: Content) -> some View {
        if authManager.userRole == requiredRole {
            content
        } else {
            VStack {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("Access Denied")
                    .font(.title)
                    .fontWeight(.bold)
                Text("You don't have permission to access this feature")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
        }
    }
}

struct PermissionRequirementModifier: ViewModifier {
    @EnvironmentObject var authManager: AuthManager
    let requiredFeature: AuthManager.AppFeature
    
    func body(content: Content) -> some View {
        if authManager.hasPermission(for: requiredFeature) {
            content
        } else {
            VStack {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("Access Denied")
                    .font(.title)
                    .fontWeight(.bold)
                Text("You don't have permission to access this feature")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
        }
    }
}

