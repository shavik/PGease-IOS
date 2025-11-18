import SwiftUI

struct RoomsListView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var rooms: [RoomListItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddRoom = false
    @State private var searchText = ""
    
    private var filteredRooms: [RoomListItem] {
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
                            NavigationLink(destination: RoomDetailView(roomId: room.id, initialRoomNumber: room.number)) {
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
                await fetchRooms()
            }
        }
        .task {
            await fetchRooms()
        }
        .sheet(isPresented: $showingAddRoom) {
            AddRoomSheet {
                Task { await fetchRooms() }
            }
            .environmentObject(authManager)
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
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
    private func fetchRooms() async {
        guard let pgId = authManager.currentPgId else {
            await MainActor.run {
                errorMessage = "Please select a PG first."
                rooms = []
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            isLoading = rooms.isEmpty
            errorMessage = nil
        }
        
        do {
            let response = try await APIManager.shared.getRooms(pgId: pgId)
            await MainActor.run {
                rooms = response.data.sorted { $0.number.localizedStandardCompare($1.number) == .orderedAscending }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

private struct RoomRowView: View {
    let room: RoomListItem
    
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
                Label("\(room.availableBeds)", systemImage: "person.crop.circle.badge.plus")

            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
//        .padding(.vertical, 6)
    }
}

private struct AddRoomSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var roomNumber: String = ""
    @State private var selectedType: RoomTypeOption = .single
    @State private var bedCount: Int = 1
    @State private var details: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    let onRoomCreated: () -> Void
    
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
                _ = try await APIManager.shared.createRoom(
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


