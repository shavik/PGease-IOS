//
//  InviteShareView.swift
//  PGEase
//
//  Share invite code and QR code with members
//

import SwiftUI

struct InviteShareView: View {
    let inviteData: GenerateInviteResponse.InviteData
    @Environment(\.dismiss) var dismiss
    
    @State private var showCopiedAlert = false
    @State private var qrImage: UIImage?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Invite \(inviteData.user.name)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(inviteData.user.role)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(20)
                    }
                    .padding(.top)
                    
                    // QR Code
                    VStack(spacing: 16) {
                        Text("Scan to Join")
                            .font(.headline)
                        
                        if let qrImage = qrImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 250, height: 250)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(20)
                                .shadow(radius: 5)
                        } else {
                            ProgressView()
                                .frame(width: 250, height: 250)
                        }
                    }
                    
                    // Invite Code
                    VStack(spacing: 12) {
                        Text("Invite Code")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(inviteData.inviteCode)
                                .font(.system(.title, design: .monospaced))
                                .fontWeight(.bold)
                            
                            Button(action: copyCode) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.title3)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        if showCopiedAlert {
                            Text("Copied!")
                                .font(.caption)
                                .foregroundColor(.green)
                                .transition(.opacity)
                        }
                    }
                    
                    // Expiry Info
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                        Text("Expires: \(formatDate(inviteData.expiresAt))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Share Options
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Share Invite")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Share via Messages
                        ShareButton(
                            icon: "message.fill",
                            title: "Share via Messages",
                            color: .green,
                            action: { shareViaMessages() }
                        )
                        
                        // Share via Email
                        ShareButton(
                            icon: "envelope.fill",
                            title: "Share via Email",
                            color: .blue,
                            action: { shareViaEmail() }
                        )
                        
                        // Copy Deep Link
                        ShareButton(
                            icon: "link",
                            title: "Copy Deep Link",
                            color: .purple,
                            action: { copyDeepLink() }
                        )
                        
                        // Save QR Code
                        if let qrImage = qrImage {
                            ShareButton(
                                icon: "square.and.arrow.down",
                                title: "Save QR Code",
                                color: .orange,
                                action: { saveQRCode(qrImage) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Share Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                generateQRImage()
            }
        }
    }
    
    // MARK: - Methods
    
    private func generateQRImage() {
        guard let data = inviteData.qrCode.data(using: .utf8) else { return }
        
        // Check if it's a data URL
        if inviteData.qrCode.hasPrefix("data:image/png;base64,") {
            let base64String = inviteData.qrCode.replacingOccurrences(of: "data:image/png;base64,", with: "")
            if let imageData = Data(base64Encoded: base64String) {
                qrImage = UIImage(data: imageData)
                return
            }
        }
        
        // Otherwise try to parse as regular base64
        if let imageData = Data(base64Encoded: inviteData.qrCode) {
            qrImage = UIImage(data: imageData)
        }
    }
    
    private func copyCode() {
        UIPasteboard.general.string = inviteData.inviteCode
        
        withAnimation {
            showCopiedAlert = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedAlert = false
            }
        }
    }
    
    private func copyDeepLink() {
        UIPasteboard.general.string = inviteData.deepLink
        
        withAnimation {
            showCopiedAlert = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedAlert = false
            }
        }
    }
    
    private func shareViaMessages() {
        let text = """
        Join PGEase!
        
        Invite Code: \(inviteData.inviteCode)
        Link: \(inviteData.deepLink)
        
        Download the app and use this code to join.
        """
        
        shareText(text)
    }
    
    private func shareViaEmail() {
        let text = """
        You've been invited to join PGEase as \(inviteData.user.role)!
        
        Invite Code: \(inviteData.inviteCode)
        Link: \(inviteData.deepLink)
        
        Please download the PGEase app and use this code to complete your registration.
        
        This invite expires on \(formatDate(inviteData.expiresAt)).
        """
        
        shareText(text)
    }
    
    private func shareText(_ text: String) {
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = window
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: window.bounds.midX,
                y: window.bounds.midY,
                width: 0,
                height: 0
            )
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func saveQRCode(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        withAnimation {
            showCopiedAlert = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedAlert = false
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        
        return displayFormatter.string(from: date)
    }
}

// MARK: - Share Button Component

struct ShareButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

