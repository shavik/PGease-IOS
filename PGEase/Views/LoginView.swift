import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject var biometricAuthManager: BiometricAuthManager
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var webAuthnManager = WebAuthnManager()
    
    @State private var showingSettings = false
    @State private var isAuthenticating = false
    @State private var showEmailLogin = false
    
    // Email/Password login fields
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var loginError = ""
    @State private var showLoginError = false
    @State private var offerBiometricSetup = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // App Logo/Icon
                    VStack(spacing: 20) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)

                        Text("PGEase")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("Smart PG Management System")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)

                    // Login Methods
                    VStack(spacing: 24) {
                        if !showEmailLogin {
                            // Biometric Login (Primary Method)
                            if biometricAuthManager.isBiometricAvailable && biometricAuthManager.isBiometricEnabled {
                                biometricLoginSection
                            } else {
                                // Biometric not set up - show email login
                                emailPasswordLoginSection
                            }
                        } else {
                            // Email/Password Login (Alternative Method)
                            emailPasswordLoginSection
                        }
                    }
                    .padding(.top, 20)

                    // Help Text for New Users
                    VStack(spacing: 12) {
                        Text("Don't have an account?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Students & Staff:")
                                    .fontWeight(.semibold)
                                Text("Get an invite from your Manager")
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "building.2")
                                    .foregroundColor(.blue)
                                Text("PG Owners:")
                                    .fontWeight(.semibold)
                                Text("Register at pg-ease.vercel.app")
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // Settings Button
                    Button(action: { showingSettings = true }) {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("Settings")
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSettings) {
            BiometricSettingsView()
        }
        .sheet(isPresented: $offerBiometricSetup) {
            BiometricSetupOfferView(
                userId: authManager.currentUser?.id ?? "",
                userName: authManager.currentUser?.name ?? "",
                onSetup: { success in
                    if success {
                        // Update user record
                        if var user = authManager.currentUser {
                            // Mark biometric as set up
                            UserDefaults.standard.set(true, forKey: "biometricSetupComplete")
                            biometricAuthManager.setBiometricEnabled(true)
                        }
                    }
                    offerBiometricSetup = false
                },
                onSkip: {
                    offerBiometricSetup = false
                }
            )
            .environmentObject(webAuthnManager)
        }
        .alert("Login Error", isPresented: $showLoginError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginError)
        }
        .onAppear {
            // Auto-authenticate if biometrics are enabled and available
            if biometricAuthManager.isBiometricEnabled && 
               biometricAuthManager.isBiometricAvailable &&
               !showEmailLogin {
                authenticateWithBiometric()
            }
        }
    }
    
    // MARK: - Biometric Login Section
    
    private var biometricLoginSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 15) {
                Image(systemName: biometricAuthManager.biometricType == .faceID ? "faceid" : "touchid")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Welcome Back!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Use \(biometricAuthManager.biometricTypeDescription) to login")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            // Biometric Login Button
            Button(action: authenticateWithBiometric) {
                HStack {
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Image(systemName: biometricAuthManager.biometricType == .faceID ? "faceid" : "touchid")
                    Text(isAuthenticating ? "Authenticating..." : "Login with \(biometricAuthManager.biometricTypeDescription)")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(isAuthenticating)
            .padding(.horizontal)
            
            // Alternative login option
            Button(action: { withAnimation { showEmailLogin = true } }) {
                Text("Use Email & Password instead")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.top, 8)
            
            if let errorMessage = biometricAuthManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Email/Password Login Section
    
    private var emailPasswordLoginSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 15) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Sign In")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Enter your credentials to continue")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Email/Password Form
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextField("your@email.com", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .disabled(isLoggingIn)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    SecureField("Enter your password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isLoggingIn)
                }
            }
            .padding(.horizontal)
            
            // Login Button
            Button(action: loginWithEmailPassword) {
                HStack {
                    if isLoggingIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(isLoggingIn ? "Logging in..." : "Login")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || isLoggingIn)
            .padding(.horizontal)
            
            // Switch back to biometric if available
            if biometricAuthManager.isBiometricAvailable && 
               biometricAuthManager.isBiometricEnabled &&
               showEmailLogin {
                Button(action: { withAnimation { showEmailLogin = false } }) {
                    HStack {
                        Image(systemName: biometricAuthManager.biometricType == .faceID ? "faceid" : "touchid")
                        Text("Use \(biometricAuthManager.biometricTypeDescription) instead")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding(.top, 8)
            }
            
            if !loginError.isEmpty {
                Text(loginError)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        return !email.isEmpty &&
               email.contains("@") &&
               !password.isEmpty &&
               password.count >= 6
    }

    // MARK: - Authentication Methods
    
    private func authenticateWithBiometric() {
        // Get saved userId (required for WebAuthn)
        guard let userId = UserDefaults.standard.string(forKey: "userId") else {
            loginError = "No saved credentials found. Please login with email/password."
            showLoginError = true
            showEmailLogin = true
            return
        }
        
        isAuthenticating = true
        print("🔐 Starting WebAuthn biometric authentication for userId: \(userId)")

        Task {
            do {
                // Step 1: Authenticate with WebAuthn (backend verification)
                let credentialId = try await webAuthnManager.authenticate(userId: userId)
                
                print("✅ WebAuthn authentication successful! CredentialId: \(credentialId)")
                
                // Step 2: Load full user data from saved session
                await loadUserDataAndLogin(userId: userId)
                
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    loginError = "Biometric authentication failed: \(error.localizedDescription)"
                    showLoginError = true
                    
                    // Offer email/password as fallback
                    showEmailLogin = true
                    
                    print("❌ WebAuthn authentication failed: \(error)")
                }
            }
        }
    }
    
    private func loadUserDataAndLogin(userId: String) async {
        // Load saved user data from UserDefaults
        guard let userData = UserDefaults.standard.data(forKey: "currentUser"),
              let user = try? JSONDecoder().decode(AuthManager.CurrentUser.self, from: userData) else {
            await MainActor.run {
                isAuthenticating = false
                loginError = "Could not load user data. Please login with email/password."
                showLoginError = true
                showEmailLogin = true
            }
            return
        }
        
        await MainActor.run {
            // Login with saved user data
            authManager.login(
                userId: user.id,
                role: user.role,
                pgId: user.pgId,
                pgName: user.pgName,
                userName: user.name
            )
            
            isAuthenticating = false
            print("✅ Biometric login successful - User: \(user.name)")
        }
    }
    
    private func loginWithEmailPassword() {
        guard isFormValid else { return }
        
        isLoggingIn = true
        loginError = ""
        
        Task {
            do {
                // Call login API
                let response = try await callLoginAPI(email: email, password: password)
                
                if response.success {
                    await MainActor.run {
                        // Save user data
                        authManager.login(
                            userId: response.userId,
                            role: response.role,
                            pgId: response.pgId,
                            pgName: response.pgName,
                            userName: response.userName
                        )
                        
                        isLoggingIn = false
                        print("✅ Email/password login successful")
                        
                        // Offer to set up biometric for future logins (if not already set up)
                        if biometricAuthManager.isBiometricAvailable && !(authManager.currentUser?.biometricSetup ?? false) {
                            offerBiometricSetup = true
                        }
                    }
                } else {
                    await MainActor.run {
                        loginError = response.message ?? "Login failed"
                        showLoginError = true
                        isLoggingIn = false
                    }
                }
            } catch {
                await MainActor.run {
                    loginError = "Login failed: \(error.localizedDescription)"
                    showLoginError = true
                    isLoggingIn = false
                    print("❌ Login error: \(error)")
                }
            }
        }
    }
    
    private func callLoginAPI(email: String, password: String) async throws -> LoginResponse {
        let endpoint = "/auth/login"
        guard let url = URL(string: "https://pg-ease.vercel.app/api\(endpoint)") else {
            throw LoginAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LoginAPIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw LoginAPIError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }
    
    private func offerBiometricSetup() async {
        // Optionally prompt user to set up biometric for faster future logins
        // This can be done later in profile settings
    }
}

// MARK: - Response Models

struct LoginResponse: Codable {
    let success: Bool
    let userId: String
    let userName: String
    let role: String
    let pgId: String
    let pgName: String
    let message: String?
}

enum LoginAPIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
}

// MARK: - Settings View

struct BiometricSettingsView: View {
    @EnvironmentObject var biometricAuthManager: BiometricAuthManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(biometricAuthManager.isBiometricAvailable ? "Available" : "Not Available")
                            .foregroundColor(biometricAuthManager.isBiometricAvailable ? .green : .red)
                    }

                    if biometricAuthManager.isBiometricAvailable {
                        HStack {
                            Text("Type")
                            Spacer()
                            Text(biometricAuthManager.biometricTypeDescription)
                                .foregroundColor(.secondary)
                        }

                        Toggle("Enable \(biometricAuthManager.biometricTypeDescription)", isOn: .constant(biometricAuthManager.isBiometricEnabled))
                            .disabled(true)
                    }
                } header: {
                    Text("Biometric Authentication")
                }

                if let error = biometricAuthManager.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    } header: {
                        Text("Error")
                    }
                }
            }
            .navigationTitle("Biometric Settings")
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
}
