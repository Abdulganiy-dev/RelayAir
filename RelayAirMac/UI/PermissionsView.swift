import SwiftUI
import RelayAirCore

/// Setup surface. Shown automatically when Accessibility is missing, and
/// reachable from the menu bar afterwards.
///
/// Capabilities are grouped under the permission that backs them, so it's
/// obvious that one Accessibility grant unlocks two of the three.
struct PermissionsView: View {
    let services: AppServices
    var onFinish: () -> Void = {}

    private var permissions: PermissionsModel { services.permissions }

    private var readyCount: Int { permissions.availableCapabilities.count }
    private var totalCount: Int { Capability.allCases.count }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    progress

                    VStack(spacing: 14) {
                        ForEach(SystemPermission.allCases) { permission in
                            PermissionCard(
                                permission: permission,
                                isGranted: permissions.isGranted(permission),
                                wasRequested: permissions.requested.contains(permission),
                                onGrant: { permissions.request(permission) },
                                onOpenSettings: { permissions.openSettings(for: permission) }
                            )
                        }
                    }
                }
                .padding(26)
            }

            footer
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 560)
        .background(.background)
        .onAppear { permissions.refresh() }
        .animation(.smooth(duration: 0.28), value: permissions.granted)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 15) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .overlay {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(.white)
                }
                .shadow(color: .accentColor.opacity(0.28), radius: 9, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(AppIdentifiers.displayName)
                    .font(.title2.weight(.semibold))
                Text(AppIdentifiers.tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Progress

    private var progress: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(permissions.isFullyPermitted ? "Everything's ready" : "Grant access to continue")
                    .font(.callout.weight(.medium))
                Spacer()
                Text("\(readyCount) of \(totalCount)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(permissions.isFullyPermitted ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.accentColor))
                        .frame(width: geometry.size.width * (Double(readyCount) / Double(totalCount)))
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                if permissions.canControlInput {
                    Label("Relay Air can fill fields", systemImage: "checkmark.seal.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                } else {
                    Label("Accessibility is required", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                Spacer()

                Button("Done", action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!permissions.canControlInput)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 16)
        }
        .background(.bar)
    }
}

// MARK: - Permission card

/// One system permission, with the capabilities it unlocks listed underneath.
private struct PermissionCard: View {
    let permission: SystemPermission
    let isGranted: Bool
    let wasRequested: Bool
    let onGrant: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow
                .padding(.horizontal, 15)
                .padding(.vertical, 12)

            Divider()

            VStack(spacing: 11) {
                ForEach(permission.capabilities) { capability in
                    CapabilityRow(capability: capability, isAvailable: isGranted)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)

            if !isGranted {
                Divider()
                actionRow
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.quinary)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(isGranted ? Color.green.opacity(0.35) : Color.secondary.opacity(0.18))
        }
    }

    private var titleRow: some View {
        HStack(spacing: 9) {
            Text(permission.title)
                .font(.headline)
            Spacer()
            StatusChip(isGranted: isGranted)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 10) {
            // The system prompt fires at most once per app identity, so after
            // the first attempt the only route left is System Settings.
            if wasRequested {
                Text("Enable it under \(permission.settingsLocation).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Open Settings", action: onOpenSettings)
            } else {
                Spacer()
                Button("Grant Access", action: onGrant)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Capability row

private struct CapabilityRow: View {
    let capability: Capability
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: capability.symbol)
                .font(.system(size: 15))
                .frame(width: 24)
                .foregroundStyle(isAvailable ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))

            VStack(alignment: .leading, spacing: 1) {
                Text(capability.title)
                    .font(.callout.weight(.medium))
                Text(capability.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: isAvailable ? "checkmark.circle.fill" : "circle.dotted")
                .font(.system(size: 15))
                .foregroundStyle(isAvailable ? AnyShapeStyle(Color.green) : AnyShapeStyle(.tertiary))
                .contentTransition(.symbolEffect(.replace))
        }
    }
}

// MARK: - Status chip

private struct StatusChip: View {
    let isGranted: Bool

    var body: some View {
        Text(isGranted ? "Granted" : "Not granted")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background {
                Capsule().fill(isGranted ? Color.green.opacity(0.16) : Color.secondary.opacity(0.14))
            }
            .foregroundStyle(isGranted ? AnyShapeStyle(Color.green) : AnyShapeStyle(.secondary))
    }
}
