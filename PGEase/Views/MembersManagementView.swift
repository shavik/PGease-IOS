//
//  MembersManagementView.swift
//  PGEase
//
//  Members management for PGADMIN/MANAGER/WARDEN
//

import SwiftUI

struct MembersManagementView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = MembersViewModel()
    
    @State private var showAddMember = false
    @State private var selectedMember: UserListItem?
    @State private var showMemberDetail = false
    @State private var searchText = ""
    @State private var selectedFilter: String? = nil
    
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
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading members...")
                    Spacer()
                } else if filteredMembers.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.slash")
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
                AddMemberView()
                    .environmentObject(authManager)
                    .onDisappear {
                        Task {
                            await loadMembers()
                        }
                    }
            }
            .sheet(item: $selectedMember) { member in
                MemberDetailView(member: member)
                    .environmentObject(authManager)
                    .onDisappear {
                        Task {
                            await loadMembers()
                        }
                    }
            }
            .task {
                await loadMembers()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
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
        var members = viewModel.members
        
        // Apply role filter
        if let filter = selectedFilter {
            members = members.filter { $0.role == filter }
        }
        
        // Apply search
        if !searchText.isEmpty {
            members = members.filter { member in
                member.name.localizedCaseInsensitiveContains(searchText) ||
                member.email.localizedCaseInsensitiveContains(searchText) ||
                (member.phone?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return members
    }
    
    // MARK: - Methods
    
    private func loadMembers() async {
        guard let pgId = authManager.currentPgId else { return }
        await viewModel.loadMembers(pgId: pgId, role: selectedFilter)
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

// MARK: - View Model

@MainActor
class MembersViewModel: ObservableObject {
    @Published var members: [UserListItem] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    func loadMembers(pgId: String, role: String? = nil) async {
        isLoading = true
        
        do {
            let response = try await APIManager.shared.listUsers(pgId: pgId, role: role)
            members = response.users
        } catch {
            errorMessage = "Failed to load members: \(error.localizedDescription)"
            showError = true
            print("❌ Load members error: \(error)")
        }
        
        isLoading = false
    }
}

