import SwiftUI

/// View for selecting user role (Student or Staff) during initial onboarding
struct RoleSelectionView: View {
    @Binding var selectedRole: OnboardingManager.UserType?
    let onContinue: () -> Void
    
    @State private var hoveredRole: OnboardingManager.UserType?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo/Icon
                Image(systemName: "building.2.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                // Title
                VStack(spacing: 12) {
                    Text("Welcome to PGEase")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Select your role to get started")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // Role Cards
                VStack(spacing: 20) {
                    RoleCard(
                        role: .student,
                        icon: "person.fill",
                        title: "Student",
                        description: "I'm a resident of the PG",
                        features: [
                            "Check-in/out with NFC",
                            "View attendance history",
                            "Manage room access"
                        ],
                        isSelected: selectedRole == .student,
                        isHovered: hoveredRole == .student
                    ) {
                        selectedRole = .student
                    }
                    
                    RoleCard(
                        role: .staff,
                        icon: "person.badge.key.fill",
                        title: "Staff",
                        description: "I work at the PG",
                        features: [
                            "Track work hours",
                            "Biometric attendance",
                            "Access staff portal"
                        ],
                        isSelected: selectedRole == .staff,
                        isHovered: hoveredRole == .staff
                    ) {
                        selectedRole = .staff
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Continue Button
                Button(action: onContinue) {
                    HStack {
                        Text("Continue")
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
}

// MARK: - Role Card

struct RoleCard: View {
    let role: OnboardingManager.UserType
    let icon: String
    let title: String
    let description: String
    let features: [String]
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.blue : Color.white.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: icon)
                            .font(.system(size: 28))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    }
                    
                    // Title & Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Selection Indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                
                // Features
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text(feature)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct RoleSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        RoleSelectionView(
            selectedRole: .constant(.student),
            onContinue: {}
        )
    }
}

