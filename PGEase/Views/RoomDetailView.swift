import SwiftUI

struct RoomDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    
    let roomId: String
    let initialRoomNumber: String
    
    @State private var roomDetail: RoomDetailData?
    @State private var editedNumber: String = ""
    @State private var editedType: RoomTypeOption = .single
    @State private var editedBedCount: Int = 1
    @State private var editedDetails: String = ""
    
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    @State private var existingTag: NFCTagInfo?
    @State private var isLoadingTag = false
    @State private var showingTagWriter = false
    
    var body: some View {
        Form {
            if isLoading {
                Section {
                    ProgressView("Loading room...")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else if let roomDetail {
                Section("Room Information") {
                    TextField("Room Number", text: $editedNumber)
                        .textInputAutocapitalization(.characters)
                    
                    Picker("Room Type", selection: $editedType) {
                        ForEach(RoomTypeOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    
                    Stepper(value: $editedBedCount, in: 1...12) {
                        Text("Bed Count: \(editedBedCount)")
                    }
                    
                    TextField("Details (optional)", text: $editedDetails, axis: .vertical)
                }
                
                Section("Occupants") {
                    if roomDetail.students.isEmpty {
                        Text("No active occupants assigned.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(roomDetail.students) { student in
                            Text(student.displayName)
                        }
                    }
                }
                
                Section("NFC Tag") {
                    if isLoadingTag {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if let tag = existingTag {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Tag ID")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(tag.tagId)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Status")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(tag.status.capitalized)
                            }
                            
                            if let lastScannedAt = tag.lastScannedAt {
                                HStack {
                                    Text("Last Scanned")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(lastScannedAt.formattedDateTime())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Button("Update Tag") {
                            showingTagWriter = true
                        }
                    } else {
                        Text("No NFC tag associated with this room.")
                            .foregroundColor(.secondary)
                        Button("Generate Tag") {
                            showingTagWriter = true
                        }
                    }
                }
            }
        }
        .navigationTitle("Room \(roomDetail?.number ?? initialRoomNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isLoading && roomDetail != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveChanges()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .task {
            await loadRoom()
        }
        .sheet(isPresented: $showingTagWriter, onDismiss: {
            Task { await loadTagInfo() }
        }) {
            if let roomDetail {
                NFCTagWriteView(roomId: roomDetail.id, roomNumber: roomDetail.number)
                    .environmentObject(authManager)
            }
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
    
    @Sendable
    private func loadRoom() async {
        guard let pgId = authManager.currentPgId else {
            await MainActor.run {
                errorMessage = "Please select a PG first."
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let detail = try await APIManager.shared.getRoomDetail(pgId: pgId, roomId: roomId)
            await MainActor.run {
                self.roomDetail = detail
                self.editedNumber = detail.number
                self.editedType = RoomTypeOption.from(detail.type)
                self.editedBedCount = detail.bedCount
                self.editedDetails = detail.details ?? ""
                self.isLoading = false
            }
            await loadTagInfo()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    @Sendable
    private func loadTagInfo() async {
        guard let pgId = authManager.currentPgId else { return }
        await MainActor.run {
            isLoadingTag = true
        }
        
        do {
            let response = try await APIManager.shared.listNFCTags(pgId: pgId, roomId: roomId)
            await MainActor.run {
                existingTag = response.data.first
                isLoadingTag = false
            }
        } catch {
            await MainActor.run {
                isLoadingTag = false
            }
        }
    }
    
    private func saveChanges() {
        guard let pgId = authManager.currentPgId else {
            errorMessage = "Please select a PG first."
            return
        }
        
        guard !editedNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Room number is required."
            return
        }
        
        isSaving = true
        
        Task {
            do {
                _ = try await APIManager.shared.updateRoom(
                    pgId: pgId,
                    roomId: roomId,
                    number: editedNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: editedType.rawValue,
                    bedCount: editedBedCount,
                    details: editedDetails.isEmpty ? nil : editedDetails
                )
                
                await loadRoom()
                
                await MainActor.run {
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

private extension String {
    func formattedDateTime() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: self) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return self
    }
}

