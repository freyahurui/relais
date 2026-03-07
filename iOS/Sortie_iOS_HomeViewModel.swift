//
//  HomeViewModel.swift
//  Sortie
//
//  Created on 2025-02-15.
//

import Foundation

/// Home view model
/// Manages home screen state and operations
@MainActor
class HomeViewModel: ObservableObject {

    // MARK: - Properties

    @Published var categories: [Category] = []
    @Published var items: [Item] = []
    @Published var selectedCategory: Category?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessMessage = false
    @Published var successMessage = ""
    @Published var searchText = ""
    @Published var selectedFilter: ItemFilter = .all

    private let categoriesRepository = CategoriesRepository.shared
    private let itemsRepository = ItemsRepository.shared

    // MARK: - Filter Types

    enum ItemFilter: String, CaseIterable {
        case all = "全部"
        case active = "进行中"
        case completed = "已完成"
        case highPriority = "高优先级"

        var icon: String {
            switch self {
            case .all: return "line.3.horizontal.decrease.circle"
            case .active: return "circle.circle"
            case .completed: return "checkmark.circle.fill"
            case .highPriority: return "exclamationmark.triangle.fill"
            }
        }
    }

    // MARK: - Computed Properties

    var filteredItems: [Item] {
        var result = items

        // Apply category filter
        if let category = selectedCategory {
            result = result.filter { $0.categoryId == category.id }
        }

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.content?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        // Apply status/priority filter
        switch selectedFilter {
        case .all:
            break
        case .active:
            result = result.filter { !$0.isCompleted }
        case .completed:
            result = result.filter { $0.isCompleted }
        case .highPriority:
            result = result.filter { item in
                item.priority == .high || item.priority == .urgent
            }
        }

        return result
    }

    var incompleteCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }

    // MARK: - Initialization

    init() {
        loadInitialData()

        // Observe repository changes
        categoriesRepository.$categories
            .assign(to: &$categories)

        itemsRepository.$items
            .assign(to: &$items)
    }

    // MARK: - Load Initial Data

    func loadInitialData() {
        Task {
            await fetchCategories()
            await fetchItems()
        }
    }

    // MARK: - Fetch Categories

    func fetchCategories() async {
        do {
            try await categoriesRepository.fetchCategories()
            categories = categoriesRepository.categories
        } catch {
            errorMessage = "加载分类失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Fetch Items

    func fetchItems() async {
        do {
            try await itemsRepository.fetchItems()
            items = itemsRepository.items
        } catch {
            errorMessage = "加载项目失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Select Category

    func selectCategory(_ category: Category?) {
        selectedCategory = category
    }

    // MARK: - Create Category

    func createCategory(title: String, description: String? = nil, color: String = "#FF6B6B", icon: String? = nil) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        // Validate input
        guard !title.isEmpty else {
            errorMessage = "请输入分类标题"
            return
        }

        do {
            let dto = CreateCategoryDTO(
                title: title,
                description: description,
                color: color,
                icon: icon,
                sortOrder: categories.count
            )

            _ = try await categoriesRepository.createCategory(dto)
            showSuccess(message: "分类已创建")
        } catch {
            errorMessage = "创建分类失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Update Category

    func updateCategory(_ categoryId: String, title: String? = nil, description: String? = nil, color: String? = nil, icon: String? = nil) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let dto = UpdateCategoryDTO(
                title: title,
                description: description,
                color: color,
                icon: icon
            )

            _ = try await categoriesRepository.updateCategory(categoryId, dto)
            showSuccess(message: "分类已更新")
        } catch {
            errorMessage = "更新分类失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Delete Category

    func deleteCategory(_ categoryId: String) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            try await categoriesRepository.deleteCategory(categoryId)

            // Clear selected category if it was deleted
            if selectedCategory?.id == categoryId {
                selectedCategory = nil
            }

            showSuccess(message: "分类已删除")
        } catch {
            errorMessage = "删除分类失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Create Item

    func createItem(title: String, content: String? = nil, priority: ItemPriority = .none, categoryId: String) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        // Validate input
        guard !title.isEmpty else {
            errorMessage = "请输入项目标题"
            return
        }

        do {
            let dto = CreateItemDTO(
                categoryId: categoryId,
                title: title,
                content: content,
                priority: priority,
                sortOrder: items.count
            )

            _ = try await itemsRepository.createItem(dto)
            showSuccess(message: "项目已创建")
        } catch {
            errorMessage = "创建项目失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Update Item

    func updateItem(_ itemId: String, title: String? = nil, content: String? = nil, isCompleted: Bool? = nil, priority: ItemPriority? = nil) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let dto = UpdateItemDTO(
                title: title,
                content: content,
                isCompleted: isCompleted,
                priority: priority,
                dueDate: nil,
                tags: nil
            )

            _ = try await itemsRepository.updateItem(itemId, dto)
            showSuccess(message: "项目已更新")
        } catch {
            errorMessage = "更新项目失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Toggle Item Completion

    func toggleItemCompletion(_ itemId: String) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            _ = try await itemsRepository.toggleItemCompletion(itemId)
        } catch {
            errorMessage = "更新项目状态失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Delete Item

    func deleteItem(_ itemId: String) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            try await itemsRepository.deleteItem(itemId)
            showSuccess(message: "项目已删除")
        } catch {
            errorMessage = "删除项目失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Refresh Data

    func refresh() async {
        await fetchCategories()
        await fetchItems()
    }

    // MARK: - Helper Methods

    private func showSuccess(message: String) {
        successMessage = message
        showSuccessMessage = true

        // Hide success message after 2 seconds
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            showSuccessMessage = false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func clearSuccess() {
        successMessage = ""
        showSuccessMessage = false
    }
}
