//
//  InviteOnboardingView.swift
//  PGEase
//
//  Universal invite-based onboarding for all user types
//  Skips role selection - role is determined from invite
//

import SwiftUI

struct InviteOnboardingView: View {
    let inviteCode: String
    let inviteType: String
    
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var webAuthnManager = WebAuthnManager()
    
    @State private var currentStep: InviteOnboardingStep = .verifyingInvite
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var phone = ""
    @State private var userInfo: InviteUserInfo?
    @State private var userId: String?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    enum InviteOnboardingStep {
        case verifyingInvite
        case setPassword
        case setupBiometric
        case complete
    }
    
    struct InviteUserInfo {
        let name: String
        let email: String
        let role: String
        let pgName: String
    }
    
    var body: some View {
        NavigationView {
            VStack {
                switch currentStep {
                case .verifyingInvite:
                    verifyingInviteView
                case .setPassword:
                    setPasswordView
                case .setupBiometric:
                    setupBiometricView
                case .complete:
                    completionView
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                verifyInvite()
            }
        }
    }
    
    // MARK: - Navigation Title
    
    private var navigationTitle: String {
        switch currentStep {
        case .verifyingInvite: return "Verifying Invite"
        case .setPassword: return "Set Password"
        case .setupBiometric: return "Secure Your Account"
        case .complete: return "Welcome!"
        }
    }
    
    // MARK: - Step 1: Verifying Invite
    
    private var verifyingInviteView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Verifying your invite...")
                .font(.headline)
            
            Text("Code: \(inviteCode)")
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
            
            Text("Type: \(inviteType.capitalized)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Step 2: Set Password
    
    private var setPasswordView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome Header
                VStack(spacing: 12) {
                    Image(systemName: roleIcon(for: inviteType))
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    if let user = userInfo {
                        Text("Welcome, \(user.name)! 👋")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Joining \(user.pgName)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Role: \(user.role)")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(20)
                    }
                }
                .padding(.top)
                
                // Password Form
                VStack(alignment: .leading, spacing: 20) {
                    Text("Create Your Password")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        SecureField("Enter password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        SecureField("Re-enter password", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                    }
                    
                    if !password.isEmpty && password != confirmPassword {
                        Label("Passwords don't match", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phone (Optional)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        TextField("+91 9876543210", text: $phone)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.phonePad)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Continue Button
                Button(action: submitPassword) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isLoading ? "Setting up..." : "Continue")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isPasswordValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isPasswordValid || isLoading)
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
    }
    
    // MARK: - Step 3: Setup Biometric
    
    private var setupBiometricView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "faceid")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Secure Your Account")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Set up Face ID for quick and secure access")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                InviteFeatureRow(icon: "bolt.fill", text: "Quick check-in (1 second)")
                InviteFeatureRow(icon: "lock.fill", text: "Ultra-secure authentication")
                InviteFeatureRow(icon: "key.fill", text: "No passwords needed")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: setupBiometric) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isLoading ? "Setting up..." : "Enable Face ID")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                
                Button(action: skipBiometric) {
                    Text("Skip for now")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    // MARK: - Step 4: Completion
    
    private var completionView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("🎉 All Set!")
                .font(.title)
                .fontWeight(.bold)
            
            if let user = userInfo {
                Text("Welcome to \(user.pgName)!")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("You can now:")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                if inviteType == "student" {
                    FeatureRow(icon: "checkmark.circle", text: "Check in/out with Face ID")
                    FeatureRow(icon: "chart.bar", text: "View your attendance")
                    FeatureRow(icon: "dollarsign.circle", text: "Make rent payments")
                    FeatureRow(icon: "fork.knife", text: "View meal schedule")
                } else if inviteType == "staff" {
                    FeatureRow(icon: "checkmark.circle", text: "Check in/out daily")
                    FeatureRow(icon: "chart.bar", text: "View your attendance")
                    FeatureRow(icon: "list.bullet", text: "View assigned tasks")
                } else {
                    FeatureRow(icon: "person.3", text: "Manage members")
                    FeatureRow(icon: "chart.bar", text: "View reports")
                    FeatureRow(icon: "gear", text: "Configure settings")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            Button(action: completeOnboarding) {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isPasswordValid: Bool {
        return !password.isEmpty &&
               password.count >= 6 &&
               password == confirmPassword
    }
    
    // MARK: - Methods
    
    private func verifyInvite() {
        // Set user type based on invite type
        if let userType = OnboardingManager.UserType(rawValue: inviteType.uppercased()) {
            onboardingManager.userType = userType
        }
        
        // Auto-fill invite code
        onboardingManager.inviteCode = inviteCode
        
        // Link device (verifies invite exists and is valid)
        Task {
            await linkDevice()
        }
    }
    
    private func linkDevice() async {
        await MainActor.run { isLoading = true }
        
        do {
            // Use universal link-device API that supports all user types
            let response = try await APIManager.shared.linkDeviceUniversal(
                inviteCode: inviteCode,
                deviceId: onboardingManager.deviceId,
                userType: inviteType
            )
            
            await MainActor.run {
                // Store user info from response
                userInfo = InviteUserInfo(
                    name: response.data.student.name,
                    email: response.data.student.email!,
                    role: inviteType.uppercased(),
                    pgName: response.data.student.pg.name
                )
                
                userId = response.data.student.id

                // Move to password step
                currentStep = .setPassword
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Invalid or expired invite code: \(error.localizedDescription)"
                showError = true
                isLoading = false
                // print("❌ Invalid error: \(error.error)")
            }
        }
    }
    
    private func submitPassword() {
        guard isPasswordValid, let _ = userId else { return }
        
        isLoading = true
        
        Task {
            do {
                // Call invite-signup API
                let endpoint = "/auth/invite-signup"
                guard let url = URL(string: "https://pg-ease.vercel.app/api\(endpoint)") else { return }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body: [String: Any] = [
                    "inviteCode": inviteCode,
                    "password": password,
                    "phone": phone.isEmpty ? nil : phone
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Debug: Print raw response
                if let httpResponse = response as? HTTPURLResponse {
                    print("📥 [Password Setup] HTTP Status: \(httpResponse.statusCode)")
                    
                    // Check for error status codes
                    if httpResponse.statusCode >= 400 {
                        if let jsonString = String(data: data, encoding: .utf8) {
                            print("❌ [Password Setup] Error response: \(jsonString)")
                            
                            // Try to parse error message
                            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let errorMsg = json["error"] as? String {
                                throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                            }
                        }
                        throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])
                    }
                }
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📥 [Password Setup] Response JSON: \(jsonString)")
                }
                
                let signupResponse = try JSONDecoder().decode(InviteSignupResponse.self, from: data)
                
                if signupResponse.success {
                    await MainActor.run {
                        userId = signupResponse.userId
                        
                        // Save credentials
                        UserDefaults.standard.set(signupResponse.userId, forKey: "userId")
                        UserDefaults.standard.set(inviteType.uppercased(), forKey: "userType")
                        
                        // Move to biometric setup
                        currentStep = .setupBiometric
                        isLoading = false
                    }
                }
            } catch let decodingError as DecodingError {
                await MainActor.run {
                    print("❌ [Password Setup] Decoding error: \(decodingError)")
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        errorMessage = "Missing key '\(key.stringValue)': \(context.debugDescription)"
                    case .typeMismatch(let type, let context):
                        errorMessage = "Type mismatch for \(type): \(context.debugDescription)"
                    case .valueNotFound(let type, let context):
                        errorMessage = "Value not found for \(type): \(context.debugDescription)"
                    case .dataCorrupted(let context):
                        errorMessage = "Data corrupted: \(context.debugDescription)"
                    @unknown default:
                        errorMessage = "Decoding error: \(decodingError.localizedDescription)"
                    }
                    showError = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to set password: \(error.localizedDescription)"
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func setupBiometric() {
        guard let userId = userId else { return }
        
        isLoading = true
        
        Task {
            do {
                let deviceName = await UIDevice.current.name
                let success = try await webAuthnManager.registerPasskey(
                    userId: userId,
                    deviceName: deviceName
                )
                
                if success {
                    await MainActor.run {
                        currentStep = .complete
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to set up Face ID: \(error.localizedDescription)"
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func skipBiometric() {
        currentStep = .complete
    }
    
    private func completeOnboarding() {
        // Mark onboarding as complete
        onboardingManager.isOnboardingComplete = true
        
        // Set user role in AuthManager
        if let userType = OnboardingManager.UserType(rawValue: inviteType.uppercased()) {
            let role: AuthManager.UserRole
            
            switch userType {
            case .student: role = .student
            case .staff: role = .staff
            case .manager: role = .manager
            case .warden: role = .warden
            case .accountant: role = .accountant
            case .pgAdmin: role = .pgAdmin
            case .vendor: role = .vendor
            case .appAdmin: role = .student // Shouldn't happen
            }
            
            authManager.updateUserRole(role)
        }
        
        // Authenticate user
        authManager.isAuthenticated = true
        
        print("✅ Invite onboarding complete for \(inviteType)")
    }
    
    private func roleIcon(for type: String) -> String {
        switch type.lowercased() {
        case "student": return "graduationcap.fill"
        case "staff": return "figure.walk"
        case "manager": return "person.badge.key.fill"
        case "warden": return "shield.fill"
        case "accountant": return "dollarsign.circle.fill"
        case "vendor": return "cart.fill"
        default: return "person.fill"
        }
    }
}

// MARK: - Feature Row Component

struct InviteFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

// MARK: - Response Model

struct InviteSignupResponse: Codable {
    let success: Bool
    let userId: String
    let userType: String
    let pgId: String?
    let pgName: String?
    let message: String
}

