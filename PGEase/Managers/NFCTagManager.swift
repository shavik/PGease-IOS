import Foundation
import CoreNFC

/// Manager for NFC tag operations including writing, locking, and reading tags
/// Only MANAGER and PGADMIN roles can write to NFC tags
class NFCTagManager: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var lastScannedTagId: String?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isLoading = false
    
    // NFC session
    private var nfcSession: NFCNDEFReaderSession?
    private var nfcTagSession: NFCTagReaderSession?
    
    // Current operation
    private var currentOperation: NFCOperation = .read
    private var tagDataToWrite: NFCTagWriteData?
    
    private let apiManager = APIManager.shared
    
    // ✅ Multi-PG Support
    private let authManager: AuthManager
    
    // ✅ Inject AuthManager for PG context
    init(authManager: AuthManager) {
        self.authManager = authManager
        super.init()
    }
    
    // MARK: - NFC Operations
    
    enum NFCOperation {
        case read
        case write
        case lock
    }
    
    struct NFCTagWriteData {
        let tagUUID: String
        let password: String
        let roomNumber: String
        let pgName: String
    }
    
    // MARK: - Check NFC Availability
    
    var isNFCAvailable: Bool {
        return NFCNDEFReaderSession.readingAvailable
    }
    
    // MARK: - Generate NFC Tag
    
    /// Step 1: Generate a new NFC tag UUID and password from the backend
    /// ✅ Now uses current PG context from AuthManager
    func generateNFCTag(roomId: String) async -> NFCTagWriteData? {
        // ✅ Get current PG ID from AuthManager
        guard let pgId = authManager.currentPgId else {
            await MainActor.run {
                self.errorMessage = "No PG selected. Please select a PG first."
            }
            return nil
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await apiManager.generateNFCTag(roomId: roomId, pgId: pgId)
            
            await MainActor.run {
                self.isLoading = false
                self.successMessage = "Tag generated successfully. Ready to write."
            }
            
            return NFCTagWriteData(
                tagUUID: response.data.tagUUID,
                password: response.data.writePassword,
                roomNumber: response.data.room.number,
                pgName: response.data.pg.name
            )
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to generate tag: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    // MARK: - Write and Lock NFC Tag
    
    /// Step 2: Write UUID to physical NFC tag and lock it with password
    func writeAndLockTag(tagData: NFCTagWriteData) {
        guard isNFCAvailable else {
            errorMessage = "NFC is not available on this device"
            return
        }
        
        self.tagDataToWrite = tagData
        self.currentOperation = .write
        
        // Start NFC session for writing
        nfcTagSession = NFCTagReaderSession(
            pollingOption: [.iso14443],
            delegate: self,
            queue: nil
        )
        
        nfcTagSession?.alertMessage = "Hold your iPhone near the NFC tag to write and lock it"
        nfcTagSession?.begin()
        
        isScanning = true
    }
    
    // MARK: - Read NFC Tag
    
    /// Read NFC tag for check-in/check-out
    func readTag(completion: @escaping (String?) -> Void) {
        guard isNFCAvailable else {
            errorMessage = "NFC is not available on this device"
            completion(nil)
            return
        }
        
        self.currentOperation = .read
        
        // Start NFC session for reading
        nfcSession = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: true
        )
        
        nfcSession?.alertMessage = "Hold your iPhone near the room's NFC tag"
        nfcSession?.begin()
        
        isScanning = true
    }
    
    // MARK: - Confirm Tag Locked
    
    /// Step 3: Confirm to backend that tag has been locked
    func confirmTagLocked(tagId: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await apiManager.confirmTagLocked(tagId: tagId)
            
            await MainActor.run {
                self.isLoading = false
                self.successMessage = "Tag locked and confirmed successfully!"
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to confirm tag lock: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - List NFC Tags
    
    /// ✅ Now uses current PG context from AuthManager (pgId param removed)
    func listTags(status: String? = nil, roomId: String? = nil) async -> [NFCTagInfo]? {
        // ✅ Get current PG ID from AuthManager
        guard let pgId = authManager.currentPgId else {
            await MainActor.run {
                self.errorMessage = "No PG selected. Please select a PG first."
            }
            return nil
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await apiManager.listNFCTags(pgId: pgId, status: status, roomId: roomId)
            
            await MainActor.run {
                self.isLoading = false
            }
            
            return response.data
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to list tags: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    // MARK: - Update NFC Tag
    
    func updateTag(tagId: String, roomId: String?, status: String?) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await apiManager.updateNFCTag(tagId: tagId, roomId: roomId, status: status)
            
            await MainActor.run {
                self.isLoading = false
                self.successMessage = "Tag updated successfully"
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to update tag: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Deactivate NFC Tag
    
    func deactivateTag(tagId: String, status: String, reason: String?) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await apiManager.deactivateNFCTag(tagId: tagId, status: status, reason: reason)
            
            await MainActor.run {
                self.isLoading = false
                self.successMessage = "Tag deactivated: \(status)"
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to deactivate tag: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Get Tag Password
    
    func getTagPassword(tagId: String) async -> String? {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await apiManager.getTagPassword(tagId: tagId)
            
            await MainActor.run {
                self.isLoading = false
            }
            
            return response.data.password
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to get tag password: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    func stopScanning() {
        nfcSession?.invalidate()
        nfcTagSession?.invalidate()
        isScanning = false
    }
}

// MARK: - NFCNDEFReaderSessionDelegate (Reading)

extension NFCTagManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Process NDEF messages
        for message in messages {
            for record in message.records {
                if let payload = String(data: record.payload, encoding: .utf8) {
                    // Extract UUID from payload
                    // Payload format: "pgease://tag/{UUID}"
                    if let tagId = extractTagId(from: payload) {
                        DispatchQueue.main.async {
                            self.lastScannedTagId = tagId
                            self.successMessage = "Tag scanned successfully"
                        }
                    }
                }
            }
        }
        
        session.invalidate()
        isScanning = false
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
            
            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    // User cancelled, don't show error
                    break
                case .readerSessionInvalidationErrorFirstNDEFTagRead:
                    // Successfully read, don't show error
                    break
                default:
                    self.errorMessage = "NFC Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func extractTagId(from payload: String) -> String? {
        // Extract UUID from "pgease://tag/{UUID}" format
        let prefix = "pgease://tag/"
        guard payload.hasPrefix(prefix) else { return nil }
        return String(payload.dropFirst(prefix.count))
    }
}

// MARK: - NFCTagReaderSessionDelegate (Writing)

extension NFCTagManager: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // Session is ready
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
            
            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    // User cancelled, don't show error
                    break
                default:
                    self.errorMessage = "NFC Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag detected")
            return
        }
        
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }
            
            // Handle different tag types
            switch tag {
            case .miFare(let miFareTag):
                self.handleMiFareTag(miFareTag, session: session)
            case .iso15693(let iso15693Tag):
                self.handleISO15693Tag(iso15693Tag, session: session)
            case .iso7816(let iso7816Tag):
                self.handleISO7816Tag(iso7816Tag, session: session)
            case .feliCa(let feliCaTag):
                session.invalidate(errorMessage: "FeliCa tags are not supported")
            @unknown default:
                session.invalidate(errorMessage: "Unsupported tag type")
            }
        }
    }
    
    // MARK: - Tag Type Handlers
    
    private func handleMiFareTag(_ tag: NFCMiFareTag, session: NFCTagReaderSession) {
        // Query NDEF support
        tag.queryNDEFStatus { status, capacity, error in
            if let error = error {
                session.invalidate(errorMessage: "Query failed: \(error.localizedDescription)")
                return
            }
            
            guard status == .readWrite else {
                session.invalidate(errorMessage: "Tag is not writable")
                return
            }
            
            if self.currentOperation == .write {
                self.writeNDEFMessage(to: tag, session: session)
            }
        }
    }
    
    private func handleISO15693Tag(_ tag: NFCISO15693Tag, session: NFCTagReaderSession) {
        // Similar to MiFare handling
        session.invalidate(errorMessage: "ISO15693 tags are not fully supported yet")
    }
    
    private func handleISO7816Tag(_ tag: NFCISO7816Tag, session: NFCTagReaderSession) {
        // Similar to MiFare handling
        session.invalidate(errorMessage: "ISO7816 tags are not fully supported yet")
    }
    
    // MARK: - Write NDEF Message
    
    private func writeNDEFMessage(to tag: NFCMiFareTag, session: NFCTagReaderSession) {
        guard let tagData = tagDataToWrite else {
            session.invalidate(errorMessage: "No tag data to write")
            return
        }
        
        // Create NDEF payload with UUID
        let uriString = "pgease://tag/\(tagData.tagUUID)"
        guard let uriPayload = uriString.data(using: .utf8) else {
            session.invalidate(errorMessage: "Failed to create payload")
            return
        }
        
        // Create NDEF record (URI type)
        let uriRecord = NFCNDEFPayload(
            format: .nfcWellKnown,
            type: "U".data(using: .utf8)!,
            identifier: Data(),
            payload: uriPayload
        )
        
        // Create NDEF message
        let ndefMessage = NFCNDEFMessage(records: [uriRecord])
        
        // Write NDEF message
        tag.writeNDEF(ndefMessage) { error in
            if let error = error {
                session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                return
            }
            
            // Now lock the tag with password
            self.lockTag(tag, password: tagData.password, tagUUID: tagData.tagUUID, session: session)
        }
    }
    
    // MARK: - Lock Tag with Password
    
    private func lockTag(_ tag: NFCMiFareTag, password: String, tagUUID: String, session: NFCTagReaderSession) {
        // Convert password to bytes (use first 4 bytes for MiFare Ultralight)
        guard let passwordData = password.data(using: .utf8) else {
            session.invalidate(errorMessage: "Invalid password format")
            return
        }
        
        // For MiFare Ultralight, set password protection
        // This is a simplified version - actual implementation depends on tag type
        
        // Command to set password (MiFare Ultralight C/EV1 specific)
        // Page 0x2B: PWD (4 bytes)
        // Page 0x2C: PACK (2 bytes)
        
        let passwordBytes = [UInt8](passwordData.prefix(4))
        let passwordCommand = Data([0xA2, 0x2B] + passwordBytes) // Write to page 0x2B
        
        tag.sendMiFareCommand(commandPacket: passwordCommand) { response, error in
            if let error = error {
                session.invalidate(errorMessage: "Failed to set password: \(error.localizedDescription)")
                return
            }
            
            // Set AUTH0 to protect all pages from 0x03 onwards
            let auth0Command = Data([0xA2, 0x2A, 0x03, 0x00, 0x00, 0x00])
            
            tag.sendMiFareCommand(commandPacket: auth0Command) { response, error in
                if let error = error {
                    session.invalidate(errorMessage: "Failed to lock tag: \(error.localizedDescription)")
                    return
                }
                
                // Success!
                session.alertMessage = "✅ Tag written and locked successfully!"
                session.invalidate()
                
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.successMessage = "Tag written and locked"
                    
                    // Confirm to backend
                    Task {
                        await self.confirmTagLocked(tagId: tagUUID)
                    }
                }
            }
        }
    }
}

