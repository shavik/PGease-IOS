//
//  PermissionManager.swift
//  PGEase
//
//  Role-based permission helpers for user management
//

import Foundation

class PermissionManager {
    
    // MARK: - User Role Enum (matching backend)
    
    enum UserRole: String, CaseIterable {
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
        
        var icon: String {
            switch self {
            case .student: return "graduationcap.fill"
            case .staff: return "figure.walk"
            case .manager: return "person.badge.key.fill"
            case .warden: return "shield.fill"
            case .accountant: return "dollarsign.circle.fill"
            case .pgAdmin: return "crown.fill"
            case .vendor: return "cart.fill"
            case .appAdmin: return "gear"
            }
        }
    }
    
    // MARK: - Permission Checks
    
    /// Which roles can the current user create?
    static func getAllowedRolesToCreate(for userRole: UserRole) -> [UserRole] {
        switch userRole {
        case .pgAdmin:
            return [.manager, .warden, .accountant, .staff, .student]
        case .manager, .warden:
            return [.staff, .student]
        default:
            return []
        }
    }
    
    /// Can current user create this role?
    static func canCreate(role: UserRole, currentUserRole: UserRole) -> Bool {
        return getAllowedRolesToCreate(for: currentUserRole).contains(role)
    }
    
    /// Can current user create this role (string version)
    static func canCreateRole(_ roleString: String, currentUserRole: UserRole) -> Bool {
        guard let role = UserRole(rawValue: roleString.uppercased()) else {
            return false
        }
        return canCreate(role: role, currentUserRole: currentUserRole)
    }
    
    /// Get roles that current user can invite/create (as strings for API)
    static func getAllowedRoleStrings(for userRole: UserRole) -> [String] {
        return getAllowedRolesToCreate(for: userRole).map { $0.rawValue }
    }
    
    /// Get roles that current user can invite/create (for picker display)
    static func getAllowedRolesForPicker(for userRole: UserRole) -> [(role: UserRole, display: String)] {
        return getAllowedRolesToCreate(for: userRole).map { 
            (role: $0, display: $0.displayName)
        }
    }
    
    // MARK: - Role-Specific Permissions
    
    /// Can manage NFC tags (write)
    static func canManageNFCTags(role: UserRole) -> Bool {
        return role == .pgAdmin || role == .manager
    }
    
    /// Can view NFC tags (read)
    static func canViewNFCTags(role: UserRole) -> Bool {
        return role == .pgAdmin || role == .manager || role == .warden
    }
    
    /// Can approve onboarding
    static func canApproveOnboarding(role: UserRole) -> Bool {
        return role == .pgAdmin || role == .manager
    }
    
    /// Can collect payments
    static func canCollectPayments(role: UserRole) -> Bool {
        return role == .pgAdmin || role == .manager || role == .accountant
    }
    
    /// Can view all attendance
    static func canViewAllAttendance(role: UserRole) -> Bool {
        return role == .pgAdmin || role == .manager || role == .warden
    }
    
    /// Can generate reports
    static func canGenerateReports(role: UserRole) -> Bool {
        return role == .pgAdmin || role == .manager || role == .warden || role == .accountant
    }
    
    /// Can manage rooms
    static func canManageRooms(role: UserRole) -> Bool {
        return role == .pgAdmin || role == .manager
    }
    
    /// Can invite users/members
    static func canInviteUsers(role: UserRole) -> Bool {
        return !getAllowedRolesToCreate(for: role).isEmpty
    }
    
    // MARK: - Helper Methods
    
    /// Get role from string (case-insensitive)
    static func roleFromString(_ string: String) -> UserRole? {
        return UserRole(rawValue: string.uppercased())
    }
    
    /// Get all available roles (for reference)
    static func allRoles() -> [UserRole] {
        return UserRole.allCases
    }
    
    /// Get role description
    static func getRoleDescription(_ role: UserRole) -> String {
        switch role {
        case .student:
            return "Lives in PG, checks in/out daily"
        case .staff:
            return "Works in PG (cook, cleaner, etc.)"
        case .manager:
            return "Manages daily operations"
        case .warden:
            return "Handles security & attendance"
        case .accountant:
            return "Manages finances & payments"
        case .pgAdmin:
            return "PG owner/super admin"
        case .vendor:
            return "Delivery partner"
        case .appAdmin:
            return "Platform administrator"
        }
    }
}

