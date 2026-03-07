//
//  SupabaseConfig.swift
//  Sortie
//
//  Created on 2025-02-15.
//

import Foundation

/// Supabase configuration constants
struct SupabaseConfig {

    // MARK: - Configuration

    /// Supabase project URL
    /// Replace with your actual Supabase project URL
    static let supabaseURL = "https://your-project.supabase.co"

    /// Supabase anon/public API key
    /// Replace with your actual Supabase anon key
    static let supabaseKey = "your-anon-key-here"

    // MARK: - Storage Keys

    static let accessTokenKey = "supabase_access_token"
    static let refreshTokenKey = "supabase_refresh_token"
    static let userIDKey = "user_id"

    // MARK: - Table Names

    static let profilesTable = "profiles"
    static let categoriesTable = "categories"
    static let itemsTable = "items"
    static let categorySharesTable = "category_shares"

    // MARK: - Storage Buckets

    static let attachmentsBucket = "attachments"
    static let avatarsBucket = "avatars"

    // MARK: - Validation

    static func validateConfig() -> Bool {
        return !supabaseURL.isEmpty &&
               !supabaseURL.contains("your-project") &&
               !supabaseKey.isEmpty &&
               !supabaseKey.contains("your-anon-key")
    }

    static var isConfigured: Bool {
        validateConfig()
    }
}

// MARK: - Environment Configuration

enum Environment {
    case development
    case production

    #if DEBUG
    static var current: Environment = .development
    #else
    static var current: Environment = .production
    #endif

    var baseURL: String {
        switch current {
        case .development:
            return SupabaseConfig.supabaseURL
        case .production:
            return SupabaseConfig.supabaseURL
        }
    }
}
