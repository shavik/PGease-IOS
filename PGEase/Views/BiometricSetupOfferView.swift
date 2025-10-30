//
//  BiometricSetupOfferView.swift
//  PGEase
//
//  Offer to set up biometric login after email/password login
//

import SwiftUI

struct BiometricSetupOfferView: View {
    let userId: String
    let userName: String
    let onSetup: (Bool) -> Void
    let onSkip: () -> Void
    
    @EnvironmentObject var webAuthnManager: WebAuthnManager
    @State private var isSettingUp = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                Image(systemName: "faceid")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                // Header
                VStack(spacing: 12) {
                    Text("Set Up Face ID")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Hi \(userName)!")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Enable Face ID for quick and secure future logins")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Benefits
                VStack(alignment: .leading, spacing: 16) {
                    BiometricBenefitRow(
                        icon: "bolt.fill",
                        title: "Lightning Fast",
                        description: "Login in 1 second"
                    )
                    
                    BiometricBenefitRow(
                        icon: "lock.shield.fill",
                        title: "Ultra Secure",
                        description: "Military-grade encryption"
                    )
                    
                    BiometricBenefitRow(
                        icon: "key.fill",
                        title: "No Passwords",
                        description: "Never type password again"
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    Button(action: setupBiometric) {
                        HStack {
                            if isSettingUp {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isSettingUp ? "Setting up..." : "Enable Face ID")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSettingUp)
                    
                    Button(action: onSkip) {
                        Text("Maybe Later")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Face ID Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        onSkip()
                    }
                }
            }
            .alert("Setup Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func setupBiometric() {
        isSettingUp = true
        
        Task {
            do {
                let deviceName = await UIDevice.current.name
                
                // WebAuthn registration with backend
                let success = try await webAuthnManager.registerPasskey(
                    userId: userId,
                    deviceName: deviceName
                )
                
                await MainActor.run {
                    isSettingUp = false
                    if success {
                        print("✅ Face ID setup successful")
                        onSetup(true)
                    } else {
                        errorMessage = "Failed to set up Face ID"
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSettingUp = false
                    errorMessage = "Error: \(error.localizedDescription)"
                    showError = true
                    print("❌ Face ID setup error: \(error)")
                }
            }
        }
    }
}

// MARK: - Benefit Row Component

struct BiometricBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}
