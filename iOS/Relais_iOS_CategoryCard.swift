//
//  CategoryCard.swift
//  Relais
//
//  Created on 2025-02-15.
//

import SwiftUI

/// Category card component
/// Displays a category with its icon, title, and item count
struct CategoryCard: View {

    // MARK: - Properties

    let category: Category
    let itemCount: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: category.color).opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: category.icon ?? "folder.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: category.color))
                }

                // Title and count
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text("\(itemCount) 个项目")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#9CA3AF"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#2A2A4A"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color(hex: category.color) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture {
            onLongPress()
        }
    }
}

// MARK: - Category Card View Model

@MainActor
class CategoryCardViewModel: ObservableObject {
    @Published var category: Category
    @Published var itemCount: Int = 0

    private let itemsRepository = ItemsRepository.shared

    init(category: Category) {
        self.category = category
        fetchItemCount()
    }

    private func fetchItemCount() {
        Task {
            do {
                try await itemsRepository.fetchItems(categoryId: category.id)
                itemCount = itemsRepository.items.filter { $0.categoryId == category.id }.count
            } catch {
                print("Failed to fetch item count: \(error)")
            }
        }
    }

    func refresh() {
        fetchItemCount()
    }
}

// MARK: - Edit Category Sheet

struct EditCategorySheet: View {
    @Environment(\.dismiss) var dismiss

    let category: Category
    let onUpdate: (String, String?, String, String?) -> Void

    @State private var title: String
    @State private var description: String
    @State private var color: String
    @State private var icon: String

    private let colors = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A",
        "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E2"
    ]

    private let icons = [
        "folder.fill", "star.fill", "heart.fill", "briefcase.fill",
        "house.fill", "car.fill", "airplane", "book.fill"
    ]

    init(category: Category, onUpdate: @escaping (String, String?, String, String?) -> Void) {
        self.category = category
        self.onUpdate = onUpdate
        _title = State(initialValue: category.title)
        _description = State(initialValue: category.description ?? "")
        _color = State(initialValue: category.color)
        _icon = State(initialValue: category.icon ?? "folder.fill")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("分类名称", text: $title)
                    TextField("描述", text: $description)
                }

                Section(header: Text("颜色")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(colors, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(color == colorHex ? Color.white : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    color = colorHex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section(header: Text("图标")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(icons, id: \.self) { iconName in
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "#2A2A4A"))
                                    .frame(width: 44, height: 44)

                                Image(systemName: iconName)
                                    .foregroundColor(icon == iconName ? Color(hex: color) : Color(hex: "#9CA3AF"))
                            }
                            .onTapGesture {
                                icon = iconName
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section(header: Text("操作")) {
                    Button(role: .destructive) {
                        // Delete category
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("删除分类")
                        }
                    }
                }
            }
            .background(Color(hex: "#1A1A2E"))
            .scrollContentBackground(.hidden)
            .navigationTitle("编辑分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#9CA3AF"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onUpdate(
                            title.isEmpty ? category.title : title,
                            description.isEmpty ? nil : description,
                            color,
                            icon
                        )
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FF6B6B"))
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Category View

struct AddCategoryView: View {
    @Environment(\.dismiss) var dismiss

    let onCreate: (String, String?, String, String?) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var selectedColor = "#FF6B6B"
    @State private var selectedIcon = "folder.fill"

    private let colors = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A",
        "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E2"
    ]

    private let icons = [
        "folder.fill", "star.fill", "heart.fill", "briefcase.fill",
        "house.fill", "car.fill", "airplane", "book.fill"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("分类名称", text: $title)
                    TextField("描述（可选）", text: $description)
                }

                Section(header: Text("颜色")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(colors, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == colorHex ? Color.white : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    selectedColor = colorHex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section(header: Text("图标")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(icons, id: \.self) { iconName in
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "#2A2A4A"))
                                    .frame(width: 44, height: 44)

                                Image(systemName: iconName)
                                    .foregroundColor(selectedIcon == iconName ? Color(hex: selectedColor) : Color(hex: "#9CA3AF"))
                            }
                            .onTapGesture {
                                selectedIcon = iconName
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .background(Color(hex: "#1A1A2E"))
            .scrollContentBackground(.hidden)
            .navigationTitle("新建分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#9CA3AF"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("创建") {
                        onCreate(title, description.isEmpty ? nil : description, selectedColor, selectedIcon)
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FF6B6B"))
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

struct CategoryCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CategoryCard(
                category: Category(
                    id: "1",
                    userId: "user1",
                    title: "工作",
                    description: "工作相关项目",
                    color: "#FF6B6B",
                    icon: "briefcase.fill",
                    sortOrder: 0,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                itemCount: 5,
                isSelected: false,
                onTap: {},
                onLongPress: {}
            )

            CategoryCard(
                category: Category(
                    id: "2",
                    userId: "user1",
                    title: "个人",
                    description: "个人项目",
                    color: "#4ECDC4",
                    icon: "person.fill",
                    sortOrder: 1,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                itemCount: 3,
                isSelected: true,
                onTap: {},
                onLongPress: {}
            )
        }
        .padding()
        .background(Color(hex: "#1A1A2E"))
    }
}
