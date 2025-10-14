import SwiftUI

/// Staff onboarding view - mirrors student onboarding with staff-specific branding
struct StaffOnboardingView: View {
    @StateObject private var onboardingManager = OnboardingManager()
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Content
            VStack {
                switch onboardingManager.currentStep {
                case .welcome:
                    WelcomeStaffView(onboardingManager: onboardingManager)
                case .enterInviteCode:
                    EnterInviteCodeView(onboardingManager: onboardingManager, userType: "Staff")
                case .linkingDevice:
                    LinkingDeviceView(onboardingManager: onboardingManager, userType: "Staff")
                case .setupBiometric:
                    SetupBiometricView(onboardingManager: onboardingManager, userType: "Staff")
                case .waitingForApproval:
                    WaitingForApprovalView(onboardingManager: onboardingManager, userType: "Staff")
                case .completed:
                    OnboardingCompletedView(onboardingManager: onboardingManager, userType: "Staff")
                }
            }
        }
        .onAppear {
            onboardingManager.userType = .staff
        }
    }
}

// MARK: - Welcome Staff View

struct WelcomeStaffView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 100))
                .foregroundColor(.white)
            
            // Title
            Text("Welcome to PGEase")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
            
            Text("Staff Portal")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            // Description
            VStack(spacing: 12) {
                FeatureRow(icon: "checkmark.shield.fill", text: "Secure biometric attendance")
                FeatureRow(icon: "wave.3.right", text: "NFC-based check-in/out")
                FeatureRow(icon: "chart.bar.fill", text: "Track your work hours")
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Get Started Button
            Button(action: {
                onboardingManager.startOnboarding()
            }) {
                HStack {
                    Text("Get Started")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(.blue)
                .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Feature Row (Reusable)

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// MARK: - Enter Invite Code View (Reusable for both Student and Staff)

struct EnterInviteCodeView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let userType: String
    
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            // Title
            Text("Enter Invite Code")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text("Enter the code provided by your manager")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Invite Code Input
            VStack(spacing: 16) {
                TextField("INVITE-CODE", text: $onboardingManager.inviteCode)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                
                if let error = onboardingManager.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Continue Button
            Button(action: {
                isInputFocused = false
                Task {
                    await onboardingManager.linkDevice()
                }
            }) {
                HStack {
                    if onboardingManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        Text("Continue")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(onboardingManager.inviteCode.isEmpty ? Color.gray : Color.white)
                .foregroundColor(.blue)
                .cornerRadius(16)
            }
            .disabled(onboardingManager.inviteCode.isEmpty || onboardingManager.isLoading)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onAppear {
            isInputFocused = true
        }
    }
}

// MARK: - Linking Device View (Reusable)

struct LinkingDeviceView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let userType: String
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Loading Animation
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(2)
            
            // Title
            Text("Linking Device...")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 30)
            
            Text("Connecting your device to your \(userType.lowercased()) account")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Device ID
            VStack(spacing: 8) {
                Text("Device ID")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(onboardingManager.deviceId)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
    }
}

// MARK: - Setup Biometric View (Reusable)

struct SetupBiometricView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let userType: String
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: "faceid")
                .font(.system(size: 100))
                .foregroundColor(.white)
            
            // Title
            Text("Setup Biometric Auth")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text("Secure your attendance with Face ID or Touch ID")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Benefits
            VStack(spacing: 16) {
                BenefitRow(icon: "lock.shield.fill", text: "Secure and private")
                BenefitRow(icon: "bolt.fill", text: "Quick check-in/out")
                BenefitRow(icon: "checkmark.seal.fill", text: "Prevents fraud")
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Setup Button
            Button(action: {
                Task {
                    await onboardingManager.setupBiometric()
                }
            }) {
                HStack {
                    if onboardingManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        Image(systemName: "faceid")
                        Text("Setup Biometric")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(.blue)
                .cornerRadius(16)
            }
            .disabled(onboardingManager.isLoading)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// MARK: - Waiting for Approval View (Reusable)

struct WaitingForApprovalView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let userType: String
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: "hourglass")
                .font(.system(size: 100))
                .foregroundColor(.white)
                .symbolEffect(.pulse)
            
            // Title
            Text("Waiting for Approval")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text("Your manager will review and approve your access shortly")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Status Info
            VStack(spacing: 16) {
                StatusInfoRow(label: userType, value: onboardingManager.staffInfo?.name ?? onboardingManager.studentInfo?.name ?? "N/A")
                StatusInfoRow(label: "PG", value: onboardingManager.staffInfo?.pg.name ?? onboardingManager.studentInfo?.pg.name ?? "N/A")
                StatusInfoRow(label: "Status", value: onboardingManager.accessStatus)
            }
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(16)
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Check Status Button
            Button(action: {
                Task {
                    if let staffId = onboardingManager.staffInfo?.id {
                        await onboardingManager.checkOnboardingStatus(studentId: staffId)
                    } else if let studentId = onboardingManager.studentInfo?.id {
                        await onboardingManager.checkOnboardingStatus(studentId: studentId)
                    }
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Check Status")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(.blue)
                .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

struct StatusInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Onboarding Completed View (Reusable)

struct OnboardingCompletedView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    let userType: String
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.green)
            
            // Title
            Text("All Set!")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
            
            Text("You're ready to use PGEase")
                .font(.title3)
                .foregroundColor(.white.opacity(0.9))
            
            // Next Steps
            VStack(spacing: 16) {
                NextStepRow(icon: "wave.3.right", text: "Tap NFC tag to check in")
                NextStepRow(icon: "qrcode", text: "Or scan QR code")
                NextStepRow(icon: "chart.bar", text: "View your attendance")
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Continue Button
            Button(action: {
                onboardingManager.completeOnboarding()
            }) {
                HStack {
                    Text("Continue to App")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(.blue)
                .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

struct NextStepRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// MARK: - Preview

struct StaffOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        StaffOnboardingView()
            .environmentObject(AuthManager())
    }
}

