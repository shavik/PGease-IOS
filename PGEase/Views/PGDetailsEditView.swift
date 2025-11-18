import SwiftUI

struct PGDetailsEditView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var phone: String = ""
    @State private var city: String = ""
    @State private var stateField: String = ""
    @State private var pincode: String = ""
    @State private var approximateCapacity: Int = 0
    @State private var pgType: String = ""
    @State private var curfewHour: Int = 21
    @State private var curfewMinute: Int = 0
    
    @State private var loadedDetails: PGDetail?
    
    private let apiManager = APIManager.shared
    private let pgTypes = ["BOYS", "GIRLS", "CO_ED"]
    
    var body: some View {
        Form {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading PG details...")
                        Spacer()
                    }
                }
            } else {
                Section(header: Text("Basic Information")) {
                    TextField("PG Name", text: $name)
                        .textContentType(.organizationName)
                    
                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(1...4)
                    
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    
                    Picker("PG Type", selection: Binding<String>(get: {
                        pgType
                    }, set: { newValue in
                        pgType = newValue
                    })) {
                        Text("Not set").tag("")
                        ForEach(pgTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }
                
                Section(header: Text("Location")) {
                    TextField("City", text: $city)
                    TextField("State", text: $stateField)
                    TextField("Pincode", text: $pincode)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Capacity")) {
                    Stepper(value: $approximateCapacity, in: 0...5000) {
                        Text("Approximate Capacity: \(approximateCapacity)")
                    }
                }
                
                Section(header: Text("Curfew")) {
                    Stepper(value: $curfewHour, in: 0...23) {
                        Text("Curfew Hour: \(curfewHour)h")
                    }
                    
                    Stepper(value: $curfewMinute, in: 0...59, step: 5) {
                        Text("Curfew Minute: \(curfewMinute)m")
                    }
                }
            }
        }
        .navigationTitle("Edit PG Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await saveChanges()
                    }
                }
                .disabled(isLoading || isSaving || !canSave)
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {
                if alertTitle == "Success" {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .task {
            await loadDetails()
        }
    }
    
    private var canSave: Bool {
        guard let loaded = loadedDetails else { return false }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return name != loaded.name ||
            address != (loaded.address ?? "") ||
            phone != (loaded.phone ?? "") ||
            city != (loaded.city ?? "") ||
            stateField != (loaded.state ?? "") ||
            pincode != (loaded.pincode ?? "") ||
            approximateCapacity != (loaded.approximateCapacity ?? 0) ||
            pgType != (loaded.pgType ?? "") ||
            curfewHour != (loaded.curfewHour ?? 21) ||
            curfewMinute != (loaded.curfewMinute ?? 0)
    }
    
    private func loadDetails() async {
        guard let pgId = authManager.currentPgId else { return }
        isLoading = true
        do {
            let response = try await apiManager.getPGDetails(pgId: pgId)
            await MainActor.run {
                self.loadedDetails = response.data
                self.name = response.data.name
                self.address = response.data.address ?? ""
                self.phone = response.data.phone ?? ""
                self.city = response.data.city ?? ""
                self.stateField = response.data.state ?? ""
                self.pincode = response.data.pincode ?? ""
                self.approximateCapacity = response.data.approximateCapacity ?? 0
                self.pgType = response.data.pgType ?? ""
                self.curfewHour = response.data.curfewHour ?? 21
                self.curfewMinute = response.data.curfewMinute ?? 0
            }
        } catch {
            await MainActor.run {
                alertTitle = "Error"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func saveChanges() async {
        guard let pgId = authManager.currentPgId,
              let userId = authManager.currentUser?.id else {
            alertTitle = "Error"
            alertMessage = "Missing PG or user information."
            showAlert = true
            return
        }
        
        isSaving = true
        let request = UpdatePGDetailsRequest(
            name: name,
            address: address,
            phone: phone,
            city: city,
            state: stateField,
            pincode: pincode,
            approximateCapacity: approximateCapacity,
            pgType: pgType.isEmpty ? nil : pgType,
            curfewHour: curfewHour,
            curfewMinute: curfewMinute
        )
        
        do {
            let response = try await apiManager.updatePGDetails(
                pgId: pgId,
                userId: userId,
                request: request
            )
            await MainActor.run {
                loadedDetails = response.data
                alertTitle = "Success"
                alertMessage = response.message ?? "PG details updated successfully."
                showAlert = true
            }
        } catch {
            await MainActor.run {
                alertTitle = "Error"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
        
        await MainActor.run {
            isSaving = false
        }
    }
}

