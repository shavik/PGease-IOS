# PGSelectorView Integration Guide

**Date:** October 16, 2025  
**Status:** ✅ Integrated

---

## 📍 **Where PGSelectorView is Shown**

### **✅ 1. ManagerTabView (for PGADMIN)**

**File:** `/PGEaseMobile/PGEase/PGEase/PGEaseApp.swift`  
**Lines:** 126-169

**Integration:**

```swift
struct ManagerTabView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 0) {
            // ✅ PG Selector (only shows for PGADMIN with multiple PGs)
            PGSelectorView()
                .environmentObject(authManager)

            TabView {
                // Dashboard, Students, Staff, NFC Tags, Profile
            }
        }
    }
}
```

**When it Shows:**

- ✅ User role is `MANAGER` or `PGADMIN`
- ✅ User has multiple PG associations (2+)
- ✅ `authManager.shouldShowPGSwitcher` returns `true`

**When it Hides:**

- ❌ User has only 1 PG → No dropdown shown, cleaner UI

---

### **✅ 2. VendorTabView (for VENDOR)**

**File:** `/PGEaseMobile/PGEase/PGEase/PGEaseApp.swift`  
**Lines:** 219-247

**Integration:**

```swift
struct VendorTabView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 0) {
            // ✅ PG Selector (only shows for VENDOR with multiple PGs)
            PGSelectorView()
                .environmentObject(authManager)

            TabView {
                // Orders, Inventory, Profile
            }
        }
    }
}
```

**When it Shows:**

- ✅ User role is `VENDOR`
- ✅ User supplies to multiple PGs (5+)
- ✅ `authManager.shouldShowPGSwitcher` returns `true`

**When it Hides:**

- ❌ Vendor has only 1 PG → No dropdown shown

---

## 🚫 **Where PGSelectorView is NOT Shown**

### **❌ 1. WardenTabView**

**Reason:** WARDEN role is single-PG only (works at 1 PG)

```swift
struct WardenTabView: View {
    var body: some View {
        TabView {
            // No PGSelectorView
            // Attendance, Reports, Profile
        }
    }
}
```

---

### **❌ 2. AccountantTabView**

**Reason:** ACCOUNTANT role is single-PG only (handles 1 PG's finances)

```swift
struct AccountantTabView: View {
    var body: some View {
        TabView {
            // No PGSelectorView
            // Finances, Reports, Profile
        }
    }
}
```

---

### **❌ 3. MainTabView (Student/Staff)**

**Reason:** STUDENT and STAFF are single-PG only (reside/work at 1 PG)

```swift
struct MainTabView: View {
    var body: some View {
        TabView {
            // No PGSelectorView
            // Home, Check-in, Profile
        }
    }
}
```

---

## 🎯 **How the Conditional Display Works**

### **Inside PGSelectorView:**

```swift
struct PGSelectorView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        // ✅ Only show if user has multiple PGs
        if authManager.shouldShowPGSwitcher {
            // Show PG dropdown UI
            HStack {
                Image(systemName: "building.2.fill")
                Text(currentPGName)
                // ...
            }
        }
        // If shouldShowPGSwitcher is false, nothing is rendered
    }
}
```

### **AuthManager Logic:**

```swift
// In AuthManager
var shouldShowPGSwitcher: Bool {
    return needsPGSwitcher && availablePGs.count > 1
}

// needsPGSwitcher is set when loading PGs:
func loadUserPGs() async {
    let response = try await apiManager.getUserPGs(userId: userId)

    // ✅ Only true for PGADMIN/VENDOR with multiple PGs
    self.needsPGSwitcher = (userRole == .pgAdmin || userRole == .vendor)
                        && response.data.pgs.count > 1
}
```

---

## 📊 **Integration Matrix**

| User Role           | Tab View          | PGSelectorView | Condition                 |
| ------------------- | ----------------- | -------------- | ------------------------- |
| **PGADMIN** (1 PG)  | ManagerTabView    | ❌ Hidden      | `availablePGs.count == 1` |
| **PGADMIN** (3 PGs) | ManagerTabView    | ✅ **Shown**   | `availablePGs.count > 1`  |
| **VENDOR** (1 PG)   | VendorTabView     | ❌ Hidden      | `availablePGs.count == 1` |
| **VENDOR** (5 PGs)  | VendorTabView     | ✅ **Shown**   | `availablePGs.count > 1`  |
| **MANAGER**         | ManagerTabView    | ❌ Hidden      | Single-PG role            |
| **WARDEN**          | WardenTabView     | ❌ Hidden      | Single-PG role            |
| **ACCOUNTANT**      | AccountantTabView | ❌ Hidden      | Single-PG role            |
| **STAFF**           | MainTabView       | ❌ Hidden      | Single-PG role            |
| **STUDENT**         | MainTabView       | ❌ Hidden      | Single-PG role            |

---

## 🖼️ **Visual Layout**

### **With PGSelectorView (Multi-PG User):**

```
┌─────────────────────────────────┐
│  🏢 Current PG                  │  ← PGSelectorView
│  Sunrise PG               ▼     │
├─────────────────────────────────┤
│  📊 Dashboard  👥 Students  ... │  ← TabView
├─────────────────────────────────┤
│                                 │
│     Dashboard Content           │
│                                 │
└─────────────────────────────────┘
```

### **Without PGSelectorView (Single-PG User):**

```
┌─────────────────────────────────┐
│  📊 Dashboard  👥 Students  ... │  ← TabView (no selector)
├─────────────────────────────────┤
│                                 │
│     Dashboard Content           │
│                                 │
└─────────────────────────────────┘
```

---

## ✅ **Integration Checklist**

- [x] PGSelectorView created (`/Views/PGSelectorView.swift`)
- [x] Integrated in `ManagerTabView` (line 132)
- [x] Integrated in `VendorTabView` (line 225)
- [x] Conditional rendering logic implemented
- [x] AuthManager dependency passed via `@EnvironmentObject`
- [x] `shouldShowPGSwitcher` computed property works correctly
- [x] NOT added to single-PG role tab views

---

## 🧪 **Testing Scenarios**

### **Test 1: PGADMIN with 3 PGs**

1. Login as PGADMIN user with 3 PG associations
2. App should show ManagerTabView
3. **✅ PGSelectorView should be visible** at the top
4. Dropdown should list all 3 PGs
5. Switching PG should update entire app context

### **Test 2: MANAGER with 1 PG**

1. Login as MANAGER user with 1 PG association
2. App should show ManagerTabView
3. **❌ PGSelectorView should be hidden**
4. Static PG name shown in navigation (optional)
5. All operations auto-scoped to their single PG

### **Test 3: VENDOR with 5 PGs**

1. Login as VENDOR user with 5 PG associations
2. App should show VendorTabView
3. **✅ PGSelectorView should be visible**
4. Dropdown should list all 5 PGs
5. Orders/inventory filtered by selected PG

### **Test 4: WARDEN with 1 PG**

1. Login as WARDEN user
2. App should show WardenTabView
3. **❌ PGSelectorView should NOT be present**
4. No VStack wrapper, just TabView directly

---

## 🔄 **Data Flow**

```
1. App Launch
   ↓
2. AuthManager.loadSavedUser()
   ↓
3. loadUserPGs() → GET /api/user/pgs
   ↓
4. Backend returns user's PGs
   ↓
5. AuthManager updates:
   - availablePGs = [pg1, pg2, pg3]
   - currentPgId = "pg1"
   - needsPGSwitcher = true (if PGADMIN/VENDOR & count > 1)
   ↓
6. PGSelectorView checks shouldShowPGSwitcher
   ↓
7a. If true → Renders dropdown
7b. If false → Renders nothing (empty view)
   ↓
8. User switches PG
   ↓
9. switchPG(pgId) → POST /api/user/switch-pg
   ↓
10. AuthManager.currentPgId updated
   ↓
11. NFCTagManager uses new PG context
```

---

## 📝 **Summary**

**Where PGSelectorView is Integrated:**

- ✅ ManagerTabView (lines 132-133)
- ✅ VendorTabView (lines 225-226)

**Total Integrations:** 2 views  
**Conditional Display:** Yes (only for multi-PG users)  
**Roles Supported:** PGADMIN, VENDOR (with 2+ PGs)

**The component is now fully integrated and ready for testing!** 🎉
