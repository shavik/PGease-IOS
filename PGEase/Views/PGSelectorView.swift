import SwiftUI

/// PG Selector Component
/// ✅ Only shown for PGADMIN & VENDOR with multiple PGs
/// ✅ Allows switching between associated PGs
struct PGSelectorView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showPGList = false
    @State private var isSwitching = false
    
    var body: some View {
        // ✅ Only show if user has multiple PGs
        if authManager.shouldShowPGSwitcher {
            HStack(spacing: 12) {
                // PG Icon
                Image(systemName: "building.2.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current PG")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(currentPGName)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                // Dropdown button
                Button(action: {
                    showPGList.toggle()
                }) {
                    Image(systemName: showPGList ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                        .font(.system(size: 14, weight: .semibold))
                }
                .disabled(isSwitching)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // PG List Dropdown
            if showPGList {
                VStack(spacing: 0) {
                    ForEach(authManager.availablePGs) { pg in
                        Button(action: {
                            switchPG(pg)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pg.name)
                                        .font(.body)
                                        .fontWeight(pg.id == authManager.currentPgId ? .semibold : .regular)
                                        .foregroundColor(.primary)
                                    
                                    if let address = pg.address {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // Current PG indicator
                                if pg.id == authManager.currentPgId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(
                                pg.id == authManager.currentPgId
                                    ? Color.blue.opacity(0.1)
                                    : Color.clear
                            )
                        }
                        .disabled(pg.id == authManager.currentPgId || isSwitching)
                        
                        if pg.id != authManager.availablePGs.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .padding(.horizontal)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var currentPGName: String {
        if let currentPG = authManager.availablePGs.first(where: { $0.id == authManager.currentPgId }) {
            return currentPG.name
        }
        return authManager.currentPgName
    }
    
    // MARK: - Actions
    
    private func switchPG(_ pg: UserPG) {
        isSwitching = true
        showPGList = false
        
        Task {
            await authManager.switchPG(pg.id)
            
            await MainActor.run {
                isSwitching = false
            }
        }
    }
}

// MARK: - Preview

struct PGSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PGSelectorView()
                .environmentObject(previewAuthManager)
            
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    static var previewAuthManager: AuthManager {
        let manager = AuthManager()
        manager.userRole = .pgAdmin
        manager.currentPgId = "pg1"
        manager.currentPgName = "Sunrise PG"
        manager.needsPGSwitcher = true
        manager.availablePGs = [
            UserPG(
                id: "pg1",
                name: "Sunrise PG",
                address: "123 Main St, Bangalore",
                status: "ACTIVE",
                role: "PGADMIN",
                isPrimary: true,
                isActive: true,
                joinedAt: nil,
                accessType: "association"
            ),
            UserPG(
                id: "pg2",
                name: "Moonlight PG",
                address: "456 Park Rd, Bangalore",
                status: "ACTIVE",
                role: "PGADMIN",
                isPrimary: false,
                isActive: true,
                joinedAt: nil,
                accessType: "association"
            ),
            UserPG(
                id: "pg3",
                name: "Starlight PG",
                address: "789 Lake View, Bangalore",
                status: "ACTIVE",
                role: "PGADMIN",
                isPrimary: false,
                isActive: true,
                joinedAt: nil,
                accessType: "association"
            ),
        ]
        return manager
    }
}

