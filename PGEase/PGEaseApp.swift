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
                } else if onboardingManager.isOnboardingComplete {
                    // Onboarding complete, need biometric login
                    LoginView()
                        .environmentObject(biometricAuthManager)
                        .environmentObject(authManager)
                        .onAppear {
                            print("🔐 App: LoginView appeared - User needs authentication")
                        }
                } else {
                    // User needs onboarding - show role selection first
                    OnboardingFlowView()
                        .environmentObject(onboardingManager)
                        .environmentObject(authManager)
                        .onAppear {
                            print("📱 App: OnboardingFlow appeared - User needs onboarding")
                        }
                }
            }
            .onReceive(authManager.$isAuthenticated) { isAuthenticated in
                print("🔄 App: Authentication state changed to: \(isAuthenticated)")
            }
            .onReceive(onboardingManager.$isOnboardingComplete) { isComplete in
                print("🔄 App: Onboarding state changed to: \(isComplete)")
            }
        }
    }
}

// MARK: - Onboarding Flow View

struct OnboardingFlowView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showRoleSelection = true
    @State private var selectedRole: OnboardingManager.UserType = .student
    
    var body: some View {
        if showRoleSelection {
            RoleSelectionView(selectedRole: $selectedRole) {
                onboardingManager.userType = selectedRole
                authManager.updateUserRole(selectedRole == .student ? .student : .staff)
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
        TabView {
            // Dashboard
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            
            // Students Management
            Text("Students")
                .tabItem {
                    Label("Students", systemImage: "person.2.fill")
                }
            
            // Staff Management
            Text("Staff")
                .tabItem {
                    Label("Staff", systemImage: "person.badge.key.fill")
                }
            
            // NFC Tags
            NFCTagListView()
                .tabItem {
                    Label("NFC Tags", systemImage: "wave.3.right")
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

// MARK: - Warden Tab View

struct WardenTabView: View {
    var body: some View {
        TabView {
            Text("Attendance")
                .tabItem {
                    Label("Attendance", systemImage: "checkmark.circle.fill")
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
    var body: some View {
        TabView {
            Text("Orders")
                .tabItem {
                    Label("Orders", systemImage: "cart.fill")
                }
            
            Text("Inventory")
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
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
