//
//  ItemRow.swift
//  Sortie
//
//  Created on 2025-02-15.
//

import SwiftUI

/// Item row component
/// Displays an item with completion toggle, title, and metadata
struct ItemRow: View {

    // MARK: - Properties

    let item: Item
    let category: Category?
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isShowingDeleteAlert = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Completion toggle
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(item.isCompleted ? Color(hex: "#10B981") : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#3A3A5A"), lineWidth: 2)
                        )

                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(item.title)
                    .font(.system(size: 16, weight: item.isCompleted ? .regular : .medium))
                    .foregroundColor(item.isCompleted ? Color(hex: "#6B7280") : .white)
                    .strikethrough(item.isCompleted)

                // Description
                if let content = item.content, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#9CA3AF"))
                        .lineLimit(2)
                }

                // Metadata
                HStack(spacing: 8) {
                    // Category
                    if let category = category {
                        HStack(spacing: 4) {
                            Image(systemName: category.icon ?? "folder.fill")
                                .font(.system(size: 10))
                            Text(category.title)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: category.color))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: category.color).opacity(0.15))
                        .cornerRadius(6)
                    }

                    // Priority
                    if item.priority != .none {
                        HStack(spacing: 4) {
                            Image(systemName: priorityIcon)
                                .font(.system(size: 10))
                            Text(item.priority.displayName)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: item.priority.color))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: item.priority.color).opacity(0.15))
                        .cornerRadius(6)
                    }

                    // Due date
                    if let dueDate = item.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(dueDateText(dueDate))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(isOverdue(dueDate) ? Color(hex: "#EF4444") : Color(hex: "#9CA3AF"))
                    }
                }
            }

            Spacer()

            // Delete button
            Button(action: {
                isShowingDeleteAlert = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#6B7280"))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color(hex: "#2A2A4A"))
        .cornerRadius(12)
        .confirmationDialog(
            "删除项目",
            isPresented: $isShowingDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要删除这个项目吗？此操作无法撤销。")
        }
    }

    // MARK: - Helper Properties

    private var priorityIcon: String {
        switch item.priority {
        case .none:
            return "circle"
        case .low:
            return "arrow.down"
        case .medium:
            return "minus"
        case .high:
            return "arrow.up"
        case .urgent:
            return "exclamationmark"
        }
    }

    // MARK: - Helper Methods

    private func dueDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInTomorrow(date) {
            return "明天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && !item.isCompleted
    }
}

// MARK: - Item Detail View

struct ItemDetailView: View {
    @Environment(\.dismiss) var dismiss

    let item: Item
    let category: Category?
    let onUpdate: (String, String?, ItemPriority) -> Void

    @State private var title: String
    @State private var content: String
    @State private var selectedPriority: ItemPriority

    init(item: Item, category: Category?, onUpdate: @escaping (String, String?, ItemPriority) -> Void) {
        self.item = item
        self.category = category
        self.onUpdate = onUpdate
        _title = State(initialValue: item.title)
        _content = State(initialValue: item.content ?? "")
        _selectedPriority = State(initialValue: item.priority)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("项目信息")) {
                    TextField("标题", text: $title)
                    TextField("描述", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section(header: Text("优先级")) {
                    Picker("优先级", selection: $selectedPriority) {
                        ForEach(ItemPriority.allCases, id: \.self) { priority in
                            HStack {
                                Image(systemName: priorityIcon(for: priority))
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                if let category = category {
                    Section(header: Text("分类")) {
                        HStack {
                            Image(systemName: category.icon ?? "folder.fill")
                                .foregroundColor(Color(hex: category.color))
                            Text(category.title)
                                .foregroundColor(.white)
                        }
                    }
                }

                if let dueDate = item.dueDate {
                    Section(header: Text("截止日期")) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(Color(hex: "#9CA3AF"))
                            Text(dueDate, style: .date)
                                .foregroundColor(.white)
                        }
                    }
                }

                if let tags = item.tags, !tags.isEmpty {
                    Section(header: Text("标签")) {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "#2A2A4A"))
                                    .foregroundColor(Color(hex: "#9CA3AF"))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            .background(Color(hex: "#1A1A2E"))
            .scrollContentBackground(.hidden)
            .navigationTitle("项目详情")
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
                            title.isEmpty ? item.title : title,
                            content.isEmpty ? nil : content,
                            selectedPriority
                        )
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FF6B6B"))
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func priorityIcon(for priority: ItemPriority) -> String {
        switch priority {
        case .none: return "circle"
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark"
        }
    }
}

// MARK: - Add Item View

struct AddItemView: View {
    @Environment(\.dismiss) var dismiss

    let categories: [Category]
    let selectedCategory: Category?
    let onCreate: (String, String?, ItemPriority, String) -> Void

    @State private var title = ""
    @State private var content = ""
    @State private var selectedPriority: ItemPriority = .none
    @State private var selectedCategory: Category?

    init(
        categories: [Category],
        selectedCategory: Category?,
        onCreate: @escaping (String, String?, ItemPriority, String) -> Void
    ) {
        self.categories = categories
        self.selectedCategory = selectedCategory
        self.onCreate = onCreate
        _selectedCategory = State(initialValue: selectedCategory)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("项目信息")) {
                    TextField("标题", text: $title)
                    TextField("描述（可选）", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section(header: Text("优先级")) {
                    Picker("优先级", selection: $selectedPriority) {
                        ForEach(ItemPriority.allCases, id: \.self) { priority in
                            HStack {
                                Image(systemName: priorityIcon(for: priority))
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("分类")) {
                    if categories.isEmpty {
                        Text("请先创建分类")
                            .foregroundColor(Color(hex: "#9CA3AF"))
                    } else {
                        Picker("选择分类", selection: $selectedCategory) {
                            ForEach(categories, id: \.id) { category in
                                HStack {
                                    Image(systemName: category.icon ?? "folder.fill")
                                        .foregroundColor(Color(hex: category.color))
                                    Text(category.title)
                                        .foregroundColor(.white)
                                }
                                .tag(category as Category?)
                            }
                        }
                    }
                }
            }
            .background(Color(hex: "#1A1A2E"))
            .scrollContentBackground(.hidden)
            .navigationTitle("新建项目")
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
                        if let category = selectedCategory {
                            onCreate(title, content.isEmpty ? nil : content, selectedPriority, category.id)
                            dismiss()
                        }
                    }
                    .foregroundColor(Color(hex: "#FF6B6B"))
                    .disabled(title.isEmpty || selectedCategory == nil)
                }
            }
        }
    }

    private func priorityIcon(for priority: ItemPriority) -> String {
        switch priority {
        case .none: return "circle"
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark"
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Preview

struct ItemRow_Previews: View {
    static var previews: some View {
        VStack(spacing: 16) {
            ItemRow(
                item: Item(
                    id: "1",
                    userId: "user1",
                    categoryId: "cat1",
                    title: "完成项目报告",
                    content: "需要在周五前完成Q4季度报告",
                    isCompleted: false,
                    priority: .high,
                    dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
                    attachmentUrls: nil,
                    tags: ["工作", "重要"],
                    sortOrder: 0,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                category: Category(
                    id: "cat1",
                    userId: "user1",
                    title: "工作",
                    description: nil,
                    color: "#FF6B6B",
                    icon: "briefcase.fill",
                    sortOrder: 0,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                onToggle: {},
                onDelete: {}
            )

            ItemRow(
                item: Item(
                    id: "2",
                    userId: "user1",
                    categoryId: "cat2",
                    title: "购买杂货",
                    content: "牛奶、鸡蛋、面包",
                    isCompleted: true,
                    priority: .none,
                    dueDate: nil,
                    attachmentUrls: nil,
                    tags: nil,
                    sortOrder: 1,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                category: Category(
                    id: "cat2",
                    userId: "user1",
                    title: "个人",
                    description: nil,
                    color: "#4ECDC4",
                    icon: "person.fill",
                    sortOrder: 1,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                onToggle: {},
                onDelete: {}
            )
        }
        .padding()
        .background(Color(hex: "#1A1A2E"))
    }
}
