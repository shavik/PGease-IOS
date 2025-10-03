import SwiftUI
import CoreNFC

struct NFCView: View {
    @StateObject private var nfcManager = NFCManager()
    @State private var messageToWrite = ""
    @State private var showingWriteForm = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("NFC Reader & Writer")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Read and write NFC tags with your device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                Spacer()
                
                // NFC Status
                if nfcManager.isScanning || nfcManager.isWriting {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text(nfcManager.isWriting ? "Writing to NFC tag..." : "Scanning for NFC tag...")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("Hold your device near an NFC tag")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Last Read Message
                if !nfcManager.lastReadMessage.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Read Message:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(nfcManager.lastReadMessage)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                // Write Success Message
                if nfcManager.writeSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Message written successfully!")
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Error Message
                if !nfcManager.errorMessage.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(nfcManager.errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Read NFC Button
                    Button(action: {
                        nfcManager.startReading()
                    }) {
                        HStack {
                            Image(systemName: "wave.3.right")
                                .font(.title2)
                            Text("Read NFC Tag")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(nfcManager.isScanning || nfcManager.isWriting)
                    
                    // Write NFC Button
                    Button(action: {
                        showingWriteForm = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                                .font(.title2)
                            Text("Write to NFC Tag")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(nfcManager.isScanning || nfcManager.isWriting)
                    
                    // Stop Button (when scanning/writing)
                    if nfcManager.isScanning || nfcManager.isWriting {
                        Button(action: {
                            nfcManager.stopReading()
                        }) {
                            HStack {
                                Image(systemName: "stop.fill")
                                    .font(.title2)
                                Text("Stop")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("NFC")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingWriteForm) {
            NFCWriteFormView(
                message: $messageToWrite,
                onWrite: { message in
                    nfcManager.writeToNFC(message: message)
                    showingWriteForm = false
                }
            )
        }
        .onAppear {
            // Check NFC availability
            if !NFCNDEFReaderSession.readingAvailable {
                nfcManager.errorMessage = "NFC is not available on this device"
            }
        }
    }
}

struct NFCWriteFormView: View {
    @Binding var message: String
    let onWrite: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var tempMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Write to NFC Tag")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter the message you want to write to the NFC tag")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Message Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextEditor(text: $tempMessage)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    
                    Text("\(tempMessage.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        onWrite(tempMessage)
                    }) {
                        HStack {
                            Image(systemName: "wave.3.right")
                                .font(.title2)
                            Text("Write to NFC Tag")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(tempMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(tempMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Write NFC")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            tempMessage = message
        }
    }
}

#Preview {
    NFCView()
}
