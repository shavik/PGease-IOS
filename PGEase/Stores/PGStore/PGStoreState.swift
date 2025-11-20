//
//  PGStoreState.swift
//  PGEase
//
//  State structure for PGStore
//

import Foundation

@MainActor
struct PGStoreState: StoreState {
    // Rooms
    var rooms: [String: Room] = [:] // roomId -> Room
    var roomsByPg: [String: [String]] = [:] // pgId -> [roomIds]
    var roomsLoading: Bool = false
    var roomsError: String? = nil
    
    // Students/Members
    var students: [String: Student] = [:] // studentId -> Student (for room operations)
    var studentsByPg: [String: [String]] = [:] // pgId -> [studentIds]
    var studentsLoading: Bool = false
    var studentsError: String? = nil
    
    // All Members (Students, Staff, Managers, etc.)
    var members: [String: UserListItem] = [:] // userId -> UserListItem (all roles)
    var membersByPg: [String: [String]] = [:] // pgId -> [userIds]
    var membersLoading: Bool = false
    var membersError: String? = nil
    
    // Check-in/out Records
    var checkInOutRecords: [String: CheckInOutRecord] = [:] // recordId -> Record
    var recordsByStudent: [String: [String]] = [:] // studentId -> [recordIds]
    var recordsByDate: [String: [String]] = [:] // date -> [recordIds]
    
    // Attendance
    var attendanceByDate: [String: DailyAttendance] = [:] // date -> Attendance
    var attendanceLoading: Bool = false
    var attendanceError: String? = nil
    
    // Cache metadata
    var lastSyncTime: Date? = nil
    var syncInProgress: Bool = false
}

