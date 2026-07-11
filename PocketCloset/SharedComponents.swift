import SwiftUI

struct FilterChip: View {
    let title: String
    var iconName: String?
    var isActive = false
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 7) {
                if let iconName {
                    Image(systemName: iconName)
                        .font(.caption.weight(.semibold))
                }
                Text(title)
                    .font(.callout.weight(isActive ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? .white : .primary)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(isActive ? PCColor.primary : Color(.secondarySystemGroupedBackground))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isActive ? Color.clear : Color(.separator).opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

struct PickerRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let iconName: String
    let title: String
    let value: String
    var accent: Color = PCColor.primary
    var isRequiredMissing = false

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        rowIcon
                        Text(title)
                            .font(.headline)
                    }

                    HStack(spacing: 10) {
                        Text(value)
                            .foregroundStyle(isRequiredMissing ? .red : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        chevron
                    }
                    .padding(.leading, 56)
                }
            } else {
                HStack(spacing: 14) {
                    rowIcon
                    Text(title)
                        .font(.headline)
                    Spacer(minLength: 16)
                    Text(value)
                        .font(.body)
                        .foregroundStyle(isRequiredMissing ? .red : .secondary)
                        .lineLimit(1)
                    chevron
                }
            }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var rowIcon: some View {
        Image(systemName: iconName)
            .font(.title3)
            .foregroundStyle(accent)
            .frame(width: 42, height: 42)
            .background(accent.opacity(0.10), in: Circle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

struct MetadataRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let iconName: String
    let title: String
    let value: String
    var accent: Color = PCColor.primary

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 13) {
                        metadataIcon
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(value)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 41)
                }
            } else {
                HStack(spacing: 13) {
                    metadataIcon
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(value)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .font(.body)
        .padding(.vertical, 8)
    }

    private var metadataIcon: some View {
        Image(systemName: iconName)
            .foregroundStyle(accent)
            .frame(width: 28)
    }
}

struct StoredPhotoView: View {
    let relativePath: String?
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let image = ImageStore.load(relativePath: relativePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    Color(.tertiarySystemGroupedBackground)
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

struct ItemCard: View {
    let item: ClothingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StoredPhotoView(relativePath: item.thumbnailPath)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(topLeadingRadius: 13, topTrailingRadius: 13))

            HStack(spacing: 5) {
                Text(item.type.rawValue)
                    .font(.callout.weight(.semibold))
                Text("·")
                    .foregroundStyle(.secondary)
                Text(item.sizeLabel)
                    .font(.callout.weight(.medium))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.type.rawValue), size \(item.sizeLabel), \(item.owner?.name ?? "no owner")")
    }
}

struct EmptyStateView: View {
    let iconName: String
    let title: String
    let message: String
    var buttonTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(PCColor.primary)
                .frame(width: 70, height: 70)
                .background(PCColor.primary.opacity(0.10), in: Circle())

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(PCColor.primary)
                    .padding(.top, 4)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

struct StatusBucketRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let status: ItemStatus
    let count: Int
    var isSelected = false

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        statusIcon
                        Spacer()
                        countLabel
                        chevron
                    }
                    Text(status.rawValue)
                        .font(.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(spacing: 16) {
                    statusIcon
                    Text(status.rawValue)
                        .font(.body.weight(.semibold))
                    Spacer()
                    countLabel
                    chevron
                }
            }
        }
        .padding(12)
        .background(isSelected ? status.accent.opacity(0.08) : Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? status.accent.opacity(0.45) : Color(.separator).opacity(0.30), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status.rawValue), \(count) items")
    }

    private var statusIcon: some View {
        Image(systemName: status.iconName)
            .font(.title3)
            .foregroundStyle(status.accent)
            .frame(width: 46, height: 46)
            .background(status.accent.opacity(0.12), in: Circle())
    }

    private var countLabel: some View {
        Text(count.formatted())
            .font(.body.weight(.semibold))
            .foregroundStyle(status.accent)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

struct PrimaryStickyButton: View {
    let title: String
    let systemImage: String?
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
        }
        .buttonStyle(.borderedProminent)
        .tint(PCColor.primary)
        .disabled(isDisabled)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }
}

struct SelectableCheckmark: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? PCColor.primary : Color.secondary.opacity(0.55))
            .contentTransition(.symbolEffect(.replace))
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
