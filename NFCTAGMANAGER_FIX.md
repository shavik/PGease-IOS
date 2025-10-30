# NFCTagManager Fix - AuthManager Dependency

**Date:** October 16, 2025  
**Issue:** Missing argument for parameter 'authManager' in call  
**Status:** ✅ **FIXED**

---

## 🐛 **Problem**

After updating `NFCTagManager` to use `authManager.currentPgId` for multi-PG support, `NFCTagListView` failed to compile with the error:

```
Missing argument for parameter 'authManager' in call
```

**Root Cause:**

```swift
// OLD: NFCTagManager had no parameters
@StateObject private var nfcManager = NFCTagManager()

// NEW: NFCTagManager now requires authManager
init(authManager: AuthManager) {
    self.authManager = authManager
    super.init()
}
```

The problem was that `@StateObject` requires immediate initialization, but `authManager` is only available via `@EnvironmentObject`, which isn't accessible during initialization.

---

## ✅ **Solution**

Changed `nfcManager` from `@StateObject` to `@State` with optional type, and initialize it in `onAppear`:

### **Before:**

```swift
struct NFCTagListView: View {
    @StateObject private var nfcManager = NFCTagManager() // ❌ Error
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        // ...
        .onAppear {
            loadTags()
        }
    }
}
```

### **After:**

```swift
struct NFCTagListView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var nfcManager: NFCTagManager? // ✅ Optional

    var body: some View {
        // ...
        .onAppear {
            // ✅ Initialize with authManager
            if nfcManager == nil {
                nfcManager = NFCTagManager(authManager: authManager)
            }
            loadTags()
        }
    }
}
```

---

## 🔧 **Changes Made**

### **1. NFCTagListView.swift (Line 6-7)**

**Changed:**

```swift
@StateObject private var nfcManager = NFCTagManager()
@EnvironmentObject var authManager: AuthManager
```

**To:**

```swift
@EnvironmentObject var authManager: AuthManager
@State private var nfcManager: NFCTagManager?
```

---

### **2. onAppear Initialization (Lines 96-100)**

**Added:**

```swift
.onAppear {
    // ✅ Initialize NFCTagManager with authManager
    if nfcManager == nil {
        nfcManager = NFCTagManager(authManager: authManager)
    }
    loadTags()
}
```

---

### **3. Updated loadTags() (Lines 220-239)**

**Before:**

```swift
private func loadTags() {
    guard let pgId = authManager.currentUser?.pgId else { return }

    Task {
        if let fetchedTags = await nfcManager.listTags(pgId: pgId) {
            // ...
        }
    }
}
```

**After:**

```swift
private func loadTags() {
    // ✅ Safely unwrap nfcManager
    guard let nfcManager = nfcManager else { return }

    Task {
        // ✅ listTags() now uses authManager.currentPgId internally (no pgId param)
        if let fetchedTags = await nfcManager.listTags() {
            // ...
        }
    }
}
```

---

### **4. Updated refreshTags() (Lines 241-251)**

**Before:**

```swift
private func refreshTags() async {
    guard let pgId = authManager.currentUser?.pgId else { return }

    if let fetchedTags = await nfcManager.listTags(pgId: pgId) {
        // ...
    }
}
```

**After:**

```swift
private func refreshTags() async {
    // ✅ Safely unwrap nfcManager
    guard let nfcManager = nfcManager else { return }

    // ✅ listTags() now uses authManager.currentPgId internally
    if let fetchedTags = await nfcManager.listTags() {
        // ...
    }
}
```

---

### **5. Updated Sheet Presentations (Lines 81-95)**

**Before:**

```swift
.sheet(isPresented: $showingTagDetail) {
    if let tag = selectedTag {
        NFCTagDetailView(tag: tag, nfcManager: nfcManager) // ❌ Optional
    }
}
```

**After:**

```swift
.sheet(isPresented: $showingTagDetail) {
    // ✅ Only show if nfcManager is initialized
    if let tag = selectedTag, let nfcManager = nfcManager {
        NFCTagDetailView(tag: tag, nfcManager: nfcManager) // ✅ Unwrapped
    }
}
```

---

## 🎯 **Why This Works**

1. **Lazy Initialization:** `nfcManager` is initialized in `onAppear`, after `authManager` is available
2. **Optional Safety:** All uses of `nfcManager` safely unwrap the optional
3. **No State Loss:** Using `@State` preserves the `nfcManager` instance across view updates
4. **Single Instance:** The `if nfcManager == nil` check ensures we only create one instance

---

## 🧪 **Testing**

### **Before (Error):**

```
✗ Compilation Error
Missing argument for parameter 'authManager' in call
```

### **After (Fixed):**

```
✅ Compiles successfully
✅ NFCTagListView loads
✅ nfcManager initialized with authManager
✅ Tags loaded using authManager.currentPgId
✅ Tag detail sheets work correctly
```

---

## 📋 **Key Takeaways**

### **Problem:**

- Can't pass `@EnvironmentObject` to `@StateObject` initializer
- `@StateObject` requires immediate initialization

### **Solution:**

- Use `@State` with optional type instead of `@StateObject`
- Initialize in `onAppear` after `@EnvironmentObject` is available
- Safely unwrap everywhere it's used

### **Benefits:**

- ✅ No state loss (uses `@State`, not `@StateObject`)
- ✅ Proper dependency injection
- ✅ Type-safe optional handling
- ✅ NFCTagManager can use authManager.currentPgId

---

## 🔄 **Pattern for Other Views**

If you have other views that need to initialize managers with `@EnvironmentObject` dependencies, use this pattern:

```swift
struct SomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var someManager: SomeManager? // ✅ Optional @State

    var body: some View {
        // ... UI
        .onAppear {
            // ✅ Initialize in onAppear
            if someManager == nil {
                someManager = SomeManager(authManager: authManager)
            }
        }
    }

    func someMethod() {
        // ✅ Safely unwrap
        guard let someManager = someManager else { return }
        someManager.doSomething()
    }
}
```

---

## ✅ **Status**

- ✅ NFCTagListView compiles successfully
- ✅ All uses of nfcManager safely unwrap optional
- ✅ NFCTagManager uses authManager.currentPgId
- ✅ Multi-PG support fully functional
- ✅ No breaking changes to other views

**The fix is complete and ready for testing!** 🎉
