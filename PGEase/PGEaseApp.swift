//
//  PGEaseApp.swift
//  PGEase
//
//  Created by Vikas Sharma on 04/08/25.
//

import SwiftUI

@main
struct PGEaseApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var biometricAuthManager = BiometricAuthManager()
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var checkInOutManager = CheckInOutManager()
    @StateObject private var appRouter = AppRouter()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    // User is authenticated - show role-based main app
                    RoleBasedMainView()
                        .environmentObject(authManager)
                        .environmentObject(biometricAuthManager)
                        .environmentObject(checkInOutManager)
                        .onAppear {
                            print("🚀 App: Main app appeared - User role: \(authManager.userRole.displayName)")
                        }
                } else {
                    // User not authenticated - smart routing
                    SmartLaunchView()
                        .environmentObject(authManager)
                        .environmentObject(biometricAuthManager)
                        .environmentObject(onboardingManager)
                        .environmentObject(appRouter)
                        .onAppear {
                            print("🔀 App: SmartLaunchView - Determining user flow")
                        }
                }
            }
            .onReceive(authManager.$isAuthenticated) { isAuthenticated in
                print("🔄 App: Authentication state changed to: \(isAuthenticated)")
            }
            .onReceive(onboardingManager.$isOnboardingComplete) { isComplete in
                print("🔄 App: Onboarding state changed to: \(isComplete)")
            }
            .onOpenURL { url in
                appRouter.handleDeepLink(url)
            }
        }
    }
}

// MARK: - App Router (Deep Link Handler)

class AppRouter: ObservableObject {
    @Published var pendingInviteCode: String?
    @Published var pendingInviteType: String?
    
    func handleDeepLink(_ url: URL) {
        print("🔗 Deep link received: \(url)")
        
        // Parse: pgease://onboard?code=ABC123&type=student
        guard url.scheme == "pgease",
              url.host == "onboard",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("❌ Invalid deep link format")
            return
        }
        
        pendingInviteCode = queryItems.first(where: { $0.name == "code" })?.value
        pendingInviteType = queryItems.first(where: { $0.name == "type" })?.value
        
        print("✅ Parsed invite - Code: \(pendingInviteCode ?? "nil"), Type: \(pendingInviteType ?? "nil")")
    }
    
    func clearPendingInvite() {
        pendingInviteCode = nil
        pendingInviteType = nil
    }
}

// MARK: - Smart Launch View

struct SmartLaunchView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var appRouter: AppRouter
    
    var body: some View {
        Group {
            if let inviteCode = appRouter.pendingInviteCode,
               let inviteType = appRouter.pendingInviteType {
                // User came via invite deep link → Direct to invite onboarding
                InviteOnboardingView(inviteCode: inviteCode, inviteType: inviteType)
                    .environmentObject(onboardingManager)
                    .environmentObject(authManager)
                    .onAppear {
                        print("🎫 App: Invite onboarding - Code: \(inviteCode), Type: \(inviteType)")
                    }
                    .onDisappear {
                        appRouter.clearPendingInvite()
                    }
            } else if onboardingManager.isOnboardingComplete {
                // User completed onboarding before → Show login
                LoginView()
                    .environmentObject(authManager)
                    .onAppear {
                        print("🔐 App: LoginView - User needs to login")
                    }
            } else {
                // No invite, no previous onboarding → Show login with help text
                LoginView()
                    .environmentObject(authManager)
                    .onAppear {
                        print("🔐 App: LoginView - First time or no invite")
                    }
            }
        }
    }
}

// MARK: - Onboarding Flow View

struct OnboardingFlowView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showRoleSelection = true
    @State private var selectedRole: OnboardingManager.UserType?

    var body: some View {
        if showRoleSelection {
            RoleSelectionView(selectedRole: $selectedRole) {
                onboardingManager.userType = selectedRole!
                authManager.updateUserRole(selectedRole == .student ? .student : .staff)
                showRoleSelection = false
            }.onChange(of: selectedRole) { _ , _ in
                showRoleSelection = false
            }
        } else {
            if selectedRole == .student {
                OnboardingView()
                    .environmentObject(onboardingManager)
            } else {
                StaffOnboardingView()
                    .environmentObject(onboardingManager)
            }
        }
    }
}

// MARK: - Role-Based Main View

struct RoleBasedMainView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var checkInOutManager: CheckInOutManager
    
    var body: some View {
        Group {
            switch authManager.userRole {
            case .student, .staff:
                // Students and Staff see the standard check-in/out interface
                MainTabView()
                    .onAppear {
                        // Set the user type in CheckInOutManager
                        checkInOutManager.userType = authManager.userRole == .student ? "STUDENT" : "STAFF"
                        checkInOutManager.userId = authManager.currentUser?.id
                        checkInOutManager.profileId = authManager.currentUser?.profileId
                    }
                    .onReceive(authManager.$currentUser) { user in
                        checkInOutManager.userId = user?.id
                        checkInOutManager.profileId = user?.profileId
                    }
                
            case .manager, .pgAdmin:
                // Managers and PG Admins see management interface with NFC tag management
                ManagerTabView()
                
            case .warden:
                // Wardens see monitoring interface
                WardenTabView()
                
            case .accountant:
                // Accountants see financial interface
                AccountantTabView()
                
            case .vendor:
                // Vendors see vendor-specific interface
                VendorTabView()
            }
        }
    }
}

// MARK: - Manager Tab View

struct ManagerTabView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        VStack(spacing: 0) {
            // ✅ PG Selector (only shows for PGADMIN with multiple PGs)
            PGSelectorView()
                .environmentObject(authManager)
            
            TabView {
                // Dashboard
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "house.fill")
                    }
                
                // Attendance
                DailyAttendanceView()
                    .tabItem {
                        Label("Attendance", systemImage: "checkmark.circle.fill")
                    }
                    .environmentObject(authManager)
                
                // Members Management (replaces Students & Staff tabs)
                MembersManagementView()
                    .tabItem {
                        Label("Members", systemImage: "person.3.fill")
                    }
                    .environmentObject(authManager)
                
                // Rooms
                RoomsListView()
                    .tabItem {
                        Label("Rooms", systemImage: "building.2.fill")
                    }
                
                // Profile
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.circle.fill")
                    }
            }
            .environmentObject(authManager)
        }
    }
}

// MARK: - Warden Tab View

struct WardenTabView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        TabView {
            // Attendance
            DailyAttendanceView()
                .tabItem {
                    Label("Attendance", systemImage: "checkmark.circle.fill")
                }
                .environmentObject(authManager)
            
            // Members Management (limited to STAFF/STUDENT)
            MembersManagementView()
                .tabItem {
                    Label("Members", systemImage: "person.3.fill")
                }
                .environmentObject(authManager)
            
            Text("Reports")
                .tabItem {
                    Label("Reports", systemImage: "chart.bar.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
    }
}

// MARK: - Accountant Tab View

struct AccountantTabView: View {
    var body: some View {
        TabView {
            Text("Finances")
                .tabItem {
                    Label("Finances", systemImage: "dollarsign.circle.fill")
                }
            
            Text("Reports")
                .tabItem {
                    Label("Reports", systemImage: "chart.bar.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
    }
}

// MARK: - Vendor Tab View

struct VendorTabView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        VStack(spacing: 0) {
            // ✅ PG Selector (only shows for VENDOR with multiple PGs)
            PGSelectorView()
                .environmentObject(authManager)
            
            TabView {
                // ✅ Orders View (filters by current PG)
                OrdersView()
                    .tabItem {
                        Label("Orders", systemImage: "cart.fill")
                    }
                    .environmentObject(authManager)
                
                // ✅ Inventory View (filters by current PG)
                InventoryView()
                    .tabItem {
                        Label("Inventory", systemImage: "shippingbox.fill")
                    }
                    .environmentObject(authManager)
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.circle.fill")
                    }
            }
            .environmentObject(authManager)
        }
    }
}

// MARK: - Placeholder Views

struct DashboardView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Manager Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Quick stats, recent activity, etc.
                    Text("Dashboard content coming soon...")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            List {
                Section("User Info") {
                    if let user = authManager.currentUser {
                        Text("Name: \(user.name)")
                        Text("Role: \(authManager.userRole.displayName)")
                        Text("PG: \(user.pgName)")
                    }
                }
                
                if authManager.userRole == .pgAdmin {
                    Section("PG Management") {
                        NavigationLink("Edit PG Details") {
                            PGDetailsEditView()
                                .environmentObject(authManager)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        authManager.logout()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("Logout")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
