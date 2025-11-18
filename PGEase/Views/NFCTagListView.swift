import SwiftUI

/// View for listing and managing NFC tags
/// Only accessible by MANAGER and PGADMIN roles
struct NFCTagListView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var nfcManager: NFCTagManager?
    
    @State private var tags: [NFCTagInfo] = []
    @State private var selectedStatus: TagStatusFilter = .all
    @State private var searchText = ""
    @State private var showingWriteView = false
    @State private var selectedTag: NFCTagInfo?
    @State private var showingTagDetail = false
    @State private var showingDeactivateSheet = false
    @State private var isRefreshing = false
    
    enum TagStatusFilter: String, CaseIterable {
        case all = "All"
        case active = "ACTIVE"
        case inactive = "INACTIVE"
        case lost = "LOST"
        case damaged = "DAMAGED"
    }
    
    var filteredTags: [NFCTagInfo] {
        var filtered = tags
        
        // Filter by status
        if selectedStatus != .all {
            filtered = filtered.filter { $0.status == selectedStatus.rawValue }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { tag in
                if let room = tag.room {
                    return room.number.localizedCaseInsensitiveContains(searchText) ||
                           tag.tagId.localizedCaseInsensitiveContains(searchText)
                }
                return tag.tagId.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Status Filter
                statusFilter
                
                // Tag List
                if isRefreshing {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredTags.isEmpty {
                    emptyState
                } else {
                    tagList
                }
            }
            .navigationTitle("NFC Tags")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingWriteView = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingWriteView) {
                NFCTagWriteView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showingTagDetail) {
                // ✅ Only show if nfcManager is initialized
                if let tag = selectedTag, let nfcManager = nfcManager {
                    NFCTagDetailView(tag: tag, nfcManager: nfcManager)
                }
            }
            .sheet(isPresented: $showingDeactivateSheet) {
                // ✅ Only show if nfcManager is initialized
                if let tag = selectedTag, let nfcManager = nfcManager {
                    DeactivateTagSheet(tag: tag, nfcManager: nfcManager) {
                        showingDeactivateSheet = false
                        loadTags()
                    }
                }
            }
            .onAppear {
                // ✅ Initialize NFCTagManager with authManager
                if nfcManager == nil {
                    nfcManager = NFCTagManager(authManager: authManager)
                }
                loadTags()
            }
            .refreshable {
                await refreshTags()
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search by room or tag ID", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding()
    }
    
    // MARK: - Status Filter
    
    private var statusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TagStatusFilter.allCases, id: \.self) { status in
                    StatusFilterChip(
                        title: status.rawValue,
                        isSelected: selectedStatus == status,
                        count: countForStatus(status)
                    ) {
                        selectedStatus = status
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Tag List
    
    private var tagList: some View {
        List {
            ForEach(filteredTags, id: \.id) { tag in
                TagRow(tag: tag)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTag = tag
                        showingTagDetail = true
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if tag.status == "ACTIVE" {
                            Button(role: .destructive) {
                                selectedTag = tag
                                showingDeactivateSheet = true
                            } label: {
                                Label("Deactivate", systemImage: "xmark.circle")
                            }
                        }
                    }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tag.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No NFC Tags")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingWriteView = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Write New Tag")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "No tags match your search"
        } else if selectedStatus != .all {
            return "No tags with status: \(selectedStatus.rawValue)"
        } else {
            return "Get started by writing your first NFC tag"
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadTags() {
        // ✅ Safely unwrap nfcManager
        guard let nfcManager = nfcManager else { return }
        
        isRefreshing = true
        
        Task {
            // ✅ listTags() now uses authManager.currentPgId internally
            if let fetchedTags = await nfcManager.listTags() {
                await MainActor.run {
                    self.tags = fetchedTags
                    self.isRefreshing = false
                }
            } else {
                await MainActor.run {
                    self.isRefreshing = false
                }
            }
        }
    }
    
    private func refreshTags() async {
        // ✅ Safely unwrap nfcManager
        guard let nfcManager = nfcManager else { return }
        
        // ✅ listTags() now uses authManager.currentPgId internally
        if let fetchedTags = await nfcManager.listTags() {
            await MainActor.run {
                self.tags = fetchedTags
            }
        }
    }
    
    private func countForStatus(_ status: TagStatusFilter) -> Int {
        if status == .all {
            return tags.count
        }
        return tags.filter { $0.status == status.rawValue }.count
    }
}

// MARK: - Tag Row

struct TagRow: View {
    let tag: NFCTagInfo
    
    var body: some View {
        HStack(spacing: 16) {
            // Status Indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            // Tag Info
            VStack(alignment: .leading, spacing: 4) {
                Text(tag.room?.number ?? "No Room")
                    .font(.headline)
                
                Text("Tag ID: \(String(tag.tagId.prefix(8)))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let lastScanned = tag.lastScannedAt {
                    Text("Last scanned: \(formatDate(lastScanned))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status Badge
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadgeNFCTag(status: tag.status)
                
                if tag.passwordSet {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Locked")
                            .font(.caption2)
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var statusColor: Color {
        switch tag.status {
        case "ACTIVE": return .green
        case "INACTIVE": return .gray
        case "LOST": return .orange
        case "DAMAGED": return .red
        default: return .gray
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Simple date formatting - can be improved
        return dateString.prefix(10).replacingOccurrences(of: "-", with: "/")
    }
}

// MARK: - Status Badge

struct StatusBadgeNFCTag: View {
    let status: String
    
    var body: some View {
        Text(status)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        switch status {
        case "ACTIVE": return .green.opacity(0.2)
        case "INACTIVE": return .gray.opacity(0.2)
        case "LOST": return .orange.opacity(0.2)
        case "DAMAGED": return .red.opacity(0.2)
        default: return .gray.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch status {
        case "ACTIVE": return .green
        case "INACTIVE": return .gray
        case "LOST": return .orange
        case "DAMAGED": return .red
        default: return .gray
        }
    }
}

// MARK: - Filter Chip

struct StatusFilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Tag Detail View

struct NFCTagDetailView: View {
    let tag: NFCTagInfo
    @ObservedObject var nfcManager: NFCTagManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showingPassword = false
    @State private var tagPassword: String?
    
    var body: some View {
        NavigationView {
            List {
                Section("Tag Information") {
                    DetailRow(title: "Tag ID", value: tag.tagId)
                    DetailRow(title: "Status", value: tag.status)
                    if let room = tag.room {
                        DetailRow(title: "Room", value: room.number)
                        DetailRow(title: "Room Type", value: room.type ?? "No Type")
                    }
                    DetailRow(title: "Password Set", value: tag.passwordSet ? "Yes" : "No")
                }
                
                Section("Timestamps") {
                    if let lastScanned = tag.lastScannedAt {
                        DetailRow(title: "Last Scanned", value: lastScanned)
                    }
                    DetailRow(title: "Created", value: tag.createdAt)
                    if let updated = tag.updatedAt {
                        DetailRow(title: "Updated", value: updated)
                    }
                }
                
                if tag.passwordSet {
                    Section("Security") {
                        Button(action: loadPassword) {
                            HStack {
                                Image(systemName: "key.fill")
                                Text("View Password")
                                Spacer()
                                if nfcManager.isLoading {
                                    ProgressView()
                                }
                            }
                        }
                        
                        if let password = tagPassword {
                            Text(showingPassword ? password : String(repeating: "•", count: 12))
                                .font(.system(.body, design: .monospaced))
                            
                            Button(action: { showingPassword.toggle() }) {
                                HStack {
                                    Image(systemName: showingPassword ? "eye.slash" : "eye")
                                    Text(showingPassword ? "Hide" : "Show")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tag Details")
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
    
    private func loadPassword() {
        Task {
            tagPassword = await nfcManager.getTagPassword(tagId: tag.tagId)
        }
    }
}

// MARK: - Deactivate Tag Sheet

struct DeactivateTagSheet: View {
    let tag: NFCTagInfo
    @ObservedObject var nfcManager: NFCTagManager
    let onComplete: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedStatus: String = "INACTIVE"
    @State private var reason: String = ""
    
    let deactivationStatuses = ["INACTIVE", "LOST", "DAMAGED"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("New Status") {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(deactivationStatuses, id: \.self) { status in
                            Text(status).tag(status)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Reason (Optional)") {
                    TextEditor(text: $reason)
                        .frame(height: 100)
                }
                
                Section {
                    Button(action: deactivate) {
                        if nfcManager.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Deactivate Tag")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(nfcManager.isLoading)
                }
            }
            .navigationTitle("Deactivate Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func deactivate() {
        Task {
            await nfcManager.deactivateTag(
                tagId: tag.tagId,
                status: selectedStatus,
                reason: reason.isEmpty ? nil : reason
            )
            
            await MainActor.run {
                dismiss()
                onComplete()
            }
        }
    }
}

// MARK: - Preview

struct NFCTagListView_Previews: PreviewProvider {
    static var previews: some View {
        // Ensure AuthManager is provided for preview
        NFCTagListView()
            .environmentObject(AuthManager())
    }
}
