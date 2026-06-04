import SwiftUI

struct CategoryGridSelector: View {
    let title: String
    let categories: [TransactionCategory]
    @Binding var selectedCategory: TransactionCategory?
    @Binding var selectedSubcategory: Subcategory?
    var onAddCategory: (() -> Void)?
    var onAddSubcategory: ((TransactionCategory) -> Void)?
    var onDismiss: (() -> Void)?

    @State private var expandedCategoryId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(categories) { category in
                CategoryExpandableRow(
                    category: category,
                    isExpanded: expandedCategoryId == category.id,
                    selectedCategory: $selectedCategory,
                    selectedSubcategory: $selectedSubcategory,
                    onTapCategory: {
                        withAnimation(.snappy(duration: 0.3)) {
                            if expandedCategoryId == category.id {
                                expandedCategoryId = nil
                            } else {
                                expandedCategoryId = category.id
                            }
                        }
                    },
                    onSelectSubcategory: { subcategory in
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedCategory = category
                            selectedSubcategory = subcategory
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onDismiss?()
                        }
                    },
                    onAddSubcategory: onAddSubcategory
                )

                if category.id != categories.last?.id {
                    Divider()
                        .padding(.leading, 56)
                }
            }

            if let onAddCategory {
                Divider()
                    .padding(.leading, 56)

                Button(action: onAddCategory) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(DarkFinanceColors.inputBackground)
                                .frame(width: 36, height: 36)
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DarkFinanceColors.secondaryText)
                        }

                        Text("Nueva categoría")
                            .font(.system(size: 15))
                            .foregroundColor(DarkFinanceColors.secondaryText)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DarkFinanceColors.cardBackground)
        )
        .onAppear {
            if let selectedId = selectedCategory?.id {
                expandedCategoryId = selectedId
            }
        }
    }
}

// MARK: - Expandable Category Row

private struct CategoryExpandableRow: View {
    let category: TransactionCategory
    let isExpanded: Bool
    @Binding var selectedCategory: TransactionCategory?
    @Binding var selectedSubcategory: Subcategory?
    let onTapCategory: () -> Void
    let onSelectSubcategory: (Subcategory) -> Void
    var onAddSubcategory: ((TransactionCategory) -> Void)?

    private var isCategorySelected: Bool {
        selectedCategory?.id == category.id
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category header row
            Button(action: onTapCategory) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(isExpanded ? 0.2 : 0.12))
                            .frame(width: 36, height: 36)
                        CategoryIconView(icon: category.icon, color: category.color, size: 15)
                    }

                    Text(category.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DarkFinanceColors.primaryText)

                    if isCategorySelected, let sub = selectedSubcategory {
                        Text(sub.name)
                            .font(.system(size: 12))
                            .foregroundColor(category.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(category.color.opacity(0.15))
                            )
                            .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DarkFinanceColors.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Subcategories (expandable)
            if isExpanded {
                VStack(spacing: 0) {
                    subcategoryChips
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    if let onAddSubcategory {
                        Button {
                            onAddSubcategory(category)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Agregar")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(DarkFinanceColors.tertiaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .stroke(DarkFinanceColors.inputBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 56)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipped()
    }

    private var subcategoryChips: some View {
        FlowLayout(spacing: 8) {
            ForEach(category.subcategories) { subcategory in
                let isSelected = selectedSubcategory?.id == subcategory.id && isCategorySelected
                Button {
                    onSelectSubcategory(subcategory)
                } label: {
                    Text(subcategory.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : DarkFinanceColors.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? category.color : DarkFinanceColors.inputBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color.clear : DarkFinanceColors.inputBorder, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(SubcategoryButtonStyle())
            }
        }
        .padding(.leading, 48)
    }
}

// MARK: - Subcategory Button Style (with press animation)

private struct SubcategoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Flow Layout for Subcategory Chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(maxWidth: proposal.width, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let availableWidth = bounds.width > 0 ? bounds.width : proposal.width
        let result = arrange(maxWidth: availableWidth, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrange(maxWidth: CGFloat?, subviews: Subviews) -> ArrangeResult {
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var measuredWidth: CGFloat = 0
        let availableWidth = maxWidth.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if let availableWidth, x > 0, x + size.width > availableWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            measuredWidth = max(measuredWidth, x > 0 ? x - spacing : 0)
        }

        let totalHeight = y + rowHeight
        return ArrangeResult(
            size: CGSize(width: availableWidth ?? measuredWidth, height: totalHeight),
            positions: positions,
            sizes: sizes
        )
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
        var sizes: [CGSize]
    }
}
