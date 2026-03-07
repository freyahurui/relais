//
//  HomeView.swift
//  Relais
//
//  Created on 2025-02-15.
//

import SwiftUI

/// Home view
/// Main application view displaying categories and items
struct HomeView: View {

    // MARK: - Properties

    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showAddCategory = false
    @State private var showAddItem = false
    @State private var showSettings = false

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "#1A1A2E")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Categories section
                    categoriesSection

                    Divider()
                        .background(Color(hex: "#2A2A4A"))

                    // Items section
                    itemsSection
                }
            }
            .navigationTitle("Relais")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let user = authViewModel.currentUser {
                        HStack(spacing: 8) {
                            AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color(hex: "#FF6B6B"))
                                    .overlay {
                                        Text(String(user.username.prefix(1)).uppercased())
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())

                            Text(user.username)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings.toggle()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(Color(hex: "#9CA3AF"))
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authViewModel)
            }
        }
        .overlay(alignment: .top) {
            // Success message
            if viewModel.showSuccessMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#10B981"))
                    Text(viewModel.successMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: "#2A2A4A"))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
                .padding(.top, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    // MARK: - Categories Section

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("分类")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    showAddCategory.toggle()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#FF6B6B"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Categories list
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // All items button
                    CategoryButton(
                        title: "全部",
                        color: "#9CA3AF",
                        icon: "square.grid.2x2",
                        isSelected: viewModel.selectedCategory == nil
                    ) {
                        withAnimation {
                            viewModel.selectCategory(nil)
                        }
                    }

                    // Category buttons
                    ForEach(viewModel.categories) { category in
                        CategoryButton(
                            title: category.title,
                            color: category.color,
                            icon: category.icon ?? "folder.fill",
                            isSelected: viewModel.selectedCategory?.id == category.id
                        ) {
                            withAnimation {
                                viewModel.selectCategory(category)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategoryView { title, description, color, icon in
                Task {
                    await viewModel.createCategory(
                        title: title,
                        description: description,
                        color: color,
                        icon: icon
                    )
                }
            }
        }
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("项目")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                // Stats
                HStack(spacing: 16) {
                    Stat(count: viewModel.incompleteCount, label: "进行中")
                    Stat(count: viewModel.completedCount, label: "已完成")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HomeViewModel.ItemFilter.allCases, id: \.self) { filter in
                        FilterButton(
                            title: filter.rawValue,
                            icon: filter.icon,
                            isSelected: viewModel.selectedFilter == filter
                        ) {
                            withAnimation {
                                viewModel.selectedFilter = filter
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 12)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: "#9CA3AF"))

                TextField("搜索项目...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)

                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(hex: "#9CA3AF"))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#2A2A4A"))
            .cornerRadius(10)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Items list
            if viewModel.filteredItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredItems) { item in
                            ItemRow(
                                item: item,
                                category: viewModel.categories.first { $0.id == item.categoryId },
                                onToggle: {
                                    Task {
                                        await viewModel.toggleItemCompletion(item.id)
                                    }
                                },
                                onDelete: {
                                    Task {
                                        await viewModel.deleteItem(item.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#3A3A5A"))

            Text("还没有项目")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#9CA3AF"))

            Button(action: {
                showAddItem.toggle()
            }) {
                Text("创建第一个项目")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#FF6B6B"))
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showAddItem) {
            AddItemView(
                categories: viewModel.categories,
                selectedCategory: viewModel.selectedCategory
            ) { title, content, priority, categoryId in
                Task {
                    await viewModel.createItem(
                        title: title,
                        content: content,
                        priority: priority,
                        categoryId: categoryId
                    )
                }
            }
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let title: String
    let color: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color(hex: color).opacity(0.2) : Color(hex: "#2A2A4A")
            )
            .foregroundColor(isSelected ? Color(hex: color) : Color(hex: "#9CA3AF"))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color(hex: color) : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? Color(hex: "#FF6B6B") : Color(hex: "#2A2A4A")
            )
            .foregroundColor(isSelected ? .white : Color(hex: "#9CA3AF"))
            .cornerRadius(16)
        }
    }
}

// MARK: - Stat

struct Stat: View {
    let count: Int
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#9CA3AF"))
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Profile section
                VStack(spacing: 16) {
                    if let user = authViewModel.currentUser {
                        AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color(hex: "#FF6B6B"))
                                .overlay {
                                    Text(String(user.username.prefix(1)).uppercased())
                                        .font(.system(size: 32, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

                        Text(user.username)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Button(action: {
                        // Edit profile
                    }) {
                        Text("编辑资料")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#FF6B6B"))
                    }
                }
                .padding(.top, 40)

                Divider()
                    .background(Color(hex: "#2A2A4A"))
                    .padding(.vertical, 20)

                // Logout button
                Button(action: {
                    Task {
                        await authViewModel.signOut()
                        dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.right.square.fill")
                            .font(.system(size: 20))
                        Text("退出登录")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#EF4444"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#2A2A4A"))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(Color(hex: "#1A1A2E"))
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FF6B6B"))
                }
            }
        }
    }
}

// MARK: - Preview

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthViewModel())
    }
}
