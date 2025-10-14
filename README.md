# PGEase iOS Mobile App

**Platform:** iOS (Swift/SwiftUI)  
**Minimum iOS Version:** 14.0+  
**Backend API:** https://pg-ease.vercel.app/api

---

## 📱 **Overview**

PGEase is a unified mobile app for managing Paying Guest (PG) accommodations. It supports multiple user roles including Students, Staff, Managers, Wardens, Accountants, PG Admins, and Vendors.

---

## 📚 **Documentation**

### **Implementation Guide**

👉 **[IOS_IMPLEMENTATION_GUIDE.md](./IOS_IMPLEMENTATION_GUIDE.md)** - Complete implementation guide with:

- Current state analysis
- Required changes
- API integration guide
- Onboarding flow
- Check-in/out flow
- Deboarding flow
- Multi-role architecture
- Implementation checklist
- Code examples

### **Related Documentation**

- [BIOMETRIC_VERIFICATION_FLOW.md](../../pgease/BIOMETRIC_VERIFICATION_FLOW.md) - Biometric authentication flow
- [UNIFIED_MOBILE_APP_ARCHITECTURE.md](../../pgease/UNIFIED_MOBILE_APP_ARCHITECTURE.md) - Multi-role app architecture
- [STUDENT_ONBOARDING_GUIDE.md](../../pgease/STUDENT_ONBOARDING_GUIDE.md) - Student onboarding process
- [USER_STORIES_ONBOARDING.md](../../pgease/USER_STORIES_ONBOARDING.md) - User stories and scenarios

---

## 🏗️ **Project Structure**

```
PGEase/
├── Managers/                   # Business logic managers
│   ├── APIManager.swift        # API client
│   ├── BiometricAuthManager.swift
│   ├── CheckInOutManager.swift
│   ├── OnboardingManager.swift
│   ├── NFCManager.swift
│   └── ...
├── Views/                      # SwiftUI views
│   ├── OnboardingView.swift
│   ├── MainTabView.swift
│   ├── LoginView.swift         # ⚠️ Needs creation
│   └── ...
├── Models/                     # Data models
│   └── ScanResult.swift
└── Assets.xcassets/           # Images and colors
```

---

## 🚀 **Quick Start**

### **Prerequisites**

- Xcode 14.0+
- iOS 14.0+ device or simulator
- Apple Developer account (for biometric testing)

### **Setup**

1. Clone the repository
2. Open `PGEase.xcodeproj` in Xcode
3. Update the base URL in `APIManager.swift` (if needed)
4. Build and run on device or simulator

### **Testing Onboarding**

1. Get an invite code from the web app (Manager dashboard)
2. Open the mobile app
3. Enter the 6-digit invite code
4. Complete biometric setup
5. Wait for manager approval

---

## 🔑 **Key Features**

### **Current Features (Implemented)**

✅ Student onboarding with invite code  
✅ Biometric authentication (Face ID/Touch ID)  
✅ Device linking  
✅ Check-in/out with biometric verification  
✅ NFC tag scanning  
✅ Location tracking

### **Upcoming Features (Needs Implementation)**

⚠️ Staff onboarding  
⚠️ Multi-role support  
⚠️ Deboarding (permanent checkout)  
⚠️ Role-based navigation  
⚠️ Manager dashboard  
⚠️ Warden dashboard

---

## 🔧 **Current State**

### **What Works**

✅ **OnboardingManager**: Student onboarding flow  
✅ **BiometricAuthManager**: Face ID/Touch ID authentication  
✅ **CheckInOutManager**: Daily check-in/out  
✅ **APIManager**: API client with student endpoints  
✅ **OnboardingView**: Onboarding UI

### **What Needs Updates**

⚠️ **APIManager**: Missing staff APIs, needs userType parameter  
⚠️ **CheckInOutManager**: Hardcoded for students only  
⚠️ **OnboardingManager**: Student-only, needs staff support  
⚠️ **MainTabView**: No role-based navigation  
⚠️ **LoginView**: Doesn't exist yet  
⚠️ **DeboardingView**: Doesn't exist yet

---

## 📋 **Implementation Checklist**

### **Phase 1: Critical Updates (Week 1)**

- [ ] Update APIManager with staff APIs
- [ ] Update CheckInOutManager with userType support
- [ ] Update OnboardingManager for staff
- [ ] Create AuthManager for role detection
- [ ] Create LoginView
- [ ] Create DeboardingView

### **Phase 2: Multi-Role Support (Week 2)**

- [ ] Update PGEaseApp with role-based routing
- [ ] Create StudentTabView
- [ ] Create StaffTabView
- [ ] Add role-specific dashboards

### **Phase 3: Testing & Polish (Week 3)**

- [ ] Test all flows (student, staff, check-in, deboard)
- [ ] Add error handling
- [ ] Add loading indicators
- [ ] Improve UI/UX

---

## 🔌 **API Endpoints**

### **Student Onboarding**

- `POST /api/onboarding/link-device` - Link device with invite code
- `POST /api/onboarding/biometric-setup` - Setup biometric auth
- `GET /api/onboarding/biometric-setup?studentId=...` - Check status

### **Staff Onboarding**

- `POST /api/staff/onboarding/link-device` - Link device with invite code
- `POST /api/staff/onboarding/biometric-setup` - Setup biometric auth
- `GET /api/staff/onboarding/biometric-setup?staffId=...` - Check status

### **Check-In/Out**

- `POST /api/check-in-out/checkin` - Daily check-in
- `POST /api/check-in-out/checkout` - Daily check-out

### **Deboarding**

- `POST /api/student/deboard` - Permanent student checkout
- `POST /api/staff/deboard` - Staff termination

### **Biometric Verification**

- `POST /api/biometric/verify` - Verify biometric signature
- `GET /api/biometric/verify?studentId=...` - Check verification status

---

## 🔐 **Security**

### **Biometric Authentication**

- Uses iOS LocalAuthentication framework
- Face ID/Touch ID for secure access
- Server-side verification of biometric signatures
- Device binding to prevent sharing

### **Data Storage**

- User data stored in UserDefaults (non-sensitive)
- Biometric templates stored on server (encrypted)
- Device ID generated and stored locally
- No sensitive data in app storage

---

## 🐛 **Known Issues**

1. **OnboardingManager**: Only supports students
2. **CheckInOutManager**: Hardcoded for students
3. **No role-based navigation**: All users see same UI
4. **No deboarding**: Can't permanently leave PG
5. **No staff support**: Staff can't onboard

---

## 📞 **Support**

For issues or questions:

- Check [IOS_IMPLEMENTATION_GUIDE.md](./IOS_IMPLEMENTATION_GUIDE.md)
- Review backend API documentation
- Contact development team

---

## 📄 **License**

Proprietary - PGEase

---

**Last Updated:** October 13, 2025  
**Version:** 1.0  
**Status:** In Development
