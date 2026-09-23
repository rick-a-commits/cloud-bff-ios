import SwiftUI

struct Language: Identifiable, Equatable {
    let id: String        // BCP-47 code: "en", "fr", etc.
    let name: String      // Native name: "English", "Français"
    let flag: String      // Emoji flag
    
    static let all: [Language] = [
        Language(id: "en", name: "English", flag: "🇬🇧"),
        Language(id: "de", name: "Deutsch", flag: "🇩🇪"),
        Language(id: "fr", name: "Français", flag: "🇫🇷"),
        Language(id: "it", name: "Italiano", flag: "🇮🇹"),
        Language(id: "es", name: "Español", flag: "🇪🇸"),
        Language(id: "da", name: "Dansk", flag: "🇩🇰"),
            ]
}

/// Central storage for user preferences that persist across launches.
enum UserPreferences {
    private static let languageKey = "pushthru.preferredLanguage"
    
    static var preferredLanguage: String? {
        get { UserDefaults.standard.string(forKey: languageKey) }
        set { UserDefaults.standard.set(newValue, forKey: languageKey) }
    }
    
    static var hasSelectedLanguage: Bool {
        preferredLanguage != nil
    }
}

struct LanguagePickerView: View {
    let onSelect: (Language) -> Void
    @State private var selected: Language?
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo / branding
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "6C63FF"), Color(hex: "48B4E0")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                    
                    Text("☁️").font(.system(size: 36))
                }
                
                Text("PushThru")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Choose your language")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Language options
            VStack(spacing: 10) {
                ForEach(Language.all) { language in
                    LanguageRow(
                        language: language,
                        isSelected: selected?.id == language.id,
                        onTap: {
                            selected = language
                        }
                    )
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Continue button
            Button(action: {
                guard let selected = selected else { return }
                UserPreferences.preferredLanguage = selected.id
                onSelect(selected)
            }) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(selected == nil ? Color.gray.opacity(0.4) : Color(hex: "6C63FF"))
                    )
            }
            .disabled(selected == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
    }
}

struct LanguageRow: View {
    let language: Language
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(language.flag)
                    .font(.system(size: 28))
                
                Text(language.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "6C63FF"))
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(hex: "6C63FF") : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LanguagePickerView(onSelect: { _ in })
        .preferredColorScheme(.dark)
}
