import SwiftUI

struct OnboardingView: View {
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var enteredInviteCode = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 20) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text(onboardingManager.currentStep.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(onboardingManager.currentStep.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Content based on current step
                Group {
                    switch onboardingManager.currentStep {
                    case .welcome:
                        welcomeContent
                    case .enterInviteCode:
                        enterInviteCodeContent
                    case .linkingDevice:
                        linkingDeviceContent
                    case .setupBiometric:
                        setupBiometricContent
                    case .waitingForApproval:
                        waitingForApprovalContent
                    case .completed:
                        completedContent
                    }
                }
                
                Spacer()
                
                // Error message
                if let errorMessage = onboardingManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Welcome Content
    private var welcomeContent: some View {
        VStack(spacing: 20) {
            Button(action: {
                onboardingManager.startOnboarding()
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            
            Button(action: {
                // Skip onboarding for demo
                onboardingManager.completeOnboarding()
            }) {
                Text("Skip for Demo")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Enter Invite Code Content
    private var enterInviteCodeContent: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Invite Code")
                    .font(.headline)
                
                TextField("Enter 6-digit code", text: $enteredInviteCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textCase(.uppercase)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .onChange(of: enteredInviteCode) { newValue in
                        // Limit to 6 characters
                        if newValue.count > 6 {
                            enteredInviteCode = String(newValue.prefix(6))
                        }
                    }
            }
            
            Button(action: {
                if enteredInviteCode.count == 6 {
                    onboardingManager.enterInviteCode(enteredInviteCode)
                    Task {
                        await onboardingManager.linkDevice()
                    }
                }
            }) {
                HStack {
                    if onboardingManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Continue")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(enteredInviteCode.count == 6 ? Color.blue : Color.gray)
                .cornerRadius(12)
            }
            .disabled(enteredInviteCode.count != 6 || onboardingManager.isLoading)
        }
    }
    
    // MARK: - Linking Device Content
    private var linkingDeviceContent: some View {
        VStack(spacing: 20) {
            if onboardingManager.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                
                Text("Linking your device...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Setup Biometric Content
    private var setupBiometricContent: some View {
        VStack(spacing: 20) {
            if let studentInfo = onboardingManager.studentInfo {
                VStack(spacing: 15) {
                    Text("Welcome, \(studentInfo.name)!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let room = studentInfo.room {
                        Text("Room: \(room.number) (\(room.type))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("PG: \(studentInfo.pg.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            VStack(spacing: 15) {
                Image(systemName: "faceid")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Setup Biometric Authentication")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("This will be used for secure check-in and check-out")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task {
                    await onboardingManager.setupBiometric()
                }
            }) {
                HStack {
                    if onboardingManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Setup Biometric Auth")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(Color.green)
                .cornerRadius(12)
            }
            .disabled(onboardingManager.isLoading)
        }
    }
    
    // MARK: - Waiting for Approval Content
    private var waitingForApprovalContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 15) {
                Image(systemName: "clock")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Waiting for Manager Approval")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Your manager will review and approve your access. You'll be notified once approved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task {
                    if let studentId = onboardingManager.currentStudentId {
                        await onboardingManager.checkOnboardingStatus(studentId: studentId)
                    }
                }
            }) {
                HStack {
                    if onboardingManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                    } else {
                        Text("Check Status")
                    }
                }
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            .disabled(onboardingManager.isLoading)
        }
    }
    
    // MARK: - Completed Content
    private var completedContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 15) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Onboarding Complete!")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("You can now use all PGEase features including NFC check-in/out and room access.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                // Navigate to main app
                onboardingManager.completeOnboarding()
            }) {
                Text("Continue to App")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color.green)
                    .cornerRadius(12)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
