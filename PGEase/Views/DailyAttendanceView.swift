import SwiftUI

struct DailyAttendanceView: View {
    @StateObject private var attendanceManager = AttendanceManager()
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showingNotifySheet = false
    @State private var selectedStudents: Set<String> = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            ZStack {
                if attendanceManager.isLoading && attendanceManager.students.isEmpty {
                    loadingView
                } else if let error = attendanceManager.errorMessage {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .navigationTitle("Daily Attendance")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    datePicker
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .refreshable {
                await loadAttendance()
            }
            .task {
                await loadAttendance()
            }
            .onDisappear {
                attendanceManager.stopAutoRefresh()
            }
            .onChange(of: selectedDate) { _, _ in
                Task {
                    await loadAttendance()
                }
            }
            .alert("Notification", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Stats Card
                if let summary = attendanceManager.summary {
                    let displayDate = attendanceManager.attendanceDate ?? selectedDate
                    summaryCard(summary, date: displayDate)
                }
                
                // Filter Tabs
                filterTabs
                
                // Student List
                studentList
                
                // Last Updated
                if let lastUpdated = attendanceManager.lastUpdated {
                    lastUpdatedView(lastUpdated)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Summary Card
    
    private func summaryCard(_ summary: AttendanceSummary, date: Date) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Attendance Summary")
                    .font(.headline)
                Spacer()
                Text("\(formattedDate(date))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(title: "Total", value: "\(summary.total)", color: .purple)
                StatCard(title: "Checked In", value: "\(summary.checkedIn)", color: .green)
                StatCard(title: "Checked Out", value: "\(summary.checkedOut)", color: .blue)
                StatCard(title: "Not Returned", value: "\(summary.notReturned)", color: .orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Filter Tabs
    
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChipAttendance(
                    title: "All",
                    count: attendanceManager.students.count,
                    isSelected: attendanceManager.selectedFilter == nil
                ) {
                    attendanceManager.setFilter(nil)
                }
                
                FilterChipAttendance(
                    title: "Checked In",
                    count: attendanceManager.getCount(for: .checkedIn),
                    isSelected: attendanceManager.selectedFilter == .checkedIn,
                    color: .green
                ) {
                    attendanceManager.setFilter(.checkedIn)
                }
                
                FilterChipAttendance(
                    title: "Checked Out",
                    count: attendanceManager.getCount(for: .checkedOut),
                    isSelected: attendanceManager.selectedFilter == .checkedOut,
                    color: .blue
                ) {
                    attendanceManager.setFilter(.checkedOut)
                }
                
                FilterChipAttendance(
                    title: "Not Returned",
                    count: attendanceManager.getCount(for: .notReturned),
                    isSelected: attendanceManager.selectedFilter == .notReturned,
                    color: .orange
                ) {
                    attendanceManager.setFilter(.notReturned)
                }
                
                FilterChipAttendance(
                    title: "Absent",
                    count: attendanceManager.getCount(for: .absent),
                    isSelected: attendanceManager.selectedFilter == .absent,
                    color: .red
                ) {
                    attendanceManager.setFilter(.absent)
                }
            }
        }
    }
    
    // MARK: - Student List
    
    private var studentList: some View {
        VStack(spacing: 12) {
            if attendanceManager.filteredStudents.isEmpty {
                emptyStateView
            } else {
                ForEach(attendanceManager.filteredStudents) { student in
                    StudentAttendanceRow(student: student) {
                        // Tap action - navigate to detail view (future)
                        print("Tapped \(student.name)")
                    } onNotify: {
                        // Notify this student's parents
                        notifyParents(studentIds: [student.studentId])
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No students in this category")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading attendance...")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("Error")
                .font(.headline)
            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    await loadAttendance()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    // MARK: - Refresh Button
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await loadAttendance()
            }
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(attendanceManager.isLoading)
    }
    
    private var datePicker: some View {
        DatePicker(
            "",
            selection: $selectedDate,
            displayedComponents: .date
        )
        .labelsHidden()
    }
    
    // MARK: - Last Updated View
    
    private func lastUpdatedView(_ date: Date) -> some View {
        Text("Last updated: \(date, formatter: timeFormatter)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    // MARK: - Helper Methods
    
    private func loadAttendance() async {
        guard let pgId = authManager.currentPgId else { return }
        await attendanceManager.fetchAttendance(pgId: pgId, date: selectedDate)
        
        if Calendar.current.isDateInToday(selectedDate) {
            attendanceManager.startAutoRefresh(pgId: pgId, date: selectedDate)
        } else {
            attendanceManager.stopAutoRefresh()
        }
    }
    
    private func notifyParents(studentIds: [String]) {
        guard let pgId = authManager.currentPgId else { return }
        Task {
            do {
                let response = try await attendanceManager.notifyParents(
                    studentIds: studentIds,
                    pgId: pgId
                )
                alertMessage = "Notifications sent: \(response.notificationsSent)\nFailed: \(response.failed)"
                showingAlert = true
            } catch {
                alertMessage = "Failed to send notifications: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Filter Chip Component

struct FilterChipAttendance: View {
    let title: String
    let count: Int
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : color.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Student Attendance Row

struct StudentAttendanceRow: View {
    let student: StudentAttendance
    let onTap: () -> Void
    let onNotify: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status Indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                // Student Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(student.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        if let room = student.roomNumber {
                            Label(room, systemImage: "door.left.hand.closed")
                                .font(.caption)
                        }
                        
                        if student.status == .checkedIn, let time = student.checkInTime {
                            Text("In: \(student.checkInTimeFormatted)")
                                .font(.caption)
                        } else if student.status == .checkedOut, let time = student.checkOutTime {
                            Text("Out: \(student.checkOutTimeFormatted)")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 6) {
                    Image(systemName: student.status.iconName)
                        .foregroundColor(statusColor)
                    Text(student.status.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.1))
                .cornerRadius(8)
                
                // Notify Button (only for not returned)
                if student.status == .notReturned {
                    Button(action: onNotify) {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.orange)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    private var statusColor: Color {
        switch student.status {
        case .checkedIn: return .green
        case .checkedOut: return .blue
        case .notReturned: return .orange
        case .absent: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    DailyAttendanceView()
        .environmentObject(AuthManager())
}

