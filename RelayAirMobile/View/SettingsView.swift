import SwiftUI

enum RelayAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .system: "iphone"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearanceRawValue = RelayAppearance.system.rawValue
    @AppStorage("wantsHaptics") private var wantsHaptics = true
    @State private var isAppearancePickerPresented = false

    private var appearance: RelayAppearance {
        RelayAppearance(rawValue: appearanceRawValue) ?? .system
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
         
                  

                    VStack(spacing: 0) {
                        appearanceRow
                            .padding(.bottom, 10)

                        hapticsRow
                            .padding(.bottom, 10)
                    }
                
                .padding(.horizontal)
                
            }
            .scrollIndicators(.hidden)

            if isAppearancePickerPresented {
                Color.black.opacity(colorScheme == .dark ? 0.42 : 0.24)
                    .ignoresSafeArea()
                    .onTapGesture(perform: closeAppearancePicker)
                    .transition(.opacity)

                RelayAppearancePicker(
                    selectedAppearance: appearance,
                    onSelect: { selectedAppearance in
                        appearanceRawValue = selectedAppearance.rawValue
                        closeAppearancePicker()
                    },
                    onClose: closeAppearancePicker
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .customTextStyle(.sectionHeading)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                }
                .accessibilityLabel("Close settings")
            }
        }
        .toolbar(.hidden, for: .bottomBar)
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: isAppearancePickerPresented)
        .animation(.easeOut(duration: 0.25), value: appearanceRawValue)
    }

    private var appearanceRow: some View {
        Button {
            isAppearancePickerPresented = true
        } label: {
            HStack {
                SettingsItemIcon(symbolName: appearance.symbolName)

                Text("Appearance")
                    .customTextStyle(.body)

                Spacer()

                Text(appearance.title)
                    .customTextStyle(.body, color: .muted)
            }
            .padding(16)
            .hireThemSettingsBackground(cornerRadius: 20)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .hapticFeedback(style: .light)
    }

    private var hapticsRow: some View {
        Toggle(isOn: $wantsHaptics) {
            HStack {
                SettingsItemIcon(symbolName: "hand.tap.fill")

                Text("Haptics")
                    .customTextStyle(.body)

                Spacer(minLength: 0)
            }
        }
        .tint(AppColors.lightColors.primaryPrimaryDefault)
        .padding(16)
        .hireThemSettingsBackground(cornerRadius: 20)
        .hapticFeedback(style: .light)
    }

    private var settingsIconGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#B0B0B5"), Color(hex: "#77777C")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func closeAppearancePicker() {
        isAppearancePickerPresented = false
    }
}

private struct SettingsItemIcon: View {
    let symbolName: String

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: "#B0B0B5"), Color(hex: "#77777C")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 24, alignment: .center)
            .padding(.trailing, 10)
    }
}

private struct HireThemSettingsBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .foregroundStyle(colorScheme == .dark ? .gray.opacity(0.07) : .gray.opacity(0.13))
        )
    }
}

private extension View {
    func hireThemSettingsBackground(cornerRadius: CGFloat) -> some View {
        modifier(HireThemSettingsBackground(cornerRadius: cornerRadius))
    }
}

private struct RelayAppearancePicker: View {
    @Environment(\.colorScheme) private var colorScheme

    let selectedAppearance: RelayAppearance
    let onSelect: (RelayAppearance) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Appearance")
                    .customTextStyle(.sectionHeading)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textMute(colorScheme: colorScheme))
                        .frame(width: 32, height: 32)
                        .background(.thinMaterial, in: Circle())
                }
                .accessibilityLabel("Close appearance picker")
            }

            HStack(spacing: 12) {
                ForEach(RelayAppearance.allCases) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: option.symbolName)
                                .font(.system(size: 28, weight: .regular))
                                .foregroundStyle(AppColors.textPrimary(colorScheme: colorScheme))

                            Text(option.title)
                                .customTextStyle(.supportingEmphasis)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    selectedAppearance == option ? Color.accentColor : Color.clear,
                                    lineWidth: 2
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .hapticFeedback(style: .light)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(colorScheme == .dark ? 0.1 : 0.6), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 28, x: 0, y: 12)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .relayAppBackground()
    }
}
