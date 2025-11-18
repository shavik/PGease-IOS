import Foundation
import Combine

@MainActor
class AttendanceManager: ObservableObject {
    @Published var summary: AttendanceSummary?
    @Published var students: [StudentAttendance] = []
    @Published var filteredStudents: [StudentAttendance] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var attendanceDate: Date?
    @Published var selectedFilter: AttendanceStatus? = nil
    
    private let apiManager = APIManager.shared
    private var refreshTimer: Timer?
    private static let requestDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    private static let isoParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    // MARK: - Fetch Attendance for Date
    
    func fetchAttendance(pgId: String, date: Date, autoRefresh: Bool = false) async {
        if !autoRefresh {
            isLoading = true
        }
        errorMessage = nil
        
        do {
            let dateString = AttendanceManager.requestDateFormatter.string(from: date)
            let offsetMinutes = TimeZone.current.secondsFromGMT(for: date) / 60
            let endpoint = "/pg/\(pgId)/attendance/today?date=\(dateString)&tzOffset=\(offsetMinutes)"
            let response: TodayAttendanceResponse = try await apiManager.makeRequest(
                endpoint: endpoint,
                method: .GET,
                responseType: TodayAttendanceResponse.self
            )
            
            summary = response.summary
            students = response.students
            applyFilter()
            
            if let responseDate = response.date,
               let parsedDate = AttendanceManager.isoParser.date(from: responseDate) {
                attendanceDate = parsedDate
            } else {
                attendanceDate = date
            }
            
            if let responseUpdated = AttendanceManager.isoParser.date(from: response.lastUpdated) {
                lastUpdated = responseUpdated
            } else {
                lastUpdated = Date()
            }
            
            print("✅ [Attendance] Fetched \(students.count) students")
        } catch {
            errorMessage = "Failed to load attendance: \(error.localizedDescription)"
            print("❌ [Attendance] Error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Filter Students
    
    func applyFilter() {
        if let filter = selectedFilter {
            filteredStudents = students.filter { $0.status == filter }
        } else {
            filteredStudents = students
        }
    }
    
    func setFilter(_ filter: AttendanceStatus?) {
        selectedFilter = filter
        applyFilter()
    }
    
    // MARK: - Notify Parents
    
    func notifyParents(
        studentIds: [String],
        notificationType: String = "NOT_RETURNED",
        channel: String = "WHATSAPP",
        message: String? = nil,
        pgId: String
    ) async throws -> NotifyParentsResponse {
        let response: NotifyParentsResponse = try await apiManager.makeRequest(
            endpoint: "/pg/\(pgId)/notify-parents",
            method: .POST,
            body: [
                "studentIds": studentIds,
                "notificationType": notificationType,
                "channel": channel,
                "message": message as Any
            ],
            responseType: NotifyParentsResponse.self
        )
        
        print("✅ [Attendance] Notifications sent: \(response.notificationsSent)")
        return response
    }
    
    // MARK: - Auto Refresh
    
    func startAutoRefresh(pgId: String, date: Date, interval: TimeInterval = 30) {
        stopAutoRefresh()
        
        guard Calendar.current.isDateInToday(date) else {
            return
        }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.fetchAttendance(pgId: pgId, date: date, autoRefresh: true)
            }
        }
        
        print("🔄 [Attendance] Auto-refresh started (every \(interval)s)")
    }
    
    nonisolated func stopAutoRefresh() {
        Task { @MainActor in
            refreshTimer?.invalidate()
            refreshTimer = nil
            print("🛑 [Attendance] Auto-refresh stopped")
        }
    }
    
    // MARK: - Helper Methods
    
    func getStudentsByStatus(_ status: AttendanceStatus) -> [StudentAttendance] {
        return students.filter { $0.status == status }
    }
    
    func getCount(for status: AttendanceStatus) -> Int {
        return getStudentsByStatus(status).count
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopAutoRefresh()
    }
}

