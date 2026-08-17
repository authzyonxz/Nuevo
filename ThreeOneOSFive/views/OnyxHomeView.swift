import SwiftUI

struct OnyxHomeView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @Binding var cleanerEnabled: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                // Header ONYX
                HStack(spacing: 15) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(AppTheme.accent)
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "cat.fill")
                            .font(.system(size: 35))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FREE FIRE TOOLKIT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                        
                        Text("ONYX FF")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Button {
                        r7x_Invalidate_8x()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                            .font(.system(size: 20))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 30)
                
                Text("A focused target workspace for Free Fire and Free Fire MAX data, patches, and injection tools.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.onyxSecondaryText)
                    .padding(.horizontal)
                
                // Status Bar
                VStack(spacing: 12) {
                    HStack {
                        Circle()
                            .fill(appState.isSupported ? .green : .red)
                            .frame(width: 8, height: 8)
                        
                        Text("Access layer ready")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text(r7x_Time_5j())
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.accent)
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    HStack {
                        Image(systemName: "key.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.onyxSecondaryText)
                        
                        Text(r7x_Mask_3h())
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AppTheme.onyxSecondaryText)
                        
                        Spacer()
                        
                        Text("Workspace ready")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.onyxSecondaryText)
                    }
                }
                .padding()
                .background(AppTheme.onyxCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal)
                
                // Quick Launch Grid
                VStack(alignment: .leading, spacing: 15) {
                    Text("QUICK LAUNCH")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.onyxSecondaryText)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        QuickLaunchCard(title: "Inject", subtitle: "Choose game target", icon: "syringe.fill", color: AppTheme.accent)
                        QuickLaunchCard(title: "Cleaner", subtitle: "Review workspace", icon: "sparkles", color: .blue)
                        QuickLaunchCard(title: "ONYX Library", subtitle: "Import packages", icon: "shippingbox.fill", color: .blue)
                        QuickLaunchCard(title: "Settings", subtitle: "Device & access", icon: "slider.horizontal.3", color: .blue)
                    }
                    .padding(.horizontal)
                }
                
                // Bottom Banner
                Text("ONYX FF · SECURE WORKSPACE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.onyxSecondaryText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.onyxCardBackground.opacity(0.5))
                    .clipShape(Capsule())
                    .padding(.horizontal)
                    .padding(.top, 10)
            }
            .padding(.bottom, 50)
        }
        .background(AppTheme.onyxBackground)
    }
}

struct QuickLaunchCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.onyxSecondaryText)
            }
        }
        .padding()
        .frame(height: 110)
        .background(AppTheme.onyxCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
