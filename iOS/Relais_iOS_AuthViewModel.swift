//
//  AuthViewModel.swift
//  Relais
//
//  Created on 2025-02-15.
//

import Foundation

/// Authentication view model
/// Manages authentication state and operations
@MainActor
class AuthViewModel: ObservableObject {

    // MARK: - Properties

    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessMessage = false
    @Published var successMessage = ""

    private let authRepository = AuthRepository.shared

    // MARK: - Computed Properties

    var currentUser: Profile? {
        return authRepository.currentUser
    }

    // MARK: - Initialization

    init() {
        isAuthenticated = authRepository.isAuthenticated

        // Observe authentication changes
        authRepository.$isAuthenticated
            .assign(to: &$isAuthenticated)
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        // Validate input
        guard authRepository.validateEmail(email) else {
            errorMessage = "请输入有效的邮箱地址"
            return
        }

        guard authRepository.validatePassword(password) else {
            errorMessage = "密码至少需要6个字符"
            return
        }

        do {
            try await authRepository.signIn(email: email, password: password)
            showSuccess(message: "登录成功")
        } catch {
            errorMessage = "登录失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, username: String) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        // Validate input
        guard authRepository.validateEmail(email) else {
            errorMessage = "请输入有效的邮箱地址"
            return
        }

        guard authRepository.validatePassword(password) else {
            errorMessage = "密码至少需要6个字符"
            return
        }

        guard authRepository.validateUsername(username) else {
            errorMessage = "用户名必须是3-20个字符，只能包含字母、数字和下划线"
            return
        }

        do {
            try await authRepository.signUp(email: email, password: password, username: username)
            showSuccess(message: "注册成功")
        } catch {
            errorMessage = "注册失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            try await authRepository.signOut()
            showSuccess(message: "已退出登录")
        } catch {
            errorMessage = "退出失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Reset Password

    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        // Validate input
        guard authRepository.validateEmail(email) else {
            errorMessage = "请输入有效的邮箱地址"
            return
        }

        do {
            try await authRepository.resetPassword(email: email)
            showSuccess(message: "密码重置邮件已发送")
        } catch {
            errorMessage = "发送失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Update Profile

    func updateProfile(username: String? = nil, avatarUrl: String? = nil) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        // Validate username if provided
        if let username = username {
            guard authRepository.validateUsername(username) else {
                errorMessage = "用户名必须是3-20个字符，只能包含字母、数字和下划线"
                return
            }
        }

        do {
            try await authRepository.updateProfile(username: username, avatarUrl: avatarUrl)
            showSuccess(message: "个人资料已更新")
        } catch {
            errorMessage = "更新失败：\(error.localizedDescription)"
        }
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
