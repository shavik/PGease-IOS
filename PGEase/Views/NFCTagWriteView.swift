import SwiftUI

/// View for writing and locking NFC tags
/// Only accessible by MANAGER and PGADMIN roles
struct NFCTagWriteView: View {
    @StateObject private var nfcManager = NFCTagManager()
    @EnvironmentObject var authManager: AuthManager
    
    @State private var selectedRoomId: String = ""
    @State private var selectedPgId: String = ""
    @State private var roomNumber: String = ""
    @State private var pgName: String = ""
    
    @State private var generatedTagData: NFCTagManager.NFCTagWriteData?
    @State private var currentStep: WriteStep = .selectRoom
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    enum WriteStep {
        case selectRoom
        case generating
        case readyToWrite
        case writing
        case success
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
            .onChange(of: nfcManager.errorMessage) { error in
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
                // Room Number Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Room Number")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("e.g., 101", text: $roomNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
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
                    DetailRow(label: "Room", value: tagData.roomNumber)
                    DetailRow(label: "PG", value: tagData.pgName)
                    DetailRow(label: "Tag UUID", value: String(tagData.tagUUID.prefix(8)) + "...")
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
                nfcManager.stopScanning()
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
                    DetailRow(label: "Room", value: tagData.roomNumber)
                    DetailRow(label: "Status", value: "Active & Locked")
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
        currentStep = .generating
        
        Task {
            // In real implementation, fetch roomId from API based on roomNumber
            // For now, using placeholder
            guard let pgId = authManager.currentUser?.pgId else {
                alertMessage = "PG ID not found"
                showAlert = true
                currentStep = .selectRoom
                return
            }
            
            // TODO: Fetch roomId from API based on roomNumber
            let roomId = "placeholder-room-id"
            
            if let tagData = await nfcManager.generateNFCTag(roomId: roomId, pgId: pgId) {
                generatedTagData = tagData
                currentStep = .readyToWrite
            } else {
                currentStep = .selectRoom
            }
        }
    }
    
    private func writeTag() {
        guard let tagData = generatedTagData else { return }
        
        currentStep = .writing
        nfcManager.writeAndLockTag(tagData: tagData)
        
        // Monitor for success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            monitorWriteStatus()
        }
    }
    
    private func monitorWriteStatus() {
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
        nfcManager.successMessage = nil
        nfcManager.errorMessage = nil
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
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

