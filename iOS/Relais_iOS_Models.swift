//
//  Models.swift
//  Relais
//
//  Created on 2025-02-15.
//

import Foundation

// MARK: - Profile Model

struct Profile: Codable, Identifiable {
    let id: String
    let userId: String
    let username: String
    let avatarUrl: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        username = try container.decode(String.self, forKey: .username)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)

        let dateFormatter = ISO8601DateFormatter()
        let createdString = try container.decode(String.self, forKey: .createdAt)
        let updatedString = try container.decode(String.self, forKey: .updatedAt)

        createdAt = dateFormatter.date(from: createdString) ?? Date()
        updatedAt = dateFormatter.date(from: updatedString) ?? Date()
    }
}

// MARK: - Category Model

struct Category: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let title: String
    let description: String?
    let color: String
    let icon: String?
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case color
        case icon
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        color = try container.decode(String.self, forKey: .color)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)

        let dateFormatter = ISO8601DateFormatter()
        let createdString = try container.decode(String.self, forKey: .createdAt)
        let updatedString = try container.decode(String.self, forKey: .updatedAt)

        createdAt = dateFormatter.date(from: createdString) ?? Date()
        updatedAt = dateFormatter.date(from: updatedString) ?? Date()
    }
}

// MARK: - Item Model

struct Item: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let categoryId: String
    let title: String
    let content: String?
    let isCompleted: Bool
    let priority: ItemPriority
    let dueDate: Date?
    let attachmentUrls: [String]?
    let tags: [String]?
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case categoryId = "category_id"
        case title
        case content
        case isCompleted = "is_completed"
        case priority
        case dueDate = "due_date"
        case attachmentUrls = "attachment_urls"
        case tags
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        categoryId = try container.decode(String.self, forKey: .categoryId)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        priority = try container.decodeIfPresent(ItemPriority.self, forKey: .priority) ?? .none
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        attachmentUrls = try container.decodeIfPresent([String].self, forKey: .attachmentUrls)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)

        let dateFormatter = ISO8601DateFormatter()
        let createdString = try container.decode(String.self, forKey: .createdAt)
        let updatedString = try container.decode(String.self, forKey: .updatedAt)

        createdAt = dateFormatter.date(from: createdString) ?? Date()
        updatedAt = dateFormatter.date(from: updatedString) ?? Date()

        if let dueDateString = try container.decodeIfPresent(String.self, forKey: .dueDate) {
            dueDate = dateFormatter.date(from: dueDateString)
        } else {
            dueDate = nil
        }
    }
}

// MARK: - Item Priority

enum ItemPriority: String, Codable, CaseIterable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"

    var displayName: String {
        switch self {
        case .none: return "无"
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .urgent: return "紧急"
        }
    }

    var color: String {
        switch self {
        case .none: return "#9CA3AF"
        case .low: return "#10B981"
        case .medium: return "#F59E0B"
        case .high: return "#EF4444"
        case .urgent: return "#DC2626"
        }
    }
}

// MARK: - Category Share Model

struct CategoryShare: Codable, Identifiable {
    let id: String
    let categoryId: String
    let sharedBy: String
    let sharedWith: String
    let permission: SharePermission
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case sharedBy = "shared_by"
        case sharedWith = "shared_with"
        case permission
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        categoryId = try container.decode(String.self, forKey: .categoryId)
        sharedBy = try container.decode(String.self, forKey: .sharedBy)
        sharedWith = try container.decode(String.self, forKey: .sharedWith)
        permission = try container.decode(SharePermission.self, forKey: .permission)

        let dateFormatter = ISO8601DateFormatter()
        let createdString = try container.decode(String.self, forKey: .createdAt)
        createdAt = dateFormatter.date(from: createdString) ?? Date()
    }
}

// MARK: - Share Permission

enum SharePermission: String, Codable {
    case view = "view"
    case edit = "edit"
    case admin = "admin"
}

// MARK: - Create/Update DTOs

struct CreateCategoryDTO: Codable {
    let title: String
    let description: String?
    let color: String
    let icon: String?
    let sortOrder: Int

    init(title: String, description: String? = nil, color: String = "#FF6B6B", icon: String? = nil, sortOrder: Int = 0) {
        self.title = title
        self.description = description
        self.color = color
        self.icon = icon
        self.sortOrder = sortOrder
    }
}

struct UpdateCategoryDTO: Codable {
    let title: String?
    let description: String?
    let color: String?
    let icon: String?
}

struct CreateItemDTO: Codable {
    let categoryId: String
    let title: String
    let content: String?
    let priority: ItemPriority
    let dueDate: String?
    let tags: [String]?
    let sortOrder: Int

    init(categoryId: String, title: String, content: String? = nil, priority: ItemPriority = .none, dueDate: Date? = nil, tags: [String]? = nil, sortOrder: Int = 0) {
        self.categoryId = categoryId
        self.title = title
        self.content = content
        self.priority = priority
        self.dueDate = dueDate?.ISO8601Format()
        self.tags = tags
        self.sortOrder = sortOrder
    }
}

struct UpdateItemDTO: Codable {
    let title: String?
    let content: String?
    let isCompleted: Bool?
    let priority: ItemPriority?
    let dueDate: String?
    let tags: [String]?
}
