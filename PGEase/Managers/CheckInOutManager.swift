import Foundation
import SwiftUI
import CoreLocation

class CheckInOutManager: NSObject, ObservableObject {
    @Published var isCheckedIn = false
    @Published var lastCheckInTime: Date?
    @Published var lastCheckOutTime: Date?
    @Published var currentLocation: CLLocation?
    @Published var isLocationEnabled = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    // User type and ID for multi-role support
    @Published var userType: String = "STUDENT" // "STUDENT" or "STAFF"
    @Published var userId: String?
    @Published var profileId: String?
    
    private let apiManager = APIManager.shared
    private let locationManager = CLLocationManager()
    private let biometricAuthManager = BiometricAuthManager()
    private let webAuthnManager = WebAuthnManager()
    private let onboardingManager = OnboardingManager()
    
    override init() {
        super.init()
        setupLocationManager()
        
        // Load identifiers from stored state
        if let storedUserId = UserDefaults.standard.string(forKey: "userId") {
            self.userId = storedUserId
        }

        if let storedProfileId = UserDefaults.standard.string(forKey: "profileId"), !storedProfileId.isEmpty {
            self.profileId = storedProfileId
        } 
        
        // else if let storedStudentId = UserDefaults.standard.string(forKey: "studentId"), !storedStudentId.isEmpty {
        //     self.profileId = storedStudentId
        // } else if let storedStaffId = UserDefaults.standard.string(forKey: "staffId"), !storedStaffId.isEmpty {
        //     self.profileId = storedStaffId
        // }
    }
    
    // MARK: - Location Management
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "Location services are disabled"
            return
        }
        
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            isLocationEnabled = true
        case .denied, .restricted:
            errorMessage = "Location access denied"
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            errorMessage = "Unknown location authorization status"
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Check-In/Out Operations
    
    func checkIn(method: CheckInMethod, nfcTagId: String? = nil) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            guard let accountUserId = getAccountUserId() else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "User ID not found"
                }
                return
            }
            
            let profileId = getCurrentProfileId() ?? accountUserId

            // ✅ Authenticate with WebAuthn (Face ID/Touch ID)
            guard let credentialId = await webAuthnManager.authenticate(userId: accountUserId) else {
                await MainActor.run {
                    self.isLoading = false
                    if let webAuthnError = webAuthnManager.errorMessage, !webAuthnError.isEmpty {
                        self.errorMessage = webAuthnError
                    } else {
                        self.errorMessage = "Biometric authentication failed. Please ensure passkey setup is complete."
                    }
                }
                return
            }
            
            let locationData = currentLocation != nil ? LocationData(
                latitude: currentLocation!.coordinate.latitude,
                longitude: currentLocation!.coordinate.longitude,
                accuracy: currentLocation!.horizontalAccuracy
            ) : nil
            
            let deviceId = UserDefaults.standard.string(forKey: "deviceId")
            
            let response = try await apiManager.checkIn(
                userType: userType,
                userId: accountUserId,
                profileId: profileId,
                method: method,
                nfcTagId: nfcTagId,
                webAuthnCredentialId: credentialId, // ✅ NEW: WebAuthn proof
                location: locationData,
                biometricVerified: true,
                deviceId: deviceId
            )
            
            await MainActor.run {
                self.isCheckedIn = true
                self.lastCheckInTime = Date()
                self.isLoading = false
            }
            
            // Refresh status from database to ensure sync
            await refreshCheckInStatus()
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func checkOut(method: CheckInMethod, nfcTagId: String? = nil) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            guard let accountUserId = getAccountUserId() else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "User ID not found"
                }
                return
            }
            
            let profileId = getCurrentProfileId() ?? accountUserId

            // ✅ Authenticate with WebAuthn (Face ID/Touch ID) - SAME as check-in
            guard let credentialId = await webAuthnManager.authenticate(userId: accountUserId) else {
                await MainActor.run {
                    self.isLoading = false
                    if let webAuthnError = webAuthnManager.errorMessage, !webAuthnError.isEmpty {
                        self.errorMessage = webAuthnError
                    } else {
                        self.errorMessage = "Biometric authentication failed. Please ensure passkey setup is complete."
                    }
                }
                return
            }
            
            let locationData = currentLocation != nil ? LocationData(
                latitude: currentLocation!.coordinate.latitude,
                longitude: currentLocation!.coordinate.longitude,
                accuracy: currentLocation!.horizontalAccuracy
            ) : nil
            
            let deviceId = UserDefaults.standard.string(forKey: "deviceId")
            
            let response = try await apiManager.checkOut(
                userType: userType,
                userId: accountUserId,
                profileId: profileId,
                method: method,
                nfcTagId: nfcTagId,
                webAuthnCredentialId: credentialId, // ✅ NEW: WebAuthn proof
                location: locationData,
                biometricVerified: true,
                deviceId: deviceId
            )
            
            await MainActor.run {
                self.isCheckedIn = false
                self.lastCheckOutTime = Date()
                self.isLoading = false
            }
            
            // Refresh status from database to ensure sync
            await refreshCheckInStatus()
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - NFC Check-In/Out
    
    func checkInWithNFC(nfcTagId: String) async {
        await checkIn(method: .nfcTag, nfcTagId: nfcTagId)
    }
    
    func checkOutWithNFC(nfcTagId: String) async {
        await checkOut(method: .nfcTag, nfcTagId: nfcTagId)
    }
    
    // MARK: - QR Code Check-In/Out
    
    func checkInWithQR() async {
        await checkIn(method: .qrCode)
    }
    
    func checkOutWithQR() async {
        await checkOut(method: .qrCode)
    }
    
    // MARK: - Biometric Check-In/Out
    
    func checkInWithBiometric(studentId: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // First authenticate with local biometrics
            let authSuccess = await biometricAuthManager.authenticateUser(
                reason: "Authenticate to check in"
            )
            
            guard authSuccess else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Biometric authentication failed"
                }
                return
            }
            
            // Get current location
            let locationData = currentLocation != nil ? LocationData(
                latitude: currentLocation!.coordinate.latitude,
                longitude: currentLocation!.coordinate.longitude,
                accuracy: currentLocation!.horizontalAccuracy
            ) : nil
            
            // Perform server-side biometric verification
            let (isVerified, confidence, error) = await onboardingManager.verifyBiometricIdentity(
                studentId: studentId,
                location: locationData
            )
            
            if isVerified {
                // Proceed with check-in using biometric verification
                await checkIn(method: .manualManager)
            } else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error ?? "Biometric verification failed (Confidence: \(String(format: "%.1f", confidence))%)"
                }
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func checkOutWithBiometric(studentId: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // First authenticate with local biometrics
            let authSuccess = await biometricAuthManager.authenticateUser(
                reason: "Authenticate to check out"
            )
            
            guard authSuccess else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Biometric authentication failed"
                }
                return
            }
            
            // Get current location
            let locationData = currentLocation != nil ? LocationData(
                latitude: currentLocation!.coordinate.latitude,
                longitude: currentLocation!.coordinate.longitude,
                accuracy: currentLocation!.horizontalAccuracy
            ) : nil
            
            // Perform server-side biometric verification
            let (isVerified, confidence, error) = await onboardingManager.verifyBiometricIdentity(
                studentId: studentId,
                location: locationData
            )
            
            if isVerified {
                // Proceed with check-out using biometric verification
                await checkOut(method: .manualManager)
            } else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error ?? "Biometric verification failed (Confidence: \(String(format: "%.1f", confidence))%)"
                }
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Geofencing Check-In/Out (Auto)
    
    func handleGeofenceEntry() async {
        // Auto check-in when entering PG area
        await checkIn(method: .geofenceAuto)
    }
    
    func handleGeofenceExit() async {
        // Auto check-out when leaving PG area
        await checkOut(method: .geofenceAuto)
    }
    
    // MARK: - Helper Methods
    
    private func getAccountUserId() -> String? {
        if let overrideId = userId, !overrideId.isEmpty {
            return overrideId
        }

        if let universalId = UserDefaults.standard.string(forKey: "userId"), !universalId.isEmpty {
            return universalId
        }

        return nil
    }

    private func getCurrentProfileId() -> String? {
        if let overrideProfileId = profileId, !overrideProfileId.isEmpty {
            return overrideProfileId
        }

        if let storedProfileId = UserDefaults.standard.string(forKey: "profileId"), !storedProfileId.isEmpty {
            return storedProfileId
        }

        // if userType == "STUDENT" {
        //     if let storedStudentId = UserDefaults.standard.string(forKey: "studentId"), !storedStudentId.isEmpty {
        //         return storedStudentId
        //     }
        // } else if userType == "STAFF" {
        //     if let storedStaffId = UserDefaults.standard.string(forKey: "staffId"), !storedStaffId.isEmpty {
        //         return storedStaffId
        //     }
        // }

        return nil
    }
    
    // MARK: - Status Refresh from Database
    
    /// Refresh check-in/out status from database (single source of truth)
    func refreshCheckInStatus() async {
        guard let accountUserId = getAccountUserId() else {
            print("⚠️ [CheckInOutManager] Cannot refresh status - userId not available")
            return
        }
        
        do {
            let response = try await apiManager.getLatestCheckInOut(
                userId: accountUserId,
                userType: userType
            )
            
            await MainActor.run {
                if let latestLog = response.data {
                    // Determine status based on latest log type
                    self.isCheckedIn = latestLog.type == "CHECK_IN"
                    
                    // Parse timestamp
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    
                    if let timestamp = formatter.date(from: latestLog.timestamp) {
                        if latestLog.type == "CHECK_IN" {
                            self.lastCheckInTime = timestamp
                        } else {
                            self.lastCheckOutTime = timestamp
                        }
                    }
                    
                    print("✅ [CheckInOutManager] Status refreshed from database: \(latestLog.type) at \(latestLog.timestamp)")
                } else {
                    // No logs found - default to checked out
                    self.isCheckedIn = false
                    self.lastCheckInTime = nil
                    self.lastCheckOutTime = nil
                    print("ℹ️ [CheckInOutManager] No check-in/out logs found - defaulting to checked out")
                }
            }
        } catch {
            print("❌ [CheckInOutManager] Failed to refresh status: \(error.localizedDescription)")
            // Fallback to UserDefaults if API fails (backward compatibility)
            await MainActor.run {
                self.isCheckedIn = UserDefaults.standard.bool(forKey: "isCheckedIn")
                self.lastCheckInTime = UserDefaults.standard.object(forKey: "lastCheckInTime") as? Date
                self.lastCheckOutTime = UserDefaults.standard.object(forKey: "lastCheckOutTime") as? Date
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var checkInStatusText: String {
        return isCheckedIn ? "Checked In" : "Checked Out"
    }
    
    var checkInStatusColor: Color {
        return isCheckedIn ? .green : .red
    }
    
    var lastActionText: String {
        if let checkInTime = lastCheckInTime, isCheckedIn {
            return "Checked in at \(formatTime(checkInTime))"
        } else if let checkOutTime = lastCheckOutTime, !isCheckedIn {
            return "Checked out at \(formatTime(checkOutTime))"
        } else {
            return "No recent activity"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - CLLocationManagerDelegate

extension CheckInOutManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Location error: \(error.localizedDescription)"
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isLocationEnabled = true
            startLocationUpdates()
        case .denied, .restricted:
            isLocationEnabled = false
            errorMessage = "Location access denied"
        case .notDetermined:
            isLocationEnabled = false
        @unknown default:
            isLocationEnabled = false
        }
    }
}
