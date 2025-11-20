import SwiftUI
import CoreNFC

struct AttendanceView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var checkInOutManager: CheckInOutManager

    @StateObject private var nfcReader = AttendanceNFCReader()

    @State private var isScanning = false
    @State private var currentAction: AttendanceAction?
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert = false
    @State private var hasInitializedStatus = false

    private enum AttendanceAction {
        case checkIn
        case checkOut
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    statusCard
                    actionButtons
                    helperSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .navigationTitle("Attendance")
            .navigationBarTitleDisplayMode(.large)
        }
        .overlay(scanningOverlay)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {
                showAlert = false
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            if !hasInitializedStatus {
                hasInitializedStatus = true
            }
            checkInOutManager.requestLocationPermission()
            checkInOutManager.startLocationUpdates()
            
            // Refresh status from database when view appears
            Task {
                await checkInOutManager.refreshCheckInStatus()
            }
        }
        .onChange(of: checkInOutManager.isCheckedIn) { newValue in
            guard hasInitializedStatus else { return }
            alertTitle = "Success"
            alertMessage = newValue ? "Checked in successfully." : "Checked out successfully."
            showAlert = true
        }
        .onChange(of: checkInOutManager.errorMessage) { newValue in
            guard let message = newValue, !message.isEmpty else { return }
            alertTitle = "Something went wrong"
            alertMessage = message
            showAlert = true
            checkInOutManager.errorMessage = nil
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(checkInOutManager.checkInStatusColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: checkInOutManager.isCheckedIn ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(checkInOutManager.checkInStatusColor)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(checkInOutManager.checkInStatusText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(checkInOutManager.checkInStatusColor)

                    Text(checkInOutManager.lastActionText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if !checkInOutManager.isLocationEnabled {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "location.slash")
                        .foregroundColor(.orange)
                    Text("Location access is recommended for accurate attendance records.")
                        .font(.footnote)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
    }

    private var actionButtons: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tap a tag to register attendance")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Hold your iPhone near the NFC tag mounted on your room door. Biometrics will be verified automatically before check-in/out is recorded.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Button(action: { beginScan(for: .checkIn) }) {
                HStack {
                    if isScanning && currentAction == .checkIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.down.to.line.circle.fill")
                    }
                    Text("Check In with NFC")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(checkInOutManager.isCheckedIn ? Color.gray.opacity(0.3) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(isScanning || checkInOutManager.isLoading || checkInOutManager.isCheckedIn)

            Button(action: { beginScan(for: .checkOut) }) {
                HStack {
                    if isScanning && currentAction == .checkOut {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.up.and.line.horizontal.and.arrow.down")
                    }
                    Text("Check Out with NFC")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(!checkInOutManager.isCheckedIn ? Color.gray.opacity(0.3) : Color.purple)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(isScanning || checkInOutManager.isLoading || !checkInOutManager.isCheckedIn)

            if checkInOutManager.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Verifying attendance...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(20)
    }

    private var helperSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Need help?")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                helperRow(icon: "questionmark.circle", title: "Can't detect the tag?", description: "Make sure NFC is enabled and tap the center-top of your phone against the tag.")

                helperRow(icon: "faceid", title: "Biometric verification", description: "Face ID or Touch ID will be requested automatically as part of the check-in/out process.")

                helperRow(icon: "person.crop.circle", title: "Wrong room?", description: "Contact your PG manager to update room assignment before checking in.")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func helperRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var scanningOverlay: some View {
        Group {
            if isScanning {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)

                        Text(currentAction == .checkIn ? "Hold near the room tag to check in" : "Hold near the room tag to check out")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("Keep your phone steady against the NFC sticker until you feel a tap.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(24)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(20)
                }
            }
        }
    }

    private func beginScan(for action: AttendanceAction) {
        guard !isScanning else { return }

#if targetEnvironment(simulator)
        alertTitle = "NFC Not Available"
        alertMessage = "NFC scanning requires a physical iOS device."
        showAlert = true
        return
#endif

        isScanning = true
        currentAction = action

        nfcReader.beginScan { result in
            DispatchQueue.main.async {
                self.isScanning = false

                switch result {
                case .success(let tagId):
                    Task {
                        if action == .checkIn {
                            await checkInOutManager.checkInWithNFC(nfcTagId: tagId)
                        } else {
                            await checkInOutManager.checkOutWithNFC(nfcTagId: tagId)
                        }
                    }

                case .failure(let error):
                    guard let readerError = error as? AttendanceNFCError else {
                        alertTitle = "NFC Error"
                        alertMessage = error.localizedDescription
                        showAlert = true
                        return
                    }

                    switch readerError {
                    case .cancelled:
                        break
                    default:
                        alertTitle = "NFC Error"
                        alertMessage = readerError.localizedDescription ?? "Unable to read tag. Please try again."
                        showAlert = true
                    }
                }
            }
        }
    }
}

// MARK: - NFC Reader Helper

private enum AttendanceNFCError: Error {
    case notSupported
    case invalidPayload
    case cancelled
    case system(Error)
}

extension AttendanceNFCError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "NFC is not available on this device."
        case .invalidPayload:
            return "This NFC tag is not registered with PGEase."
        case .cancelled:
            return "Scan cancelled."
        case .system(let error):
            return error.localizedDescription
        }
    }
}

@MainActor
private final class AttendanceNFCReader: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    private var session: NFCNDEFReaderSession?
    private var completion: ((Result<String, Error>) -> Void)?
    private var didCompleteSuccessfully = false

    func beginScan(completion: @escaping (Result<String, Error>) -> Void) {
        guard NFCNDEFReaderSession.readingAvailable else {
            completion(.failure(AttendanceNFCError.notSupported))
            return
        }

        self.completion = completion
        didCompleteSuccessfully = false

        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "Hold your iPhone near the room's NFC tag"
        session?.begin()
    }

    // MARK: NFCNDEFReaderSessionDelegate

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let message = messages.first,
              let record = message.records.first,
              let tagId = extractTagId(from: record) else {
            complete(with: .failure(AttendanceNFCError.invalidPayload))
            session.invalidate(errorMessage: "Unsupported NFC tag")
            return
        }

        didCompleteSuccessfully = true
        session.alertMessage = "Tag detected! Processing attendance..."
        session.invalidate()
        complete(with: .success(tagId))
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        guard !didCompleteSuccessfully else { return }

        if let nfcError = error as? NFCReaderError,
           nfcError.code == .readerSessionInvalidationErrorUserCanceled {
            complete(with: .failure(AttendanceNFCError.cancelled))
        } else {
            complete(with: .failure(AttendanceNFCError.system(error)))
        }
    }

    // MARK: Helpers

    private func complete(with result: Result<String, Error>) {
        completion?(result)
        completion = nil
        session = nil
    }

    private func extractTagId(from record: NFCNDEFPayload) -> String? {
        let uriString: String?

        switch record.typeNameFormat {
        case .nfcWellKnown:
            if let type = String(data: record.type, encoding: .utf8), type == "U" {
                uriString = parseURIRecord(record)
            } else if let type = String(data: record.type, encoding: .utf8), type == "T" {
                uriString = parseTextRecord(record)
            } else {
                uriString = String(data: record.payload, encoding: .utf8)
            }
        case .absoluteURI, .media:
            uriString = String(data: record.payload, encoding: .utf8)
        default:
            uriString = String(data: record.payload, encoding: .utf8)
        }

        if let value = uriString, let normalized = normalizedTagId(from: value) {
            return normalized
        }

        if let rawString = String(data: record.payload, encoding: .utf8), let normalized = normalizedTagId(from: rawString) {
            return normalized
        }

        return nil
    }

    private func normalizedTagId(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        if lowercased.hasPrefix("pgease://tag/") {
            return String(trimmed.dropFirst("pgease://tag/".count))
        }

        if lowercased.hasPrefix("gease://tag/") {
            // Some tags drop the leading 'p' when read back; compensate here.
            return String(trimmed.dropFirst("gease://tag/".count))
        }

        if let range = lowercased.range(of: "://tag/") {
            let dropCount = trimmed.distance(from: trimmed.startIndex, to: range.upperBound)
            return String(trimmed.dropFirst(dropCount))
        }

        return nil
    }

    private func parseURIRecord(_ payload: NFCNDEFPayload) -> String? {
        guard payload.payload.count > 0 else { return nil }

        let prefixes = [
            "",
            "http://www.",
            "https://www.",
            "http://",
            "https://",
            "tel:",
            "mailto:",
            "ftp://anonymous:anonymous@",
            "ftp://ftp.",
            "ftps://",
            "sftp://",
            "smb://",
            "nfs://",
            "ftp://",
            "dav://",
            "news:",
            "telnet://",
            "imap:",
            "rtsp://",
            "urn:",
            "pop:",
            "sip:",
            "sips:",
            "tftp:",
            "btspp://",
            "btl2cap://",
            "btgoep://",
            "tcpobex://",
            "irdaobex://",
            "file://",
            "urn:epc:id:",
            "urn:epc:tag:",
            "urn:epc:pat:",
            "urn:epc:raw:",
            "urn:epc:",
            "urn:nfc:"
        ]

        let identifierCode = Int(payload.payload[0])
        let prefix = identifierCode < prefixes.count ? prefixes[identifierCode] : ""
        let uriData = payload.payload.subdata(in: 1..<payload.payload.count)
        let rest = String(data: uriData, encoding: .utf8) ?? ""
        return prefix + rest
    }

    private func parseTextRecord(_ payload: NFCNDEFPayload) -> String? {
        guard payload.payload.count > 0 else { return nil }

        let statusByte = payload.payload[0]
        let isUTF16 = (statusByte & 0x80) != 0
        let languageCodeLength = Int(statusByte & 0x3F)

        guard payload.payload.count > languageCodeLength + 1 else {
            return String(data: payload.payload, encoding: .utf8)
        }

        let textStartIndex = 1 + languageCodeLength
        let textData = payload.payload.subdata(in: textStartIndex..<payload.payload.count)
        let encoding: String.Encoding = isUTF16 ? .utf16 : .utf8
        return String(data: textData, encoding: encoding) ?? String(data: textData, encoding: .utf8)
    }
}


