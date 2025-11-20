//
//  AppStore.swift
//  PGEase
//
//  Main store container that holds all domain stores
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var pgStore: PGStore
    @Published var chatStore: ChatStore
    
    private let apiManager: APIManager
    private let authManager: AuthManager
    
    init(apiManager: APIManager = .shared, authManager: AuthManager) {
        print("🏪 [AppStore] Initializing AppStore...")
        self.apiManager = apiManager
        self.authManager = authManager
        
        print("🏪 [AppStore] Creating PGStore...")
        self.pgStore = PGStore(apiManager: apiManager, authManager: authManager)
        print("🏪 [AppStore] Creating ChatStore...")
        self.chatStore = ChatStore(apiManager: apiManager, authManager: authManager)
        print("✅ [AppStore] AppStore initialized successfully")
    }
}

