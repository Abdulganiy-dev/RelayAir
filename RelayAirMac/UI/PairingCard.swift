import SwiftUI
import RelayAirCore

/// The QR pairing panel in the setup window.
///
/// Shows the code while unpaired, and collapses to a connection status line
/// once a phone is talking to us — nobody needs to stare at a QR they've
/// already scanned.
struct PairingCard: View {
    let services: AppServices

    @State private var isShowingCode = false

    private var pairing: PairingManager { services.pairing }
    private var linkState: RelayLink.State { services.relay.linkState }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow
                .padding(.horizontal, 15)
                .padding(.vertical, 12)

            Divider()

            if linkState.isConnected && !isShowingCode {
                connectedBody
            } else {
                pairingBody
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.quinary)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(linkState.isConnected ? Color.green.opacity(0.35) : Color.secondary.opacity(0.18))
        }
        .animation(.smooth(duration: 0.28), value: linkState)
    }

    // MARK: - Title

    private var titleRow: some View {
        HStack(spacing: 9) {
            Text("Your iPhone")
                .font(.headline)
            Spacer()
            Text(linkState.isConnected ? "Connected" : "Not connected")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background {
                    Capsule().fill(
                        linkState.isConnected ? Color.green.opacity(0.16) : Color.secondary.opacity(0.14)
                    )
                }
                .foregroundStyle(linkState.isConnected ? AnyShapeStyle(Color.green) : AnyShapeStyle(.secondary))
        }
    }

    // MARK: - Connected

    private var connectedBody: some View {
        HStack(spacing: 11) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 22))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(linkState.description)
                    .font(.callout.weight(.medium))
                Text("Encrypted with the code you scanned.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Show Code") { isShowingCode = true }
                .buttonStyle(.link)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
    }

    // MARK: - Pairing

    private var pairingBody: some View {
        VStack(spacing: 13) {
            if let image = pairing.qrImage(side: 190) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .frame(width: 190, height: 190)
                    .padding(9)
                    .background {
                        // The QR needs a light backing to scan reliably in
                        // dark mode, where the generated image would otherwise
                        // sit on a dark surface.
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(.white)
                    }
            } else {
                ProgressView().frame(height: 190)
            }

            Text("Open Relay Air on your iPhone and scan this code.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                if linkState.isConnected {
                    Button("Hide") { isShowingCode = false }
                }
                Spacer()
                Button("Generate New Code") {
                    pairing.regenerate()
                    services.relay.restartLink()
                }
                .help("Invalidates every iPhone already paired with this Mac.")
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 15)
        .padding(.vertical, 15)
    }
}
