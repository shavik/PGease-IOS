//
//  MembersManagementView.swift
//  PGEase
//
//  Members management for PGADMIN/MANAGER/WARDEN
//

import SwiftUI

struct MembersManagementView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appStore: AppStore
    
    @State private var showAddMember = false
    @State private var selectedMember: UserListItem?
    @State private var showMemberDetail = false
    @State private var searchText = ""
    @State private var selectedFilter: String? = nil
    
    // Helper view that observes pgStore
    var body: some View {
        MembersManagementContentView(
            pgStore: appStore.pgStore,
            showAddMember: $showAddMember,
            selectedMember: $selectedMember,
            showMemberDetail: $showMemberDetail,
            searchText: $searchText,
            selectedFilter: $selectedFilter
        )
        .environmentObject(authManager)
    }
}

// Helper view that directly observes pgStore
private struct MembersManagementContentView: View {
    @ObservedObject var pgStore: PGStore
    @EnvironmentObject var authManager: AuthManager
    
    @Binding var showAddMember: Bool
    @Binding var selectedMember: UserListItem?
    @Binding var showMemberDetail: Bool
    @Binding var searchText: String
    @Binding var selectedFilter: String?
    
    // Computed properties from store
    private var isLoading: Bool {
        pgStore.state.membersLoading
    }
    
    private var errorMessage: String? {
        pgStore.state.membersError
    }
    
    // Get all members from store and filter locally
    private var members: [UserListItem] {
        guard let pgId = authManager.currentPgId else { return [] }
        let memberIds = pgStore.state.membersByPg[pgId] ?? []
        return memberIds.compactMap { userId -> UserListItem? in
            guard let member = pgStore.state.members[userId] else { return nil }
            // Get room number from room data if available (for students)
            let roomNumber: String? = {
                if let roomId = member.roomId, let room = pgStore.state.rooms[roomId] {
                    return room.number
                }
                return member.roomNumber // Fallback to roomNumber from API
            }()
            // Return member with updated room number if we have it from store
            return UserListItem(
                id: member.id,
                name: member.name,
                email: member.email,
                phone: member.phone,
                studentId: member.studentId,
                roomId: member.roomId,
                roomNumber: roomNumber,
                role: member.role,
                status: member.status,
                accessStatus: member.accessStatus,
                inviteStatus: member.inviteStatus,
                createdAt: member.createdAt,
                updatedAt: member.updatedAt
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedFilter == nil,
                            action: { selectedFilter = nil }
                        )
                        
                        ForEach(availableFilters, id: \.self) { role in
                            FilterChip(
                                title: role,
                                isSelected: selectedFilter == role,
                                action: { selectedFilter = role }
                            )
                        }
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search members...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Members List
                if isLoading {
                    Spacer()
                    ProgressView("Loading members...")
                    Spacer()
                } else if filteredMembers.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No members found")
                            .font(.title3)
                            .fontWeight(.semibold)
                        if selectedFilter != nil {
                            Text("Try changing the filter")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredMembers) { member in
                            MemberRow(member: member)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedMember = member
                                    showMemberDetail = true
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await loadMembers()
                    }
                }
            }
            .navigationTitle("Members")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddMember = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddMember) {
                AddMemberView(pgStore: pgStore)
                    .environmentObject(authManager)
                    // No need to reload on dismiss - store already updated optimistically
            }
            .sheet(item: $selectedMember) { member in
                MemberDetailView(member: member, pgStore: pgStore)
                    .environmentObject(authManager)
                    // No need to reload on dismiss - store already updated optimistically
            }
            .task {
                print("📋 [Members] Task triggered - loading members...")
                // Wait a bit for currentPgId to be set if needed
                if authManager.currentPgId == nil {
                    print("⏳ [Members] Waiting for currentPgId...")
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                }
                await loadMembers()
            }
            .onAppear {
                print("📋 [Members] View appeared - pgId: \(authManager.currentPgId ?? "nil")")
                print("📋 [Members] Current members count: \(members.count)")
            }
            .onChange(of: authManager.currentPgId) { oldValue, newValue in
                print("📋 [Members] currentPgId changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
                if newValue != nil && members.isEmpty {
                    Task {
                        await loadMembers()
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { _ in pgStore.clearMembersError() }
            )) {
                Button("OK", role: .cancel) {
                    pgStore.clearMembersError()
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var availableFilters: [String] {
        guard let userRole = PermissionManager.roleFromString(authManager.userRole.rawValue) else {
            return []
        }
        return PermissionManager.getAllowedRoleStrings(for: userRole)
    }
    
    private var filteredMembers: [UserListItem] {
        var filtered = members
        
        // Apply role filter
        if let filter = selectedFilter {
            filtered = filtered.filter { $0.role == filter }
        }
        
        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { member in
                member.name.localizedCaseInsensitiveContains(searchText) ||
                member.email.localizedCaseInsensitiveContains(searchText) ||
                (member.phone?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return filtered
    }
    
    // MARK: - Methods
    
    @Sendable
    private func loadMembers() async {
        guard let pgId = authManager.currentPgId else {
            print("❌ [Members] Cannot load - currentPgId is nil")
            print("❌ [Members] Auth state - authenticated: \(authManager.isAuthenticated), role: \(authManager.userRole.rawValue)")
            return
        }
        print("📋 [Members] Loading members for PG: \(pgId)")
        // Load all members (no role filter - we filter locally)
        do {
            try await pgStore.loadMembers(pgId: pgId, role: nil)
            print("✅ [Members] Members loaded successfully")
        } catch {
            print("❌ [Members] Failed to load members: \(error.localizedDescription)")
        }
    }
}

// MARK: - Member Row Component

struct MemberRow: View {
    let member: UserListItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Avatar
                ZStack {
                    Circle()
                        .fill(roleColor(for: member.role))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: roleIcon(for: member.role))
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                // Member Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Text(member.role)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(roleColor(for: member.role).opacity(0.2))
                            .foregroundColor(roleColor(for: member.role))
                            .cornerRadius(4)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(member.status)
                            .font(.caption)
                            .foregroundColor(statusColor(for: member.status))
                        
                        // Show room number for students
                        if let roomNumber = member.roomNumber {
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 2) {
                                Image(systemName: "door.left.hand.closed")
                                    .font(.caption2)
                                Text(roomNumber)
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    Text(member.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Invite Status Indicator
                if let inviteStatus = member.inviteStatus {
                    inviteStatusBadge(inviteStatus)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func inviteStatusBadge(_ status: InviteStatus) -> some View {
        if status.isUsed {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        } else if status.isExpired {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundColor(.orange)
                .font(.title3)
        } else if status.hasInvite {
            Image(systemName: "envelope.fill")
                .foregroundColor(.blue)
                .font(.title3)
        } else {
            Image(systemName: "envelope.badge.fill")
                .foregroundColor(.gray)
                .font(.title3)
        }
    }
    
    private func roleColor(for role: String) -> Color {
        switch role {
        case "MANAGER": return .purple
        case "WARDEN": return .orange
        case "ACCOUNTANT": return .green
        case "STAFF": return .blue
        case "STUDENT": return .indigo
        default: return .gray
        }
    }
    
    private func roleIcon(for role: String) -> String {
        switch role {
        case "MANAGER": return "person.badge.key.fill"
        case "WARDEN": return "shield.fill"
        case "ACCOUNTANT": return "dollarsign.circle.fill"
        case "STAFF": return "figure.walk"
        case "STUDENT": return "graduationcap.fill"
        default: return "person.fill"
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "ACTIVE": return .green
        case "PENDING": return .orange
        case "INACTIVE", "SUSPENDED": return .red
        default: return .gray
        }
    }
}

// MARK: - Filter Chip Component

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}


