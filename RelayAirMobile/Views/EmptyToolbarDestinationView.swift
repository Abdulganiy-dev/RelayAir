import SwiftUI

struct EmptyToolbarDestinationView: View {
    @Environment(RelayNavigationStore.self) private var navigation

    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaBar(edge: .top) {
                HStack {
                    CircularButton(icon: "chevron.left") { navigation.pop() }
                        .accessibilityLabel("Back")
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
    }
}
