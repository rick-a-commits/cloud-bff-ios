import SwiftUI

struct WelcomeView: View {
    let onSignIn: () -> Void
    let onCreateAccount: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo and tagline
            VStack(spacing: 20) {
                Image("PushThruLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                
                Text("Your training partner")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: onSignIn) {
                    Text("Sign in")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: "6C63FF"))
                        )
                }
                
                Button(action: onCreateAccount) {
                    Text("Create account")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "6C63FF"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "6C63FF"), lineWidth: 1.5)
                        )
                }
            }
            .padding(.horizontal, 24)
            
            // Legal footer
            legalFooter
                .padding(.top, 20)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
    }
    
    private var legalFooter: some View {
        // The tappable "Terms" and "Privacy Policy" links open in Safari.
        // Replace these URLs with your real legal pages before launch.
        VStack(spacing: 4) {
            Text("By continuing, you agree to our")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Link("Terms of Service", destination: URL(string: "https://pushthru.app/terms")!)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "6C63FF"))
                
                Text("and")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Link("Privacy Policy", destination: URL(string: "https://pushthru.app/privacy")!)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "6C63FF"))
            }
        }
        .multilineTextAlignment(.center)
    }
}

#Preview {
    WelcomeView(
        onSignIn: { print("Sign in tapped") },
        onCreateAccount: { print("Create account tapped") }
    )
    .preferredColorScheme(.dark)
}
