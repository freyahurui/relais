//
//  ItemsRepository.swift
//  Relais
//
//  Created on 2025-02-15.
//

import Foundation
import Supabase

/// Items repository
/// Handles all item operations
@MainActor
class ItemsRepository: ObservableObject {

    // MARK: - Singleton

    static let shared = ItemsRepository()

    // MARK: - Properties

    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared
    private var realtimeChannel: RealtimeChannel?

    // MARK: - Initialization

    private init() {
        setupRealtimeSubscription()
    }

    // MARK: - Fetch Items

    func fetchItems(categoryId: String? = nil) async throws {
        guard let client = supabase.supabaseClient,
              let userId = supabase.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        var query = client.database
            .from(SupabaseConfig.itemsTable)
            .select()
            .eq("user_id", value: userId)
            .order("sort_order", ascending: true)

        if let categoryId = categoryId {
            query = query.eq("category_id", value: categoryId)
        }

        let response: [Item] = try await client.database.execute(query: query)

        items = response
    }

    // MARK: - Fetch Item by ID

    func fetchItem(_ itemId: String) async throws -> Item {
        guard let client = supabase.supabaseClient else {
            throw SupabaseError.clientNotConfigured
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        let query = client.database
            .from(SupabaseConfig.itemsTable)
            .select()
            .eq("id", value: itemId)
            .single()

        let response: Item = try await client.database.execute(query: query)

        return response
    }

    // MARK: - Create Item

    func createItem(_ dto: CreateItemDTO) async throws -> Item {
        guard let client = supabase.supabaseClient,
              let userId = supabase.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        var itemData = try JSONEncoder().encode(dto)
        let json = try JSONSerialization.jsonObject(with: itemData) as? [String: Any] ?? [:]
        var mutableJson = json

        // Add user_id
        mutableJson["user_id"] = userId

        let query = client.database
            .from(SupabaseConfig.itemsTable)
            .insert(values: mutableJson)
            .select()
            .single()

        let response: Item = try await client.database.execute(query: query)

        items.append(response)

        return response
    }

    // MARK: - Update Item

    func updateItem(_ itemId: String, _ dto: UpdateItemDTO) async throws -> Item {
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

        if let content = dto.content {
            updates["content"] = content
        }

        if let isCompleted = dto.isCompleted {
            updates["is_completed"] = isCompleted
        }

        if let priority = dto.priority {
            updates["priority"] = priority.rawValue
        }

        if let dueDate = dto.dueDate {
            updates["due_date"] = dueDate
        }

        if let tags = dto.tags {
            updates["tags"] = tags
        }

        updates["updated_at"] = Date().ISO8601Format()

        let query = client.database
            .from(SupabaseConfig.itemsTable)
            .update(values: updates)
            .eq("id", value: itemId)
            .select()
            .single()

        let response: Item = try await client.database.execute(query: query)

        // Update local array
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index] = response
        }

        return response
    }

    // MARK: - Toggle Item Completion

    func toggleItemCompletion(_ itemId: String) async throws -> Item {
        guard let item = items.first(where: { $0.id == itemId }) else {
            throw SupabaseError.invalidResponse
        }

        return try await updateItem(itemId, UpdateItemDTO(isCompleted: !item.isCompleted))
    }

    // MARK: - Delete Item

    func deleteItem(_ itemId: String) async throws {
        guard let client = supabase.supabaseClient else {
            throw SupabaseError.clientNotConfigured
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        let query = client.database
            .from(SupabaseConfig.itemsTable)
            .delete()
            .eq("id", value: itemId)

        try await client.database.execute(query: query)

        // Remove from local array
        items.removeAll { $0.id == itemId }
    }

    // MARK: - Reorder Items

    func reorderItems(_ itemIds: [String]) async throws {
        guard let client = supabase.supabaseClient else {
            throw SupabaseError.clientNotConfigured
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        // Update sort_order for each item
        for (index, itemId) in itemIds.enumerated() {
            let query = client.database
                .from(SupabaseConfig.itemsTable)
                .update(values: ["sort_order": index])
                .eq("id", value: itemId)

            try await client.database.execute(query: query)
        }

        // Refresh items
        try await fetchItems()
    }

    // MARK: - Search Items

    func searchItems(_ searchText: String) async throws -> [Item] {
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
            .from(SupabaseConfig.itemsTable)
            .select()
            .eq("user_id", value: userId)
            .ilike("title", value: "%\(searchText)%")
            .order("sort_order", ascending: true)

        let response: [Item] = try await client.database.execute(query: query)

        return response
    }

    // MARK: - Filter Items by Priority

    func filterItemsByPriority(_ priority: ItemPriority) async throws -> [Item] {
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
            .from(SupabaseConfig.itemsTable)
            .select()
            .eq("user_id", value: userId)
            .eq("priority", value: priority.rawValue)
            .order("sort_order", ascending: true)

        let response: [Item] = try await client.database.execute(query: query)

        return response
    }

    // MARK: - Filter Items by Completion Status

    func filterItemsByCompletion(_ isCompleted: Bool) async throws -> [Item] {
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
            .from(SupabaseConfig.itemsTable)
            .select()
            .eq("user_id", value: userId)
            .eq("is_completed", value: isCompleted)
            .order("sort_order", ascending: true)

        let response: [Item] = try await client.database.execute(query: query)

        return response
    }

    // MARK: - Realtime Subscription

    private func setupRealtimeSubscription() {
        guard let client = supabase.supabaseClient else {
            return
        }

        let channel = client.realtime.channel("public:items")

        let subscription = channel
            .on("INSERT", filter: nil) { [weak self] payload in
                Task { @MainActor in
                    if let item = try? JSONDecoder().decode(Item.self, from: JSONSerialization.data(withJSONObject: payload)) {
                        self?.items.append(item)
                    }
                }
            }
            .on("UPDATE", filter: nil) { [weak self] payload in
                Task { @MainActor in
                    if let item = try? JSONDecoder().decode(Item.self, from: JSONSerialization.data(withJSONObject: payload)) {
                        if let index = self?.items.firstIndex(where: { $0.id == item.id }) {
                            self?.items[index] = item
                        }
                    }
                }
            }
            .on("DELETE", filter: nil) { [weak self] payload in
                Task { @MainActor in
                    if let itemId = payload["id"] as? String {
                        self?.items.removeAll { $0.id == itemId }
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
