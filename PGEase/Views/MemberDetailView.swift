//
//  MemberDetailView.swift
//  PGEase
//
//  Detailed view of a member with invite management
//

import SwiftUI

struct MemberDetailView: View {
    let member: UserListItem
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var inviteData: GenerateInviteResponse.InviteData?
    @State private var isLoading = false
    @State private var isGeneratingInvite = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showInviteShare = false
    
    // Room assignment
    @State private var currentRoom: BasicRoomInfo?
    @State private var availableRooms: [AvailableRoom] = []
    @State private var isLoadingRooms = false
    @State private var isAssigningRoom = false
    @State private var showRoomPicker = false
    @State private var selectedRoomId: String?
    
    // Room swap
    @State private var showSwapSheet = false
    @State private var isSwappingRoom = false
    @State private var swapCandidates: [StudentSwapCandidate] = []
    @State private var selectedSwapCandidate: StudentSwapCandidate?
    
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(roleColor(for: member.role))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: roleIcon(for: member.role))
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                        
                        Text(member.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(member.role)
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(roleColor(for: member.role).opacity(0.2))
                            .foregroundColor(roleColor(for: member.role))
                            .cornerRadius(20)
                        
                        MemberStatusBadge(status: member.status)
                    }
                    .padding(.top)
                    
                    // Contact Info
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Contact Information")
                        
                        MemberInfoRow(icon: "envelope.fill", label: "Email", value: member.email)

                        if let phone = member.phone, !phone.isEmpty {
                            MemberInfoRow(icon: "phone.fill", label: "Phone", value: phone)
                        }
                        
                        MemberInfoRow(icon: "calendar", label: "Added", value: formatDate(member.createdAt))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Room Assignment (only for students, only for PG Admin/Manager)
                    if member.role == "STUDENT" && (authManager.userRole == .pgAdmin || authManager.userRole == .manager) {
                        roomAssignmentSection
                    }
                    
                    // Invite Status
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Invite Status")
                        
                        if let inviteStatus = member.inviteStatus {
                            if inviteStatus.isUsed {
                                // Invite used - show success with regenerate option
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                    VStack(alignment: .leading) {
                                        Text("Invite Used")
                                            .font(.headline)
                                        Text("Member has activated their account")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                                
                                // Regenerate button (for creating a new invite)
                                Button(action: generateInvite) {
                                    HStack {
                                        if isGeneratingInvite {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                        Image(systemName: "arrow.clockwise")
                                        Text(isGeneratingInvite ? "Generating..." : "Generate New Invite")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(isGeneratingInvite)
                                
                            } else if inviteStatus.isExpired {
                                // Invite expired
                                HStack {
                                    Image(systemName: "clock.badge.exclamationmark")
                                        .foregroundColor(.orange)
                                        .font(.title2)
                                    VStack(alignment: .leading) {
                                        Text("Invite Expired")
                                            .font(.headline)
                                        if let expiresAt = inviteStatus.expiresAt {
                                            Text("Expired on \(formatDate(expiresAt))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                                
                                // Regenerate button
                                Button(action: generateInvite) {
                                    HStack {
                                        if isGeneratingInvite {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                        Text(isGeneratingInvite ? "Regenerating..." : "Regenerate Invite")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(isGeneratingInvite)
                                
                            } else {
                                // Invite active
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                    VStack(alignment: .leading) {
                                        Text("Invite Active")
                                            .font(.headline)
                                        if let expiresAt = inviteStatus.expiresAt {
                                            Text("Expires on \(formatDate(expiresAt))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                
                                // View/Share button
                                Button(action: loadAndShowInvite) {
                                    HStack {
                                        Image(systemName: "qrcode")
                                        Text("View/Share Invite")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }
                        } else {
                            // No invite yet
                            HStack {
                                Image(systemName: "envelope.badge.fill")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text("No Invite Generated")
                                        .font(.headline)
                                    Text("Generate an invite to onboard this member")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                            
                            // Generate button
                            Button(action: generateInvite) {
                                HStack {
                                    if isGeneratingInvite {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    }
                                    Image(systemName: "envelope.badge.plus")
                                    Text(isGeneratingInvite ? "Generating..." : "Generate Invite")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isGeneratingInvite)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Member Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showInviteShare) {
                if let invite = inviteData {
                    InviteShareView(inviteData: invite)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showRoomPicker) {
                roomPickerSheet
            }
            .task {
                if member.role == "STUDENT" {
                    await loadStudentRoom()
                    await loadAvailableRooms()
                }
            }
        }
    }
    
    // MARK: - Room Assignment Section
    
    private var roomAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Room Assignment")
            
            // Current Room
            if let room = currentRoom {
                HStack {
                    Image(systemName: "door.left.hand.closed.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Room")
                            .font(.headline)
                        Text("Room \(room.number)")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            } else {
                HStack {
                    Image(systemName: "door.left.hand.closed")
                        .foregroundColor(.gray)
                        .font(.title2)
                    Text("No room assigned")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Assign/Change Room Button
            Button(action: {
                showRoomPicker = true
            }) {
                HStack {
                    if isAssigningRoom {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Image(systemName: currentRoom == nil ? "plus.circle.fill" : "arrow.triangle.2.circlepath")
                    Text(currentRoom == nil ? "Assign Room" : "Change Room")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isAssigningRoom || isLoadingRooms)
            
            if authManager.userRole == .pgAdmin || authManager.userRole == .manager {
                Button(action: {
                    showSwapSheet = true
                }) {
                    HStack {
                        if isSwappingRoom {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                        Text("Swap Room")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isSwappingRoom || isLoadingRooms || currentRoom == nil)
                .sheet(isPresented: $showSwapSheet) {
                    swapSheet
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var roomPickerSheet: some View {
        NavigationView {
            VStack {
                if isLoadingRooms {
                    ProgressView("Loading rooms...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if availableRooms.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "door.left.hand.closed")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No Available Rooms")
                            .font(.headline)
                        Text("All rooms are currently occupied")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        // Unassign option (if room is currently assigned)
                        if currentRoom != nil {
                            Button(action: {
                                selectedRoomId = "unassign"
                                assignRoom(roomId: nil)
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Unassign Room")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    Spacer()
                                    if selectedRoomId == "unassign" && isAssigningRoom {
                                        ProgressView()
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                        }
                        
                        // Available rooms
                        ForEach(availableRooms) { room in
                            Button(action: {
                                selectedRoomId = room.id
                                assignRoom(roomId: room.id)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Room \(room.number)")
                                            .font(.headline)
                                        Text("\(room.availableBeds) bed\(room.availableBeds == 1 ? "" : "s") available")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedRoomId == room.id && isAssigningRoom {
                                        ProgressView()
                                    } else if currentRoom?.id == room.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Select Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showRoomPicker = false
                        selectedRoomId = nil
                    }
                }
            }
        }
    }
    
    private var swapSheet: some View {
        NavigationView {
            VStack {
                if isSwappingRoom {
                    ProgressView("Swapping rooms...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if swapCandidates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No available students")
                            .font(.headline)
                        Text("Only students with assigned rooms can be swapped.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(swapCandidates) { candidate in
                            Button {
                                selectedSwapCandidate = candidate
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(candidate.name)
                                            .font(.headline)
                                        if let room = candidate.roomNumber {
                                            Text("Room \(room)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if selectedSwapCandidate?.id == candidate.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.purple)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Swap Room With")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showSwapSheet = false
                        selectedSwapCandidate = nil
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Swap") {
                        Task {
                            await performSwap()
                        }
                    }
                    .disabled(selectedSwapCandidate == nil || isSwappingRoom)
                }
            }
            .task {
                await loadSwapCandidates()
            }
        }
    }
    
    // MARK: - Methods
    
    private func generateInvite() {
        guard let creatorId = authManager.currentUser?.id else { return }
        
        isGeneratingInvite = true
        
        Task {
            do {
                let response = try await APIManager.shared.generateInvite(
                    userId: member.id,
                    createdBy: creatorId
                )
                
                if response.success {
                    inviteData = response.data
                    showInviteShare = true
                    print("✅ Invite generated: \(response.data.inviteCode)")
                }
            } catch {
                errorMessage = "Failed to generate invite: \(error.localizedDescription)"
                showError = true
                print("❌ Generate invite error: \(error)")
            }
            
            isGeneratingInvite = false
        }
    }
    
    private func loadSwapCandidates() async {
        guard let pgId = authManager.currentPgId,
              let currentStudentId = member.studentId else {
            await MainActor.run {
                swapCandidates = []
            }
            return
        }
        
        do {
            let response: StudentsListResponse = try await APIManager.shared.makeRequest(
                endpoint: "/pg/\(pgId)/students?limit=500",
                method: .GET,
                responseType: StudentsListResponse.self
            )
            
            let candidates = response.data.data
                .filter {
                    $0.id != currentStudentId &&
                    $0.status == "ACTIVE" &&
                    $0.room?.id != nil
                }
                .map {
                    StudentSwapCandidate(
                        id: $0.id,
                        name: $0.name,
                        roomId: $0.room?.id,
                        roomNumber: $0.room?.number
                    )
                }
            
            await MainActor.run {
                swapCandidates = candidates
            }
        } catch {
            await MainActor.run {
                swapCandidates = []
            }
            print("❌ [Room Swap] Failed to load candidates: \(error)")
        }
    }
    
    private func performSwap() async {
        guard let pgId = authManager.currentPgId,
              let studentId = member.studentId,
              currentRoom != nil,
              let candidate = selectedSwapCandidate else {
            return
        }
        
        await MainActor.run {
            isSwappingRoom = true
        }
        
        do {
            let swapResult = try await APIManager.shared.swapStudentRooms(
                pgId: pgId,
                studentAId: studentId,
                studentBId: candidate.id
            )
            
            await loadStudentRoom()
            await loadAvailableRooms()
            await MainActor.run {
                self.currentRoom = swapResult.studentA.room
                showSwapSheet = false
                selectedSwapCandidate = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to swap rooms: \(error.localizedDescription)"
                showError = true
            }
        }

        await MainActor.run {
            isSwappingRoom = false
        }
    }
    private func loadAndShowInvite() {
        isLoading = true
        
        Task {
            do {
                let response = try await APIManager.shared.getUserInviteStatus(userId: member.id)
                
                if response.success, let data = response.data {
                    inviteData = GenerateInviteResponse.InviteData(
                        inviteCode: data.inviteCode,
                        qrCode: data.qrCode ?? "",
                        deepLink: data.deepLink ?? "",
                        expiresAt: data.expiresAt,
                        user: GenerateInviteResponse.InviteUser(
                            id: data.user.id,
                            name: data.user.name,
                            email: data.user.email,
                            role: data.user.role
                        )
                    )
                    showInviteShare = true
                } else {
                    // No existing invite found; generate one on the fly
                    await MainActor.run {
                        isLoading = false
                        isGeneratingInvite = true
                    }
                    generateInvite()
                }
            } catch {
                errorMessage = "Failed to load invite: \(error.localizedDescription)"
                showError = true
                print("❌ Load invite error: \(error)")
            }
            
            isLoading = false
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        
        return displayFormatter.string(from: date)
    }
    
    // MARK: - Room Assignment Methods
    
    private func loadStudentRoom() async {
        guard let pgId = authManager.currentPgId,
              let studentId = member.studentId else {
            // Not a student or studentId not available
            return
        }
        
        do {
            // Fetch student details to get room info
            let response: GetStudentResponse = try await APIManager.shared.makeRequest(
                endpoint: "/pg/\(pgId)/students/\(studentId)",
                method: .GET,
                responseType: GetStudentResponse.self
            )
            
            if let studentData = response.data, let room = studentData.room {
                await MainActor.run {
                    currentRoom = room
                }
            } else {
                await MainActor.run {
                    currentRoom = nil
                }
            }
        } catch {
            print("⚠️ [Room Assignment] Could not load student room: \(error)")
            // Not critical, continue without room info
        }
    }
    
    private func loadAvailableRooms() async {
        guard let pgId = authManager.currentPgId else { return }
        
        await MainActor.run {
            isLoadingRooms = true
        }
        
        do {
            let response = try await APIManager.shared.getAvailableRooms(pgId: pgId)
            
            await MainActor.run {
                availableRooms = response.data
                isLoadingRooms = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load available rooms: \(error.localizedDescription)"
                showError = true
                isLoadingRooms = false
            }
            print("❌ Load available rooms error: \(error)")
        }
    }
    
    private func assignRoom(roomId: String?) {
        guard let pgId = authManager.currentPgId,
              let studentId = member.studentId else {
            print("❌ [Room Assignment] Missing pgId or studentId")
            return
        }
        
        print("🏠 [Room Assignment] Assigning room \(roomId ?? "nil") to student \(studentId)")
        
        isAssigningRoom = true
        
        Task {
            do {
                let response = try await APIManager.shared.updateStudentRoom(
                    studentId: studentId,
                    pgId: pgId,
                    roomId: roomId
                )
                
                print("✅ [Room Assignment] Response: success=\(response.success)")
                
                if response.success {
                    // Update current room
                    if let roomData = response.data?.room {
                        print("✅ [Room Assignment] Room assigned: \(roomData.number)")
                        await MainActor.run {
                            currentRoom = roomData
                            showRoomPicker = false
                            selectedRoomId = nil
                        }
                    } else {
                        // Room was unassigned
                        print("✅ [Room Assignment] Room unassigned")
                        await MainActor.run {
                            currentRoom = nil
                            showRoomPicker = false
                            selectedRoomId = nil
                        }
                    }
                    
                    // Reload available rooms to reflect changes
                    await loadAvailableRooms()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to assign room: \(error.localizedDescription)"
                    showError = true
                }
                print("❌ [Room Assignment] Error: \(error)")
            }
            
            await MainActor.run {
                isAssigningRoom = false
            }
        }
    }
    
    private func roleColor(for role: String) -> Color {
        switch role {
        case "MANAGER": return .purple
        case "WARDEN": return .orange
        case "ACCOUNTANT": return .green
        case "STAFF": return .blue
        case "STUDENT": return .indigo
        default: return .gray
        }
    }
    
    private func roleIcon(for role: String) -> String {
        switch role {
        case "MANAGER": return "person.badge.key.fill"
        case "WARDEN": return "shield.fill"
        case "ACCOUNTANT": return "dollarsign.circle.fill"
        case "STAFF": return "figure.walk"
        case "STUDENT": return "graduationcap.fill"
        default: return "person.fill"
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.bold)
    }
}

struct MemberInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }
            
            Spacer()
        }
    }
}

struct MemberStatusBadge: View {
    let status: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(status)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .cornerRadius(20)
    }
    
    private var statusColor: Color {
        switch status {
        case "ACTIVE": return .green
        case "PENDING": return .orange
        case "INACTIVE", "SUSPENDED": return .red
        default: return .gray
        }
    }
}

struct StudentSwapCandidate: Identifiable {
    let id: String
    let name: String
    let roomId: String?
    let roomNumber: String?
}

