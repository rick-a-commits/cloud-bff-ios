import SwiftUI

struct DOBGateView: View {
    @State private var onboarding = OnboardingService.shared
    @State private var auth = AuthService.shared
    @State private var selectedDate: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()

    var body: some View {
        switch onboarding.status {
        case .underage:
            underageView
        case .checkFailed:
            retryView
        default:
            dobEntryView
        }
    }

    // MARK: - DOB entry

    private var dobEntryView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 44))
                    .foregroundColor(Color(hex: "6C63FF"))

                Text("When's your birthday?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Text("PushThru requires users to be at least 16 years old.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            DatePicker(
                "Date of birth",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding(.horizontal, 24)

            Spacer()

            Button(action: {
                Task { await onboarding.submitDateOfBirth(selectedDate) }
            }) {
                if onboarding.isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                } else {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "6C63FF"))
            )
            .disabled(onboarding.isSubmitting)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Underage block

    private var underageView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary)

                Text("You need to be 16 or older")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Text("PushThru isn't available for users under 16. If you believe this is a mistake, please contact support@pushthru.app.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button(action: {
                auth.signOut()
            }) {
                Text("Sign Out")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Network failure

    private var retryView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Couldn't reach PushThru")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Text("Check your connection and try again.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    Task { await onboarding.checkProfile() }
                }) {
                    Text("Try Again")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: "6C63FF"))
                        )
                }

                // Escape hatch: if the network stays down, the user can back
                // out to Welcome instead of being stuck on this screen forever.
                Button(action: {
                    auth.signOut()
                }) {
                    Text("Sign Out")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    DOBGateView()
        .preferredColorScheme(.dark)
}
