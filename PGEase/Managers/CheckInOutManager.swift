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
    
    private let apiManager = APIManager.shared
    private let locationManager = CLLocationManager()
    private let biometricAuthManager = BiometricAuthManager()
    
    override init() {
        super.init()
        setupLocationManager()
        loadCheckInStatus()
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
            // Authenticate with biometrics first
            let biometricSuccess = await biometricAuthManager.authenticateUser(
                reason: "Authenticate for check-in"
            )
            
            guard biometricSuccess else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Biometric authentication failed"
                }
                return
            }
            
            guard let userId = getCurrentUserId() else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "User ID not found"
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
                userId: userId,
                method: method,
                nfcTagId: nfcTagId,
                location: locationData,
                biometricVerified: true,
                deviceId: deviceId
            )
            
            await MainActor.run {
                self.isCheckedIn = true
                self.lastCheckInTime = Date()
                self.isLoading = false
                self.saveCheckInStatus()
            }
            
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
            // Authenticate with biometrics first
            let biometricSuccess = await biometricAuthManager.authenticateUser(
                reason: "Authenticate for check-out"
            )
            
            guard biometricSuccess else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Biometric authentication failed"
                }
                return
            }
            
            guard let userId = getCurrentUserId() else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "User ID not found"
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
                userId: userId,
                method: method,
                nfcTagId: nfcTagId,
                location: locationData,
                biometricVerified: true,
                deviceId: deviceId
            )
            
            await MainActor.run {
                self.isCheckedIn = false
                self.lastCheckOutTime = Date()
                self.isLoading = false
                self.saveCheckInStatus()
            }
            
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
                await checkIn(method: .manualManager, biometricVerified: true)
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
                await checkOut(method: .manualManager, biometricVerified: true)
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
    
    private func getCurrentUserId() -> String? {
        // Return appropriate ID based on userType
        if userType == "STUDENT" {
            return UserDefaults.standard.string(forKey: "studentId")
        } else if userType == "STAFF" {
            return UserDefaults.standard.string(forKey: "staffId")
        }
        return userId
    }
    
    private func saveCheckInStatus() {
        UserDefaults.standard.set(isCheckedIn, forKey: "isCheckedIn")
        if let checkInTime = lastCheckInTime {
            UserDefaults.standard.set(checkInTime, forKey: "lastCheckInTime")
        }
        if let checkOutTime = lastCheckOutTime {
            UserDefaults.standard.set(checkOutTime, forKey: "lastCheckOutTime")
        }
    }
    
    private func loadCheckInStatus() {
        isCheckedIn = UserDefaults.standard.bool(forKey: "isCheckedIn")
        lastCheckInTime = UserDefaults.standard.object(forKey: "lastCheckInTime") as? Date
        lastCheckOutTime = UserDefaults.standard.object(forKey: "lastCheckOutTime") as? Date
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
