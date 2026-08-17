import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var licenseKey: String = ""
    @State private var isValidating: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Background gradient effect
            VStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .blur(radius: 100)
                    .frame(width: 400, height: 400)
                    .offset(y: -200)
                Spacer()
            }
            
            ScrollView {
                VStack(spacing: 30) {
                    Spacer().frame(height: 40)
                    
                    // Logo
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(LinearGradient(colors: [Color.blue.opacity(0.8), Color.blue], startPoint: .top, endPoint: .bottom))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "shield.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color.blue.opacity(0.5), radius: 20)
                    
                    Text("ONYX SECURE ACCESS")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.blue.opacity(0.8))
                        .tracking(1.5)
                    
                    VStack(spacing: 12) {
                        Text("Activate this device")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Enter the 19-character key. Letters and numbers only. It binds this installation and is not stored on the device.")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    // Input Card
                    VStack(alignment: .leading, spacing: 15) {
                        Text("LICENSE KEY")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                        
                        HStack {
                            TextField("XXXXXXXXXXXXXXXXXXX", text: $licenseKey)
                                .foregroundColor(.white)
                                .font(.system(size: 18, design: .monospaced))
                            
                            Button(action: {
                                if let pasted = UIPasteboard.general.string {
                                    licenseKey = pasted
                                }
                            }) {
                                Text("Paste")
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(white: 0.1))
                        .cornerRadius(12)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: validateKey) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [Color.blue, Color.blue.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                                
                                if isValidating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Activate Device")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(height: 56)
                        }
                        .disabled(isValidating || licenseKey.isEmpty)
                    }
                    .padding(25)
                    .background(Color(white: 0.05))
                    .cornerRadius(24)
                    .padding(.horizontal, 20)
                    
                    Text("Protected by a device-bound P-256 key stored in Keychain. Previously activated app features remain available when the service is offline.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 50)
                    
                    Spacer()
                }
            }
        }
    }
    
    private func validateKey() {
        isValidating = true
        errorMessage = nil
        
        LicenseService.shared.validateKey(licenseKey) { result in
            DispatchQueue.main.async {
                isValidating = false
                switch result {
                case .success(let info):
                    appState.activate(with: info)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
