import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var biometricAuthManager: BiometricAuthManager
    
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
            
            // Checkin Tab (Current ContentView)
            ContentView()
                .environmentObject(biometricAuthManager)
                .tabItem {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Checkin")
                }
            
            // NFC Tab
            NFCView()
                .tabItem {
                    Image(systemName: "wave.3.right")
                    Text("NFC")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(BiometricAuthManager())
}
