//
//  PGStore.swift
//  PGEase
//
//  Store for managing PG-related data (rooms, students, attendance, check-in/out)
//

import Foundation
import Combine

@MainActor
final class PGStore: ObservableObject, Store {
    typealias State = PGStoreState
    
    @Published private(set) var state = PGStoreState()
    
    private let apiManager: APIManager
    private let authManager: AuthManager
    private var cancellables = Set<AnyCancellable>()
    
    init(apiManager: APIManager, authManager: AuthManager) {
        self.apiManager = apiManager
        self.authManager = authManager
    }
    
    // MARK: - Room Operations
    
    func loadRooms(pgId: String) async throws {
        print("🏠 [PGStore] loadRooms called for pgId: \(pgId)")
        state.roomsLoading = true
        state.roomsError = nil
        
        do {
            print("📡 [PGStore] Calling API: getRooms(pgId: \(pgId))")
            let response: RoomsListResponse = try await apiManager.getRooms(pgId: pgId)
            print("✅ [PGStore] API call successful")
            print("📦 [PGStore] Response success: \(response.success)")
            print("📦 [PGStore] Response data count: \(response.data.count)")
            
            // Log raw response data for debugging
            if response.data.isEmpty {
                print("⚠️ [PGStore] Response data is empty")
            } else {
                print("📋 [PGStore] First room in response: id=\(response.data[0].id), number=\(response.data[0].number), type=\(response.data[0].type)")
            }
            
            print("🔄 [PGStore] Converting DTOs to Room domain models...")
            let rooms = response.data.map { dto in
                print("  🔄 Converting room: id=\(dto.id), number=\(dto.number)")
                return dto.toRoom(pgId: pgId)
            }
            print("✅ [PGStore] Converted \(rooms.count) rooms to domain models")
            
            // Update state
            var updatedRooms = state.rooms
            var updatedRoomsByPg = state.roomsByPg
            var roomIds: [String] = []
            
            print("💾 [PGStore] Updating store state...")
            for room in rooms {
                updatedRooms[room.id] = room
                roomIds.append(room.id)
                print("✅ Added room to store: id=\(room.id), number=\(room.number), students=\(room.students.map { $0.name }.joined(separator: ", "))")
            }
            
            updatedRoomsByPg[pgId] = roomIds
            
            // Update state atomically to ensure SwiftUI observes the change
            // Create a new state object to ensure @Published triggers
            var newState = state
            newState.rooms = updatedRooms
            newState.roomsByPg = updatedRoomsByPg
            newState.roomsLoading = false
            newState.lastSyncTime = Date()
            
            print("💾 [PGStore] Updating state - roomsLoading will be: false")
            state = newState
            
            print("✅ [PGStore] State updated successfully. Total rooms in store: \(state.rooms.count), Rooms for pgId \(pgId): \(state.roomsByPg[pgId]?.count ?? 0)")
            print("💾 [PGStore] Final roomsLoading state: \(state.roomsLoading)")
        } catch {
            print("❌ [PGStore] Error loading rooms:")
            print("   Error type: \(type(of: error))")
            print("   Error description: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                print("   🔍 Decoding error details:")
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("      Type mismatch: expected \(type), path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("      Value not found: \(type), path: \(context.codingPath)")
                case .keyNotFound(let key, let context):
                    print("      Key not found: \(key.stringValue), path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("      Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("      Unknown decoding error")
                }
            }
            if let urlError = error as? URLError {
                print("   🌐 URL Error: \(urlError.localizedDescription)")
                print("   Code: \(urlError.code.rawValue)")
            }
            state.roomsError = error.localizedDescription
            state.roomsLoading = false
            throw error
        }
    }
    
    func createRoom(pgId: String, number: String, type: String, bedCount: Int, details: String?) async throws -> Room {
        // 1. Generate temporary ID
        let tempId = UUID().uuidString
        let tempRoom = Room(
            id: tempId,
            pgId: pgId,
            number: number,
            type: type,
            bedCount: bedCount,
            occupiedBeds: 0,
            availableBeds: bedCount,
            details: details,
            photos: nil,
            order: nil,
            students: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // 2. Optimistically update local state
        applyOptimisticUpdate { state in
            var updated = state
            updated.rooms[tempId] = tempRoom
            updated.roomsByPg[pgId, default: []].append(tempId)
            return updated
        }
        
        // 3. Sync to remote
        do {
            let roomData: RoomData = try await apiManager.createRoom(
                pgId: pgId,
                number: number,
                type: type,
                bedCount: bedCount,
                details: details,
                photos: nil
            )
            let realRoom = roomData.toRoom()
            
            // Replace temp with real
            applyUpdate { state in
                var updated = state
                updated.rooms.removeValue(forKey: tempId)
                updated.rooms[realRoom.id] = realRoom
                
                if let index = updated.roomsByPg[pgId]?.firstIndex(of: tempId) {
                    updated.roomsByPg[pgId]?[index] = realRoom.id
                }
                
                updated.lastSyncTime = Date()
                return updated
            }
            
            return realRoom
        } catch {
            // Rollback optimistic update
            applyUpdate { state in
                var updated = state
                updated.rooms.removeValue(forKey: tempId)
                updated.roomsByPg[pgId]?.removeAll { $0 == tempId }
                updated.roomsError = error.localizedDescription
                return updated
            }
            throw error
        }
    }
    
    func updateRoom(pgId: String, roomId: String, number: String?, type: String?, bedCount: Int?, details: String?) async throws -> Room {
        // Optimistic update
        guard let existingRoom = state.rooms[roomId] else {
            throw StoreError.roomNotFound
        }
        
        let updatedRoom = existingRoom.withUpdates(
            number: number,
            type: type,
            bedCount: bedCount,
            details: details
        )
        
        applyOptimisticUpdate { state in
            var updated = state
            updated.rooms[roomId] = updatedRoom
            return updated
        }
        
        // Sync to remote
        do {
            let roomData: RoomData = try await apiManager.updateRoom(
                pgId: pgId,
                roomId: roomId,
                number: number ?? existingRoom.number,
                type: type ?? existingRoom.type,
                bedCount: bedCount ?? existingRoom.bedCount,
                details: details ?? existingRoom.details,
                photos: existingRoom.photos
            )
            let realRoom = roomData.toRoom(students: existingRoom.students)
            
            applyUpdate { state in
                var updated = state
                updated.rooms[roomId] = realRoom
                updated.lastSyncTime = Date()
                return updated
            }
            
            return realRoom
        } catch {
            // Rollback
            applyUpdate { state in
                var updated = state
                updated.rooms[roomId] = existingRoom
                updated.roomsError = error.localizedDescription
                return updated
            }
            throw error
        }
    }
    
    // Note: deleteRoom will be implemented when API endpoint is available
    // func deleteRoom(pgId: String, roomId: String) async throws { ... }
    
    // MARK: - Student/Member Operations
    
    /// Load all members (students, staff, managers, etc.) for a PG
    /// Stores all users in members dictionary, and also converts students to Student domain models
    func loadMembers(pgId: String, role: String? = nil) async throws {
        print("👥 [PGStore] loadMembers called for pgId: \(pgId), role: \(role ?? "all")")
        state.membersLoading = true
        state.membersError = nil
        
        do {
            print("📡 [PGStore] Calling API: listUsers(pgId: \(pgId), role: \(role ?? "nil"))")
            let response = try await apiManager.listUsers(pgId: pgId, role: role)
            print("✅ [PGStore] API call successful")
            print("📦 [PGStore] Response users count: \(response.users.count)")
            
            // Store all members (all roles) in members dictionary
            print("🔄 [PGStore] Storing all members...")
            var updatedMembers = state.members
            var updatedMembersByPg = state.membersByPg
            var memberIds: [String] = []
            
            for userItem in response.users {
                updatedMembers[userItem.id] = userItem
                memberIds.append(userItem.id)
                print("  ✅ Added member to store: id=\(userItem.id), name=\(userItem.name), role=\(userItem.role)")
            }
            
            updatedMembersByPg[pgId] = memberIds
            
            // Also convert students to Student domain models (for room operations)
            print("🔄 [PGStore] Converting students to Student domain models...")
            let students = response.users.compactMap { userItem -> Student? in
                // Only convert students (users with studentId)
                guard let studentId = userItem.studentId else { return nil }
                return Student(
                    id: studentId,
                    pgId: pgId,
                    name: userItem.name,
                    email: userItem.email,
                    phone: userItem.phone,
                    roomId: userItem.roomId,
                    status: userItem.status,
                    checkInStatus: nil,
                    lastCheckIn: nil,
                    lastCheckOut: nil
                )
            }
            print("✅ [PGStore] Converted \(students.count) students from \(response.users.count) users")
            
            // Update students state (for backward compatibility with room operations)
            var updatedStudents = state.students
            var updatedStudentsByPg = state.studentsByPg
            var studentIds: [String] = []
            
            for student in students {
                updatedStudents[student.id] = student
                studentIds.append(student.id)
            }
            
            updatedStudentsByPg[pgId] = studentIds
            
            // Update state atomically
            var newState = state
            newState.members = updatedMembers
            newState.membersByPg = updatedMembersByPg
            newState.students = updatedStudents
            newState.studentsByPg = updatedStudentsByPg
            newState.membersLoading = false
            newState.lastSyncTime = Date()
            
            print("💾 [PGStore] Updating state - membersLoading will be: false")
            state = newState
            
            print("✅ [PGStore] State updated successfully. Total members in store: \(state.members.count), Members for pgId \(pgId): \(state.membersByPg[pgId]?.count ?? 0)")
            print("✅ [PGStore] Total students in store: \(state.students.count), Students for pgId \(pgId): \(state.studentsByPg[pgId]?.count ?? 0)")
            print("💾 [PGStore] Final membersLoading state: \(state.membersLoading)")
        } catch {
            print("❌ [PGStore] Error loading members:")
            print("   Error type: \(type(of: error))")
            print("   Error description: \(error.localizedDescription)")
            state.membersError = error.localizedDescription
            state.membersLoading = false
            throw error
        }
    }
    
    /// Legacy method for backward compatibility - loads only students
    /// Use loadMembers() for loading all members
    func loadStudents(pgId: String, role: String? = nil) async throws {
        // Delegate to loadMembers, which handles both
        try await loadMembers(pgId: pgId, role: role)
    }
    
    /// Create a new member (user) with any role (STUDENT, STAFF, MANAGER, WARDEN, ACCOUNTANT)
    /// This creates the user and reloads members to show them in the list
    /// Note: Invitation must be generated separately via generateInvite API
    func createMember(pgId: String, name: String, email: String, phone: String?, role: String, createdBy: String) async throws -> String {
        print("👥 [PGStore] createMember called for pgId: \(pgId), name: \(name), role: \(role)")
        
        // Optimistic update: Add a temporary member to the store
        let tempUserId = UUID().uuidString
        let tempMember = UserListItem(
            id: tempUserId,
            name: name,
            email: email,
            phone: phone,
            studentId: role == "STUDENT" ? tempUserId : nil,
            roomId: nil,
            roomNumber: nil,
            role: role,
            status: "PENDING",
            accessStatus: nil,
            inviteStatus: InviteStatus(
                hasInvite: false,
                inviteCode: nil,
                isUsed: false,
                isExpired: false,
                expiresAt: nil
            ),
            createdAt: "",
            updatedAt: ""
        )
        
        // Optimistically add to store
        applyUpdate { state in
            var updated = state
            updated.members[tempUserId] = tempMember
            if updated.membersByPg[pgId] == nil {
                updated.membersByPg[pgId] = []
            }
            updated.membersByPg[pgId]?.append(tempUserId)
            return updated
        }
        
        do {
            print("📡 [PGStore] Calling API: createUser(...)")
            let response = try await apiManager.createUser(
                name: name,
                email: email,
                phone: phone,
                role: role,
                pgId: pgId,
                createdBy: createdBy
            )
            print("✅ [PGStore] User created: userId=\(response.userId), role=\(role)")
            
            // Reload members to get the actual user data (with correct IDs, status, etc.)
            // This is necessary because:
            // - For students: API returns userId, but we need studentId from the student record
            // - For all roles: We need the full UserListItem with correct status, invite info, etc.
            try await loadMembers(pgId: pgId)
            
            // Clean up temporary optimistic member (it will be replaced by real data from API)
            applyUpdate { state in
                var updated = state
                updated.members.removeValue(forKey: tempUserId)
                return updated
            }
            
            return response.userId
        } catch {
            print("❌ [PGStore] Error creating member:")
            print("   Error type: \(type(of: error))")
            print("   Error description: \(error.localizedDescription)")
            
            // Rollback optimistic update
            applyUpdate { state in
                var updated = state
                updated.members.removeValue(forKey: tempUserId)
                updated.membersByPg[pgId]?.removeAll { $0 == tempUserId }
                updated.membersError = error.localizedDescription
                return updated
            }
            
            throw error
        }
    }
    
    /// Legacy method for backward compatibility
    /// Use createMember() instead
    func createStudent(pgId: String, name: String, email: String, phone: String?, role: String, createdBy: String) async throws -> String {
        return try await createMember(pgId: pgId, name: name, email: email, phone: phone, role: role, createdBy: createdBy)
    }
    
    func updateStudentRoom(pgId: String, studentId: String, roomId: String?) async throws {
        print("👥 [PGStore] updateStudentRoom called: studentId=\(studentId), roomId=\(roomId ?? "nil")")
        
        // Optimistic update
        guard var existingStudent = state.students[studentId] else {
            throw StoreError.studentNotFound
        }
        
        let previousRoomId = existingStudent.roomId
        existingStudent.roomId = roomId
        
        applyUpdate { state in
            var updated = state
            updated.students[studentId] = existingStudent
            return updated
        }
        
        // Also update room's students list if needed
        if let previousRoomId = previousRoomId, let previousRoom = state.rooms[previousRoomId] {
            let updatedStudents = previousRoom.students.filter { $0.id != studentId }
            let updatedRoom = previousRoom.withUpdates(students: updatedStudents)
            applyUpdate { state in
                var updated = state
                updated.rooms[previousRoomId] = updatedRoom
                return updated
            }
        }
        
        if let newRoomId = roomId, let newRoom = state.rooms[newRoomId] {
            let updatedStudents: [Student]
            if !newRoom.students.contains(where: { $0.id == studentId }) {
                updatedStudents = newRoom.students + [existingStudent]
            } else {
                updatedStudents = newRoom.students
            }
            let updatedRoom = newRoom.withUpdates(students: updatedStudents)
            applyUpdate { state in
                var updated = state
                updated.rooms[newRoomId] = updatedRoom
                return updated
            }
        }
        
        // Sync to remote
        do {
            print("📡 [PGStore] Calling API: updateStudentRoom(...)")
            let response = try await apiManager.updateStudentRoom(
                studentId: studentId,
                pgId: pgId,
                roomId: roomId
            )
            print("✅ [PGStore] Student room updated successfully")
            
            // Update student and room from response if available (no need to reload all)
            if let updatedStudentData = response.data {
                // Update student in store if response includes updated student data
                // For now, we trust our optimistic update since API confirms success
                // Only reload if we need to sync other fields that might have changed
            }
            
            // No need to reload all students/rooms - optimistic update is sufficient
            // The API call confirms the change was successful
        } catch {
            // Rollback
            print("❌ [PGStore] Error updating student room, rolling back...")
            if var student = state.students[studentId] {
                student.roomId = previousRoomId
                applyUpdate { state in
                    var updated = state
                    updated.students[studentId] = student
                    updated.studentsError = error.localizedDescription
                    return updated
                }
            }
            throw error
        }
    }
    
    func swapStudentRooms(pgId: String, studentAId: String, studentBId: String) async throws {
        print("👥 [PGStore] swapStudentRooms called: studentAId=\(studentAId), studentBId=\(studentBId)")
        
        guard let studentA = state.students[studentAId],
              let studentB = state.students[studentBId] else {
            throw StoreError.studentNotFound
        }
        
        let studentARoomId = studentA.roomId
        let studentBRoomId = studentB.roomId
        
        // Optimistic update
        var updatedStudentA = studentA
        var updatedStudentB = studentB
        updatedStudentA.roomId = studentBRoomId
        updatedStudentB.roomId = studentARoomId
        
        applyUpdate { state in
            var updated = state
            updated.students[studentAId] = updatedStudentA
            updated.students[studentBId] = updatedStudentB
            return updated
        }
        
        // Update rooms' student lists
        if let roomAId = studentARoomId, let roomA = state.rooms[roomAId] {
            var updatedStudents = roomA.students.filter { $0.id != studentAId }
            if let studentBInRoom = state.students[studentBId] {
                if !updatedStudents.contains(where: { $0.id == studentBId }) {
                    updatedStudents.append(studentBInRoom)
                }
            }
            let updatedRoomA = roomA.withUpdates(students: updatedStudents)
            applyUpdate { state in
                var updated = state
                updated.rooms[roomAId] = updatedRoomA
                return updated
            }
        }
        
        if let roomBId = studentBRoomId, let roomB = state.rooms[roomBId] {
            var updatedStudents = roomB.students.filter { $0.id != studentBId }
            if let studentAInRoom = state.students[studentAId] {
                if !updatedStudents.contains(where: { $0.id == studentAId }) {
                    updatedStudents.append(studentAInRoom)
                }
            }
            let updatedRoomB = roomB.withUpdates(students: updatedStudents)
            applyUpdate { state in
                var updated = state
                updated.rooms[roomBId] = updatedRoomB
                return updated
            }
        }
        
        // Sync to remote
        do {
            print("📡 [PGStore] Calling API: swapStudentRooms(...)")
            let swapResult = try await apiManager.swapStudentRooms(
                pgId: pgId,
                studentAId: studentAId,
                studentBId: studentBId
            )
            print("✅ [PGStore] Student rooms swapped successfully")
            
            // Update room info from response if available
            // For now, we trust our optimistic update since API confirms success
            // No need to reload all students/rooms - optimistic update is sufficient
        } catch {
            // Rollback
            print("❌ [PGStore] Error swapping student rooms, rolling back...")
            if var studentA = state.students[studentAId] {
                studentA.roomId = studentARoomId
                applyUpdate { state in
                    var updated = state
                    updated.students[studentAId] = studentA
                    return updated
                }
            }
            if var studentB = state.students[studentBId] {
                studentB.roomId = studentBRoomId
                applyUpdate { state in
                    var updated = state
                    updated.students[studentBId] = studentB
                    updated.studentsError = error.localizedDescription
                    return updated
                }
            }
            throw error
        }
    }
    
    func clearStudentsError() {
        state.studentsError = nil
    }
    
    func clearMembersError() {
        state.membersError = nil
    }
    
    func loadRoomDetail(pgId: String, roomId: String) async throws -> Room {
        print("🏠 [PGStore] loadRoomDetail called for pgId: \(pgId), roomId: \(roomId)")
        do {
            print("📡 [PGStore] Calling API: getRoomDetail(pgId: \(pgId), roomId: \(roomId))")
            let response: RoomDetailData = try await apiManager.getRoomDetail(pgId: pgId, roomId: roomId)
            print("✅ [PGStore] API call successful")
            print("📦 [PGStore] Room detail: id=\(response.id), number=\(response.number), type=\(response.type), students count=\(response.students.count)")
            
            print("🔄 [PGStore] Converting RoomDetailData to Room...")
            let room = response.toRoom()
            print("✅ [PGStore] Converted to Room: id=\(room.id), number=\(room.number)")
            
            applyUpdate { state in
                var updated = state
                updated.rooms[roomId] = room
                updated.lastSyncTime = Date()
                return updated
            }
            
            print("✅ [PGStore] Room detail loaded and stored successfully")
            return room
        } catch {
            print("❌ [PGStore] Error loading room detail:")
            print("   Error type: \(type(of: error))")
            print("   Error description: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                print("   🔍 Decoding error details:")
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("      Type mismatch: expected \(type), path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("      Value not found: \(type), path: \(context.codingPath)")
                case .keyNotFound(let key, let context):
                    print("      Key not found: \(key.stringValue), path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("      Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("      Unknown decoding error")
                }
            }
            state.roomsError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Store Protocol
    
    func refresh() async {
        guard let pgId = authManager.currentPgId else { return }
        
        state.syncInProgress = true
        
        async let roomsTask = loadRooms(pgId: pgId)
        
        do {
            try await roomsTask
        } catch {
            // Errors already set in state
        }
        
        state.syncInProgress = false
    }
    
    func clear() {
        state = PGStoreState()
    }
    
    func clearRoomsError() {
        state.roomsError = nil
    }
    
    // MARK: - Private Helpers
    
    private func applyOptimisticUpdate(_ transform: @escaping (PGStoreState) -> PGStoreState) {
        state = transform(state)
    }
    
    private func applyUpdate(_ transform: @escaping (PGStoreState) -> PGStoreState) {
        state = transform(state)
    }
}

