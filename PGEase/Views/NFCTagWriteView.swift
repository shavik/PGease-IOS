import SwiftUI

/// View for writing and locking NFC tags
/// Only accessible by MANAGER and PGADMIN roles
struct NFCTagWriteView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var nfcManager: NFCTagManager?
    
    @State private var selectedRoomId: String = ""
    @State private var selectedPgId: String = ""
    @State private var roomNumber: String = ""
    @State private var pgName: String = ""
    
    @State private var generatedTagData: NFCTagManager.NFCTagWriteData?
    @State private var currentStep: WriteStep = .selectRoom
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let presetRoomId: String?
    private let presetRoomNumber: String?
    
    enum WriteStep {
        case selectRoom
        case generating
        case readyToWrite
        case writing
        case success
    }
    
    init(roomId: String? = nil, roomNumber: String? = nil) {
        self._selectedRoomId = State(initialValue: roomId ?? "")
        self._selectedPgId = State(initialValue: "")
        self._roomNumber = State(initialValue: roomNumber ?? "")
        self._pgName = State(initialValue: "")
        self._generatedTagData = State(initialValue: nil)
        self._currentStep = State(initialValue: .selectRoom)
        self._showAlert = State(initialValue: false)
        self._alertMessage = State(initialValue: "")
        self.presetRoomId = roomId
        self.presetRoomNumber = roomNumber
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Progress Indicator
                    progressIndicator
                    
                    // Step Content
                    switch currentStep {
                    case .selectRoom:
                        selectRoomView
                    case .generating:
                        generatingView
                    case .readyToWrite:
                        readyToWriteView
                    case .writing:
                        writingView
                    case .success:
                        successView
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Write NFC Tag")
            .navigationBarTitleDisplayMode(.large)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                // ✅ Initialize NFCTagManager with authManager
                if nfcManager == nil {
                    nfcManager = NFCTagManager(authManager: authManager)
                }
            }
            .onChange(of: nfcManager?.errorMessage) { error in
                if let error = error {
                    alertMessage = error
                    showAlert = true
                }
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 12) {
            ForEach(0..<4) { index in
                Circle()
                    .fill(stepColor(for: index))
                    .frame(width: 12, height: 12)
                
                if index < 3 {
                    Rectangle()
                        .fill(stepColor(for: index))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func stepColor(for index: Int) -> Color {
        let currentIndex = stepIndex(for: currentStep)
        return index <= currentIndex ? .blue : .gray.opacity(0.3)
    }
    
    private func stepIndex(for step: WriteStep) -> Int {
        switch step {
        case .selectRoom: return 0
        case .generating: return 1
        case .readyToWrite: return 2
        case .writing, .success: return 3
        }
    }
    
    // MARK: - Step 1: Select Room
    
    private var selectRoomView: some View {
        VStack(spacing: 20) {
            Image(systemName: "door.left.hand.open")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Select Room")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Choose the room where you want to install the NFC tag")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                // Room Number Input or Display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Room Number")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let presetRoomNumber = presetRoomNumber, !presetRoomNumber.isEmpty {
                        Text(presetRoomNumber)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)

                    } else {
                        TextField("e.g., 101", text: $roomNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                }
                
                // PG Name (read-only, from current user)
                VStack(alignment: .leading, spacing: 8) {
                    Text("PG Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(authManager.currentUser?.pgName ?? "Unknown PG")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            Button(action: generateTag) {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Generate Tag")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(roomNumber.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(roomNumber.isEmpty)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Step 2: Generating
    
    private var generatingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Generating Tag...")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Creating unique UUID and password for the NFC tag")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Step 3: Ready to Write
    
    private var readyToWriteView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Tag Generated!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Ready to write to physical NFC tag")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Tag Details
            if let tagData = generatedTagData {
                VStack(spacing: 12) {
                    DetailRowNFCTag(label: "Room", value: tagData.roomNumber)
                    DetailRowNFCTag(label: "PG", value: tagData.pgName)
                    DetailRowNFCTag(label: "Tag UUID", value: String(tagData.tagUUID.prefix(8)) + "...")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                Text("Instructions:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    InstructionRow(number: 1, text: "Hold your iPhone near the NFC tag")
                    InstructionRow(number: 2, text: "Keep it steady until writing completes")
                    InstructionRow(number: 3, text: "The tag will be locked with a password")
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Button(action: writeTag) {
                HStack {
                    Image(systemName: "wave.3.right")
                    Text("Start Writing")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Step 4: Writing
    
    private var writingView: some View {
        VStack(spacing: 20) {
            LottieView(animationName: "nfc-scanning")
                .frame(width: 200, height: 200)
            
            Text("Writing to NFC Tag...")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Hold your iPhone near the tag")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                nfcManager?.stopScanning()
                currentStep = .readyToWrite
            }) {
                Text("Cancel")
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Step 5: Success
    
    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Success!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("NFC tag has been written and locked successfully")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if let tagData = generatedTagData {
                VStack(spacing: 12) {
                    DetailRowNFCTag(label: "Room", value: tagData.roomNumber)
                    DetailRowNFCTag(label: "Status", value: "Active & Locked")
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Button(action: resetFlow) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Write Another Tag")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Button(action: {
                // Navigate back or to tag list
            }) {
                Text("View All Tags")
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Actions
    
    private func generateTag() {
        // ✅ Safely unwrap nfcManager
        guard let nfcManager = nfcManager,
              let pgId = authManager.currentPgId else { return }
        
        currentStep = .generating
        
        Task {
            do {
                var resolvedRoomId: String?
                var resolvedRoomNumber = roomNumber
                
                if let presetRoomId = presetRoomId, !presetRoomId.isEmpty {
                    resolvedRoomId = presetRoomId
                } else {
                    // Fetch room ID from room number
                    print("🔍 [NFC Write] Looking up room: \(roomNumber) in PG: \(pgId)")
                    
                    let roomsResponse: RoomsListResponse = try await APIManager.shared.makeRequest(
                        endpoint: "/pg/\(pgId)/rooms",
                        method: .GET,
                        responseType: RoomsListResponse.self
                    )
                    
                    // Find room with matching number (case-insensitive)
                    guard let room = roomsResponse.data.first(where: { $0.number.caseInsensitiveCompare(roomNumber) == .orderedSame }) else {
                        await MainActor.run {
                            alertMessage = "Room \(roomNumber) not found. Please check the room number."
                            showAlert = true
                            currentStep = .selectRoom
                        }
                        return
                    }
                    
                    print("✅ [NFC Write] Found room: \(room.number), ID: \(room.id)")
                    resolvedRoomId = room.id
                    resolvedRoomNumber = room.number
                }
                
                guard let roomIdToUse = resolvedRoomId else {
                    await MainActor.run {
                        alertMessage = "Unable to resolve room information."
                        showAlert = true
                        currentStep = .selectRoom
                    }
                    return
                }
                
                // Generate NFC tag
                if let tagData = await nfcManager.generateNFCTag(roomId: roomIdToUse) {
                    await MainActor.run {
                        self.selectedRoomId = roomIdToUse
                        self.roomNumber = resolvedRoomNumber
                        generatedTagData = tagData
                        currentStep = .readyToWrite
                    }
                } else {
                    await MainActor.run {
                        currentStep = .selectRoom
                    }
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to generate tag: \(error.localizedDescription)"
                    showAlert = true
                    currentStep = .selectRoom
                }
                print("❌ [NFC Write] Error: \(error)")
            }
        }
    }
    
    private func writeTag() {
        // ✅ Safely unwrap nfcManager and tagData
        guard let nfcManager = nfcManager,
              let tagData = generatedTagData else { return }
        
        currentStep = .writing
        nfcManager.writeAndLockTag(tagData: tagData)
        
        // Monitor for success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            monitorWriteStatus()
        }
    }
    
    private func monitorWriteStatus() {
        // ✅ Safely unwrap nfcManager
        guard let nfcManager = nfcManager else { return }
        
        if let success = nfcManager.successMessage, success.contains("locked") {
            currentStep = .success
        } else if !nfcManager.isScanning && currentStep == .writing {
            // Check again after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if currentStep == .writing {
                    monitorWriteStatus()
                }
            }
        }
    }
    
    private func resetFlow() {
        currentStep = .selectRoom
        roomNumber = ""
        generatedTagData = nil
        
        // ✅ Safely unwrap nfcManager
        nfcManager?.successMessage = nil
        nfcManager?.errorMessage = nil
    }
}

// MARK: - Supporting Views

struct DetailRowNFCTag: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// Placeholder for Lottie animation
struct LottieView: View {
    let animationName: String
    
    var body: some View {
        // Replace with actual Lottie animation
        Image(systemName: "wave.3.right.circle.fill")
            .font(.system(size: 100))
            .foregroundColor(.blue)
            .symbolEffect(.pulse)
    }
}

// MARK: - Preview

struct NFCTagWriteView_Previews: PreviewProvider {
    static var previews: some View {
        NFCTagWriteView()
            .environmentObject(AuthManager())
    }
}

