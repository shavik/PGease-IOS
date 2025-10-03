import SwiftUI

struct IssuesView: View {
    @State private var selectedCategory = "All"
    @State private var showingNewIssue = false
    
    let categories = ["All", "Room", "Facilities", "Service", "Technical", "Other"]
    
    @State private var issues: [Issue] = [
        Issue(
            title: "Air conditioning not working",
            description: "The AC in my room is not cooling properly. Temperature seems to be stuck at 75°F.",
            category: "Room",
            status: .open,
            priority: .high,
            timestamp: Date().addingTimeInterval(-3600)
        ),
        Issue(
            title: "WiFi connection issues",
            description: "Internet keeps dropping every few minutes. Very frustrating when trying to work.",
            category: "Technical",
            status: .inProgress,
            priority: .medium,
            timestamp: Date().addingTimeInterval(-7200)
        ),
        Issue(
            title: "Room service delay",
            description: "Ordered breakfast 2 hours ago, still haven't received it.",
            category: "Service",
            status: .resolved,
            priority: .high,
            timestamp: Date().addingTimeInterval(-14400)
        ),
        Issue(
            title: "Elevator maintenance",
            description: "Elevator on floor 3 is making strange noises.",
            category: "Facilities",
            status: .open,
            priority: .low,
            timestamp: Date().addingTimeInterval(-1800)
        )
    ]
    
    var filteredIssues: [Issue] {
        if selectedCategory == "All" {
            return issues
        } else {
            return issues.filter { $0.category == selectedCategory }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            CategoryFilterButton(
                                title: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                
                // Issues List
                if filteredIssues.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredIssues) { issue in
                                IssueCard(issue: issue)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Issues & Support")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewIssue = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewIssue) {
                NewIssueView { newIssue in
                    issues.append(newIssue)
                }
            }
        }
    }
}

struct Issue: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let category: String
    var status: IssueStatus
    let priority: IssuePriority
    let timestamp: Date
}

enum IssueStatus: String, CaseIterable {
    case open = "Open"
    case inProgress = "In Progress"
    case resolved = "Resolved"
    case closed = "Closed"
    
    var color: Color {
        switch self {
        case .open: return .orange
        case .inProgress: return .blue
        case .resolved: return .green
        case .closed: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .open: return "exclamationmark.circle"
        case .inProgress: return "clock"
        case .resolved: return "checkmark.circle"
        case .closed: return "xmark.circle"
        }
    }
}

enum IssuePriority: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(20)
        }
    }
}

struct IssueCard: View {
    let issue: Issue
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(issue.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 4) {
                    Image(systemName: issue.status.icon)
                        .font(.caption)
                    Text(issue.status.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(issue.status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(issue.status.color.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Description
            Text(issue.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // Footer
            HStack {
                // Priority
                HStack(spacing: 4) {
                    Circle()
                        .fill(issue.priority.color)
                        .frame(width: 8, height: 8)
                    Text(issue.priority.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Timestamp
                Text(formatTime(issue.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Details Button
                Button("Details") {
                    showingDetails = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingDetails) {
            IssueDetailView(issue: issue)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("No Issues Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Great! There are no issues in this category.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct IssueDetailView: View {
    let issue: Issue
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status and Priority
                    HStack {
                        StatusBadge(status: issue.status)
                        PriorityBadge(priority: issue.priority)
                        Spacer()
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        Text(issue.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.headline)
                        
                        DetailIssueRow(label: "Category", value: issue.category)
                        DetailIssueRow(label: "Created", value: formatDate(issue.timestamp))
                        DetailIssueRow(label: "Status", value: issue.status.rawValue)
                        DetailIssueRow(label: "Priority", value: issue.priority.rawValue)
                    }
                }
                .padding()
            }
            .navigationTitle(issue.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: IssueStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption)
            Text(status.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(status.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PriorityBadge: View {
    let priority: IssuePriority
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(priority.color)
                .frame(width: 8, height: 8)
            Text(priority.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(priority.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(priority.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DetailIssueRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct NewIssueView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var selectedCategory = "Room"
    @State private var selectedPriority = IssuePriority.medium
    
    let categories = ["Room", "Facilities", "Service", "Technical", "Other"]
    let onSave: (Issue) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Issue Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Priority") {
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(IssuePriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let newIssue = Issue(
                            title: title,
                            description: description,
                            category: selectedCategory,
                            status: .open,
                            priority: selectedPriority,
                            timestamp: Date()
                        )
                        onSave(newIssue)
                        dismiss()
                    }
                    .disabled(title.isEmpty || description.isEmpty)
                }
            }
        }
    }
}

#Preview {
    IssuesView()
}
