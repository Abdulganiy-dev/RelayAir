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

    var artworkAsset: RelayArtworkAsset {
        switch self {
        case .system: .appearanceSystem
        case .light: .appearanceLight
        case .dark: .appearanceDark
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
    @Environment(RelayNavigationStore.self) private var navigation
    @AppStorage("appearance") private var appearanceRawValue = RelayAppearance.system.rawValue
    @AppStorage("wantsHaptics") private var wantsHaptics = true
    @State private var isAppearancePickerPresented = false

    private var appearance: RelayAppearance {
        RelayAppearance(rawValue: appearanceRawValue) ?? .system
    }

    private var appearanceOptions: [RelayMenuOption] {
        RelayAppearance.allCases.map { option in
            RelayMenuOption(
                label: option.title,
                iconName: option.artworkAsset,
                isSelected: appearance == option
            ) {
                appearanceRawValue = option.rawValue
                closeAppearancePicker()
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    appearanceRow
                    hapticsRow
                }
                .padding(.horizontal)
                .padding(.top, AppDesignTokens.topPadding)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .blur(radius: isAppearancePickerPresented ? AppDesignTokens.popupBackgroundBlurRadius : 0)

            if isAppearancePickerPresented {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture(perform: closeAppearancePicker)

                RelayPopupMenu(
                    title: "Appearance",
                    subtitle: "Choose how RelayAir looks",
                    options: appearanceOptions,
                    onClose: closeAppearancePicker
                )
                .frame(maxWidth: 460)
                .padding(.horizontal, 20)
                .transition(RelayPopupMenu.presentationTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaBar(edge: .top) {
            ZStack {
                Text("Settings")
                    .customTextStyle(.sectionHeading,color: .inverted)
                    .accessibilityAddTraits(.isHeader)

                HStack {
                    CircularButton(icon: "chevron.left") { navigation.pop() }
                        .accessibilityLabel("Back")
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .blur(radius: isAppearancePickerPresented ? AppDesignTokens.popupBackgroundBlurRadius : 0)
            .allowsHitTesting(!isAppearancePickerPresented)
        }
    }

    private var appearanceRow: some View {
        Button {
            withAnimation(RelayPopupMenu.presentationAnimation) {
                isAppearancePickerPresented = true
            }
        } label: {
            HStack {
                RelayArtworkIcon(asset: appearance.artworkAsset, size: SettingsRowMetrics.iconSize)
                    .saturation(0.8)

                Text("Appearance")
                    .customTextStyle(.body)

                Spacer()

                Text(appearance.title)
                    .customTextStyle(.body, color: .muted)
            }
            .frame(minHeight: SettingsRowMetrics.contentHeight)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .relayRowBackground(cornerRadius: 18)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .frame(minHeight: SettingsRowMetrics.contentHeight)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .relayRowBackground(cornerRadius: 18)
        .hapticFeedback(style: .light)
    }

    private func closeAppearancePicker() {
        withAnimation(RelayPopupMenu.presentationAnimation) {
            isAppearancePickerPresented = false
        }
    }
}

private struct SettingsItemIcon: View {
    let symbolName: String

    private var hapticsGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#DC706A"), Color(hex: "#B94F60")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(hapticsGradient)
            .frame(width: SettingsRowMetrics.iconSize, height: SettingsRowMetrics.iconSize)
            .accessibilityHidden(true)
    }
}

private enum SettingsRowMetrics {
    static let iconSize: CGFloat = 28
    static let contentHeight: CGFloat = 36
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(RelayNavigationStore())
            .relayAppBackground()
    }
}
