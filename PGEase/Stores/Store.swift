//
//  Store.swift
//  PGEase
//
//  Store protocol for single source of truth architecture
//

import Foundation
import Combine

/// Protocol that all domain stores must conform to
protocol Store: ObservableObject {
    associatedtype State: StoreState
    var state: State { get }
    func refresh() async
    func clear()
}

/// Protocol for store state structures
protocol StoreState {
    var lastSyncTime: Date? { get set }
    var syncInProgress: Bool { get set }
}

/// Store errors
enum StoreError: LocalizedError {
    case roomNotFound
    case studentNotFound
    case userNotAuthenticated
    case invalidData
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .roomNotFound:
            return "Room not found"
        case .studentNotFound:
            return "Student not found"
        case .userNotAuthenticated:
            return "User not authenticated"
        case .invalidData:
            return "Invalid data"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

