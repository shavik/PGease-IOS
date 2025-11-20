//
//  CheckInOutRecord.swift
//  PGEase
//
//  Domain model for Check-in/out records (placeholder - will be fully implemented in Phase 3)
//

import Foundation

struct CheckInOutRecord: Identifiable, Codable {
    let id: String
    let studentId: String
    let pgId: String
    let method: String
    let type: String // "checkIn" or "checkOut"
    let timestamp: Date
    let nfcTagId: String?
    let location: CheckInLocation?
    let deviceId: String?
    
    // Will be fully implemented in Phase 3
}

struct CheckInLocation: Codable {
    let latitude: Double
    let longitude: Double
}

struct DailyAttendance: Codable {
    let date: Date
    let summary: AttendanceSummary
    let students: [AttendanceStudent]
    
    // Will be fully implemented in Phase 3
}

struct AttendanceStudent: Codable, Identifiable {
    let id: String
    let name: String
    let status: String
}

