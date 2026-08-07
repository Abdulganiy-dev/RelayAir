import SwiftUI
import RelayAirCore

/// The sender side of Relay Air: pair with the Mac, then drive it.
///
/// The screenshot button is the first working end-to-end command; Send/Approve/
/// Fill itself is still scaffolding.
struct ContentView: View {
    @State private var sender = SenderModel()
    @State private var isScanning = false
    @State private var draft = ""
    @State private var followUp: FillRequest.FollowUp = .none
    @State private var isConfirmingSend = false
    @FocusState private var isDraftFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                headerSection

                if sender.isPaired {
                    connectionSection
                    fieldsSection
                    sendSection
                    screenshotSection
                } else {
                    unpairedSection
                }

                stepsSection
            }
            .navigationTitle(AppIdentifiers.displayName)
        }
        .fontDesign(Tokens.fontDesign)
        .task { sender.begin() }
        .sheet(isPresented: $isScanning) {
            ScannerSheet(
                onScan: { code in
                    sender.handleScan(code)
                    isScanning = false
                },
                onError: { message in
                    sender.reportScanError(message)
                    isScanning = false
                }
            )
        }
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

    // MARK: - Unpaired

    private var unpairedSection: some View {
        Section("Pair with your Mac") {
            Text("Open Relay Air on your Mac, then scan the code it shows. The code carries the key that encrypts everything between the two devices.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                sender.clearPairingError()
                isScanning = true
            } label: {
                Label("Scan Pairing Code", systemImage: "qrcode.viewfinder")
            }

            if let error = sender.pairingError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        Section("Mac") {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sender.pairedMacName ?? "Mac")
                    Text(sender.linkState.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: sender.isConnected ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right")
                    .foregroundStyle(sender.isConnected ? .green : .secondary)
            }

            if !sender.isConnected {
                Text("Make sure Relay Air is running on your Mac, both devices are on the same Wi-Fi, and Local Network access is allowed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    sender.reconnect()
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
            }

            Button {
                sender.clearPairingError()
                isScanning = true
            } label: {
                Label("Rescan Pairing Code", systemImage: "qrcode.viewfinder")
            }

            Button("Forget This Mac", role: .destructive) {
                sender.unpair()
            }

            if let error = sender.pairingError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Fields

    /// What the Mac can see in front of it, so the text can be aimed at one
    /// field rather than at whatever happens to be focused.
    private var fieldsSection: some View {
        Section {
            Button {
                Task { await sender.listMacFields() }
            } label: {
                HStack {
                    Label(
                        sender.fields.isEmpty ? "See Fields on Mac" : "Refresh Fields",
                        systemImage: "text.viewfinder"
                    )
                    Spacer()
                    if sender.isLoadingFields {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(!sender.isConnected || sender.isLoadingFields)

            switch sender.fieldsOutcome {
            case .idle, .loading:
                EmptyView()

            case .loaded(let snapshot):
                fieldsContextRow(snapshot)

                if snapshot.isEmpty {
                    Text("No fields found here. You can still send text to whatever your Mac has focused.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.fields) { field in
                        fieldRow(field)
                    }
                }

            case .failed(let reason):
                Label(reason, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Fields on Mac")
        } footer: {
            if !sender.fields.isEmpty {
                Text("Your Mac reads labels and positions only — never what's already typed in a field.")
            }
        }
    }

    /// Where the fields were found. The address matters most: it's the last
    /// chance to notice a password is headed somewhere unexpected.
    @ViewBuilder
    private func fieldsContextRow(_ snapshot: FormSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.contextDescription)
                .font(.caption.weight(.medium))
            if let url = snapshot.url {
                Label(url, systemImage: "safari")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldRow(_ field: FormField) -> some View {
        let isSelected = sender.selectedField?.id == field.id

        return Button {
            sender.selectField(field)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: field.semanticType.symbolName)
                    .frame(width: 22)
                    .foregroundStyle(field.semanticType.isSensitive ? .orange : .accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(field.label)
                        .foregroundStyle(.primary)
                    if let note = note(for: field) {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .disabled(!field.isEnabled)
    }

    /// The caveats worth a line under a field's name.
    private func note(for field: FormField) -> String? {
        var parts: [String] = []
        if field.isSecure { parts.append("Hidden while typing") }
        if field.isRequired { parts.append("Required") }
        if field.hasExistingValue { parts.append("Already has text") }
        if !field.isEnabled { parts.append("Disabled") }
        // Say so when the Mac found a box but couldn't read a name for it,
        // rather than presenting a guess as though it were a label.
        if field.confidence < 0.5 { parts.append("Unlabelled — check before filling") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Send

    private var sendSection: some View {
        Section("Send text") {
            TextField("What should the Mac type?", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isDraftFocused)

            Picker("Then press", selection: $followUp) {
                Text("Nothing").tag(FillRequest.FollowUp.none)
                Text("Tab").tag(FillRequest.FollowUp.tab)
                Text("Return").tag(FillRequest.FollowUp.return)
            }

            destinationRow

            // Step 2. This is the last point at which the transfer can be
            // stopped — once it leaves, the Mac types it immediately.
            Button {
                isDraftFocused = false
                isConfirmingSend = true
            } label: {
                HStack {
                    Label("Send to Mac", systemImage: "paperplane.fill")
                    Spacer()
                    if sender.isSending {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(!sender.isConnected || sender.isSending || draft.trimmed.isEmpty)

            sendStatus
        }
        .confirmationDialog(
            "Send to \(sender.pairedMacName ?? "your Mac")?",
            isPresented: $isConfirmingSend,
            titleVisibility: .visible
        ) {
            Button("Send \(draft.trimmed.count) characters") {
                let text = draft
                Task {
                    await sender.send(text: text, followUp: followUp)
                    if sender.sendOutcome == .filled { draft = "" }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(sendConfirmationMessage)
        }
    }

    /// Where the text is going, shown above the send button.
    ///
    /// Worth its own row: the difference between "the field I picked" and
    /// "whatever is focused over there" is the difference between a password
    /// landing in a password box and landing in a chat window.
    @ViewBuilder
    private var destinationRow: some View {
        if let field = sender.selectedField {
            LabeledContent("Into") {
                HStack(spacing: 6) {
                    Image(systemName: field.semanticType.symbolName)
                    Text(field.label)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button {
                        sender.selectedField = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear chosen field")
                }
            }
        } else {
            LabeledContent("Into", value: "Whatever your Mac has focused")
        }
    }

    private var sendConfirmationMessage: String {
        guard let field = sender.selectedField else {
            return "Your Mac will type this into whatever field is focused, straight away."
        }
        if let url = sender.fieldsURL {
            return "Your Mac will type this into “\(field.label)” on \(url), straight away."
        }
        let context = sender.fieldsContext ?? "your Mac"
        return "Your Mac will type this into “\(field.label)” in \(context), straight away."
    }

    @ViewBuilder
    private var sendStatus: some View {
        switch sender.sendOutcome {
        case .idle:
            EmptyView()
        case .sending:
            Label("Sending…", systemImage: "paperplane")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .filled:
            Label("Filled on your Mac", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)
        case .failed(let reason):
            Label(reason, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Screenshot

    private var screenshotSection: some View {
        Section("Mac screen") {
            Button {
                Task { await sender.captureMacScreen() }
            } label: {
                HStack {
                    Label("Capture Window Under Pointer", systemImage: "macwindow.badge.plus")
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
                VStack(alignment: .leading, spacing: 4) {
                    if let source = screenshot.source {
                        Text(source)
                            .font(.caption.weight(.medium))
                    }

                    // Only browsers that answered supply this, so its presence
                    // is itself the signal that the link is trustworthy.
                    if let urlString = screenshot.sourceURL {
                        if let url = URL(string: urlString) {
                            Link(destination: url) {
                                Label(urlString, systemImage: "safari")
                                    .font(.caption)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                            .contextMenu {
                                Button("Copy Link", systemImage: "doc.on.doc") {
                                    UIPasteboard.general.string = urlString
                                }
                            }
                        } else {
                            Text(urlString)
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }

                    Text(caption(for: screenshot))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            case .failed(let reason):
                Label(reason, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func caption(for screenshot: Screenshot) -> String {
        let dimensions = "\(screenshot.sourceWidth)×\(screenshot.sourceHeight)"
        let size = ByteCountFormatter.string(fromByteCount: Int64(screenshot.byteCount), countStyle: .file)
        return "\(dimensions) · \(size)"
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

// MARK: - Scanner sheet

/// Full-screen camera with a viewfinder cutout and a cancel affordance.
private struct ScannerSheet: View {
    let onScan: (String) -> Void
    let onError: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                QRScannerView(onScan: onScan, onError: onError)
                    .ignoresSafeArea()

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 240, height: 240)
                    .shadow(radius: 8)

                VStack {
                    Spacer()
                    Text("Point at the code on your Mac")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(.bottom, 48)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

#Preview {
    ContentView()
}
