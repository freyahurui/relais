//
//  LoginView.swift
//  Relais
//
//  Created on 2025-02-15.
//

import SwiftUI

/// Login view
/// Handles user authentication (sign in and sign up)
struct LoginView: View {

    // MARK: - Properties

    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = LoginViewModel()
    @FocusState private var focusedField: Field?

    enum Field {
        case email
        case password
        case username
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#1A1A2E"),
                    Color(hex: "#16213E")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Logo and title
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color(hex: "#FF6B6B"))

                    Text("Relais")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(viewModel.isSignUp ? "创建您的账户" : "欢迎使用 Relais")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#9CA3AF"))
                }
                .padding(.top, 60)

                // Form
                VStack(spacing: 20) {
                    // Username field (sign up only)
                    if viewModel.isSignUp {
                        TextField("用户名", text: $viewModel.username)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .focused($focusedField, equals: .username)
                            .submitLabel(.next)
                    }

                    // Email field
                    TextField("邮箱", text: $viewModel.email)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .focused($focusedField, equals: .email)
                        .submitLabel(viewModel.isSignUp ? .next : .done)

                    // Password field
                    SecureField("密码", text: $viewModel.password)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(viewModel.isSignUp ? .newPassword : .password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.done)

                    // Confirm password field (sign up only)
                    if viewModel.isSignUp {
                        SecureField("确认密码", text: $viewModel.confirmPassword)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.done)
                    }

                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color(hex: "#EF4444"))
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#EF4444"))
                        }
                        .transition(.opacity)
                    }

                    // Submit button
                    Button(action: {
                        Task {
                            await viewModel.submit()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 8)
                            }
                            Text(viewModel.isSignUp ? "注册" : "登录")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "#FF6B6B"),
                                    Color(hex: "#FF8E53")
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading || !viewModel.isValid)
                    .opacity(viewModel.isLoading || !viewModel.isValid ? 0.6 : 1)
                }
                .padding(.horizontal, 24)

                // Toggle sign in/sign up
                Button(action: {
                    withAnimation {
                        viewModel.toggleMode()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(viewModel.isSignUp ? "已有账户？" : "还没有账户？")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#9CA3AF"))
                        Text(viewModel.isSignUp ? "登录" : "注册")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#FF6B6B"))
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onSubmit {
            handleSubmit()
        }
    }

    // MARK: - Helper Methods

    private func handleSubmit() {
        switch focusedField {
        case .username:
            focusedField = .email
        case .email:
            focusedField = .password
        case .password, .none:
            Task {
                await viewModel.submit()
            }
        }
    }
}

// MARK: - Login ViewModel

@MainActor
class LoginViewModel: ObservableObject {
    @Published var isSignUp = false
    @Published var email = ""
    @Published var password = ""
    @Published var username = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    @EnvironmentObject var authViewModel: AuthViewModel

    var isValid: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !username.isEmpty && password == confirmPassword
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }

    func toggleMode() {
        isSignUp.toggle()
        errorMessage = nil
    }

    func submit() async {
        isLoading = true
        errorMessage = nil

        if isSignUp {
            await authViewModel.signUp(email: email, password: password, username: username)
        } else {
            await authViewModel.signIn(email: email, password: password)
        }

        isLoading = false

        if let error = authViewModel.errorMessage {
            errorMessage = error
        }
    }
}

// MARK: - Custom TextField Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "#2A2A4A"))
            .foregroundColor(.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: "#3A3A5A"), lineWidth: 1)
            )
    }
}

// MARK: - Preview

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
