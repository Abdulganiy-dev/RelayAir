import SwiftUI
import AppKit
import RelayAirCore

/// The menu-bar panel — the app's entire everyday UI.
///
/// A `.window`-style `MenuBarExtra` rather than a plain menu, because a menu
/// can't render the pairing QR. The top line always answers "what is Relay Air
/// doing right now" in the vocabulary of *Send. Approve. Fill.*
struct MenuContent: View {
    let services: AppServices

    @State private var isShowingCode = false

    private var relay: RelayController { services.relay }
    private var pairing: PairingManager { services.pairing }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if services.permissions.canControlInput {
                statusHeader
                activityRow
                Divider()
                devicesSection
                Divider()
                pairingSection
            } else {
                permissionPrompt
            }

            Divider()
            footer
        }
        .frame(width: 300)
        .animation(.smooth(duration: 0.25), value: relay.state)
        .animation(.smooth(duration: 0.25), value: pairing.devices)
        .animation(.smooth(duration: 0.25), value: isShowingCode)
        // Enrolment is only open while the code is actually on screen.
        .onChange(of: isShowingCode) { _, showing in
            showing ? pairing.beginShowingCode() : pairing.endShowingCode()
        }
        .onDisappear { pairing.endShowingCode() }
    }

    // MARK: - Status

    private var statusHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: relay.state.symbol)
                .font(.system(size: 16))
                .frame(width: 22)
                .foregroundStyle(relay.isActive ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 1) {
                Text(relay.state.statusText)
                    .font(.callout.weight(.medium))
                Text(relay.linkState.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            Toggle("", isOn: relayBinding)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .help(relay.isActive ? "Pause Relay Air" : "Resume Relay Air")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    /// The most recent transfer, and a way out of an error state.
    ///
    /// There's no approve/reject here any more: the phone asks before it sends,
    /// so by the time the Mac has the text the decision is made. This row is a
    /// receipt, not a prompt.
    @ViewBuilder
    private var activityRow: some View {
        if let fill = relay.lastFill {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text(fill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }

        if case .failed = relay.state {
            HStack {
                Spacer()
                Button("Dismiss") { relay.clearError() }
                    .buttonStyle(.link)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Devices

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paired iPhones")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if pairing.devices.isEmpty {
                Text("None yet. Show the pairing code and scan it with Relay Air on your iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(pairing.devices) { device in
                    DeviceRow(
                        device: device,
                        isConnected: relay.connectedDeviceName == device.name,
                        onUnpair: { pairing.unpair(device) }
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Pairing

    private var pairingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                isShowingCode.toggle()
            } label: {
                HStack {
                    Label(
                        isShowingCode ? "Hide Pairing Code" : "Show Pairing Code",
                        systemImage: "qrcode"
                    )
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .rotationEffect(.degrees(isShowingCode ? 90 : 0))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isShowingCode {
                VStack(spacing: 9) {
                    if let image = pairing.qrImage(side: 172) {
                        Image(nsImage: image)
                            .interpolation(.none)
                            .frame(width: 172, height: 172)
                            .padding(8)
                            // A light backing so the code still scans in dark mode.
                            .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        ProgressView().frame(height: 172)
                    }

                    Text("Scan with Relay Air on your iPhone. New devices are only accepted while this is showing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Generate New Code") {
                        pairing.regenerate()
                        relay.restartLink()
                    }
                    .controlSize(.small)
                    .help("Invalidates the code and unpairs every iPhone.")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Permission prompt

    private var permissionPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Accessibility permission required", systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.medium))
                .foregroundStyle(.orange)
            Text("Relay Air can't type into other apps until this is granted.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open Setup…") { openSetup() }
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Setup…") { openSetup() }
                .buttonStyle(.link)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.link)
                .keyboardShortcut("q")
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var relayBinding: Binding<Bool> {
        Binding(
            get: { relay.isActive },
            set: { shouldRun in
                if shouldRun {
                    relay.start()
                } else {
                    relay.stop()
                }
            }
        )
    }

    private func openSetup() {
        (NSApp.delegate as? AppDelegate)?.showOnboarding()
    }
}

// MARK: - Device row

private struct DeviceRow: View {
    let device: DeviceRecord
    let isConnected: Bool
    let onUnpair: () -> Void

    @State private var isConfirming = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 15))
                .frame(width: 20)
                .foregroundStyle(isConnected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))

            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.callout)
                    .lineLimit(1)
                Text(isConnected ? "Connected" : "Last seen \(device.lastSeenAt.relativeDescription)")
                    .font(.caption2)
                    .foregroundStyle(isConnected ? AnyShapeStyle(Color.green) : AnyShapeStyle(.secondary))
            }

            Spacer(minLength: 4)

            Button(isConfirming ? "Confirm" : "Unpair") {
                if isConfirming {
                    onUnpair()
                } else {
                    isConfirming = true
                }
            }
            .controlSize(.small)
            .tint(isConfirming ? .red : nil)
        }
        .padding(.vertical, 3)
        // Don't leave a primed destructive button sitting there.
        .onDisappear { isConfirming = false }
    }
}

private extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

private extension FillRequest {
    /// Never show the payload itself — it's routinely a password or a one-time
    /// code, and the menu bar sits in front of whoever is looking at the screen.
    var previewText: String {
        "\(text.count) characters" + (followUp == .none ? "" : ", then \(followUp.rawValue)")
    }
}
