# PGEase iOS - Quick Reference Card

**For iOS Developers** 🍎

---

## 🎯 **Quick Links**

| Document                                                                      | Purpose                       |
| ----------------------------------------------------------------------------- | ----------------------------- |
| [IOS_IMPLEMENTATION_GUIDE.md](./IOS_IMPLEMENTATION_GUIDE.md)                  | Complete implementation guide |
| [README.md](./README.md)                                                      | Project overview              |
| [BIOMETRIC_VERIFICATION_FLOW.md](../../pgease/BIOMETRIC_VERIFICATION_FLOW.md) | Biometric flow details        |

---

## 🔧 **Critical Changes Needed**

### **1. APIManager.swift - Add Staff APIs**

```swift
// ⚠️ ADD THESE METHODS

// Staff onboarding
func linkStaffDevice(inviteCode: String, deviceId: String) async throws -> LinkStaffDeviceResponse
func setupStaffBiometric(staffId: String, biometricData: BiometricData, deviceId: String) async throws -> BiometricSetupResponse
func getStaffBiometricStatus(staffId: String) async throws -> BiometricStatusResponse

// Deboarding
func deboardStudent(studentId: String, deboardDate: String, reason: String?) async throws -> DeboardResponse
func deboardStaff(staffId: String, terminationDate: String, reason: String?) async throws -> DeboardResponse

// Updated check-in/out
func checkIn(userType: String, userId: String, ...) async throws -> CheckInOutResponse
func checkOut(userType: String, userId: String, ...) async throws -> CheckInOutResponse
```

### **2. CheckInOutManager.swift - Add UserType**

```swift
// ⚠️ ADD THESE PROPERTIES
@Published var userType: String = "STUDENT"  // or "STAFF"
@Published var userId: String?

// ⚠️ UPDATE METHODS
func checkIn(method: CheckInMethod, nfcTagId: String? = nil) async {
    // Use userType and userId instead of hardcoded studentId
    let response = try await apiManager.checkIn(
        userType: userType,
        userId: userId,
        method: method,
        ...
    )
}
```

### **3. OnboardingManager.swift - Add Staff Support**

```swift
// ⚠️ ADD THESE PROPERTIES
@Published var userType: UserType = .student
@Published var staffInfo: StaffInfo?

// ⚠️ UPDATE METHODS
func linkDevice() async {
    if userType == .student {
        // Call student API
        let response = try await apiManager.linkDevice(...)
    } else {
        // Call staff API
        let response = try await apiManager.linkStaffDevice(...)
    }
}
```

### **4. Create New Files**

```swift
// ⚠️ CREATE THESE FILES

// AuthManager.swift - Role detection and auth state
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userRole: UserRole = .none
    @Published var userType: UserType = .student

    func checkAuthStatus() { ... }
    func logout() { ... }
}

// LoginView.swift - Initial login screen
struct LoginView: View {
    // "I'm a Student" button
    // "I'm a Staff Member" button
}

// DeboardingView.swift - Permanent checkout
struct DeboardingView: View {
    // Deboard form with reason and date
    // Biometric authentication
    // API call to deboard endpoint
}
```

---

## 📡 **API Endpoints Quick Reference**

### **Student APIs**

| Endpoint                                        | Method | Purpose                      |
| ----------------------------------------------- | ------ | ---------------------------- |
| `/api/onboarding/link-device`                   | POST   | Link device with invite code |
| `/api/onboarding/biometric-setup`               | POST   | Setup biometric auth         |
| `/api/onboarding/biometric-setup?studentId=...` | GET    | Check onboarding status      |
| `/api/student/deboard`                          | POST   | Permanent checkout           |

### **Staff APIs**

| Endpoint                                            | Method | Purpose                      |
| --------------------------------------------------- | ------ | ---------------------------- |
| `/api/staff/onboarding/link-device`                 | POST   | Link device with invite code |
| `/api/staff/onboarding/biometric-setup`             | POST   | Setup biometric auth         |
| `/api/staff/onboarding/biometric-setup?staffId=...` | GET    | Check onboarding status      |
| `/api/staff/deboard`                                | POST   | Staff termination            |

### **Check-In/Out APIs**

| Endpoint                     | Method | Body Parameters                                                              |
| ---------------------------- | ------ | ---------------------------------------------------------------------------- |
| `/api/check-in-out/checkin`  | POST   | `userType`, `studentId`/`staffId`, `method`, `biometricVerified`, `location` |
| `/api/check-in-out/checkout` | POST   | Same as check-in                                                             |

---

## 🔄 **Flow Diagrams**

### **Student Onboarding**

```
Welcome → Enter Code → Link Device → Setup Biometric → Wait Approval → Complete
```

### **Staff Onboarding**

```
Welcome → Enter Code → Link Device → Setup Biometric → Wait Approval → Complete
(Same flow, different API endpoints)
```

### **Check-In**

```
Tap Check-In → Biometric Auth → Verify Signature → Record Check-In → Success
```

### **Deboarding**

```
Profile → Leave PG → Confirm → Biometric Auth → API Call → Clear Data → Welcome
```

---

## 🧪 **Testing Checklist**

### **Student Flow**

- [ ] Onboarding with invite code
- [ ] Biometric setup
- [ ] Manager approval
- [ ] Daily check-in
- [ ] Daily check-out
- [ ] Deboarding

### **Staff Flow**

- [ ] Onboarding with invite code
- [ ] Biometric setup
- [ ] Manager approval
- [ ] Daily check-in
- [ ] Daily check-out
- [ ] Termination

### **Edge Cases**

- [ ] Invalid invite code
- [ ] Expired invite code
- [ ] Biometric authentication failure
- [ ] Network errors
- [ ] Offline mode

---

## 🔐 **Security Notes**

### **Biometric Template**

- Generated on device during enrollment
- Sent to server for storage
- Used for verification on each check-in
- Format: `SIG_<deviceHash>_<studentHash>_<enrollmentHash>_<biometricHash>`

### **Device Binding**

- Each device has unique UUID
- Stored in UserDefaults
- Tied to biometric template
- Prevents device sharing

### **UserDefaults Keys**

```swift
// Student
"studentId"              // Student UUID
"userType"               // "STUDENT"
"deviceId"               // Device UUID
"onboardingComplete"     // Bool
"biometricSetupComplete" // Bool

// Staff
"staffId"                // Staff UUID
"userType"               // "STAFF"
"deviceId"               // Device UUID
"onboardingComplete"     // Bool
"biometricSetupComplete" // Bool
```

---

## 🐛 **Common Issues**

### **Issue: Biometric not working**

**Solution:** Check device capabilities and permissions

```swift
// Check biometric availability
BiometricAuthManager().checkBiometricAvailability()
```

### **Issue: API calls failing**

**Solution:** Check base URL and network connection

```swift
// Verify base URL in APIManager.swift
private let baseURL = "https://pg-ease.vercel.app/api"
```

### **Issue: Onboarding stuck at "Waiting for Approval"**

**Solution:** Manager needs to approve in web app

```
Web App → Students → Pending Approvals → Approve
```

---

## 📱 **Device Requirements**

| Feature         | Requirement             |
| --------------- | ----------------------- |
| **Minimum iOS** | 14.0+                   |
| **Biometric**   | Face ID or Touch ID     |
| **Location**    | Optional (for check-in) |
| **NFC**         | Optional (for NFC tags) |
| **Camera**      | Optional (for QR codes) |

---

## 🚀 **Deployment Checklist**

- [ ] Update base URL for production
- [ ] Configure app signing
- [ ] Add privacy descriptions in Info.plist:
  - [ ] Face ID usage description
  - [ ] Location usage description
  - [ ] Camera usage description
  - [ ] NFC usage description
- [ ] Test on physical device
- [ ] Submit to App Store

---

## 📞 **Quick Help**

| Problem         | Solution                          |
| --------------- | --------------------------------- |
| Can't onboard   | Check invite code validity        |
| Biometric fails | Ensure Face ID/Touch ID is set up |
| Can't check-in  | Verify onboarding is complete     |
| API errors      | Check network and base URL        |
| App crashes     | Check Xcode console for errors    |

---

## 🔗 **Useful Links**

- Backend API: https://pg-ease.vercel.app/api
- Web App: https://pg-ease.vercel.app
- Documentation: [IOS_IMPLEMENTATION_GUIDE.md](./IOS_IMPLEMENTATION_GUIDE.md)

---

**Last Updated:** October 13, 2025  
**Version:** 1.0
