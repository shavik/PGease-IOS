# Single Source of Truth Architecture Plan (iOS Swift)

## Overview

Implement a centralized state management system using Store pattern (similar to Android `AppStore` with `PGStore`, `ChatStore`) to manage all app data locally with automatic remote synchronization using Swift/SwiftUI patterns.

## Architecture Goals

1. **Single Source of Truth**: All data lives in stores, Views read from stores via `@EnvironmentObject`
2. **Optimistic Updates**: Update local state immediately, sync to remote in background
3. **Automatic Sync**: Stores handle remote sync transparently
4. **Type Safety**: Strong typing with Swift enums and structs
5. **Reactive**: Combine-based reactive updates with `@Published`
6. **Offline Support**: Local state persists, syncs when online

---

## 1. Core Store Structure

### 1.1 AppStore (Main Container)

```swift
import Foundation
import Combine
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var pgStore: PGStore
    @Published var chatStore: ChatStore
    // Future: attendanceStore, foodStore, etc.

    private let apiManager: APIManager
    private let authManager: AuthManager

    init(apiManager: APIManager = .shared, authManager: AuthManager) {
        self.apiManager = apiManager
        self.authManager = authManager

        self.pgStore = PGStore(apiManager: apiManager, authManager: authManager)
        self.chatStore = ChatStore(apiManager: apiManager, authManager: authManager)
    }
}
```

### 1.2 Store Protocol

```swift
protocol Store: ObservableObject {
    associatedtype State: StoreState
    var state: State { get }
    func refresh() async
    func clear()
}

protocol StoreState {
    var lastSyncTime: Date? { get }
    var syncInProgress: Bool { get }
}
```

---

## 2. PGStore Implementation

### 2.1 State Structure

```swift
@MainActor
struct PGStoreState: StoreState {
    // Rooms
    var rooms: [String: Room] = [:] // roomId -> Room
    var roomsByPg: [String: [String]] = [:] // pgId -> [roomIds]
    var roomsLoading: Bool = false
    var roomsError: String? = nil

    // Students/Members
    var students: [String: Student] = [:] // studentId -> Student
    var studentsByPg: [String: [String]] = [:] // pgId -> [studentIds]
    var studentsLoading: Bool = false
    var studentsError: String? = nil

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
```

### 2.2 PGStore Class

```swift
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
        state.roomsLoading = true
        state.roomsError = nil

        do {
            let response: RoomsListResponse = try await apiManager.getRooms(pgId: pgId)
            let rooms = response.data.map { $0.toRoom(pgId: pgId) }

            // Update state
            var updatedRooms = state.rooms
            var updatedRoomsByPg = state.roomsByPg
            var roomIds: [String] = []

            for room in rooms {
                updatedRooms[room.id] = room
                roomIds.append(room.id)
            }

            updatedRoomsByPg[pgId] = roomIds

            state.rooms = updatedRooms
            state.roomsByPg = updatedRoomsByPg
            state.roomsLoading = false
            state.lastSyncTime = Date()
        } catch {
            state.roomsError = error.localizedDescription
            state.roomsLoading = false
            throw error
        }
    }

    func createRoom(pgId: String, room: CreateRoomRequest) async throws -> Room {
        // 1. Generate temporary ID
        let tempId = UUID().uuidString
        let tempRoom = Room(
            id: tempId,
            pgId: pgId,
            number: room.number,
            type: room.type,
            bedCount: room.bedCount,
            occupiedBeds: 0,
            availableBeds: room.bedCount,
            details: room.details,
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
            let response: CreateRoomResponse = try await apiManager.createRoom(
                pgId: pgId,
                request: room
            )
            let realRoom = response.data.toRoom(pgId: pgId)

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

    func updateRoom(pgId: String, roomId: String, updates: UpdateRoomRequest) async throws -> Room {
        // Optimistic update
        guard let existingRoom = state.rooms[roomId] else {
            throw StoreError.roomNotFound
        }

        let updatedRoom = existingRoom.withUpdates(updates)
        applyOptimisticUpdate { state in
            var updated = state
            updated.rooms[roomId] = updatedRoom
            return updated
        }

        // Sync to remote
        do {
            let response: UpdateRoomResponse = try await apiManager.updateRoom(
                pgId: pgId,
                roomId: roomId,
                request: updates
            )
            let realRoom = response.data.toRoom(pgId: pgId)

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

    func deleteRoom(pgId: String, roomId: String) async throws {
        guard let room = state.rooms[roomId] else {
            throw StoreError.roomNotFound
        }

        // Optimistic delete
        applyOptimisticUpdate { state in
            var updated = state
            updated.rooms.removeValue(forKey: roomId)
            updated.roomsByPg[pgId]?.removeAll { $0 == roomId }
            return updated
        }

        // Sync to remote
        do {
            try await apiManager.deleteRoom(pgId: pgId, roomId: roomId)

            applyUpdate { state in
                var updated = state
                updated.lastSyncTime = Date()
                return updated
            }
        } catch {
            // Rollback
            applyUpdate { state in
                var updated = state
                updated.rooms[roomId] = room
                updated.roomsByPg[pgId, default: []].append(roomId)
                updated.roomsError = error.localizedDescription
                return updated
            }
            throw error
        }
    }

    // MARK: - Student Operations

    func loadStudents(pgId: String) async throws {
        state.studentsLoading = true
        state.studentsError = nil

        do {
            let response: StudentsListResponse = try await apiManager.getStudents(
                pgId: pgId,
                limit: 100,
                status: "ACTIVE"
            )
            let students = response.data?.data.map { $0.toStudent(pgId: pgId) } ?? []

            var updatedStudents = state.students
            var updatedStudentsByPg = state.studentsByPg
            var studentIds: [String] = []

            for student in students {
                updatedStudents[student.id] = student
                studentIds.append(student.id)
            }

            updatedStudentsByPg[pgId] = studentIds

            state.students = updatedStudents
            state.studentsByPg = updatedStudentsByPg
            state.studentsLoading = false
            state.lastSyncTime = Date()
        } catch {
            state.studentsError = error.localizedDescription
            state.studentsLoading = false
            throw error
        }
    }

    func loadStudentDetail(pgId: String, studentId: String) async throws -> Student {
        do {
            let response: StudentDetailResponse = try await apiManager.getStudentDetail(
                pgId: pgId,
                studentId: studentId
            )
            let student = response.data.toStudent(pgId: pgId)

            applyUpdate { state in
                var updated = state
                updated.students[studentId] = student
                updated.lastSyncTime = Date()
                return updated
            }

            return student
        } catch {
            state.studentsError = error.localizedDescription
            throw error
        }
    }

    func updateStudentRoom(pgId: String, studentId: String, roomId: String) async throws {
        guard var student = state.students[studentId] else {
            throw StoreError.studentNotFound
        }

        let oldRoomId = student.roomId

        // Optimistic update
        student.roomId = roomId
        applyOptimisticUpdate { state in
            var updated = state
            updated.students[studentId] = student
            return updated
        }

        // Sync to remote
        do {
            try await apiManager.updateStudentRoom(
                pgId: pgId,
                studentId: studentId,
                roomId: roomId
            )

            applyUpdate { state in
                var updated = state
                updated.lastSyncTime = Date()
                return updated
            }
        } catch {
            // Rollback
            student.roomId = oldRoomId
            applyUpdate { state in
                var updated = state
                updated.students[studentId] = student
                updated.studentsError = error.localizedDescription
                return updated
            }
            throw error
        }
    }

    // MARK: - Check-in/out Operations

    func checkIn(method: CheckInMethod, nfcTagId: String?) async throws -> CheckInOutRecord {
        guard let userId = authManager.userId,
              let profileId = authManager.profileId ?? authManager.userId else {
            throw StoreError.userNotAuthenticated
        }

        let record = CheckInOutRecord(
            id: UUID().uuidString,
            studentId: profileId,
            pgId: authManager.currentPgId ?? "",
            method: method,
            type: .checkIn,
            timestamp: Date(),
            nfcTagId: nfcTagId,
            location: nil,
            deviceId: UIDevice.current.identifierForVendor?.uuidString
        )

        // Optimistic update
        applyOptimisticUpdate { state in
            var updated = state
            updated.checkInOutRecords[record.id] = record
            updated.recordsByStudent[profileId, default: []].append(record.id)

            let dateKey = ISO8601DateFormatter().string(from: record.timestamp)
            updated.recordsByDate[dateKey, default: []].append(record.id)

            // Update student check-in status
            if var student = updated.students[profileId] {
                student.checkInStatus = .checkedIn
                student.lastCheckIn = record.timestamp
                updated.students[profileId] = student
            }

            return updated
        }

        // Sync to remote
        do {
            let response: CheckInResponse = try await apiManager.checkIn(
                profileId: profileId,
                userId: userId,
                userType: authManager.userRole.rawValue,
                method: method.rawValue,
                nfcTagId: nfcTagId,
                deviceId: record.deviceId
            )

            let realRecord = CheckInOutRecord(
                id: response.data.checkIn.id,
                studentId: profileId,
                pgId: authManager.currentPgId ?? "",
                method: method,
                type: .checkIn,
                timestamp: ISO8601DateFormatter().date(from: response.data.checkIn.timestamp) ?? Date(),
                nfcTagId: nfcTagId,
                location: nil,
                deviceId: record.deviceId
            )

            applyUpdate { state in
                var updated = state
                updated.checkInOutRecords.removeValue(forKey: record.id)
                updated.checkInOutRecords[realRecord.id] = realRecord
                updated.lastSyncTime = Date()
                return updated
            }

            return realRecord
        } catch {
            // Rollback
            applyUpdate { state in
                var updated = state
                updated.checkInOutRecords.removeValue(forKey: record.id)
                updated.recordsByStudent[profileId]?.removeAll { $0 == record.id }

                if var student = updated.students[profileId] {
                    student.checkInStatus = nil
                    student.lastCheckIn = nil
                    updated.students[profileId] = student
                }

                return updated
            }
            throw error
        }
    }

    func checkOut(method: CheckInMethod, nfcTagId: String?) async throws -> CheckInOutRecord {
        // Similar implementation to checkIn
        // ...
    }

    // MARK: - Attendance Operations

    func loadAttendance(pgId: String, date: Date) async throws -> DailyAttendance {
        let dateKey = ISO8601DateFormatter().string(from: date)

        state.attendanceLoading = true
        state.attendanceError = nil

        do {
            let response: DailyAttendanceResponse = try await apiManager.getDailyAttendance(
                pgId: pgId,
                date: dateKey
            )

            let attendance = response.toDailyAttendance()

            applyUpdate { state in
                var updated = state
                updated.attendanceByDate[dateKey] = attendance
                updated.attendanceLoading = false
                updated.lastSyncTime = Date()
                return updated
            }

            return attendance
        } catch {
            state.attendanceError = error.localizedDescription
            state.attendanceLoading = false
            throw error
        }
    }

    // MARK: - Store Protocol

    func refresh() async {
        guard let pgId = authManager.currentPgId else { return }

        state.syncInProgress = true

        async let roomsTask = loadRooms(pgId: pgId)
        async let studentsTask = loadStudents(pgId: pgId)

        do {
            try await roomsTask
            try await studentsTask
        } catch {
            // Errors already set in state
        }

        state.syncInProgress = false
    }

    func clear() {
        state = PGStoreState()
    }

    // MARK: - Private Helpers

    private func applyOptimisticUpdate(_ transform: @escaping (PGStoreState) -> PGStoreState) {
        state = transform(state)
    }

    private func applyUpdate(_ transform: @escaping (PGStoreState) -> PGStoreState) {
        state = transform(state)
    }
}

enum StoreError: LocalizedError {
    case roomNotFound
    case studentNotFound
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .roomNotFound:
            return "Room not found"
        case .studentNotFound:
            return "Student not found"
        case .userNotAuthenticated:
            return "User not authenticated"
        }
    }
}
```

---

## 3. ChatStore Implementation

### 3.1 State Structure

```swift
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
```

### 3.2 ChatStore Class

```swift
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

    func loadConversations(pgId: String) async throws {
        state.loading = true
        state.error = nil

        do {
            let response: ConversationsResponse = try await apiManager.getConversations(pgId: pgId)
            let conversations = response.data.map { $0.toConversation() }

            var updatedConversations = state.conversations
            var conversationIds: [String] = []

            for conversation in conversations {
                updatedConversations[conversation.id] = conversation
                conversationIds.append(conversation.id)
            }

            state.conversations = updatedConversations
            state.loading = false
            state.lastSyncTime = Date()
        } catch {
            state.error = error.localizedDescription
            state.loading = false
            throw error
        }
    }

    func loadMessages(conversationId: String) async throws {
        do {
            let response: MessagesResponse = try await apiManager.getMessages(
                conversationId: conversationId
            )
            let messages = response.data.map { $0.toChatMessage() }

            applyUpdate { state in
                var updated = state
                var messageIds: [String] = []

                for message in messages {
                    updated.messages[message.id] = message
                    messageIds.append(message.id)
                }

                updated.messagesByConversation[conversationId] = messageIds
                updated.lastSyncTime = Date()
                return updated
            }
        } catch {
            state.error = error.localizedDescription
            throw error
        }
    }

    func sendMessage(conversationId: String, text: String) async throws -> ChatMessage {
        let tempId = UUID().uuidString
        let tempMessage = ChatMessage(
            id: tempId,
            conversationId: conversationId,
            senderId: authManager.userId ?? "",
            text: text,
            timestamp: Date(),
            isRead: false
        )

        // Optimistic update
        applyOptimisticUpdate { state in
            var updated = state
            updated.messages[tempId] = tempMessage
            updated.messagesByConversation[conversationId, default: []].append(tempId)
            return updated
        }

        // Sync to remote
        do {
            let response: SendMessageResponse = try await apiManager.sendMessage(
                conversationId: conversationId,
                text: text
            )
            let realMessage = response.data.toChatMessage()

            applyUpdate { state in
                var updated = state
                updated.messages.removeValue(forKey: tempId)
                updated.messages[realMessage.id] = realMessage

                if let index = updated.messagesByConversation[conversationId]?.firstIndex(of: tempId) {
                    updated.messagesByConversation[conversationId]?[index] = realMessage.id
                }

                updated.lastSyncTime = Date()
                return updated
            }

            return realMessage
        } catch {
            // Rollback
            applyUpdate { state in
                var updated = state
                updated.messages.removeValue(forKey: tempId)
                updated.messagesByConversation[conversationId]?.removeAll { $0 == tempId }
                updated.error = error.localizedDescription
                return updated
            }
            throw error
        }
    }

    func markAsRead(conversationId: String) async throws {
        // Optimistic update
        applyOptimisticUpdate { state in
            var updated = state
            updated.unreadCounts[conversationId] = 0

            if let messageIds = updated.messagesByConversation[conversationId] {
                for messageId in messageIds {
                    updated.messages[messageId]?.isRead = true
                }
            }

            return updated
        }

        // Sync to remote
        do {
            try await apiManager.markConversationAsRead(conversationId: conversationId)

            applyUpdate { state in
                var updated = state
                updated.lastSyncTime = Date()
                return updated
            }
        } catch {
            // Rollback handled by error state
            state.error = error.localizedDescription
            throw error
        }
    }

    func deleteMessage(messageId: String) async throws {
        guard let message = state.messages[messageId] else {
            throw StoreError.messageNotFound
        }

        // Optimistic delete
        applyOptimisticUpdate { state in
            var updated = state
            updated.messages.removeValue(forKey: messageId)
            updated.messagesByConversation[message.conversationId]?.removeAll { $0 == messageId }
            return updated
        }

        // Sync to remote
        do {
            try await apiManager.deleteMessage(messageId: messageId)

            applyUpdate { state in
                var updated = state
                updated.lastSyncTime = Date()
                return updated
            }
        } catch {
            // Rollback
            applyUpdate { state in
                var updated = state
                updated.messages[messageId] = message
                updated.messagesByConversation[message.conversationId, default: []].append(messageId)
                updated.error = error.localizedDescription
                return updated
            }
            throw error
        }
    }

    func refresh() async {
        guard let pgId = authManager.currentPgId else { return }
        state.syncInProgress = true

        do {
            try await loadConversations(pgId: pgId)
        } catch {
            // Error already set in state
        }

        state.syncInProgress = false
    }

    func clear() {
        state = ChatStoreState()
    }

    private func applyOptimisticUpdate(_ transform: @escaping (ChatStoreState) -> ChatStoreState) {
        state = transform(state)
    }

    private func applyUpdate(_ transform: @escaping (ChatStoreState) -> ChatStoreState) {
        state = transform(state)
    }
}
```

---

## 4. View Integration

### 4.1 Updated View Pattern

```swift
struct RoomsListView: View {
    @EnvironmentObject var appStore: AppStore
    @State private var searchText = ""

    private var rooms: [Room] {
        guard let pgId = appStore.authManager.currentPgId else { return [] }
        let roomIds = appStore.pgStore.state.roomsByPg[pgId] ?? []
        return roomIds.compactMap { appStore.pgStore.state.rooms[$0] }
    }

    private var isLoading: Bool {
        appStore.pgStore.state.roomsLoading
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading rooms...")
                } else if rooms.isEmpty {
                    emptyState
                } else {
                    List(filteredRooms) { room in
                        NavigationLink(destination: RoomDetailView(roomId: room.id)) {
                            RoomRowView(room: room)
                        }
                    }
                }
            }
            .navigationTitle("Rooms")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddRoom = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .refreshable {
                await appStore.pgStore.refresh()
            }
        }
        .task {
            await loadRooms()
        }
        .sheet(isPresented: $showingAddRoom) {
            AddRoomSheet {
                Task { await loadRooms() }
            }
        }
    }

    private var filteredRooms: [Room] {
        guard !searchText.isEmpty else { return rooms }
        return rooms.filter { room in
            room.number.localizedCaseInsensitiveContains(searchText) ||
            room.type.localizedCaseInsensitiveContains(searchText)
        }
    }

    @Sendable
    private func loadRooms() async {
        guard let pgId = appStore.authManager.currentPgId else { return }
        try? await appStore.pgStore.loadRooms(pgId: pgId)
    }
}
```

### 4.2 App Integration

```swift
@main
struct PGEaseApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var appStore: AppStore

    init() {
        let auth = AuthManager()
        _authManager = StateObject(wrappedValue: auth)
        _appStore = StateObject(wrappedValue: AppStore(authManager: auth))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    RoleBasedMainView()
                        .environmentObject(authManager)
                        .environmentObject(appStore)
                } else {
                    SmartLaunchView()
                        .environmentObject(authManager)
                }
            }
        }
    }
}
```

---

## 5. Data Models

### 5.1 Domain Models (Store Layer)

```swift
struct Room: Identifiable, Codable {
    let id: String
    let pgId: String
    let number: String
    let type: String
    let bedCount: Int
    let occupiedBeds: Int
    let availableBeds: Int
    let details: String?
    let students: [String] // student IDs
    let createdAt: Date
    let updatedAt: Date

    func withUpdates(_ updates: UpdateRoomRequest) -> Room {
        Room(
            id: id,
            pgId: pgId,
            number: updates.number ?? number,
            type: updates.type ?? type,
            bedCount: updates.bedCount ?? bedCount,
            occupiedBeds: occupiedBeds,
            availableBeds: availableBeds,
            details: updates.details ?? details,
            students: students,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

struct Student: Identifiable, Codable {
    let id: String
    let pgId: String
    let name: String
    let email: String?
    let phone: String?
    var roomId: String?
    let status: StudentStatus
    var checkInStatus: CheckInStatus?
    var lastCheckIn: Date?
    var lastCheckOut: Date?
}

struct CheckInOutRecord: Identifiable, Codable {
    let id: String
    let studentId: String
    let pgId: String
    let method: CheckInMethod
    let type: RecordType
    let timestamp: Date
    let nfcTagId: String?
    let location: GeoLocation?
    let deviceId: String?
}

enum RecordType: String, Codable {
    case checkIn
    case checkOut
}

struct DailyAttendance: Codable {
    let date: Date
    let summary: AttendanceSummary
    let students: [AttendanceStudent]
}

struct AttendanceSummary: Codable {
    let total: Int
    let checkedIn: Int
    let checkedOut: Int
    let notReturned: Int
    let absent: Int
}
```

### 5.2 DTO to Domain Mapping

```swift
extension RoomListItem {
    func toRoom(pgId: String) -> Room {
        Room(
            id: id,
            pgId: pgId,
            number: number,
            type: type,
            bedCount: bedCount,
            occupiedBeds: occupiedBeds,
            availableBeds: availableBeds,
            details: nil,
            students: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

extension StudentDto {
    func toStudent(pgId: String) -> Student {
        Student(
            id: id,
            pgId: pgId,
            name: name,
            email: email,
            phone: phone,
            roomId: roomId,
            status: StudentStatus(rawValue: status) ?? .active,
            checkInStatus: nil,
            lastCheckIn: nil,
            lastCheckOut: nil
        )
    }
}
```

---

## 6. Migration Strategy

### Phase 1: Foundation (Week 1)

1. Create `AppStore` and `Store` protocol
2. Implement `PGStore` with basic state structure
3. Add room operations (load, create, update, delete)
4. Update `RoomsListView` to use `AppStore`
5. Test optimistic updates

### Phase 2: Students & Check-in/out (Week 2)

1. Add student operations to `PGStore`
2. Add check-in/out operations
3. Update `MembersManagementView` and `AttendanceView`
4. Test end-to-end flows

### Phase 3: Attendance (Week 2-3)

1. Add attendance operations to `PGStore`
2. Update `DailyAttendanceView`
3. Test attendance dashboard

### Phase 4: Chat (Week 3)

1. Implement `ChatStore`
2. Update `ChatView`
3. Test chat functionality

### Phase 5: Cleanup (Week 4)

1. Remove old Manager state management
2. Remove direct API calls from Views
3. Add comprehensive tests
4. Documentation

---

## 7. Benefits

1. **Consistency**: Single source of truth prevents data inconsistencies
2. **Performance**: Optimistic updates make UI feel instant
3. **Offline**: Local state works offline, syncs when online
4. **Testability**: Stores can be easily mocked/tested
5. **Maintainability**: Clear separation of concerns
6. **SwiftUI Integration**: Natural fit with `@EnvironmentObject` and `@Published`

---

## 8. Considerations

### 8.1 Memory Management

- Stores hold all data in memory
- Consider pagination for large lists
- Implement cache eviction policies

### 8.2 Conflict Resolution

- Last-write-wins for simple cases
- Timestamp-based for complex scenarios
- User notification for conflicts

### 8.3 Error Handling

- Network errors: Retry with exponential backoff
- Validation errors: Show immediately
- Sync errors: Queue for retry

### 8.4 Thread Safety

- All store operations must be `@MainActor`
- Use `async/await` for network calls
- State updates happen on main thread

### 8.5 Testing

- Unit tests for store operations
- Integration tests for sync behavior
- UI tests for optimistic updates

---

## 9. File Structure

```
PGEase/
  Stores/
    AppStore.swift
    Store.swift
    PGStore/
      PGStore.swift
      PGStoreState.swift
      Models/
        Room.swift
        Student.swift
        CheckInOutRecord.swift
        DailyAttendance.swift
    ChatStore/
      ChatStore.swift
      ChatStoreState.swift
      Models/
        Conversation.swift
        ChatMessage.swift
```

---

## 10. Key Differences from Android

1. **SwiftUI vs Compose**: Uses `@EnvironmentObject` instead of Hilt injection
2. **Combine vs Flow**: Uses `@Published` and Combine instead of StateFlow
3. **async/await**: Native Swift concurrency instead of Coroutines
4. **Result Types**: Swift `Result<T, Error>` instead of sealed classes
5. **@MainActor**: Ensures thread safety for UI updates

---

## Next Steps

1. Review and approve this plan
2. Start with Phase 1 implementation
3. Create base Store infrastructure
4. Implement PGStore with rooms first
5. Migrate RoomsListView as proof of concept
6. Iterate based on learnings
