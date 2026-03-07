//
//  AuthRepository.swift
//  Sortie
//
//  Created on 2025-02-15.
//

import Foundation
import Supabase

/// Authentication repository
/// Handles all authentication operations
@MainActor
class AuthRepository: ObservableObject {

    // MARK: - Singleton

    static let shared = AuthRepository()

    // MARK: - Properties

    @Published var isAuthenticated = false
    @Published var currentUser: Profile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared

    // MARK: - Initialization

    private init() {
        isAuthenticated = supabase.isAuthenticated
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            try await supabase.signIn(email: email, password: password)
            isAuthenticated = true

            // Fetch user profile
            try await fetchUserProfile()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, username: String) async throws {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            try await supabase.signUp(email: email, password: password, username: username)
            isAuthenticated = true

            // Profile will be created by database trigger
            // Fetch user profile
            try await fetchUserProfile()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Sign Out

    func signOut() async throws {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            try await supabase.signOut()
            isAuthenticated = false
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Fetch User Profile

    private func fetchUserProfile() async throws {
        guard let client = supabase.supabaseClient,
              let userId = supabase.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        let query = client.database
            .from(SupabaseConfig.profilesTable)
            .select()
            .eq("user_id", value: userId)
            .single()

        let response: Profile = try await client.database.execute(query: query)

        currentUser = response
    }

    // MARK: - Update Profile

    func updateProfile(username: String? = nil, avatarUrl: String? = nil) async throws {
        guard let client = supabase.supabaseClient,
              let userId = supabase.currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        var updates: [String: Any] = [:]

        if let username = username {
            updates["username"] = username
        }

        if let avatarUrl = avatarUrl {
            updates["avatar_url"] = avatarUrl
        }

        updates["updated_at"] = Date().ISO8601Format()

        let query = client.database
            .from(SupabaseConfig.profilesTable)
            .update(values: updates)
            .eq("user_id", value: userId)

        try await client.database.execute(query: query)

        // Refresh profile
        try await fetchUserProfile()
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async throws {
        guard let client = supabase.supabaseClient else {
            throw SupabaseError.clientNotConfigured
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        // Supabase will send a password reset email
        try await client.auth.resetPassword(email: email)
    }

    // MARK: - Validation

    func validateEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    func validatePassword(_ password: String) -> Bool {
        // Minimum 6 characters
        return password.count >= 6
    }

    func validateUsername(_ username: String) -> Bool {
        // 3-20 characters, alphanumeric and underscores only
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
}
