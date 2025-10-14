# PGEase iOS Mobile App - Implementation Guide

**Date:** October 13, 2025  
**Target:** iOS (Swift/SwiftUI)  
**Current Status:** Basic structure exists, needs updates for unified multi-role architecture  
**Backend API:** https://pg-ease.vercel.app/api

---

## 📋 **Table of Contents**

1. [Current State Analysis](#current-state-analysis)
2. [Required Changes](#required-changes)
3. [API Integration Guide](#api-integration-guide)
4. [Onboarding Flow](#onboarding-flow)
5. [Check-In/Out Flow](#check-in-out-flow)
6. [Deboarding Flow](#deboarding-flow)
7. [Multi-Role Architecture](#multi-role-architecture)
8. [Implementation Checklist](#implementation-checklist)

---

## 🔍 **Current State Analysis**

### **Existing Files**

```
PGEase/
├── Managers/
│   ├── APIManager.swift              ✅ Exists (needs updates)
│   ├── BiometricAuthManager.swift    ✅ Exists (good)
│   ├── CheckInOutManager.swift       ✅ Exists (needs updates)
│   ├── OnboardingManager.swift       ✅ Exists (needs updates)
│   ├── NFCManager.swift              ✅ Exists
│   └── ...
├── Views/
│   ├── OnboardingView.swift          ✅ Exists (good)
│   ├── MainTabView.swift             ✅ Exists (needs role-based tabs)
│   ├── LoginView.swift               ⚠️ Needs creation
│   └── ...
└── Models/
    └── ScanResult.swift              ✅ Exists
```

### **What Works**

✅ **OnboardingManager**: Good structure for student onboarding  
✅ **BiometricAuthManager**: Solid biometric authentication  
✅ **CheckInOutManager**: Basic check-in/out logic  
✅ **APIManager**: API structure exists  
✅ **OnboardingView**: UI for onboarding flow

### **What Needs Updates**

⚠️ **APIManager**: Missing staff APIs, needs userType parameter  
⚠️ **CheckInOutManager**: Hardcoded for students only  
⚠️ **OnboardingManager**: Student-only, needs staff support  
⚠️ **MainTabView**: No role-based navigation  
⚠️ **LoginView**: Doesn't exist yet  
⚠️ **No Deboarding**: No UI/logic for permanent checkout

---

## 🔧 **Required Changes**

### **Priority 1: Critical Updates**

1. **Add User Type Support**

   - Update all managers to support `userType` (STUDENT/STAFF)
   - Update API calls to use correct endpoints

2. **Create Login Flow**

   - Add LoginView for role detection
   - Store user role in UserDefaults
   - Route to correct onboarding flow

3. **Update Check-In/Out APIs**

   - Add `userType` parameter
   - Support both `/api/check-in-out/checkin` for students and staff

4. **Add Deboarding Support**
   - Create DeboaringView
   - Add API call to `/api/student/deboard` or `/api/staff/deboard`

### **Priority 2: Multi-Role Support**

5. **Role-Based Navigation**

   - Update MainTabView to show role-specific tabs
   - Create role-specific dashboards

6. **Staff Onboarding**
   - Add staff-specific onboarding flow
   - Use `/api/staff/onboarding/*` endpoints

---

## 🔌 **API Integration Guide**

### **Base Configuration**

```swift
// APIManager.swift - Update base URL (already correct)
private let baseURL = "https://pg-ease.vercel.app/api"
```

### **1. Student Onboarding APIs**

#### **1.1 Generate Invite (Manager → Web Only)**

```
POST /api/onboarding/generate-invite
Body: {
  "studentId": "student123",
  "expiresInDays": 7
}
Response: {
  "success": true,
  "data": {
    "inviteCode": "ABC123",
    "qrCode": "data:image/png;base64,...",
    "deepLink": "pgease://onboard?code=ABC123",
    "expiresAt": "2025-10-20T10:00:00Z"
  }
}
```

#### **1.2 Link Device (Student → Mobile)**

```swift
// Current: ✅ Already implemented in APIManager
func linkDevice(inviteCode: String, deviceId: String) async throws -> LinkDeviceResponse

// API Call
POST /api/onboarding/link-device
Body: {
  "inviteCode": "ABC123",
  "deviceId": "device-uuid-123"
}
Response: {
  "success": true,
  "data": {
    "student": {
      "id": "student123",
      "name": "John Doe",
      "email": "john@example.com",
      "phoneNumber": "+1234567890",
      "room": { "id": "room1", "number": "101", "type": "SINGLE" },
      "pg": { "id": "pg1", "name": "Sunrise PG", "address": "123 Main St" }
    },
    "deviceId": "device-uuid-123",
    "linkedAt": "2025-10-13T10:00:00Z",
    "accessStatus": "PENDING_BIOMETRIC"
  }
}
```

#### **1.3 Setup Biometric (Student → Mobile)**

```swift
// Current: ✅ Already implemented in APIManager
func setupBiometric(
  studentId: String,
  biometricData: BiometricData,
  deviceId: String
) async throws -> BiometricSetupResponse

// API Call
POST /api/onboarding/biometric-setup
Body: {
  "studentId": "student123",
  "biometricData": {
    "method": "Face ID",
    "template": "SIG_A1B2C3D4_...",
    "metadata": {
      "quality": 95,
      "attempts": 1
    }
  },
  "deviceId": "device-uuid-123"
}
Response: {
  "success": true,
  "data": {
    "student": {...},
    "biometric": {
      "enabled": true,
      "method": "Face ID",
      "setupAt": "2025-10-13T10:05:00Z"
    },
    "accessStatus": "PENDING_APPROVAL",
    "nextStep": "WAIT_FOR_APPROVAL"
  }
}
```

#### **1.4 Check Onboarding Status (Student → Mobile)**

```swift
// Current: ✅ Already implemented in APIManager
func getBiometricStatus(studentId: String) async throws -> BiometricStatusResponse

// API Call
GET /api/onboarding/biometric-setup?studentId=student123
Response: {
  "success": true,
  "data": {
    "biometricEnabled": true,
    "biometricMethod": "Face ID",
    "biometricSetupAt": "2025-10-13T10:05:00Z",
    "accessStatus": "ACTIVE"  // or "PENDING_APPROVAL"
  }
}
```

---

### **2. Staff Onboarding APIs**

#### **2.1 Generate Staff Invite (Manager → Web Only)**

```
POST /api/staff/onboarding/generate-invite
Body: {
  "staffId": "staff123",
  "expiresInDays": 7
}
Response: {
  "success": true,
  "data": {
    "inviteCode": "XYZ789",
    "qrCode": "data:image/png;base64,...",
    "deepLink": "pgease://onboard-staff?code=XYZ789",
    "expiresAt": "2025-10-20T10:00:00Z"
  }
}
```

#### **2.2 Link Device (Staff → Mobile)**

```swift
// ⚠️ NEEDS TO BE ADDED to APIManager
func linkStaffDevice(inviteCode: String, deviceId: String) async throws -> LinkStaffDeviceResponse

// API Call
POST /api/staff/onboarding/link-device
Body: {
  "inviteCode": "XYZ789",
  "deviceId": "device-uuid-456"
}
Response: {
  "success": true,
  "data": {
    "staff": {
      "id": "staff123",
      "name": "Jane Smith",
      "email": "jane@example.com",
      "phoneNumber": "+1234567890",
      "role": "CLEANING_STAFF",
      "pg": { "id": "pg1", "name": "Sunrise PG" }
    },
    "deviceId": "device-uuid-456",
    "linkedAt": "2025-10-13T10:00:00Z",
    "accessStatus": "PENDING_BIOMETRIC"
  }
}
```

#### **2.3 Setup Biometric (Staff → Mobile)**

```swift
// ⚠️ NEEDS TO BE ADDED to APIManager
func setupStaffBiometric(
  staffId: String,
  biometricData: BiometricData,
  deviceId: String
) async throws -> BiometricSetupResponse

// API Call
POST /api/staff/onboarding/biometric-setup
Body: {
  "staffId": "staff123",
  "biometricData": {
    "method": "Face ID",
    "template": "SIG_X7Y8Z9A1_...",
    "metadata": {
      "quality": 92,
      "attempts": 1
    }
  },
  "deviceId": "device-uuid-456"
}
Response: {
  "success": true,
  "data": {
    "staff": {...},
    "biometric": {
      "enabled": true,
      "method": "Face ID",
      "setupAt": "2025-10-13T10:05:00Z"
    },
    "accessStatus": "PENDING_APPROVAL",
    "nextStep": "WAIT_FOR_APPROVAL"
  }
}
```

---

### **3. Check-In/Out APIs (Students & Staff)**

#### **3.1 Check-In (Daily Attendance)**

```swift
// Current: ⚠️ Needs userType parameter
func checkIn(
  userType: String,        // ⚠️ ADD THIS: "STUDENT" or "STAFF"
  userId: String,          // ⚠️ RENAME from studentId
  method: CheckInMethod,
  nfcTagId: String? = nil,
  location: LocationData? = nil,
  biometricVerified: Bool = false
) async throws -> CheckInOutResponse

// API Call
POST /api/check-in-out/checkin
Body: {
  "userType": "STUDENT",              // ⚠️ ADD THIS
  "studentId": "student123",          // For students
  // OR
  "staffId": "staff123",              // For staff

  "method": "MANUAL_MANAGER",
  "biometricVerified": true,
  "location": {
    "latitude": 12.9716,
    "longitude": 77.5946,
    "accuracy": 5.0
  }
}
Response: {
  "success": true,
  "data": {
    "studentId": "student123",        // or "staffId"
    "type": "CHECK_IN",
    "method": "MANUAL_MANAGER",
    "timestamp": "2025-10-13T10:00:00Z",
    "location": {...}
  },
  "message": "Check-in successful"
}
```

#### **3.2 Check-Out (Daily Attendance)**

```swift
// Current: ⚠️ Needs userType parameter
func checkOut(
  userType: String,        // ⚠️ ADD THIS: "STUDENT" or "STAFF"
  userId: String,          // ⚠️ RENAME from studentId
  method: CheckInMethod,
  nfcTagId: String? = nil,
  location: LocationData? = nil,
  biometricVerified: Bool = false
) async throws -> CheckInOutResponse

// API Call
POST /api/check-in-out/checkout
Body: {
  "userType": "STUDENT",              // ⚠️ ADD THIS
  "studentId": "student123",          // For students
  // OR
  "staffId": "staff123",              // For staff

  "method": "MANUAL_MANAGER",
  "biometricVerified": true,
  "location": {...}
}
Response: {
  "success": true,
  "data": {
    "studentId": "student123",
    "type": "CHECK_OUT",
    "method": "MANUAL_MANAGER",
    "timestamp": "2025-10-13T18:00:00Z",
    "location": {...}
  },
  "message": "Check-out successful"
}
```

---

### **4. Deboarding APIs (Permanent Checkout)**

#### **4.1 Student Deboard**

```swift
// ⚠️ NEEDS TO BE ADDED to APIManager
func deboardStudent(
  studentId: String,
  deboardDate: Date,
  reason: String?
) async throws -> DeboardResponse

// API Call
POST /api/student/deboard
Body: {
  "studentId": "student123",
  "deboardDate": "2025-10-13",
  "reason": "Course completed"
}
Response: {
  "success": true,
  "message": "Student deboarded successfully",
  "data": {
    "studentId": "student123",
    "deboardedAt": "2025-10-13T10:00:00Z",
    "historyRecordId": "history123"
  }
}
```

#### **4.2 Staff Deboard (Termination)**

```swift
// ⚠️ NEEDS TO BE ADDED to APIManager
func deboardStaff(
  staffId: String,
  terminationDate: Date,
  reason: String?
) async throws -> DeboardResponse

// API Call
POST /api/staff/deboard
Body: {
  "staffId": "staff123",
  "terminationDate": "2025-10-13",
  "reason": "Resigned"
}
Response: {
  "success": true,
  "message": "Staff deboarded successfully",
  "data": {
    "staffId": "staff123",
    "terminatedAt": "2025-10-13T10:00:00Z"
  }
}
```

---

## 🚀 **Onboarding Flow**

### **Student Onboarding (Current Implementation)**

```
┌─────────────────────────────────────────────────────────────┐
│                   STUDENT ONBOARDING FLOW                   │
└─────────────────────────────────────────────────────────────┘

1. WELCOME SCREEN
   ├─ User opens app
   ├─ Sees "Welcome to PGEase"
   └─ Taps "Get Started"

2. ENTER INVITE CODE
   ├─ User enters 6-digit code (from manager)
   ├─ App validates format
   └─ Taps "Continue"

3. LINK DEVICE
   ├─ App generates deviceId (UUID)
   ├─ Calls POST /api/onboarding/link-device
   ├─ Server validates invite code
   ├─ Server creates StudentProfile
   ├─ Server returns student info
   └─ Status: PENDING_BIOMETRIC

4. SETUP BIOMETRIC
   ├─ App shows "Setup Face ID/Touch ID"
   ├─ User authenticates with biometric
   ├─ App generates enrollment signature
   ├─ Calls POST /api/onboarding/biometric-setup
   ├─ Server stores biometric template
   └─ Status: PENDING_APPROVAL

5. WAITING FOR APPROVAL
   ├─ App shows "Waiting for manager approval"
   ├─ User can tap "Check Status"
   ├─ Calls GET /api/onboarding/biometric-setup?studentId=...
   └─ Polls until status = ACTIVE

6. ONBOARDING COMPLETE
   ├─ App shows "Onboarding Complete!"
   ├─ Saves onboardingComplete = true
   └─ Navigates to MainTabView
```

### **Staff Onboarding (Needs Implementation)**

```
┌─────────────────────────────────────────────────────────────┐
│                    STAFF ONBOARDING FLOW                    │
└─────────────────────────────────────────────────────────────┘

1. WELCOME SCREEN
   ├─ User opens app
   ├─ Sees "Welcome to PGEase"
   └─ Taps "I'm a Staff Member"

2. ENTER INVITE CODE
   ├─ User enters 6-digit code (from manager)
   ├─ App validates format
   └─ Taps "Continue"

3. LINK DEVICE
   ├─ App generates deviceId (UUID)
   ├─ Calls POST /api/staff/onboarding/link-device  ⚠️ STAFF ENDPOINT
   ├─ Server validates invite code
   ├─ Server creates StaffProfile
   ├─ Server returns staff info
   └─ Status: PENDING_BIOMETRIC

4. SETUP BIOMETRIC
   ├─ App shows "Setup Face ID/Touch ID"
   ├─ User authenticates with biometric
   ├─ App generates enrollment signature
   ├─ Calls POST /api/staff/onboarding/biometric-setup  ⚠️ STAFF ENDPOINT
   ├─ Server stores biometric template
   └─ Status: PENDING_APPROVAL

5. WAITING FOR APPROVAL
   ├─ App shows "Waiting for manager approval"
   ├─ User can tap "Check Status"
   ├─ Calls GET /api/staff/onboarding/biometric-setup?staffId=...
   └─ Polls until status = ACTIVE

6. ONBOARDING COMPLETE
   ├─ App shows "Onboarding Complete!"
   ├─ Saves onboardingComplete = true
   ├─ Saves userType = "STAFF"
   └─ Navigates to MainTabView (Staff Dashboard)
```

---

## ✅ **Check-In/Out Flow**

### **Daily Attendance (Students & Staff)**

```
┌─────────────────────────────────────────────────────────────┐
│                   DAILY CHECK-IN FLOW                       │
└─────────────────────────────────────────────────────────────┘

1. USER INITIATES CHECK-IN
   ├─ User taps "Check In" button
   └─ App shows biometric prompt

2. LOCAL BIOMETRIC AUTHENTICATION
   ├─ App calls BiometricAuthManager.authenticateUser()
   ├─ iOS shows Face ID/Touch ID prompt
   ├─ User authenticates
   └─ Returns success/failure

3. GENERATE VERIFICATION SIGNATURE
   ├─ App calls OnboardingManager.generateVerificationSignature()
   ├─ Creates signature based on:
   │   ├─ Device ID
   │   ├─ User ID (student/staff)
   │   ├─ Biometric type
   │   └─ Biometric hash
   └─ Returns signature string

4. SEND VERIFICATION REQUEST (Optional - for biometric verification)
   ├─ App calls APIManager.verifyBiometric()
   ├─ POST /api/biometric/verify
   ├─ Server compares with enrollment template
   ├─ Server returns confidence score
   └─ If confidence ≥ 85%, proceed

5. RECORD CHECK-IN
   ├─ App calls APIManager.checkIn()
   ├─ POST /api/check-in-out/checkin
   ├─ Body includes:
   │   ├─ userType: "STUDENT" or "STAFF"
   │   ├─ studentId or staffId
   │   ├─ method: "MANUAL_MANAGER"
   │   ├─ biometricVerified: true
   │   └─ location: { lat, lng, accuracy }
   └─ Server creates CheckInOutLog

6. UPDATE UI
   ├─ App shows "✅ Check-in successful!"
   ├─ Updates isCheckedIn = true
   ├─ Saves lastCheckInTime
   └─ Updates UI to show "Check Out" button

┌─────────────────────────────────────────────────────────────┐
│                   DAILY CHECK-OUT FLOW                      │
└─────────────────────────────────────────────────────────────┘

Same as check-in, but:
- POST /api/check-in-out/checkout
- Updates isCheckedIn = false
- Saves lastCheckOutTime
```

---

## 🚪 **Deboarding Flow**

### **Student Deboarding (Permanent Checkout)**

```
┌─────────────────────────────────────────────────────────────┐
│                  STUDENT DEBOARDING FLOW                    │
└─────────────────────────────────────────────────────────────┘

1. USER INITIATES DEBOARD
   ├─ User goes to Profile → Settings
   ├─ Taps "Leave PG" or "Deboard"
   └─ App shows confirmation dialog

2. CONFIRMATION DIALOG
   ├─ "Are you sure you want to leave this PG?"
   ├─ "This will permanently remove your access."
   ├─ Input: Reason (optional)
   ├─ Input: Deboard Date (default: today)
   └─ Buttons: "Cancel" | "Confirm Deboard"

3. BIOMETRIC AUTHENTICATION
   ├─ App calls BiometricAuthManager.authenticateUser()
   ├─ User authenticates with Face ID/Touch ID
   └─ Returns success/failure

4. SEND DEBOARD REQUEST
   ├─ App calls APIManager.deboardStudent()
   ├─ POST /api/student/deboard
   ├─ Body:
   │   ├─ studentId: "student123"
   │   ├─ deboardDate: "2025-10-13"
   │   └─ reason: "Course completed"
   └─ Server processes deboarding

5. SERVER ACTIONS
   ├─ Updates StudentProfile status to "INACTIVE"
   ├─ Moves data to StudentProfileHistory
   ├─ Archives CheckInOutLogs
   ├─ Deletes sensitive data (biometric template)
   └─ Returns success response

6. APP CLEANUP
   ├─ Clears UserDefaults:
   │   ├─ studentId
   │   ├─ onboardingComplete
   │   ├─ biometricSetupComplete
   │   └─ deviceId
   ├─ Shows "Deboarding successful" message
   └─ Navigates back to Welcome screen

7. USER SEES CONFIRMATION
   ├─ "✅ You have been successfully deboarded"
   ├─ "Your access has been removed"
   └─ "Thank you for using PGEase"
```

### **Staff Deboarding (Termination)**

```
┌─────────────────────────────────────────────────────────────┐
│                   STAFF DEBOARDING FLOW                     │
└─────────────────────────────────────────────────────────────┘

Same as student deboarding, but:
- POST /api/staff/deboard
- Uses staffId instead of studentId
- Reason might be "Resigned", "Terminated", etc.
- Clears staff-specific data
```

---

## 🎭 **Multi-Role Architecture**

### **Current State**

```swift
// Current: Single role (student only)
struct PGEaseApp: App {
    var body: some Scene {
        WindowGroup {
            if onboardingComplete {
                MainTabView()  // ⚠️ Student-only tabs
            } else {
                OnboardingView()
            }
        }
    }
}
```

### **Required Changes**

```swift
// ⚠️ NEEDS TO BE IMPLEMENTED
struct PGEaseApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                // Show role-based UI
                switch authManager.userRole {
                case .student:
                    StudentTabView()
                case .staff:
                    StaffTabView()
                case .manager:
                    ManagerTabView()
                case .warden:
                    WardenTabView()
                case .accountant:
                    AccountantTabView()
                case .pgAdmin:
                    PGAdminTabView()
                case .vendor:
                    VendorTabView()
                default:
                    LoginView()
                }
            } else {
                // Show login/onboarding
                if authManager.hasInviteCode {
                    OnboardingView(userType: authManager.inviteUserType)
                } else {
                    LoginView()
                }
            }
        }
    }
}
```

### **AuthManager (Needs Creation)**

```swift
// ⚠️ NEEDS TO BE CREATED
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userRole: UserRole = .none
    @Published var userId: String?
    @Published var userType: UserType = .student  // STUDENT or STAFF
    @Published var hasInviteCode = false
    @Published var inviteUserType: UserType = .student

    init() {
        checkAuthStatus()
    }

    func checkAuthStatus() {
        // Check if user is onboarded
        if let userId = UserDefaults.standard.string(forKey: "userId"),
           let userTypeString = UserDefaults.standard.string(forKey: "userType"),
           UserDefaults.standard.bool(forKey: "onboardingComplete") {
            self.userId = userId
            self.userType = UserType(rawValue: userTypeString) ?? .student
            self.isAuthenticated = true
            self.userRole = getUserRole()
        }
    }

    func getUserRole() -> UserRole {
        // Fetch user role from API or UserDefaults
        // For now, map userType to role
        switch userType {
        case .student:
            return .student
        case .staff:
            return .staff
        default:
            return .none
        }
    }

    func logout() {
        isAuthenticated = false
        userRole = .none
        userId = nil
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "userType")
        UserDefaults.standard.removeObject(forKey: "onboardingComplete")
    }
}

enum UserType: String {
    case student = "STUDENT"
    case staff = "STAFF"
}

enum UserRole {
    case none
    case student
    case staff
    case manager
    case warden
    case accountant
    case pgAdmin
    case vendor
}
```

---

## 📝 **Implementation Checklist**

### **Phase 1: Critical Updates (Week 1)**

#### **1.1 Update APIManager.swift**

- [ ] Add `userType` parameter to check-in/out functions
- [ ] Add staff onboarding APIs:
  - [ ] `linkStaffDevice(inviteCode:deviceId:)`
  - [ ] `setupStaffBiometric(staffId:biometricData:deviceId:)`
  - [ ] `getStaffBiometricStatus(staffId:)`
- [ ] Add deboarding APIs:
  - [ ] `deboardStudent(studentId:deboardDate:reason:)`
  - [ ] `deboardStaff(staffId:terminationDate:reason:)`

#### **1.2 Update CheckInOutManager.swift**

- [ ] Add `userType` property
- [ ] Update `checkIn()` to accept `userType` and `userId`
- [ ] Update `checkOut()` to accept `userType` and `userId`
- [ ] Update `getCurrentStudentId()` to `getCurrentUserId()`

#### **1.3 Update OnboardingManager.swift**

- [ ] Add `userType` property (STUDENT/STAFF)
- [ ] Add `isStaffOnboarding` flag
- [ ] Update `linkDevice()` to call correct API based on userType
- [ ] Update `setupBiometric()` to call correct API based on userType
- [ ] Update `checkOnboardingStatus()` to call correct API

#### **1.4 Create AuthManager.swift**

- [ ] Create `AuthManager` class
- [ ] Add `isAuthenticated`, `userRole`, `userType` properties
- [ ] Add `checkAuthStatus()` method
- [ ] Add `logout()` method
- [ ] Add `getUserRole()` method

#### **1.5 Create LoginView.swift**

- [ ] Create basic login UI
- [ ] Add "I'm a Student" button
- [ ] Add "I'm a Staff Member" button
- [ ] Route to correct onboarding flow

#### **1.6 Create DeboardingView.swift**

- [ ] Create deboarding UI
- [ ] Add confirmation dialog
- [ ] Add reason input field
- [ ] Add deboard date picker
- [ ] Add biometric authentication
- [ ] Call deboard API
- [ ] Clear UserDefaults on success

### **Phase 2: Multi-Role Support (Week 2)**

#### **2.1 Update PGEaseApp.swift**

- [ ] Add `AuthManager` state object
- [ ] Add role-based routing
- [ ] Show correct tab view based on role

#### **2.2 Create Role-Specific Tab Views**

- [ ] Create `StudentTabView.swift`
- [ ] Create `StaffTabView.swift`
- [ ] Create `ManagerTabView.swift` (future)
- [ ] Create `WardenTabView.swift` (future)

#### **2.3 Update MainTabView.swift**

- [ ] Rename to `StudentTabView.swift`
- [ ] Keep existing student-specific tabs
- [ ] Add "Profile" tab with deboard option

#### **2.4 Create StaffTabView.swift**

- [ ] Add "Home" tab (check-in/out)
- [ ] Add "Attendance" tab (view own attendance)
- [ ] Add "Tasks" tab (assigned tasks)
- [ ] Add "Profile" tab (with resign option)

### **Phase 3: Testing & Polish (Week 3)**

#### **3.1 Testing**

- [ ] Test student onboarding flow
- [ ] Test staff onboarding flow
- [ ] Test student check-in/out
- [ ] Test staff check-in/out
- [ ] Test student deboarding
- [ ] Test staff deboarding
- [ ] Test role-based navigation

#### **3.2 Error Handling**

- [ ] Add network error handling
- [ ] Add retry logic for failed API calls
- [ ] Add offline mode support
- [ ] Add error messages for all failure scenarios

#### **3.3 UI/UX Polish**

- [ ] Add loading indicators
- [ ] Add success/error animations
- [ ] Add haptic feedback
- [ ] Improve accessibility
- [ ] Add dark mode support

---

## 🔧 **Code Examples**

### **1. Updated APIManager.swift**

```swift
// ⚠️ ADD THESE METHODS

// MARK: - Staff Onboarding APIs

func linkStaffDevice(inviteCode: String, deviceId: String) async throws -> LinkStaffDeviceResponse {
    let body = [
        "inviteCode": inviteCode,
        "deviceId": deviceId
    ]

    return try await makeRequest(
        endpoint: "/staff/onboarding/link-device",
        method: .POST,
        body: body,
        responseType: LinkStaffDeviceResponse.self
    )
}

func setupStaffBiometric(
    staffId: String,
    biometricData: BiometricData,
    deviceId: String
) async throws -> BiometricSetupResponse {
    let body: [String: Any] = [
        "staffId": staffId,
        "biometricData": [
            "method": biometricData.method,
            "template": biometricData.template,
            "metadata": [
                "quality": biometricData.quality,
                "attempts": biometricData.attempts
            ]
        ],
        "deviceId": deviceId
    ]

    return try await makeRequest(
        endpoint: "/staff/onboarding/biometric-setup",
        method: .POST,
        body: body,
        responseType: BiometricSetupResponse.self
    )
}

func getStaffBiometricStatus(staffId: String) async throws -> BiometricStatusResponse {
    return try await makeRequest(
        endpoint: "/staff/onboarding/biometric-setup?staffId=\(staffId)",
        method: .GET,
        responseType: BiometricStatusResponse.self
    )
}

// MARK: - Deboarding APIs

func deboardStudent(
    studentId: String,
    deboardDate: String,
    reason: String?
) async throws -> DeboardResponse {
    var body: [String: Any] = [
        "studentId": studentId,
        "deboardDate": deboardDate
    ]

    if let reason = reason {
        body["reason"] = reason
    }

    return try await makeRequest(
        endpoint: "/student/deboard",
        method: .POST,
        body: body,
        responseType: DeboardResponse.self
    )
}

func deboardStaff(
    staffId: String,
    terminationDate: String,
    reason: String?
) async throws -> DeboardResponse {
    var body: [String: Any] = [
        "staffId": staffId,
        "terminationDate": terminationDate
    ]

    if let reason = reason {
        body["reason"] = reason
    }

    return try await makeRequest(
        endpoint: "/staff/deboard",
        method: .POST,
        body: body,
        responseType: DeboardResponse.self
    )
}

// MARK: - Updated Check-In/Out APIs

func checkIn(
    userType: String,
    userId: String,
    method: CheckInMethod,
    nfcTagId: String? = nil,
    location: LocationData? = nil,
    biometricVerified: Bool = false
) async throws -> CheckInOutResponse {
    var body: [String: Any] = [
        "userType": userType,
        "method": method.rawValue,
        "biometricVerified": biometricVerified
    ]

    // Add userId based on userType
    if userType == "STUDENT" {
        body["studentId"] = userId
    } else if userType == "STAFF" {
        body["staffId"] = userId
    }

    if let nfcTagId = nfcTagId {
        body["nfcTagId"] = nfcTagId
    }

    if let location = location {
        body["location"] = [
            "latitude": location.latitude,
            "longitude": location.longitude,
            "accuracy": location.accuracy
        ]
    }

    return try await makeRequest(
        endpoint: "/check-in-out/checkin",
        method: .POST,
        body: body,
        responseType: CheckInOutResponse.self
    )
}

func checkOut(
    userType: String,
    userId: String,
    method: CheckInMethod,
    nfcTagId: String? = nil,
    location: LocationData? = nil,
    biometricVerified: Bool = false
) async throws -> CheckInOutResponse {
    var body: [String: Any] = [
        "userType": userType,
        "method": method.rawValue,
        "biometricVerified": biometricVerified
    ]

    // Add userId based on userType
    if userType == "STUDENT" {
        body["studentId"] = userId
    } else if userType == "STAFF" {
        body["staffId"] = userId
    }

    if let nfcTagId = nfcTagId {
        body["nfcTagId"] = nfcTagId
    }

    if let location = location {
        body["location"] = [
            "latitude": location.latitude,
            "longitude": location.longitude,
            "accuracy": location.accuracy
        ]
    }

    return try await makeRequest(
        endpoint: "/check-in-out/checkout",
        method: .POST,
        body: body,
        responseType: CheckInOutResponse.self
    )
}

// MARK: - Response Models

struct LinkStaffDeviceResponse: Codable {
    let success: Bool
    let data: LinkStaffDeviceData
    let message: String
}

struct LinkStaffDeviceData: Codable {
    let staff: StaffInfo
    let deviceId: String
    let linkedAt: String
    let accessStatus: String
}

struct StaffInfo: Codable {
    let id: String
    let name: String
    let email: String?
    let phoneNumber: String?
    let role: String
    let pg: PGInfo
}

struct DeboardResponse: Codable {
    let success: Bool
    let message: String
    let data: DeboardData?
}

struct DeboardData: Codable {
    let studentId: String?
    let staffId: String?
    let deboardedAt: String?
    let terminatedAt: String?
    let historyRecordId: String?
}
```

### **2. Updated CheckInOutManager.swift**

```swift
// ⚠️ UPDATE THESE PROPERTIES AND METHODS

class CheckInOutManager: NSObject, ObservableObject {
    // ... existing properties ...

    // ⚠️ ADD THESE
    @Published var userType: String = "STUDENT"  // or "STAFF"
    @Published var userId: String?

    // ⚠️ UPDATE THIS METHOD
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

            // ⚠️ UPDATED API CALL
            let response = try await apiManager.checkIn(
                userType: userType,
                userId: userId,
                method: method,
                nfcTagId: nfcTagId,
                location: locationData,
                biometricVerified: true
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

    // ⚠️ UPDATE THIS METHOD
    func checkOut(method: CheckInMethod, nfcTagId: String? = nil) async {
        // Similar to checkIn, but call apiManager.checkOut()
        // ... (same structure as checkIn)
    }

    // ⚠️ RENAME THIS METHOD
    private func getCurrentUserId() -> String? {
        // Check userType and return appropriate ID
        if userType == "STUDENT" {
            return UserDefaults.standard.string(forKey: "studentId")
        } else if userType == "STAFF" {
            return UserDefaults.standard.string(forKey: "staffId")
        }
        return nil
    }
}
```

### **3. Updated OnboardingManager.swift**

```swift
// ⚠️ ADD THESE PROPERTIES

class OnboardingManager: ObservableObject {
    // ... existing properties ...

    // ⚠️ ADD THESE
    @Published var userType: UserType = .student
    @Published var staffInfo: StaffInfo?

    // ⚠️ UPDATE THIS METHOD
    func linkDevice() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            if userType == .student {
                // Student onboarding
                let response = try await apiManager.linkDevice(
                    inviteCode: inviteCode,
                    deviceId: deviceId
                )

                await MainActor.run {
                    self.studentInfo = response.data.student
                    self.accessStatus = response.data.accessStatus
                    self.isLoading = false

                    UserDefaults.standard.set(response.data.student.id, forKey: "studentId")
                    UserDefaults.standard.set("STUDENT", forKey: "userType")

                    // Move to next step
                    switch response.data.accessStatus {
                    case "PENDING_BIOMETRIC":
                        self.currentStep = .setupBiometric
                    case "ACTIVE":
                        self.completeOnboarding()
                    default:
                        self.currentStep = .waitingForApproval
                    }
                }
            } else {
                // Staff onboarding
                let response = try await apiManager.linkStaffDevice(
                    inviteCode: inviteCode,
                    deviceId: deviceId
                )

                await MainActor.run {
                    self.staffInfo = response.data.staff
                    self.accessStatus = response.data.accessStatus
                    self.isLoading = false

                    UserDefaults.standard.set(response.data.staff.id, forKey: "staffId")
                    UserDefaults.standard.set("STAFF", forKey: "userType")

                    // Move to next step
                    switch response.data.accessStatus {
                    case "PENDING_BIOMETRIC":
                        self.currentStep = .setupBiometric
                    case "ACTIVE":
                        self.completeOnboarding()
                    default:
                        self.currentStep = .waitingForApproval
                    }
                }
            }

        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // ⚠️ UPDATE THIS METHOD
    func setupBiometric() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            // Authenticate with local biometrics
            let authSuccess = await biometricAuthManager.authenticateUser(
                reason: "Setup biometric authentication for PGEase"
            )

            guard authSuccess else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Biometric authentication failed"
                }
                return
            }

            // Create biometric data
            let publicSignature = generateEnrollmentSignature()
            let qualityScore = generateQualityScore(for: biometricAuthManager.biometricType)

            let biometricData = BiometricData(
                method: biometricAuthManager.biometricTypeDescription,
                template: publicSignature,
                quality: qualityScore,
                attempts: 1
            )

            if userType == .student {
                // Student biometric setup
                guard let studentId = studentInfo?.id else {
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = "Student ID not found"
                    }
                    return
                }

                let response = try await apiManager.setupBiometric(
                    studentId: studentId,
                    biometricData: biometricData,
                    deviceId: deviceId
                )

                await MainActor.run {
                    self.biometricData = biometricData
                    self.accessStatus = response.data.accessStatus
                    self.isLoading = false

                    UserDefaults.standard.set(true, forKey: "biometricSetupComplete")

                    // Move to next step
                    switch response.data.accessStatus {
                    case "PENDING_APPROVAL":
                        self.currentStep = .waitingForApproval
                    case "ACTIVE":
                        self.completeOnboarding()
                    default:
                        self.currentStep = .waitingForApproval
                    }
                }
            } else {
                // Staff biometric setup
                guard let staffId = staffInfo?.id else {
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = "Staff ID not found"
                    }
                    return
                }

                let response = try await apiManager.setupStaffBiometric(
                    staffId: staffId,
                    biometricData: biometricData,
                    deviceId: deviceId
                )

                await MainActor.run {
                    self.biometricData = biometricData
                    self.accessStatus = response.data.accessStatus
                    self.isLoading = false

                    UserDefaults.standard.set(true, forKey: "biometricSetupComplete")

                    // Move to next step
                    switch response.data.accessStatus {
                    case "PENDING_APPROVAL":
                        self.currentStep = .waitingForApproval
                    case "ACTIVE":
                        self.completeOnboarding()
                    default:
                        self.currentStep = .waitingForApproval
                    }
                }
            }

        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

enum UserType {
    case student
    case staff
}
```

### **4. Create DeboardingView.swift**

```swift
// ⚠️ CREATE THIS FILE

import SwiftUI

struct DeboardingView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var deboardingManager = DeboardingManager()
    @State private var showConfirmation = false
    @State private var reason = ""
    @State private var deboardDate = Date()

    let userType: String
    let userId: String
    let userName: String

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Deboarding Information")) {
                    Text("Name: \(userName)")
                    Text("User Type: \(userType)")

                    DatePicker("Deboard Date", selection: $deboardDate, displayedComponents: .date)

                    TextField("Reason (optional)", text: $reason)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Section(header: Text("Warning")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("⚠️ This action cannot be undone")
                            .font(.headline)
                            .foregroundColor(.red)

                        Text("Deboarding will:")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 5) {
                            Text("• Remove your access to this PG")
                            Text("• Delete your biometric data")
                            Text("• Clear your device registration")
                            Text("• Archive your attendance history")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                }

                Section {
                    Button(action: {
                        showConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            if deboardingManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Deboard")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color.red)
                    .disabled(deboardingManager.isLoading)
                }
            }
            .navigationTitle("Leave PG")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Confirm Deboarding", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Confirm", role: .destructive) {
                    Task {
                        await deboard()
                    }
                }
            } message: {
                Text("Are you sure you want to leave this PG? This action cannot be undone.")
            }
            .alert("Deboarding Result", isPresented: $deboardingManager.showResult) {
                Button("OK") {
                    if deboardingManager.deboardingSuccess {
                        // Navigate back to welcome screen
                        dismiss()
                    }
                }
            } message: {
                Text(deboardingManager.resultMessage)
            }
        }
    }

    private func deboard() async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let deboardDateString = dateFormatter.string(from: deboardDate)

        await deboardingManager.deboard(
            userType: userType,
            userId: userId,
            deboardDate: deboardDateString,
            reason: reason.isEmpty ? nil : reason
        )
    }
}

// MARK: - Deboarding Manager

class DeboardingManager: ObservableObject {
    @Published var isLoading = false
    @Published var showResult = false
    @Published var deboardingSuccess = false
    @Published var resultMessage = ""

    private let apiManager = APIManager.shared
    private let biometricAuthManager = BiometricAuthManager()

    func deboard(
        userType: String,
        userId: String,
        deboardDate: String,
        reason: String?
    ) async {
        await MainActor.run {
            isLoading = true
        }

        do {
            // Authenticate with biometrics
            let authSuccess = await biometricAuthManager.authenticateUser(
                reason: "Authenticate to deboard"
            )

            guard authSuccess else {
                await MainActor.run {
                    self.isLoading = false
                    self.showResult = true
                    self.deboardingSuccess = false
                    self.resultMessage = "Biometric authentication failed"
                }
                return
            }

            // Call deboard API
            if userType == "STUDENT" {
                let response = try await apiManager.deboardStudent(
                    studentId: userId,
                    deboardDate: deboardDate,
                    reason: reason
                )

                await MainActor.run {
                    self.isLoading = false
                    self.showResult = true
                    self.deboardingSuccess = response.success
                    self.resultMessage = response.message

                    if response.success {
                        // Clear UserDefaults
                        UserDefaults.standard.removeObject(forKey: "studentId")
                        UserDefaults.standard.removeObject(forKey: "userType")
                        UserDefaults.standard.removeObject(forKey: "onboardingComplete")
                        UserDefaults.standard.removeObject(forKey: "biometricSetupComplete")
                    }
                }
            } else {
                let response = try await apiManager.deboardStaff(
                    staffId: userId,
                    terminationDate: deboardDate,
                    reason: reason
                )

                await MainActor.run {
                    self.isLoading = false
                    self.showResult = true
                    self.deboardingSuccess = response.success
                    self.resultMessage = response.message

                    if response.success {
                        // Clear UserDefaults
                        UserDefaults.standard.removeObject(forKey: "staffId")
                        UserDefaults.standard.removeObject(forKey: "userType")
                        UserDefaults.standard.removeObject(forKey: "onboardingComplete")
                        UserDefaults.standard.removeObject(forKey: "biometricSetupComplete")
                    }
                }
            }

        } catch {
            await MainActor.run {
                self.isLoading = false
                self.showResult = true
                self.deboardingSuccess = false
                self.resultMessage = error.localizedDescription
            }
        }
    }
}
```

---

## 🎯 **Summary**

### **Key Changes Required**

1. **API Updates**: Add staff APIs and userType parameter
2. **Manager Updates**: Support both students and staff
3. **UI Updates**: Add login, deboarding, and role-based navigation
4. **Auth System**: Create AuthManager for role detection

### **Implementation Priority**

1. ✅ **Week 1**: API updates, manager updates, deboarding
2. ✅ **Week 2**: Multi-role support, role-based navigation
3. ✅ **Week 3**: Testing, error handling, polish

### **Testing Checklist**

- [ ] Student onboarding works
- [ ] Staff onboarding works
- [ ] Student check-in/out works
- [ ] Staff check-in/out works
- [ ] Student deboarding works
- [ ] Staff deboarding works
- [ ] Role-based navigation works
- [ ] Error handling works
- [ ] Offline mode works

---

## 📚 **Related Documentation**

- [BIOMETRIC_VERIFICATION_FLOW.md](/Users/vikassharma/Cursor/pgease/BIOMETRIC_VERIFICATION_FLOW.md)
- [UNIFIED_MOBILE_APP_ARCHITECTURE.md](/Users/vikassharma/Cursor/pgease/UNIFIED_MOBILE_APP_ARCHITECTURE.md)
- [STUDENT_ONBOARDING_GUIDE.md](/Users/vikassharma/Cursor/pgease/STUDENT_ONBOARDING_GUIDE.md)
- [USER_STORIES_ONBOARDING.md](/Users/vikassharma/Cursor/pgease/USER_STORIES_ONBOARDING.md)

---

**Last Updated:** October 13, 2025  
**Version:** 1.0  
**Status:** Ready for Implementation
