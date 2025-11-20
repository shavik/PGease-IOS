//
//  Student.swift
//  PGEase
//
//  Domain model for Student (placeholder - will be fully implemented in Phase 2)
//

import Foundation

struct Student: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let pgId: String
    let name: String
    let email: String?
    let phone: String?
    var roomId: String?
    let status: String
    var checkInStatus: String?
    var lastCheckIn: Date?
    var lastCheckOut: Date?
    
    // Will be fully implemented in Phase 2
}
