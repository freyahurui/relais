//
//  CategoriesRepository.swift
//  Sortie
//
//  Created on 2025-02-15.
//

import Foundation
import Supabase

/// Categories repository
/// Handles all category operations
@MainActor
class CategoriesRepository: ObservableObject {

    // MARK: - Singleton

    static let shared = CategoriesRepository()

    // MARK: - Properties

    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared
    private var realtimeChannel: RealtimeChannel?

    // MARK: - Initialization

    private init() {
        setupRealtimeSubscription()
    }

    // MARK: - Fetch Categories

    func fetchCategories() async throws {
        guard let client = supabase.supabaseClient,
              let userId = supabase.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        let query = client.database
            .from(SupabaseConfig.categoriesTable)
            .select()
            .eq("user_id", value: userId)
            .order("sort_order", ascending: true)

        let response: [Category] = try await client.database.execute(query: query)

        categories = response
    }

    // MARK: - Create Category

    func createCategory(_ dto: CreateCategoryDTO) async throws -> Category {
        guard let client = supabase.supabaseClient,
              let userId = supabase.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        var categoryData = try JSONEncoder().encode(dto)
        let json = try JSONSerialization.jsonObject(with: categoryData) as? [String: Any] ?? [:]
        var mutableJson = json

        // Add user_id
        mutableJson["user_id"] = userId

        let query = client.database
            .from(SupabaseConfig.categoriesTable)
            .insert(values: mutableJson)
            .select()
            .single()

        let response: Category = try await client.database.execute(query: query)

        categories.append(response)

        return response
    }

    // MARK: - Update Category

    func updateCategory(_ categoryId: String, _ dto: UpdateCategoryDTO) async throws -> Category {
        guard let client = supabase.supabaseClient else {
            throw SupabaseError.clientNotConfigured
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        var updates: [String: Any] = [:]

        if let title = dto.title {
            updates["title"] = title
        }

        if let description = dto.description {
            updates["description"] = description
        }

        if let color = dto.color {
            updates["color"] = color
        }

        if let icon = dto.icon {
            updates["icon"] = icon
        }

        updates["updated_at"] = Date().ISO8601Format()

        let query = client.database
            .from(SupabaseConfig.categoriesTable)
            .update(values: updates)
            .eq("id", value: categoryId)
            .select()
            .single()

        let response: Category = try await client.database.execute(query: query)

        // Update local array
        if let index = categories.firstIndex(where: { $0.id == categoryId }) {
            categories[index] = response
        }

        return response
    }

    // MARK: - Delete Category

    func deleteCategory(_ categoryId: String) async throws {
        guard let client = supabase.supabaseClient else {
            throw SupabaseError.clientNotConfigured
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        let query = client.database
            .from(SupabaseConfig.categoriesTable)
            .delete()
            .eq("id", value: categoryId)

        try await client.database.execute(query: query)

        // Remove from local array
        categories.removeAll { $0.id == categoryId }
    }

    // MARK: - Reorder Categories

    func reorderCategories(_ categoryIds: [String]) async throws {
        guard let client = supabase.supabaseClient else {
            throw SupabaseError.clientNotConfigured
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        // Update sort_order for each category
        for (index, categoryId) in categoryIds.enumerated() {
            let query = client.database
                .from(SupabaseConfig.categoriesTable)
                .update(values: ["sort_order": index])
                .eq("id", value: categoryId)

            try await client.database.execute(query: query)
        }

        // Refresh categories
        try await fetchCategories()
    }

    // MARK: - Realtime Subscription

    private func setupRealtimeSubscription() {
        guard let client = supabase.supabaseClient else {
            return
        }

        let channel = client.realtime.channel("public:categories")

        let subscription = channel
            .on("INSERT", filter: nil) { [weak self] payload in
                Task { @MainActor in
                    if let category = try? JSONDecoder().decode(Category.self, from: JSONSerialization.data(withJSONObject: payload)) {
                        self?.categories.append(category)
                    }
                }
            }
            .on("UPDATE", filter: nil) { [weak self] payload in
                Task { @MainActor in
                    if let category = try? JSONDecoder().decode(Category.self, from: JSONSerialization.data(withJSONObject: payload)) {
                        if let index = self?.categories.firstIndex(where: { $0.id == category.id }) {
                            self?.categories[index] = category
                        }
                    }
                }
            }
            .on("DELETE", filter: nil) { [weak self] payload in
                Task { @MainActor in
                    if let categoryId = payload["id"] as? String {
                        self?.categories.removeAll { $0.id == categoryId }
                    }
                }
            }
            .subscribe()

        realtimeChannel = channel
    }

    // MARK: - Cleanup

    deinit {
        realtimeChannel?.unsubscribe()
    }
}
