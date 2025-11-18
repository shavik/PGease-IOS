//
//  ManualInviteEntryView.swift
//  PGEase
//
//  For users who have an invite code but no deep link
//

import SwiftUI

struct ManualInviteEntryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var inviteCode = ""
    @State private var selectedUserType: OnboardingManager.UserType = .student
    @State private var isVerifying = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var navigateToOnboarding = false
    @State private var verifiedCode = ""
    @State private var verifiedType = ""
    
    let userTypes: [(type: OnboardingManager.UserType, display: String)] = [
        (.student, "Student"),
        (.staff, "Staff"),
        (.manager, "Manager"),
        (.warden, "Warden"),
        (.accountant, "Accountant"),
        (.vendor, "Vendor")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.blue)
                        
                        Text("Enter Invite Code")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Enter the code your manager sent you")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Invite Code Entry
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Invite Code")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            TextField("ABC123", text: $inviteCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.allCharacters)
                                .font(.system(.title3, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .onChange(of: inviteCode) { newValue in
                                    // Auto-uppercase and limit to 6 characters
                                    inviteCode = newValue.uppercased().prefix(6).description
                                }
                            
                            Text("6-character code (letters and numbers)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("I am a...")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Picker("User Type", selection: $selectedUserType) {
                                ForEach(userTypes, id: \.type) { item in
                                    HStack {
                                        Image(systemName: roleIcon(for: item.type))
                                        Text(item.display)
                                    }
                                    .tag(item.type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            Text("Select your role in the PG")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Example
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Where to find your code?")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("•")
                                Text("Check your WhatsApp/Email")
                            }
                            HStack {
                                Text("•")
                                Text("Ask your Manager/Warden")
                            }
                            HStack {
                                Text("•")
                                Text("Scan the QR code (if available)")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Verify Button
                    Button(action: verifyInviteCode) {
                        HStack {
                            if isVerifying {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isVerifying ? "Verifying..." : "Verify Code")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || isVerifying)
                    .padding(.horizontal)
                    
                    // Cancel Button
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .fullScreenCover(isPresented: $navigateToOnboarding) {
                InviteOnboardingView(
                    inviteCode: verifiedCode,
                    inviteType: verifiedType
                )
                .environmentObject(onboardingManager)
                .environmentObject(authManager)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        return inviteCode.count == 6
    }
    
    // MARK: - Methods
    
    private func verifyInviteCode() {
        isVerifying = true
        
        Task {
            do {
                // Call API to verify invite code exists and is valid
                let endpoint = "/users/verify-invite"
                guard let url = URL(string: "https://pg-ease.vercel.app/api\(endpoint)?code=\(inviteCode)&type=\(selectedUserType.rawValue.lowercased())") else {
                    await MainActor.run {
                        errorMessage = "Invalid request"
                        showError = true
                        isVerifying = false
                    }
                    return
                }
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                if httpResponse.statusCode == 200 {
                    let result = try JSONDecoder().decode(VerifyInviteResponse.self, from: data)
                    
                    if result.success {
                        await MainActor.run {
                            // Store verified data
                            verifiedCode = inviteCode
                            verifiedType = selectedUserType.rawValue.lowercased()
                            
                            // Navigate to full onboarding flow
                            navigateToOnboarding = true
                            isVerifying = false
                            
                            print("✅ Invite verified: \(inviteCode)")
                        }
                    } else {
                        await MainActor.run {
                            errorMessage = result.message ?? "Invalid invite code"
                            showError = true
                            isVerifying = false
                        }
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Invalid or expired invite code"
                        showError = true
                        isVerifying = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to verify code: \(error.localizedDescription)"
                    showError = true
                    isVerifying = false
                    print("❌ Verify error: \(error)")
                }
            }
        }
    }
    
    private func roleIcon(for type: OnboardingManager.UserType) -> String {
        switch type {
        case .student: return "graduationcap.fill"
        case .staff: return "figure.walk"
        case .manager: return "person.badge.key.fill"
        case .warden: return "shield.fill"
        case .accountant: return "dollarsign.circle.fill"
        case .vendor: return "cart.fill"
        case .pgAdmin: return "crown.fill"
        case .appAdmin: return "star.fill"
        }
    }
}

// MARK: - Response Model

struct VerifyInviteResponse: Codable {
    let success: Bool
    let message: String?
    let data: InviteData?
    
    struct InviteData: Codable {
        let userId: String
        let userName: String
        let userEmail: String
        let pgName: String
        let expiresAt: String
    }
}

#Preview {
    ManualInviteEntryView()
        .environmentObject(OnboardingManager())
        .environmentObject(AuthManager())
}

