import SwiftUI

struct CustomRelayFieldEditorSheet: View {
    let mode: CustomFieldEditorMode
    @Binding var details: CustomRelayDetails
    let onFieldAdded: (UUID) -> Void
    let onClose: () -> Void

    @State private var draftTitle: String
    @State private var draftKind: CustomFieldKind?
    @Environment(\.colorScheme) private var colorScheme

    init(
        mode: CustomFieldEditorMode,
        details: Binding<CustomRelayDetails>,
        onFieldAdded: @escaping (UUID) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.mode = mode
        _details = details
        self.onFieldAdded = onFieldAdded
        self.onClose = onClose

        switch mode {
        case .adding:
            _draftTitle = State(initialValue: "")
            _draftKind = State(initialValue: nil)
        case .editing(let id):
            let field = details.wrappedValue.fields.first { $0.id == id }
            _draftTitle = State(initialValue: field?.title ?? "")
            _draftKind = State(initialValue: field?.value.kind)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(mode == .adding ? "Add a custom field" : "Edit custom field")
                        .customTextStyle(.prominent, color: .inverted)
                        .accessibilityAddTraits(.isHeader)

                    Text(
                        mode == .adding
                            ? "Name what you want to save, then choose how you'll enter it."
                            : "Rename this field or choose a new type. Changing its type clears its value."
                    )
                    .customTextStyle(.supporting, color: .muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .modifier(CustomFieldBuilderScrollBlur())

                CustomTextField(
                    title: "Field title",
                    text: $draftTitle,
                    shouldIncludeLineLimit: false,
                    placeholder: "e.g. Account number",
                    leadingSystemImageName: "textformat",
                    autocapitalization: .sentences
                )
                .modifier(CustomFieldBuilderScrollBlur())

                VStack(alignment: .leading, spacing: 8) {
                    Text("Value type")
                        .customTextStyle(.caption, color: .muted)
                        .modifier(CustomFieldBuilderScrollBlur())

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(CustomFieldKind.allCases) { kind in
                            Button {
                                draftKind = kind
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: kind.icon)
                                        .font(.system(size: 15, weight: .medium))
                                    Text(kind.title)
                                        .customTextStyle(.supportingEmphasis, color: .inverted)
                                    Spacer(minLength: 0)
                                    if draftKind == kind {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(AppColors.textInverted(colorScheme: colorScheme))
                                .padding(.horizontal, 14)
                                .frame(minHeight: RelayFormFieldLayout.controlHeight)
                                .relayRowBackground(cornerRadius: RelayFormFieldLayout.cornerRadius)
                                .overlay {
                                    RoundedRectangle(cornerRadius: RelayFormFieldLayout.cornerRadius)
                                        .strokeBorder(
                                            draftKind == kind ? AppColors.iconBrand(colorScheme: colorScheme) : .clear,
                                            lineWidth: 1.5
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                            .hapticFeedback(style: .light)
                            .accessibilityAddTraits(draftKind == kind ? .isSelected : [])
                            .modifier(CustomFieldBuilderScrollBlur())
                        }
                    }
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .top) {
            HStack(spacing: 18) {
                CircularButton(icon: "xmark") { onClose() }
                    .accessibilityLabel("Cancel")

                Spacer()

                CircularButton(
                    icon: mode == .adding ? "plus" : "checkmark",
                    iconColor: canCommit ? nil : AppColors.iconDisabled(colorScheme: colorScheme)
                ) { commitDraft() }
                    .accessibilityLabel(mode == .adding ? "Add field" : "Update field")
                    .disabled(!canCommit)
                    .opacity(canCommit ? 1 : 0.45)
            }
            .padding()
        }
    }

    private var canCommit: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draftKind != nil
    }

    private func commitDraft() {
        guard canCommit, let kind = draftKind else { return }
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .adding:
            let field = CustomRelayField(title: title, value: .empty(for: kind))
            details.fields.append(field)
            onFieldAdded(field.id)
            onClose()
        case .editing(let id):
            guard let index = details.fields.firstIndex(where: { $0.id == id }) else { return }
            details.fields[index].title = title
            if details.fields[index].value.kind != kind {
                details.fields[index].value = .empty(for: kind)
            }
            onClose()
        }
    }
}

private struct CustomFieldBuilderScrollBlur: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollTransition(.interactive, axis: .vertical) { view, phase in
            view.blur(radius: !phase.isIdentity ? 8 : 0)
        }
    }
}

extension CustomFieldKind {
    var icon: String {
        switch self {
        case .text: "text.alignleft"
        case .number: "number"
        case .date: "calendar"
        case .gender: "person"
        }
    }
}
