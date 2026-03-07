//
//  SupabaseManager.swift
//  Sortie
//
//  Created on 2025-02-15.
//

import Foundation
import Supabase

/// Supabase client manager
/// Handles all Supabase interactions
@MainActor
class SupabaseManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SupabaseManager()

    // MARK: - Properties

    private var client: SupabaseClient?

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var errorMessage: String?

    // MARK: - Initialization

    private init() {
        setupClient()
        checkAuthentication()
    }

    // MARK: - Setup

    private func setupClient() {
        guard SupabaseConfig.isConfigured else {
            print("⚠️ Supabase is not configured. Please update SupabaseConfig.swift")
            return
        }

        let configuration = SupabaseConfiguration(
            url: SupabaseConfig.supabaseURL,
            headers: [
                "apikey": SupabaseConfig.supabaseKey,
                "Authorization": "Bearer \(SupabaseConfig.supabaseKey)"
            ]
        )

        client = SupabaseClient(configuration: configuration)
        print("✅ Supabase client configured successfully")
    }

    // MARK: - Authentication

    private func checkAuthentication() {
        guard let token = UserDefaults.standard.string(forKey: SupabaseConfig.accessTokenKey) else {
            isAuthenticated = false
            return
        }

        Task {
            do {
                let user = try await client?.auth.user(token: token)
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                }
            } catch {
                await MainActor.run {
                    self.isAuthenticated = false
                    self.currentUser = nil
                }
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        guard let client = client else {
            throw SupabaseError.clientNotConfigured
        }

        let response = try await client.auth.signIn(
            email: email,
            password: password
        )

        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true

            // Store tokens
            UserDefaults.standard.set(response.accessToken, forKey: SupabaseConfig.accessTokenKey)
            UserDefaults.standard.set(response.refreshToken, forKey: SupabaseConfig.refreshTokenKey)
        }
    }

    func signUp(email: String, password: String, username: String) async throws {
        guard let client = client else {
            throw SupabaseError.clientNotConfigured
        }

        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["username": username]
        )

        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true

            // Store tokens
            UserDefaults.standard.set(response.accessToken, forKey: SupabaseConfig.accessTokenKey)
            UserDefaults.standard.set(response.refreshToken, forKey: SupabaseConfig.refreshTokenKey)
        }
    }

    func signOut() async throws {
        guard let client = client else {
            throw SupabaseError.clientNotConfigured
        }

        try await client.auth.signOut()

        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false

            // Clear stored tokens
            UserDefaults.standard.removeObject(forKey: SupabaseConfig.accessTokenKey)
            UserDefaults.standard.removeObject(forKey: SupabaseConfig.refreshTokenKey)
            UserDefaults.standard.removeObject(forKey: SupabaseConfig.userIDKey)
        }
    }

    // MARK: - Client Access

    var supabaseClient: SupabaseClient? {
        return client
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case clientNotConfigured
    case notAuthenticated
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .clientNotConfigured:
            return "Supabase client is not configured"
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}
