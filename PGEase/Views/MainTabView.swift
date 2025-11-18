import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var biometricAuthManager: BiometricAuthManager
    @EnvironmentObject var checkInOutManager: CheckInOutManager
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        TabView {
            // Food Tab
            FoodView()
                .tabItem {
                    Image(systemName: "fork.knife")
                    Text("Food")
                }
            
            // Chat Tab
            ChatView()
                .tabItem {
                    Image(systemName: "message")
                    Text("Chat")
                }
            
            // Issues Tab
            IssuesView()
                .tabItem {
                    Image(systemName: "exclamationmark.triangle")
                    Text("Issues")
                }
            
            // // Checkin Tab (Current ContentView)
            // ContentView()
            //     .environmentObject(biometricAuthManager)
            AttendanceView()
                .environmentObject(authManager)
                .environmentObject(checkInOutManager)
                .tabItem {
                    Image(systemName: "checkmark.circle")
                    Text("Attendance")
                }

            if authManager.userRole == .student {
                ProfileView()
                    .environmentObject(authManager)
                    .tabItem {
                        Image(systemName: "person.circle")
                        Text("Profile")
                    }
            } else {
                // NFC Tab (hidden for students)
                NFCView()
                    .tabItem {
                        Image(systemName: "wave.3.right")
                        Text("NFC")
                    }
            }
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(BiometricAuthManager())
        .environmentObject(CheckInOutManager())
        .environmentObject(AuthManager())
}
