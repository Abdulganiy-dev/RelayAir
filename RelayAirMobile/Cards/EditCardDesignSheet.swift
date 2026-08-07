//
//  EditCardDesignSheet.swift
//  RelayAirMobile
//
//  Sheet for dressing the card — card + background picker, with Portal destination.
//

import SwiftUI
import PortalTransitions

struct EditCardDesignSheet: View {
    @Binding var background: CardBackground
    @Binding var kind: CardBackgroundKind
    let portalID: String
    let portalNamespace: Namespace.ID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var cardSize: CGSize { EditableCard.compact }

    var body: some View {
        VStack(spacing: 16) {
            EditableCard(background: background, size: cardSize)
                .portal(id: portalID, as: .destination, in: portalNamespace)
                .padding(.top, Tokens.topPadding)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

            ScrollView {
                CardBackgroundPicker(background: $background, kind: $kind)
                    .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
        }
        .background(AppColors.background(colorScheme: colorScheme).ignoresSafeArea())
        .safeAreaBar(edge: .top) {
            HStack {
                Spacer()
                CircularButton(icon: "xmark") {
                    dismiss()
                }
            }
            .padding(.horizontal, 16)
        }
        .fontDesign(Tokens.fontDesign)
        .onChange(of: kind) { _, newKind in
            guard background.kind != newKind else { return }
            background = switch newKind {
            case .colour:   .solid(CardSolid.palette[0])
            case .gradient: .gradient(CardGradient.palette[1])
            }
        }
    }
}

#Preview {
    @Previewable @Namespace var namespace
    EditCardDesignSheet(
        background: .constant(.default),
        kind: .constant(.gradient),
        portalID: "previewCard",
        portalNamespace: namespace
    )
}
