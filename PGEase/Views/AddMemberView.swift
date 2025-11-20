//
//  AddMemberView.swift
//  PGEase
//
//  Form to add new members (users) to the PG
//

import SwiftUI

struct AddMemberView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var pgStore: PGStore
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var selectedRole: PermissionManager.UserRole?
    
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var createdUserId: String?
    @State private var showSuccess = false
    @State private var generatedInvite: GenerateInviteResponse.InviteData?
    @State private var showInviteShare = false
    @State private var isGeneratingInvite = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Add New Member")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Fill in the details below")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name *")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            TextField("Enter full name", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                        }
                        
                        // Email
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email *")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            TextField("example@email.com", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                        }
                        
                        // Phone
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phone")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            TextField("+91 9876543210", text: $phone)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.phonePad)
                        }
                        
                        // Role Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Role *")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Menu {
                                ForEach(allowedRoles, id: \.role) { item in
                                    Button(action: {
                                        selectedRole = item.role
                                    }) {
                                        HStack {
                                            Image(systemName: item.role.icon)
                                            Text(item.display)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    if let role = selectedRole {
                                        Image(systemName: role.icon)
                                        Text(role.displayName)
                                    } else {
                                        Text("Select role...")
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Create Button
                    Button(action: createMember) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isCreating ? "Creating..." : "Create Member")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || isCreating)
                    .padding(.horizontal)
                    
                    // Info Box
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What happens next?", systemImage: "info.circle")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("1. Member account will be created")
                        Text("2. You'll be taken to generate an invite")
                        Text("3. Share the invite code or QR with the member")
                        Text("4. Member signs up and sets their password")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Member Created!", isPresented: $showSuccess) {
                Button("Generate Invite Now") {
                    generateInviteForCreatedMember()
                }
                Button("Later", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("\(name) has been added. Generate an invite to onboard them.")
            }
            .sheet(isPresented: $showInviteShare) {
                if let invite = generatedInvite {
                    InviteShareView(inviteData: invite)
                        .onDisappear {
                            dismiss() // Close AddMemberView after sharing
                        }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var allowedRoles: [(role: PermissionManager.UserRole, display: String)] {
        guard let userRole = PermissionManager.roleFromString(authManager.userRole.rawValue) else {
            return []
        }
        return PermissionManager.getAllowedRolesForPicker(for: userRole)
    }
    
    private var isFormValid: Bool {
        return !name.isEmpty &&
               !email.isEmpty &&
               email.contains("@") &&
               selectedRole != nil
    }
    
    // MARK: - Methods
    
    private func createMember() {
        guard let role = selectedRole,
              let pgId = authManager.currentPgId,
              let creatorId = authManager.currentUser?.id else {
            return
        }
        
        isCreating = true
        
        Task {
            do {
                let userId = try await pgStore.createMember(
                    pgId: pgId,
                    name: name,
                    email: email,
                    phone: phone.isEmpty ? nil : phone,
                    role: role.rawValue,
                    createdBy: creatorId
                )
                
                createdUserId = userId
                showSuccess = true
                print("✅ Member created: \(userId)")
            } catch {
                errorMessage = "Failed to create member: \(error.localizedDescription)"
                showError = true
                print("❌ Create member error: \(error)")
            }
            
            isCreating = false
        }
    }
    
    private func generateInviteForCreatedMember() {
        guard let userId = createdUserId,
              let creatorId = authManager.currentUser?.id else {
            return
        }
        
        isGeneratingInvite = true
        showSuccess = false // Dismiss the success alert
        
        Task {
            do {
                let response = try await APIManager.shared.generateInvite(
                    userId: userId,
                    createdBy: creatorId
                )
                
                if response.success {
                    await MainActor.run {
                        generatedInvite = response.data
                        isGeneratingInvite = false
                        showInviteShare = true // Show invite share sheet
                        print("✅ Invite generated: \(response.data.inviteCode)")
                    }
                }
            } catch {
                await MainActor.run {
                    isGeneratingInvite = false
                    errorMessage = "Failed to generate invite: \(error.localizedDescription)"
                    showError = true
                    print("❌ Generate invite error: \(error)")
                }
            }
        }
    }
}

//#Preview {
//    AddMemberView pgStore: <#PGStore#>)
//        .environmentObject(AuthManager())
//}

