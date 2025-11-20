//
//  ChatStore.swift
//  PGEase
//
//  Store for managing chat-related data (conversations, messages)
//  Placeholder implementation - will be fully implemented in Phase 4
//

import Foundation
import Combine

@MainActor
struct ChatStoreState: StoreState {
    var conversations: [String: Conversation] = [:] // conversationId -> Conversation
    var messages: [String: ChatMessage] = [:] // messageId -> Message
    var messagesByConversation: [String: [String]] = [:] // conversationId -> [messageIds]
    var unreadCounts: [String: Int] = [:] // conversationId -> unread count
    var loading: Bool = false
    var error: String? = nil
    var lastSyncTime: Date? = nil
    var syncInProgress: Bool = false
}

// Placeholder models - will be implemented in Phase 4
struct Conversation: Identifiable, Codable {
    let id: String
    let name: String
    let lastMessage: String?
    let lastMessageTime: Date?
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let conversationId: String
    let text: String
    let timestamp: Date
}

@MainActor
final class ChatStore: ObservableObject, Store {
    typealias State = ChatStoreState
    
    @Published private(set) var state = ChatStoreState()
    
    private let apiManager: APIManager
    private let authManager: AuthManager
    
    init(apiManager: APIManager, authManager: AuthManager) {
        self.apiManager = apiManager
        self.authManager = authManager
    }
    
    func refresh() async {
        // Will be implemented in Phase 4
        state.syncInProgress = false
    }
    
    func clear() {
        state = ChatStoreState()
    }
}

