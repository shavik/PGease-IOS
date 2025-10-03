//
//  PGEaseApp.swift
//  PGEase
//
//  Created by Vikas Sharma on 04/08/25.
//

import SwiftUI

@main
struct PGEaseApp: App {
    @StateObject private var biometricAuthManager = BiometricAuthManager()

    var body: some Scene {
           WindowGroup {
               Group {
                   if biometricAuthManager.isAuthenticated {
                       MainTabView()
                           .environmentObject(biometricAuthManager)
                           .onAppear {
                               print("🚀 App: MainTabView appeared - User is authenticated")
                           }
                   } else {
                       LoginView()
                           .environmentObject(biometricAuthManager)
                           .onAppear {
                               print("🔐 App: LoginView appeared - User needs authentication")
                           }
                   }
               }
               .onReceive(biometricAuthManager.$isAuthenticated) { isAuthenticated in
                   print("🔄 App: Authentication state changed to: \(isAuthenticated)")
               }
           }
       }
}
