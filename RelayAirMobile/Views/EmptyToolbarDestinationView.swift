import SwiftUI

struct EmptyToolbarDestinationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .navigationBarBackButtonHidden()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaBar(edge: .top) {
                HStack {
                    Spacer()
                    CircularButton(icon: "xmark") { dismiss() }
                        .accessibilityLabel("Close")
                }
                .padding(.horizontal, 16)
            }
    }
}
