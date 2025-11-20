//
//  Room.swift
//  PGEase
//
//  Domain model for Room
//

import Foundation

struct Room: Identifiable, Codable, Equatable {
    let id: String
    let pgId: String
    let number: String
    let type: String
    let bedCount: Int
    let occupiedBeds: Int
    let availableBeds: Int
    let details: String?
    let photos: [String]?
    let order: Int?
    let students: [Student] // student objects
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: String,
        pgId: String,
        number: String,
        type: String,
        bedCount: Int,
        occupiedBeds: Int = 0,
        availableBeds: Int? = nil,
        details: String? = nil,
        photos: [String]? = nil,
        order: Int? = nil,
        students: [Student] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.pgId = pgId
        self.number = number
        self.type = type
        self.bedCount = bedCount
        self.occupiedBeds = occupiedBeds
        self.availableBeds = availableBeds ?? (bedCount - occupiedBeds)
        self.details = details
        self.photos = photos
        self.order = order
        self.students = students
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    func withUpdates(
        number: String? = nil,
        type: String? = nil,
        bedCount: Int? = nil,
        details: String? = nil,
        photos: [String]? = nil,
        students: [Student]? = nil
    ) -> Room {
        Room(
            id: id,
            pgId: pgId,
            number: number ?? self.number,
            type: type ?? self.type,
            bedCount: bedCount ?? self.bedCount,
            occupiedBeds: occupiedBeds,
            availableBeds: nil, // Will be calculated
            details: details ?? self.details,
            photos: photos ?? self.photos,
            order: order,
            students: students ?? self.students,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

// MARK: - DTO Extensions

extension RoomListItem {
    func toRoom(pgId: String) -> Room {
        print("  🔄 [RoomListItem.toRoom] Converting: id=\(id), number=\(number), type=\(type), bedCount=\(bedCount), occupiedBeds=\(occupiedBeds), availableBeds=\(availableBeds)")
        // Convert RoomStudentDto to Student domain objects
        let room = Room(
            id: id,
            pgId: pgId,
            number: number,
            type: type,
            bedCount: bedCount,
            occupiedBeds: occupiedBeds,
            availableBeds: availableBeds,
            details: nil,
            photos: nil,
            order: nil,
            students: students ?? [],
            createdAt: Date(),
            updatedAt: Date()
        )
        print("  ✅ [RoomListItem.toRoom] Created Room: id=\(room.id), number=\(room.number), students: \(room.students.count)")
        return room
    }
}

extension RoomData {
    func toRoom(students: [Student] = []) -> Room {
        Room(
            id: id,
            pgId: pgId,
            number: number,
            type: type,
            bedCount: bedCount,
            occupiedBeds: 0, // Will be calculated from students
            availableBeds: bedCount,
            details: details,
            photos: photos,
            order: order,
            students: students,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

extension RoomDetailData {
    func toRoom() -> Room {
        print("  🔄 [RoomDetailData.toRoom] Converting: id=\(id), number=\(number), type=\(type), bedCount=\(bedCount)")
        print("  📊 [RoomDetailData.toRoom] occupiedBeds: \(occupiedBeds?.description ?? "nil"), availableBeds: \(availableBeds?.description ?? "nil")")
        print("  👥 [RoomDetailData.toRoom] students count: \(students.count)")
        let room = Room(
            id: id,
            pgId: pgId,
            number: number,
            type: type,
            bedCount: bedCount,
            occupiedBeds: occupiedBeds ?? 0,
            availableBeds: availableBeds ?? (bedCount - (occupiedBeds ?? 0)),
            details: details,
            photos: photos,
            order: order,
            students: students,
            createdAt: Date(),
            updatedAt: Date()
        )
        print("  ✅ [RoomDetailData.toRoom] Created Room: id=\(room.id), number=\(room.number), students: \(room.students.count)")
        return room
    }
}

