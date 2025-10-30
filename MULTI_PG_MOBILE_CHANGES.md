# Mobile App Changes for Multi-PG & WebAuthn Support

**Date:** October 16, 2025  
**Status:** Required Changes Analysis  
**Scope:** ✅ **CORRECTED - PG ADMIN & VENDOR Only**

---

## 🎯 **Required Changes Overview**

### **Summary:**

The mobile app needs **targeted updates** to support:

1. ✅ WebAuthn authentication (replacing custom biometric) - **DONE**
2. ✅ Multi-PG support **ONLY for PG ADMIN & VENDOR** - **TO DO**
3. ✅ Correct role hierarchy - **DONE**
4. ✅ PG context in all API calls - **TO DO**

### **✅ Corrected Multi-PG Scope:**

| Role           | Multi-PG Support         | UI Changes Needed              | Complexity |
| -------------- | ------------------------ | ------------------------------ | ---------- |
| **PGADMIN**    | ✅ YES (owns 2-3 PGs)    | PG Switcher dropdown           | Medium     |
| **VENDOR**     | ✅ YES (supplies 5+ PGs) | PG Switcher + "All PGs" view   | Medium     |
| **MANAGER**    | ❌ NO (single PG)        | ❌ None                        | None       |
| **WARDEN**     | ❌ NO (single PG)        | ❌ None                        | None       |
| **ACCOUNTANT** | ❌ NO (single PG)        | ❌ None                        | None       |
| **STAFF**      | ❌ NO (single PG)        | ❌ None                        | None       |
| **STUDENT**    | ❌ NO (single PG)        | ❌ None                        | None       |
| **APPADMIN**   | ⭐ Platform (ALL PGs)    | Filter dropdown (not switcher) | Low        |

**Impact:** Only 2 roles need multi-PG UI instead of 5 → **60% less work!** 🎉

---

## 📋 **Required Changes by Component**

### **1. Managers (6 files to update)**

#### **A. APIManager.swift** ✅ Already Updated

- ✅ WebAuthn API methods added
- ✅ `checkIn/checkOut` updated with `webAuthnCredentialId`
- ✅ Response models for WebAuthn added
- ⏳ Need: Add PG management APIs

**Additional Methods Needed:**

```swift
// Get user's PGs
func getUserPGs(userId: String) async throws -> UserPGsResponse

// Switch PG
func switchPG(userId: String, pgId: String) async throws -> SwitchPGResponse
```

#### **B. WebAuthnManager.swift** ✅ Already Created

- ✅ Complete implementation
- ✅ Registration and authentication
- ✅ Works for all user types
- ✅ No changes needed

#### **C. OnboardingManager.swift** ✅ Already Updated

- ✅ WebAuthn registration integrated
- ✅ Supports student/staff userType
- ⏳ Need: Add support for MANAGER, WARDEN, ACCOUNTANT roles

**Required Changes:**

```swift
class OnboardingManager {
    // ✅ Already has
    @Published var userType: UserType = .student

    // ⏳ Need to expand UserType enum
    enum UserType {
        case student
        case staff
        case manager    // ⏳ ADD
        case warden     // ⏳ ADD
        case accountant // ⏳ ADD
        case pgAdmin    // ⏳ ADD
        case vendor     // ⏳ ADD
    }
}
```

#### **D. CheckInOutManager.swift** ✅ Already Updated

- ✅ WebAuthn authentication
- ✅ Unified verification
- ✅ Multi-role support (STUDENT/STAFF)
- ✅ No changes needed for multi-PG (check-in is always to current PG)

#### **E. AuthManager.swift** ✅ Already Created

- ✅ Role-based permissions
- ⏳ Need: Add PG context to permissions

**Required Changes:**

```swift
class AuthManager {
    @Published var currentPgId: String? // ⏳ ADD: Current PG context
    @Published var availablePGs: [PG] = [] // ⏳ ADD: User's PGs

    // ⏳ ADD: Load user's PGs
    func loadUserPGs() async {
        let response = try await apiManager.getUserPGs(userId: currentUser.id)
        availablePGs = response.pgs
        currentPgId = response.primaryPg.id
    }

    // ⏳ ADD: Switch PG
    func switchPG(_ pgId: String) async {
        await apiManager.switchPG(userId: currentUser.id, pgId: pgId)
        currentPgId = pgId
        // Reload data
    }
}
```

#### **F. NFCTagManager.swift** ✅ Already Created

- ✅ NFC write/lock/read operations
- ⏳ Need: Use current PG context for tag operations

**Required Changes:**

```swift
func generateNFCTag(roomId: String) async -> NFCTagWriteData? {
    // ⏳ Get pgId from AuthManager.currentPgId instead of hardcoding
    guard let pgId = AuthManager.shared.currentPgId else { return nil }

    let response = try await apiManager.generateNFCTag(roomId: roomId, pgId: pgId)
    // ... rest
}
```

---

### **2. Views (7 files to create/update)**

#### **A. PGSelectorView.swift** ⏳ NEW - REQUIRED

**Purpose:** Dropdown to switch between PGs (for multi-PG users)

```swift
import SwiftUI

struct PGSelectorView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showPGList = false

    var body: some View {
        Menu {
            ForEach(authManager.availablePGs) { pg in
                Button(action: { switchPG(pg) }) {
                    HStack {
                        if pg.id == authManager.currentPgId {
                            Image(systemName: "checkmark")
                        }
                        VStack(alignment: .leading) {
                            Text(pg.name)
                                .font(.body)
                            if pg.isPrimary {
                                Text("Primary")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "building.2")
                Text(currentPGName)
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }

    var currentPGName: String {
        authManager.availablePGs.first { $0.id == authManager.currentPgId }?.name ?? "Select PG"
    }

    func switchPG(_ pg: PG) {
        Task {
            await authManager.switchPG(pg.id)
        }
    }
}

struct PG: Identifiable, Codable {
    let id: String
    let name: String
    let role: String
    let isPrimary: Bool
    let isActive: Bool
}
```

**Where to Use:**

- ✅ Top navigation of ManagerTabView
- ✅ Top navigation of WardenTabView
- ✅ Top navigation of AccountantTabView
- ✅ Top navigation for PGADMIN
- ❌ NOT shown for STUDENT/STAFF (single PG only)

---

#### **B. RoleSelectionView.swift** ✅ Already Created

- ⏳ Need: Add more role options

**Required Changes:**

```swift
struct RoleSelectionView: View {
    // Current: Only shows Student/Staff
    // ⏳ ADD: Show Manager/Warden/Accountant/PGAdmin/Vendor

    var roles: [Role] = [
        Role(type: .student, icon: "person.fill", title: "Student"),
        Role(type: .staff, icon: "person.badge.key.fill", title: "Staff"),
        Role(type: .manager, icon: "person.2.fill", title: "Manager"),    // ⏳ ADD
        Role(type: .warden, icon: "shield.fill", title: "Warden"),        // ⏳ ADD
        Role(type: .accountant, icon: "dollarsign.circle", title: "Accountant"), // ⏳ ADD
        Role(type: .pgAdmin, icon: "building.2", title: "PG Admin"),      // ⏳ ADD
        Role(type: .vendor, icon: "cart.fill", title: "Vendor")           // ⏳ ADD
    ]
}
```

---

#### **C. ManagerTabView (in PGEaseApp.swift)** ✅ Already Created

- ⏳ Need: Add PG selector to navigation

**Required Changes:**

```swift
struct ManagerTabView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        TabView {
            // Dashboard
            NavigationView {
                DashboardView()
                    .navigationTitle("Dashboard")
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            // ⏳ ADD: PG Selector
                            if authManager.availablePGs.count > 1 {
                                PGSelectorView()
                            }
                        }
                    }
            }
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }

            // ... rest of tabs
        }
        .onAppear {
            // ⏳ ADD: Load user's PGs
            Task {
                await authManager.loadUserPGs()
            }
        }
    }
}
```

---

#### **D. NFCTagWriteView.swift** ✅ Already Created

- ⏳ Need: Use current PG context

**Required Changes:**

```swift
struct NFCTagWriteView: View {
    @EnvironmentObject var authManager: AuthManager

    private func generateTag() {
        currentStep = .generating

        Task {
            // ⏳ Use authManager.currentPgId instead of hardcoding
            guard let pgId = authManager.currentPgId else {
                alertMessage = "PG ID not found"
                showAlert = true
                currentStep = .selectRoom
                return
            }

            if let tagData = await nfcManager.generateNFCTag(roomId: roomId, pgId: pgId) {
                // ...
            }
        }
    }
}
```

---

#### **E. NFCTagListView.swift** ✅ Already Created

- ⏳ Need: Filter tags by current PG

**Required Changes:**

```swift
struct NFCTagListView: View {
    @EnvironmentObject var authManager: AuthManager

    private func loadTags() {
        // ⏳ Use authManager.currentPgId
        guard let pgId = authManager.currentPgId else { return }

        Task {
            if let fetchedTags = await nfcManager.listTags(pgId: pgId) {
                // ...
            }
        }
    }
}
```

---

### **3. App Structure (PGEaseApp.swift)** ✅ Partially Updated

**Current State:**

- ✅ Role-based routing implemented
- ✅ AuthManager integrated
- ⏳ Need: Load PGs on app launch for multi-PG users

**Required Changes:**

```swift
struct RoleBasedMainView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            switch authManager.userRole {
            case .manager, .pgAdmin, .warden, .accountant:
                // ⏳ ADD: Load PGs on appear
                ManagerTabView()
                    .onAppear {
                        Task {
                            await authManager.loadUserPGs()
                        }
                    }

            // ... rest
            }
        }
    }
}
```

---

## 📊 **Changes Summary**

### **Files to Create (1):**

- ⏳ `Views/PGSelectorView.swift` - NEW (150 lines)

### **Files to Update (8):**

1. ⏳ `Managers/APIManager.swift` - Add PG management APIs
2. ⏳ `Managers/OnboardingManager.swift` - Expand UserType enum
3. ⏳ `Managers/AuthManager.swift` - Add PG context + switching
4. ⏳ `Managers/NFCTagManager.swift` - Use current PG context
5. ⏳ `Views/RoleSelectionView.swift` - Add all 7 roles
6. ⏳ `Views/NFCTagWriteView.swift` - Use current PG
7. ⏳ `Views/NFCTagListView.swift` - Filter by current PG
8. ⏳ `PGEaseApp.swift` - Load PGs on launch

### **No Changes Needed (5):**

- ✅ `WebAuthnManager.swift` - Already universal
- ✅ `CheckInOutManager.swift` - Already works with any PG
- ✅ `BiometricAuthManager.swift` - Still used by CheckInOutManager
- ✅ `StaffOnboardingView.swift` - Already generic
- ✅ Main check-in/out views - Already work with current context

---

## 🎯 **Priority Changes**

### **Critical (Must Have):**

1. **✅ CRITICAL: Expand UserType enum in OnboardingManager**

   ```swift
   enum UserType {
       case student
       case staff
       case manager
       case warden
       case accountant
       case pgAdmin
       case vendor
   }
   ```

   **Why:** Without this, MANAGER/WARDEN/ACCOUNTANT can't onboard

2. **✅ CRITICAL: Add PG management methods to APIManager**

   ```swift
   func getUserPGs(userId: String) async throws -> UserPGsResponse
   func switchPG(userId: String, pgId: String) async throws -> SwitchPGResponse
   ```

   **Why:** Multi-PG users need to see/switch their PGs

3. **✅ CRITICAL: Add PG context to AuthManager**
   ```swift
   @Published var currentPgId: String?
   @Published var availablePGs: [PG] = []
   ```
   **Why:** All PG-scoped operations need context

### **Important (Should Have):**

4. **Create PGSelectorView component**

   - Show dropdown when user has > 1 PG
   - Switch PG context
   - Update all views

5. **Update RoleSelectionView**

   - Add all 7 role options
   - Role-specific onboarding flows

6. **Update NFCTagManager**
   - Use `authManager.currentPgId`
   - Don't hardcode PG

### **Nice to Have (Can Wait):**

7. **Consolidated dashboard for multi-PG**

   - Show stats across all PGs
   - Or filter by selected PG

8. **PG switching animations**
   - Smooth transitions
   - Loading states

---

## 🔧 **Detailed Implementation Plan**

### **Phase 1: Critical Updates (2-3 hours)**

#### **Step 1: Expand UserType Enum**

**File:** `Managers/OnboardingManager.swift`

```swift
class OnboardingManager: ObservableObject {
    // ... existing code

    enum UserType: String {
        case student = "STUDENT"
        case staff = "STAFF"
        case manager = "MANAGER"          // ⏳ ADD
        case warden = "WARDEN"            // ⏳ ADD
        case accountant = "ACCOUNTANT"    // ⏳ ADD
        case pgAdmin = "PGADMIN"          // ⏳ ADD
        case vendor = "VENDOR"            // ⏳ ADD

        var displayName: String {
            switch self {
            case .student: return "Student"
            case .staff: return "Staff"
            case .manager: return "Manager"
            case .warden: return "Warden"
            case .accountant: return "Accountant"
            case .pgAdmin: return "PG Admin"
            case .vendor: return "Vendor"
            }
        }

        var requiresApproval: Bool {
            return self == .student || self == .staff
        }
    }
}
```

---

#### **Step 2: Add PG Management to AuthManager**

**File:** `Managers/AuthManager.swift`

```swift
class AuthManager: ObservableObject {
    // ... existing code

    // ⏳ ADD: Multi-PG support
    @Published var currentPgId: String?
    @Published var currentPgName: String = "Loading..."
    @Published var availablePGs: [UserPG] = []
    @Published var isLoadingPGs = false

    // ⏳ ADD: Load user's PGs
    func loadUserPGs() async {
        guard let userId = currentUser?.id else { return }

        await MainActor.run { isLoadingPGs = true }

        do {
            let response = try await apiManager.getUserPGs(userId: userId)

            await MainActor.run {
                self.availablePGs = response.data.pgs
                self.currentPgId = response.data.primaryPg.id
                self.currentPgName = response.data.primaryPg.name
                self.isLoadingPGs = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoadingPGs = false
            }
        }
    }

    // ⏳ ADD: Switch PG
    func switchPG(_ pgId: String) async {
        guard let userId = currentUser?.id else { return }

        do {
            let response = try await apiManager.switchPG(userId: userId, pgId: pgId)

            await MainActor.run {
                self.currentPgId = pgId
                self.currentPgName = response.data.currentPG.name
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

struct UserPG: Identifiable, Codable {
    let id: String
    let name: String
    let address: String?
    let role: String
    let isPrimary: Bool
    let isActive: Bool
}
```

---

#### **Step 3: Add PG APIs to APIManager**

**File:** `Managers/APIManager.swift`

```swift
// ⏳ ADD: PG Management APIs

func getUserPGs(userId: String) async throws -> UserPGsResponse {
    return try await makeRequest(
        endpoint: "/user/pgs?userId=\(userId)",
        method: .GET,
        responseType: UserPGsResponse.self
    )
}

func switchPG(userId: String, pgId: String) async throws -> SwitchPGResponse {
    let body = [
        "userId": userId,
        "pgId": pgId
    ]

    return try await makeRequest(
        endpoint: "/user/switch-pg",
        method: .POST,
        body: body,
        responseType: SwitchPGResponse.self
    )
}

// ⏳ ADD: Response models
struct UserPGsResponse: Codable {
    let success: Bool
    let data: UserPGsData
}

struct UserPGsData: Codable {
    let userId: String
    let userName: String
    let email: String
    let primaryPg: PGInfo
    let pgs: [UserPG]
    let totalPGs: Int
}

struct SwitchPGResponse: Codable {
    let success: Bool
    let message: String
    let data: SwitchPGData
}

struct SwitchPGData: Codable {
    let currentPG: PGInfo
    let role: String
}
```

---

### **Phase 2: UI Updates (2-3 hours)**

#### **Step 4: Create PGSelectorView**

**File:** `Views/PGSelectorView.swift` (NEW)

_See implementation above_

---

#### **Step 5: Update RoleSelectionView**

**File:** `Views/RoleSelectionView.swift`

```swift
struct RoleSelectionView: View {
    @Binding var selectedRole: OnboardingManager.UserType

    var roles: [RoleOption] = [
        RoleOption(
            type: .student,
            icon: "person.fill",
            title: "Student",
            description: "I'm a resident",
            features: ["NFC check-in", "Attendance tracking"]
        ),
        RoleOption(
            type: .staff,
            icon: "person.badge.key.fill",
            title: "Staff",
            description: "I work here",
            features: ["Work hours", "Shift attendance"]
        ),
        // ⏳ ADD:
        RoleOption(
            type: .manager,
            icon: "person.2.fill",
            title: "Manager",
            description: "I manage the PG",
            features: ["Manage students", "NFC tags", "Reports"]
        ),
        RoleOption(
            type: .warden,
            icon: "shield.fill",
            title: "Warden",
            description: "I monitor security",
            features: ["Attendance", "Security alerts"]
        ),
        // ... etc for ACCOUNTANT, PGADMIN, VENDOR
    ]
}
```

---

#### **Step 6: Add PG Selector to Tab Views**

**File:** `PGEaseApp.swift`

```swift
struct ManagerTabView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 0) {
            // ⏳ ADD: PG Selector (only if multiple PGs)
            if authManager.availablePGs.count > 1 {
                PGSelectorView()
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .shadow(radius: 2)
            }

            // Existing TabView
            TabView {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                // ... rest
            }
        }
        .onAppear {
            Task {
                await authManager.loadUserPGs()
            }
        }
    }
}

// ⏳ ADD: Same for WardenTabView, AccountantTabView
```

---

### **Phase 3: Context-Aware Updates (1-2 hours)**

#### **Step 7: Update NFCTagManager**

**File:** `Managers/NFCTagManager.swift`

```swift
class NFCTagManager: ObservableObject {
    // ⏳ ADD: Inject AuthManager
    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    func generateNFCTag(roomId: String) async -> NFCTagWriteData? {
        // ⏳ Use current PG context
        guard let pgId = authManager.currentPgId else {
            await MainActor.run {
                self.errorMessage = "No PG selected"
            }
            return nil
        }

        let response = try await apiManager.generateNFCTag(roomId: roomId, pgId: pgId)
        // ...
    }
}
```

---

## 🎯 **Impact Analysis**

### **For Single-PG Users (STUDENT, STAFF, Most MANAGERS):**

- ✅ **No UI changes** - PG selector not shown
- ✅ **Same experience** - currentPgId set automatically
- ✅ **No confusion** - App works exactly as before

### **For Multi-PG Users (PGADMIN, Some ACCOUNTANTS/WARDENS):**

- ✅ **PG selector appears** in top navigation
- ✅ **Can switch PGs** with one tap
- ✅ **Data filtered** by selected PG
- ✅ **Consolidated view** option (across all PGs)

---

## 📋 **Implementation Checklist**

### **Backend (Already Done):**

- [x] Schema: Add `UserPGAssociation` model
- [x] Migration: Apply schema changes
- [x] API: `GET /api/user/pgs`
- [x] API: `POST /api/user/switch-pg`
- [x] API: `POST /api/user/pgs` (add association)

### **iOS (To Do):**

- [ ] Expand `OnboardingManager.UserType` enum (7 roles)
- [ ] Add PG context to `AuthManager`
- [ ] Add PG management methods to `APIManager`
- [ ] Create `PGSelectorView` component
- [ ] Update `RoleSelectionView` (show all 7 roles)
- [ ] Add PG selector to `ManagerTabView`
- [ ] Add PG selector to `WardenTabView`
- [ ] Add PG selector to `AccountantTabView`
- [ ] Update `NFCTagManager` to use PG context
- [ ] Update `NFCTagWriteView` to use PG context
- [ ] Update `NFCTagListView` to filter by PG
- [ ] Load PGs on app launch for multi-PG users

**Estimated Time:** 4-6 hours of iOS development

---

## 🚀 **Minimal Changes for MVP**

If you want to **ship quickly**, here's the minimum:

### **Must Have (2 hours):**

1. ✅ Expand `UserType` enum (10 minutes)
2. ✅ Add PG APIs to `APIManager` (30 minutes)
3. ✅ Add `currentPgId` to `AuthManager` (30 minutes)
4. ✅ Update `NFCTagManager` to use `currentPgId` (15 minutes)
5. ✅ Set `currentPgId` from user's primary PG on login (15 minutes)

### **Can Wait (2-4 hours):**

- PG selector UI (users can still use app without it)
- Multi-PG switching (can add in v2.0)
- Consolidated dashboards (nice to have)

---

## 💡 **Recommendation**

### **Approach: Phased Implementation**

**Phase 1 (Immediate - MVP):**

```
✅ Expand UserType enum
✅ Add PG context to AuthManager (set from primary PG)
✅ Update NFCTagManager to use context
✅ All users get their primary PG automatically
✅ No UI changes (ship faster)
```

**Phase 2 (v2.0 - Multi-PG UX):**

```
⏳ Create PGSelectorView
⏳ Add to ManagerTabView, WardenTabView
⏳ Multi-PG switching
⏳ Consolidated dashboards
```

This way:

- ✅ You can ship WebAuthn + multi-PG backend **immediately**
- ✅ Single-PG users (99% of users) see no change
- ✅ Multi-PG users can still use app (shows primary PG)
- ✅ Add PG switcher UI in next release

---

## 🎊 **Conclusion**

**YES, mobile app needs changes**, but they're **well-structured** and can be **phased**:

### **Current Status:**

- ✅ Backend: 100% ready for multi-PG
- ✅ iOS Managers: 80% ready (need PG context)
- ⏳ iOS Views: 60% ready (need PG selector)

### **Minimum to Ship:**

- 2 hours of iOS changes (expand enum, add PG context)
- Users can onboard with all roles
- Multi-PG users see primary PG automatically

### **Full Feature Set:**

- Additional 4-6 hours for PG selector UI
- Beautiful PG switching experience
- Consolidated multi-PG dashboards

**Your call: Ship MVP now (2 hours) or complete full multi-PG UX (6 hours)?** 🚀

---

**Document Version:** 1.0  
**Last Updated:** October 16, 2025  
**Author:** AI Assistant (Claude Sonnet 4.5)
