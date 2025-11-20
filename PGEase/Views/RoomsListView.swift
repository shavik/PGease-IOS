import SwiftUI

struct RoomsListView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appStore: AppStore
    
    @State private var showingAddRoom = false
    @State private var searchText = ""
    
    var body: some View {
        // Use a helper view that directly observes pgStore
        RoomsListContentView(
            pgStore: appStore.pgStore,
            showingAddRoom: $showingAddRoom,
            searchText: $searchText
        )
        .environmentObject(authManager)
    }
}

// Helper view that directly observes pgStore to ensure SwiftUI tracks changes
private struct RoomsListContentView: View {
    @ObservedObject var pgStore: PGStore
    @EnvironmentObject var authManager: AuthManager
    
    @Binding var showingAddRoom: Bool
    @Binding var searchText: String
    
    @EnvironmentObject var appStore: AppStore
    
    private var rooms: [Room] {
        let storeState = pgStore.state
        guard let pgId = authManager.currentPgId else {
            return []
        }
        let roomIds = storeState.roomsByPg[pgId] ?? []
        let allRooms = storeState.rooms
        let result = roomIds.compactMap { allRooms[$0] }
            .sorted { $0.number.localizedStandardCompare($1.number) == .orderedAscending }
        
        print("📱 [RoomsListContentView.rooms] Computed: pgId=\(pgId), roomIds=\(roomIds.count), allRooms=\(allRooms.count), result=\(result.count)")
        
        return result
    }
    
    private var isLoading: Bool {
        pgStore.state.roomsLoading
    }
    
    private var errorMessage: String? {
        pgStore.state.roomsError
    }
    
    private var filteredRooms: [Room] {
        guard !searchText.isEmpty else { return rooms }
        return rooms.filter { room in
            room.number.localizedCaseInsensitiveContains(searchText) ||
            room.type.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading rooms...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if filteredRooms.isEmpty {
                    emptyState
                } else {
                    List(filteredRooms) { room in
                        NavigationLink(destination: RoomDetailView(
                            pgStore: pgStore,
                            roomId: room.id,
                            initialRoomNumber: room.number
                        )) {
                            RoomRowView(room: room)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Rooms")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddRoom = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("Add Room")
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .refreshable {
                await loadRooms()
            }
        }
        .task {
            await loadRooms()
        }
        .sheet(isPresented: $showingAddRoom) {
            AddRoomSheet(
                pgStore: pgStore,
                onRoomCreated: {
                    // Room will be added optimistically, no need to reload
                }
            )
            .environmentObject(authManager)
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in
                pgStore.clearRoomsError()
            }
        )) {
            Button("OK", role: .cancel) {
                pgStore.clearRoomsError()
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2.slash")
                .font(.system(size: 52))
                .foregroundColor(.gray)
            
            Text("No Rooms Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the + button to create your first room.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding()
    }
    
    @Sendable
    private func loadRooms() async {
        print("📱 [RoomsListContentView] loadRooms called")
        guard let pgId = authManager.currentPgId else {
            print("⚠️ [RoomsListContentView] No pgId available, cannot load rooms")
            return
        }
        
        print("📱 [RoomsListContentView] Loading rooms for pgId: \(pgId)")
        do {
            try await pgStore.loadRooms(pgId: pgId)
            print("✅ [RoomsListContentView] Rooms loaded successfully")
            print("📊 [RoomsListContentView] Current rooms count in view: \(rooms.count)")
        } catch {
            // Error is already set in store state
            print("❌ [RoomsListContentView] Failed to load rooms: \(error.localizedDescription)")
            print("   Error type: \(type(of: error))")
        }
    }
}

private struct RoomRowView: View {
    let room: Room
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("Room \(room.number)")
                    .font(.headline)
                Text(room.type.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label("\(room.bedCount)", systemImage: "bed.double")
                Label("\(room.occupiedBeds)", systemImage: "person.2.fill")
                //Label("\(room.availableBeds)", systemImage: "person.crop.circle.badge.plus")

            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
//        .padding(.vertical, 6)
    }
}

private struct AddRoomSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var pgStore: PGStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var roomNumber: String = ""
    @State private var selectedType: RoomTypeOption = .single
    @State private var bedCount: Int = 1
    @State private var details: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    let onRoomCreated: () -> Void
    
    private var isLoading: Bool {
        pgStore.state.roomsLoading
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Room Information") {
                    TextField("Room Number", text: $roomNumber)
                        .textContentType(.none)
                        .autocapitalization(.none)
                    
                    Picker("Room Type", selection: $selectedType) {
                        ForEach(RoomTypeOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    
                    Stepper(value: $bedCount, in: 1...12) {
                        Text("Bed Count: \(bedCount)")
                    }
                    
                    TextField("Details (optional)", text: $details, axis: .vertical)
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Room")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveRoom) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || roomNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveRoom() {
        guard let pgId = authManager.currentPgId else {
            errorMessage = "Please select a PG first."
            return
        }
        
        let trimmedNumber = roomNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNumber.isEmpty else {
            errorMessage = "Room number is required."
            return
        }
        
        errorMessage = nil
        isSaving = true
        
        Task {
            do {
                // Use store's createRoom which handles optimistic updates
                _ = try await pgStore.createRoom(
                    pgId: pgId,
                    number: trimmedNumber,
                    type: selectedType.rawValue,
                    bedCount: bedCount,
                    details: details.isEmpty ? nil : details
                )
                
                await MainActor.run {
                    isSaving = false
                    onRoomCreated()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}


