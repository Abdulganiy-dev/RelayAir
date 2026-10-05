//
//  ExpandingSearchBar.swift
//  RelayAirMobile
//


import SwiftUI

struct ExpandingSearchBar<Accessory: View>: View {
    @Binding var text: String
    @Binding var isPresented: Bool
    var prompt: String = "Search"

    
    @ViewBuilder var accessory: () -> Accessory

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let size: CGFloat = 48

    private var animation: Animation {
        reduceMotion ? .smooth(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.82)
    }

    private var iconColor: Color {
        AppColors.iconInverted(colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 12) {
            searchCapsule

            if isPresented {
                CircularButton(icon: "xmark", action: dismiss)
                    .accessibilityLabel("Close search")
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                Spacer(minLength: 0)

                accessory()
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(animation, value: isPresented)
        .onChange(of: isPresented) { _, presented in
            // Kept in step with the binding so a parent can open or close search too.
            isFocused = presented
            if !presented { text = "" }
        }
    }

    private var searchCapsule: some View {
        HStack(spacing: 10) {
            if isPresented {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(iconColor.gradient)
                    .accessibilityHidden(true)

                TextField("", text: $text)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .customTextStyle(.bodyMedium, color: .inverted)
                    .tint(iconColor)
                    .placeholder(when: text.isEmpty) {
                        Text(prompt)
                            .customTextStyle(.body, color: .muted)
                    }
                    .accessibilityLabel(prompt)
                    .accessibilityAddTraits(.isSearchField)

                if !text.isEmpty {
                    Button {
                        text = ""
                        isFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(iconColor)
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .hapticFeedback(style: .light)
                    .accessibilityLabel("Clear search")
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            } else {
                // Same glyph treatment as `CircularButton`.
                Button(action: present) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(iconColor.gradient)
                        .frame(width: size, height: size)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .hapticFeedback(style: .light)
                .accessibilityLabel("Search")
            }
        }
        .padding(.horizontal, isPresented ? 16 : 0)
        .frame(width: isPresented ? nil : size, height: size)
        .frame(maxWidth: isPresented ? .infinity : size, alignment: .leading)
        .contentShape(Capsule())
        .glassEffect(.regular.interactive(), in: .capsule)
        .animation(.smooth(duration: 0.2), value: text.isEmpty)
        .accessibilityAction(.escape) {
            if isPresented { dismiss() }
        }
    }

    private func present() {
        withAnimation(animation) { isPresented = true }
    }

    private func dismiss() {
        withAnimation(animation) { isPresented = false }
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @State var isPresented = false

    VStack {
        Spacer()
        ExpandingSearchBar(text: $text, isPresented: $isPresented, prompt: "Search items") {
            CircularButton(icon: "document.viewfinder") {}
        }
        .padding(.horizontal, 24)
    }
    .relayAppBackground()
}
