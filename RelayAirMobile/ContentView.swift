import SwiftUI
import RelayAirCore

/// The sender side of Relay Air: pick something on the iPhone, send it, approve
/// the transfer, and the Mac fills it into whatever field is focused.
///
/// The screenshot button is the first working end-to-end command; Send/Approve/
/// Fill itself is still scaffolding.
struct ContentView: View {
    @State private var sender = SenderModel()

    var body: some View {
        NavigationStack {
            List {
                headerSection
                connectionSection
                screenshotSection
                stepsSection
            }
            .navigationTitle(AppIdentifiers.displayName)
        }
        .task { sender.connect() }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppIdentifiers.displayName)
                    .font(.headline)
                Text(AppIdentifiers.tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        Section("Mac") {
            Label {
                Text(sender.linkState.description)
            } icon: {
                Image(systemName: sender.isConnected ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right")
                    .foregroundStyle(sender.isConnected ? .green : .secondary)
            }

            if !sender.isConnected {
                Text("Make sure Relay Air is running on your Mac, both devices are on the same Wi-Fi, and Local Network access is allowed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Screenshot

    private var screenshotSection: some View {
        Section("Mac screen") {
            Button {
                Task { await sender.captureMacScreen() }
            } label: {
                HStack {
                    Label("Take Screenshot on Mac", systemImage: "camera.viewfinder")
                    Spacer()
                    if sender.isBusy {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(!sender.isConnected || sender.isBusy)

            switch sender.outcome {
            case .idle, .capturing:
                EmptyView()

            case .captured(let screenshot):
                if let image = UIImage(data: screenshot.imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                }
                Text(caption(for: screenshot))
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .failed(let reason):
                Label(reason, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func caption(for screenshot: Screenshot) -> String {
        let source = "\(screenshot.sourceWidth)×\(screenshot.sourceHeight)"
        let sent = "\(screenshot.width)×\(screenshot.height)"
        let size = ByteCountFormatter.string(fromByteCount: Int64(screenshot.byteCount), countStyle: .file)
        return "\(source) captured, sent as \(sent) · \(size)"
    }

    // MARK: - Steps

    private var stepsSection: some View {
        Section("How it works") {
            ForEach(RelayStep.allCases) { step in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(step.number). \(step.title)")
                        Text(step.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: step.symbol)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
