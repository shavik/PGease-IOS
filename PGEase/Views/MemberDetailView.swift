//
//  MemberDetailView.swift
//  PGEase
//
//  Detailed view of a member with invite management
//

import SwiftUI

struct MemberDetailView: View {
    let member: UserListItem
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var inviteData: GenerateInviteResponse.InviteData?
    @State private var isLoading = false
    @State private var isGeneratingInvite = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showInviteShare = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(roleColor(for: member.role))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: roleIcon(for: member.role))
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                        
                        Text(member.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(member.role)
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(roleColor(for: member.role).opacity(0.2))
                            .foregroundColor(roleColor(for: member.role))
                            .cornerRadius(20)
                        
                        MemberStatusBadge(status: member.status)
                    }
                    .padding(.top)
                    
                    // Contact Info
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Contact Information")
                        
                        MemberInfoRow(icon: "envelope.fill", label: "Email", value: member.email)

                        if let phone = member.phone, !phone.isEmpty {
                            MemberInfoRow(icon: "phone.fill", label: "Phone", value: phone)
                        }
                        
                        MemberInfoRow(icon: "calendar", label: "Added", value: formatDate(member.createdAt))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Invite Status
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Invite Status")
                        
                        if let inviteStatus = member.inviteStatus {
                            if inviteStatus.isUsed {
                                // Invite used - show success
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                    VStack(alignment: .leading) {
                                        Text("Invite Used")
                                            .font(.headline)
                                        Text("Member has activated their account")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                                
                            } else if inviteStatus.isExpired {
                                // Invite expired
                                HStack {
                                    Image(systemName: "clock.badge.exclamationmark")
                                        .foregroundColor(.orange)
                                        .font(.title2)
                                    VStack(alignment: .leading) {
                                        Text("Invite Expired")
                                            .font(.headline)
                                        if let expiresAt = inviteStatus.expiresAt {
                                            Text("Expired on \(formatDate(expiresAt))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                                
                                // Regenerate button
                                Button(action: generateInvite) {
                                    HStack {
                                        if isGeneratingInvite {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                        Text(isGeneratingInvite ? "Regenerating..." : "Regenerate Invite")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(isGeneratingInvite)
                                
                            } else {
                                // Invite active
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                    VStack(alignment: .leading) {
                                        Text("Invite Active")
                                            .font(.headline)
                                        if let expiresAt = inviteStatus.expiresAt {
                                            Text("Expires on \(formatDate(expiresAt))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                
                                // View/Share button
                                Button(action: loadAndShowInvite) {
                                    HStack {
                                        Image(systemName: "qrcode")
                                        Text("View/Share Invite")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }
                        } else {
                            // No invite yet
                            HStack {
                                Image(systemName: "envelope.badge.fill")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text("No Invite Generated")
                                        .font(.headline)
                                    Text("Generate an invite to onboard this member")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                            
                            // Generate button
                            Button(action: generateInvite) {
                                HStack {
                                    if isGeneratingInvite {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    }
                                    Image(systemName: "envelope.badge.plus")
                                    Text(isGeneratingInvite ? "Generating..." : "Generate Invite")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isGeneratingInvite)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Member Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showInviteShare) {
                if let invite = inviteData {
                    InviteShareView(inviteData: invite)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Methods
    
    private func generateInvite() {
        guard let creatorId = authManager.currentUser?.id else { return }
        
        isGeneratingInvite = true
        
        Task {
            do {
                let response = try await APIManager.shared.generateInvite(
                    userId: member.id,
                    createdBy: creatorId
                )
                
                if response.success {
                    inviteData = response.data
                    showInviteShare = true
                    print("✅ Invite generated: \(response.data.inviteCode)")
                }
            } catch {
                errorMessage = "Failed to generate invite: \(error.localizedDescription)"
                showError = true
                print("❌ Generate invite error: \(error)")
            }
            
            isGeneratingInvite = false
        }
    }
    
    private func loadAndShowInvite() {
        isLoading = true
        
        Task {
            do {
                let response = try await APIManager.shared.getUserInviteStatus(userId: member.id)
                
                if response.success, let data = response.data {
                    inviteData = GenerateInviteResponse.InviteData(
                        inviteCode: data.inviteCode,
                        qrCode: data.qrCode ?? "",
                        deepLink: data.deepLink ?? "",
                        expiresAt: data.expiresAt,
                        user: GenerateInviteResponse.InviteUser(
                            id: data.user.id,
                            name: data.user.name,
                            email: data.user.email,
                            role: data.user.role
                        )
                    )
                    showInviteShare = true
                }
            } catch {
                errorMessage = "Failed to load invite: \(error.localizedDescription)"
                showError = true
                print("❌ Load invite error: \(error)")
            }
            
            isLoading = false
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        
        return displayFormatter.string(from: date)
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
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.bold)
    }
}

struct MemberInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }
            
            Spacer()
        }
    }
}

struct MemberStatusBadge: View {
    let status: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(status)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .cornerRadius(20)
    }
    
    private var statusColor: Color {
        switch status {
        case "ACTIVE": return .green
        case "PENDING": return .orange
        case "INACTIVE", "SUSPENDED": return .red
        default: return .gray
        }
    }
}

