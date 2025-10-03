import Foundation
import CoreNFC
import Combine

@MainActor
class NFCManager: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var lastReadMessage: String = ""
    @Published var errorMessage: String = ""
    @Published var isWriting = false
    @Published var writeSuccess = false

    private var nfcSession: NFCNDEFReaderSession?
    private var nfcTag: NFCNDEFTag?
    private var retryCount = 0
    private let maxRetries = 3

    override init() {
        super.init()
    }

    // MARK: - NFC Reading
    func startReading() {
        guard NFCNDEFReaderSession.readingAvailable else {
            errorMessage = "NFC reading is not available on this device"
            return
        }

        // Check if we're on a simulator
        #if targetEnvironment(simulator)
        errorMessage = "NFC is not available in the iOS Simulator. Please test on a physical device."
        return
        #endif

        // Reset retry count on new attempt
        retryCount = 0

        do {
            nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
            nfcSession?.alertMessage = "Hold your iPhone near an NFC tag to read it"
            nfcSession?.begin()
            isScanning = true
            errorMessage = ""
        } catch {
            errorMessage = "Failed to start NFC session: \(error.localizedDescription)"
            isScanning = false
        }
    }

    func stopReading() {
        nfcSession?.invalidate()
        nfcSession = nil
        isScanning = false
    }

    // MARK: - NFC Writing
    func writeToNFC(message: String) {
        guard NFCNDEFReaderSession.readingAvailable else {
            errorMessage = "NFC writing is not available on this device"
            return
        }

        // Check if we're on a simulator
        #if targetEnvironment(simulator)
        errorMessage = "NFC is not available in the iOS Simulator. Please test on a physical device."
        return
        #endif

        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Message cannot be empty"
            return
        }

        do {
            nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
            nfcSession?.alertMessage = "Hold your iPhone near an NFC tag to write to it"
            nfcSession?.begin()
            isWriting = true
            writeSuccess = false
            errorMessage = ""

            // Store the message to write
            messageToWrite = message
        } catch {
            errorMessage = "Failed to start NFC session: \(error.localizedDescription)"
            isWriting = false
        }
    }

    private var messageToWrite: String = ""
    
    // MARK: - Helper Methods
    private func parseNDEFPayload(_ payload: NFCNDEFPayload) -> String {
        // Check payload type
        let typeString = String(data: payload.type, encoding: .utf8) ?? ""
        
        // Handle different NDEF record types
        if typeString == "T" {
            // Text Record (NDEF Well Known Type)
            return parseTextRecord(payload)
        } else if typeString == "U" {
            // URI Record
            return parseURIRecord(payload)
        } else if payload.typeNameFormat == .nfcWellKnown {
            // Well-known type but not T or U, try text parsing
            return parseTextRecord(payload)
        } else if payload.typeNameFormat == .absoluteURI {
            // Absolute URI
            return String(data: payload.payload, encoding: .utf8) ?? ""
        } else if payload.typeNameFormat == .media {
            // Media type
            return String(data: payload.payload, encoding: .utf8) ?? ""
        } else {
            // Unknown type, try direct UTF-8 decoding
            return String(data: payload.payload, encoding: .utf8) ?? ""
        }
    }
    
    private func parseTextRecord(_ payload: NFCNDEFPayload) -> String {
        guard payload.payload.count > 0 else { return "" }
        
        // NDEF Text Record format:
        // Byte 0: Status byte (bit 7 = encoding, bits 5-0 = language code length)
        // Bytes 1-n: Language code
        // Bytes n+1-end: Text
        
        let statusByte = payload.payload[0]
        let isUTF16 = (statusByte & 0x80) != 0
        let languageCodeLength = Int(statusByte & 0x3F)
        
        guard payload.payload.count > languageCodeLength + 1 else {
            // Fallback: try simple UTF-8 decode
            return String(data: payload.payload, encoding: .utf8) ?? ""
        }
        
        let textStartIndex = 1 + languageCodeLength
        let textData = payload.payload.subdata(in: textStartIndex..<payload.payload.count)
        
        let encoding: String.Encoding = isUTF16 ? .utf16 : .utf8
        return String(data: textData, encoding: encoding) ?? String(data: textData, encoding: .utf8) ?? ""
    }
    
    private func parseURIRecord(_ payload: NFCNDEFPayload) -> String {
        guard payload.payload.count > 0 else { return "" }
        
        // NDEF URI Record format:
        // Byte 0: URI identifier code
        // Bytes 1-end: URI
        
        let uriPrefixes = [
            "", // 0x00
            "http://www.", // 0x01
            "https://www.", // 0x02
            "http://", // 0x03
            "https://", // 0x04
            "tel:", // 0x05
            "mailto:", // 0x06
            "ftp://anonymous:anonymous@", // 0x07
            "ftp://ftp.", // 0x08
            "ftps://", // 0x09
            "sftp://", // 0x0A
            "smb://", // 0x0B
            "nfs://", // 0x0C
            "ftp://", // 0x0D
            "dav://", // 0x0E
            "news:", // 0x0F
            "telnet://", // 0x10
            "imap:", // 0x11
            "rtsp://", // 0x12
            "urn:", // 0x13
            "pop:", // 0x14
            "sip:", // 0x15
            "sips:", // 0x16
            "tftp:", // 0x17
            "btspp://", // 0x18
            "btl2cap://", // 0x19
            "btgoep://", // 0x1A
            "tcpobex://", // 0x1B
            "irdaobex://", // 0x1C
            "file://", // 0x1D
            "urn:epc:id:", // 0x1E
            "urn:epc:tag:", // 0x1F
            "urn:epc:pat:", // 0x20
            "urn:epc:raw:", // 0x21
            "urn:epc:", // 0x22
            "urn:nfc:" // 0x23
        ]
        
        let identifierCode = Int(payload.payload[0])
        let prefix = identifierCode < uriPrefixes.count ? uriPrefixes[identifierCode] : ""
        
        let uriData = payload.payload.subdata(in: 1..<payload.payload.count)
        let uriString = String(data: uriData, encoding: .utf8) ?? ""
        
        return prefix + uriString
    }
}

// MARK: - NFCNDEFReaderSessionDelegate
extension NFCManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
            self.isWriting = false

            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    // User canceled - don't show error
                    break
                case .readerSessionInvalidationErrorSessionTimeout:
                    self.errorMessage = "Session timed out. Please try again."
                case .readerSessionInvalidationErrorSystemIsBusy:
                    self.errorMessage = "System is busy. Please try again."
                case .readerSessionInvalidationErrorSessionTerminatedUnexpectedly:
                    self.errorMessage = "NFC session terminated unexpectedly. Please try again."
                case .readerSessionInvalidationErrorFirstNDEFTagRead:
                    // This is normal - session ends after first read
                    break
                default:
                    self.errorMessage = "NFC Error: \(nfcError.localizedDescription)"
                }
            } else {
                // Handle XPC connection errors
                let errorDescription = error.localizedDescription
                if errorDescription.contains("XPC Error") || errorDescription.contains("com.apple.nfcd.service.corenfc") {
                    if self.retryCount < self.maxRetries {
                        self.retryCount += 1
                        self.errorMessage = "NFC service error. Retrying... (Attempt \(self.retryCount)/\(self.maxRetries))"

                        // Retry after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            if self.isScanning {
                                self.startReading()
                            } else if self.isWriting {
                                self.writeToNFC(message: self.messageToWrite)
                            }
                        }
                    } else {
                        self.errorMessage = "NFC service connection failed after \(self.maxRetries) attempts. Please restart the app."
                        self.retryCount = 0
                    }
                } else {
                    self.errorMessage = "Unknown error: \(errorDescription)"
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async {
            self.isScanning = false
            
            if let message = messages.first,
               let payload = message.records.first {
                let parsedMessage = self.parseNDEFPayload(payload)
                if !parsedMessage.isEmpty {
                    self.lastReadMessage = parsedMessage
                    self.errorMessage = ""
                } else {
                    self.errorMessage = "Could not read NFC tag content"
                }
            } else {
                self.errorMessage = "Could not read NFC tag content"
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No NFC tag found")
            return
        }

        session.connect(to: tag) { [weak self] (error: Error?) in
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }

            self?.nfcTag = tag

            if self?.isWriting == true {
                self?.writeToTag(tag: tag, session: session)
            } else {
                self?.readFromTag(tag: tag, session: session)
            }
        }
    }

    private func readFromTag(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.queryNDEFStatus { [weak self] (status: NFCNDEFStatus, capacity: Int, error: Error?) in
            if let error = error {
                session.invalidate(errorMessage: "Query failed: \(error.localizedDescription)")
                return
            }

            switch status {
            case .notSupported:
                session.invalidate(errorMessage: "Tag is not NDEF compliant")
            case .readOnly:
                session.invalidate(errorMessage: "Tag is read only")
            case .readWrite:
                tag.readNDEF { [weak self] (message: NFCNDEFMessage?, error: Error?) in
                    if let error = error {
                        session.invalidate(errorMessage: "Read failed: \(error.localizedDescription)")
                        return
                    }

                    if let message = message,
                       let payload = message.records.first {
                        let parsedMessage = self?.parseNDEFPayload(payload) ?? ""
                        DispatchQueue.main.async {
                            if !parsedMessage.isEmpty {
                                self?.lastReadMessage = parsedMessage
                                self?.isScanning = false
                                self?.errorMessage = ""
                            } else {
                                self?.errorMessage = "Could not parse NFC tag content"
                            }
                        }
                    }

                    session.invalidate()
                }
            @unknown default:
                session.invalidate(errorMessage: "Unknown tag status")
            }
        }
    }

    private func writeToTag(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.queryNDEFStatus { [weak self] (status: NFCNDEFStatus, capacity: Int, error: Error?) in
            if let error = error {
                session.invalidate(errorMessage: "Query failed: \(error.localizedDescription)")
                return
            }

            switch status {
            case .notSupported:
                session.invalidate(errorMessage: "Tag is not NDEF compliant")
            case .readOnly:
                session.invalidate(errorMessage: "Tag is read only")
            case .readWrite:
                guard let messageToWrite = self?.messageToWrite else {
                    session.invalidate(errorMessage: "No message to write")
                    return
                }

                let payload = NFCNDEFPayload(
                    format: .nfcWellKnown,
                    type: "T".data(using: .utf8)!,
                    identifier: Data(),
                    payload: Data([0x02, 0x65, 0x6E] + messageToWrite.utf8) // English language code + message
                )

                let message = NFCNDEFMessage(records: [payload])

                tag.writeNDEF(message) { [weak self] (error: Error?) in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.errorMessage = "Write failed: \(error.localizedDescription)"
                        } else {
                            self?.writeSuccess = true
                            self?.lastReadMessage = messageToWrite
                        }
                        self?.isWriting = false
                    }
                    session.invalidate()
                }
            @unknown default:
                session.invalidate(errorMessage: "Unknown tag status")
            }
        }
    }
}
