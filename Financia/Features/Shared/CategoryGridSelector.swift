import SwiftUI

struct CategoryGridSelector: View {
    let title: String
    let categories: [TransactionCategory]
    @Binding var selectedCategory: TransactionCategory?
    @Binding var selectedSubcategory: Subcategory?
    var onAddCategory: (() -> Void)?
    var onAddSubcategory: ((TransactionCategory) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let onAddCategory {
                    Button(action: onAddCategory) {
                        Label("Nueva", systemImage: "plus.circle.fill")
                    }
                }
            }

            LazyVGrid(columns: categoryColumns, spacing: 12) {
                ForEach(categories) { category in
                    CategoryCard(
                        category: category,
                        selectedCategory: $selectedCategory,
                        selectedSubcategory: $selectedSubcategory,
                        onAddSubcategory: onAddSubcategory
                    )
                }
            }
        }
    }

    private var categoryColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }
}

private struct CategoryCard: View {
    let category: TransactionCategory
    @Binding var selectedCategory: TransactionCategory?
    @Binding var selectedSubcategory: Subcategory?
    var onAddSubcategory: ((TransactionCategory) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            subcategoryGrid
            if let onAddSubcategory {
                Button(action: { onAddSubcategory(category) }) {
                    Label("Agregar subcategoría", systemImage: "plus")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .foregroundColor(category.color)
            Text(category.name)
                .font(.subheadline.weight(.semibold))
            Spacer()
            if selectedCategory?.id == category.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
    }

    private var subcategoryGrid: some View {
        LazyVGrid(columns: subcategoryColumns, alignment: .leading, spacing: 6) {
            ForEach(category.subcategories) { subcategory in
                subcategoryChip(for: subcategory)
            }
        }
    }

    private func subcategoryChip(for subcategory: Subcategory) -> some View {
        let isSelected = selectedSubcategory?.id == subcategory.id
        return Button {
            selectedSubcategory = subcategory
            selectedCategory = category
        } label: {
            Text(subcategory.name)
                .font(.caption)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? category.color : Color(.systemGray6), in: Capsule())
        }
    }

    private var subcategoryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 80), spacing: 6)]
    }
}
