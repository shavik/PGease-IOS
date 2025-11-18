import Foundation

// MARK: - Attendance Status Enum
enum AttendanceStatus: String, Codable {
    case checkedIn = "CHECKED_IN"
    case checkedOut = "CHECKED_OUT"
    case notReturned = "NOT_RETURNED"
    case absent = "ABSENT"
    case unknown = "UNKNOWN"
    
    var displayName: String {
        switch self {
        case .checkedIn: return "Checked In"
        case .checkedOut: return "Checked Out"
        case .notReturned: return "Not Returned"
        case .absent: return "Absent"
        case .unknown: return "Unknown"
        }
    }
    
    var color: String {
        switch self {
        case .checkedIn: return "green"
        case .checkedOut: return "blue"
        case .notReturned: return "orange"
        case .absent: return "red"
        case .unknown: return "gray"
        }
    }
    
    var iconName: String {
        switch self {
        case .checkedIn: return "checkmark.circle.fill"
        case .checkedOut: return "arrow.uturn.right.circle.fill"
        case .notReturned: return "exclamationmark.triangle.fill"
        case .absent: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Student Attendance Model
struct StudentAttendance: Identifiable, Codable {
    let id: String
    let studentId: String
    let name: String
    let roomNumber: String?
    let photo: String?
    let status: AttendanceStatus
    let checkInTime: String?
    let checkOutTime: String?
    let lastUpdated: String?
    
    var checkInTimeFormatted: String {
        guard let checkInTime = checkInTime else { return "N/A" }
        return formatTime(checkInTime)
    }
    
    var checkOutTimeFormatted: String {
        guard let checkOutTime = checkOutTime else { return "N/A" }
        return formatTime(checkOutTime)
    }
    
    private func formatTime(_ isoString: String) -> String {
        print("Formatting1:", isoString)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else { return isoString }
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateFormat = "h:mm a" // "HH" for 24-hour format, "mm" for minutes
//        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
//        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let date2 = timeFormatter.string(from: date)
        print("Formatting2:", date2)
        return date2
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case studentId
        case name
        case roomNumber
        case photo
        case status
        case checkInTime
        case checkOutTime
        case lastUpdated
    }
}

// MARK: - Attendance Summary Model
struct AttendanceSummary: Codable {
    let total: Int
    let checkedIn: Int
    let checkedOut: Int
    let notReturned: Int
    let absent: Int
    
    var checkedInPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(checkedIn) / Double(total) * 100
    }
    
    var notReturnedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(notReturned) / Double(total) * 100
    }
    
    enum CodingKeys: String, CodingKey {
        case total
        case checkedIn
        case checkedOut
        case notReturned
        case absent
    }
}

// MARK: - Attendance Response Models
struct TodayAttendanceResponse: Codable {
    let success: Bool
    let summary: AttendanceSummary
    let students: [StudentAttendance]
    let lastUpdated: String
    let date: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case summary
        case students
        case lastUpdated
        case date
    }
}

// MARK: - Notify Parents Request
struct NotifyParentsRequest: Codable {
    let studentIds: [String]
    let notificationType: String
    let channel: String
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case studentIds
        case notificationType
        case channel
        case message
    }
}

// MARK: - Notify Parents Response
struct NotifyParentsResponse: Codable {
    let success: Bool
    let notificationsSent: Int
    let failed: Int
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case notificationsSent
        case failed
        case message
    }
}

