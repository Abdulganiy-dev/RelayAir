//
//  MiniCardShowcase.swift
//  RelayAir
//
//  Created by ABDULGANIY LAWAL on 06/08/2026.
//
//  A shelf of the mini cards for looking at them on device. Deliberately plain:
//  no scroll transitions, no scale effects, nothing that would distort a card
//  while it is being judged.
//

import SwiftUI

struct MiniCardShowcase: View {
    @Environment(\.dismiss) private var dismiss

    /// The app pins itself to light, so the showcase carries its own switch —
    /// otherwise the dark variants are unreachable on device.
    @State private var previewDark = false

    private var scheme: ColorScheme { previewDark ? .dark : .light }

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                HStack(spacing: 24) {
                    ForEach(Kind.allCases) { kind in
                        VStack(spacing: 16) {
                            tile(for: kind)
                            Text(kind.title)
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.3)
                                .foregroundStyle(AppColors.textMute(colorScheme: scheme))
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 32)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .safeAreaPadding(.horizontal, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background(colorScheme: scheme).ignoresSafeArea())
            .navigationTitle("Design Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        previewDark.toggle()
                    } label: {
                        Image(systemName: previewDark ? "moon" : "sun.max")
                            .contentTransition(.symbolEffect(.replace))
                            .foregroundStyle(AppColors.iconInverted(colorScheme: scheme).gradient)
                    }
                    .hapticFeedback(style: .soft)
                    .buttonStyle(BouncyButton())
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .environment(\.colorScheme, scheme)
    }

    @ViewBuilder
    private func tile(for kind: Kind) -> some View {
        switch kind {
        case .credit:   CreditCardMini()
        case .passport: PassportMini()
        case .address:  AddressMini()
        }
    }

    private enum Kind: String, CaseIterable, Identifiable {
        case credit, passport, address

        var id: String { rawValue }

        var title: String {
            switch self {
            case .credit:   "CARD"
            case .passport: "PASSPORT"
            case .address:  "ADDRESS"
            }
        }
    }
}

#Preview {
    MiniCardShowcase()
}
