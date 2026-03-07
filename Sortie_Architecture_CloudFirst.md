# Sortie 架构设计 - 云端优先版本

## 版本策略

### Phase 1：云端优先（当前版本）
- 所有数据存储在 Supabase
- iOS App 直接通过 Supabase Client 读写数据
- 实时同步，无需手动同步逻辑
- 快速验证产品核心功能

### Phase 2：混合存储（后续迭代）
- 根据 Phase 1 的用户反馈决定
- 添加本地缓存以提升性能
- 支持离线访问核心功能
- 保持云端作为主要数据源

---

## Phase 1 架构

```
┌─────────────────────────────────────────────────────────────┐
│                      iOS App (Swift)                         │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  UI Layer    │  │ ViewModel    │  │  Repository  │      │
│  │  (SwiftUI)   │  │              │  │   Layer      │      │
│  └──────────────┘  └──────────────┘  └──────┬───────┘      │
└─────────────────────────────────────────────┴───────────────┘
                                                   │
                                                   ▼
┌─────────────────────────────────────────────────────────────┐
│                  Supabase Client (supabase-swift)            │
├─────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Auth (认证)                                           │ │
│  │  - Apple OAuth 登录                                    │ │
│  │  - Session 管理                                        │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Database (PostgreSQL)                                 │ │
│  │  - Realtime 订阅                                       │ │
│  │  - Query Builder                                       │ │
│  │  - RLS 自动处理                                        │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Storage (文件存储)                                    │ │
│  │  - 图片/文件上传                                       │ │
│  │  - 自动生成 CDN URL                                    │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                                   │
                                                   ▼
┌─────────────────────────────────────────────────────────────┐
│                    Supabase Cloud                            │
├─────────────────────────────────────────────────────────────┤
│  PostgreSQL + Realtime + Storage + Auth + Edge Functions    │
└─────────────────────────────────────────────────────────────┘
```

---

## 数据流

### 读取数据
```
UI 组件
  ↓ (State 变化触发)
ViewModel
  ↓ (调用 Repository)
Repository
  ↓ (Supabase 查询)
Supabase Client
  ↓ (HTTPS + RLS)
Supabase Database
  ↓ (返回结果)
Repository (缓存到内存)
  ↓ (传递 ViewModel)
ViewModel (更新 State)
  ↓
UI 更新
```

### 写入数据
```
用户操作
  ↓
UI 组件
  ↓ (调用 ViewModel 方法)
ViewModel
  ↓ (验证 + 构造数据)
Repository
  ↓ (Supabase 插入/更新)
Supabase Client
  ↓ (HTTPS + RLS 验证)
Supabase Database
  ↓ (触发 Realtime 广播)
所有订阅的客户端
  ↓ (自动更新)
UI 自动刷新
```

### Realtime 同步
```
设备 A 修改数据
  ↓
Supabase Database
  ↓
Realtime Engine
  ↓
├─> 设备 A (确认更新)
└─> 设备 B (自动收到更新)
     ↓
   UI 自动刷新
```

---

## 技术栈

### iOS 端
```swift
// 主要依赖
- supabase-swift      // Supabase 官方 SDK
- SwiftUI            // UI 框架
- Combine            // 响应式编程
- Kingfisher         // 图片加载（可选）
```

### 后端
```
- Supabase PostgreSQL
- Supabase Realtime
- Supabase Storage
- Supabase Auth
- Supabase Edge Functions（Apple 日历集成）
```

---

## Repository 层设计

```swift
// MARK: - 数据仓库基类
protocol Repository {
    func fetch<T>() async throws -> [T] where T: Decodable
    func create<T>(_ item: T) async throws where T: Encodable
    func update<T>(_ item: T) async throws where T: Encodable
    func delete(id: UUID) async throws
}

// MARK: - Items Repository
class ItemsRepository: Repository {
    private let supabase: SupabaseClient
    private var cache: [Item] = []

    // 获取所有项目
    func fetchItems() async throws -> [Item] {
        let response: [Item] = try await supabase
            .from("items")
            .select()
            .eq("user_id", value: supabase.auth.currentUser?.id)
            .not("deleted_at", operator: .is, value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value

        cache = response
        return response
    }

    // 按 ID 获取
    func fetchItem(id: UUID) async throws -> Item {
        let response: [Item] = try await supabase
            .from("items")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value

        return response.first!
    }

    // 按类型获取
    func fetchItems(type: ItemType) async throws -> [Item] {
        let response: [Item] = try await supabase
            .from("items")
            .select()
            .eq("user_id", value: supabase.auth.currentUser?.id)
            .eq("item_type", value: type.rawValue)
            .not("deleted_at", operator: .is, value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value

        return response
    }

    // 按分类获取
    func fetchItems(categoryId: UUID) async throws -> [Item] {
        let response: [Item] = try await supabase
            .from("items")
            .select()
            .eq("user_id", value: supabase.auth.currentUser?.id)
            .eq("category_id", value: categoryId.uuidString)
            .not("deleted_at", operator: .is, value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value

        return response
    }

    // 创建
    func create(_ item: Item) async throws {
        let _: Item = try await supabase
            .from("items")
            .insert(item)
            .select()
            .single()
            .execute()
            .value

        // 更新缓存
        cache.insert(item, at: 0)
    }

    // 更新
    func update(_ item: Item) async throws {
        let updatedItem = item.withUpdatedTimestamp()
        let _: Item = try await supabase
            .from("items")
            .update(updatedItem)
            .eq("id", value: item.id.uuidString)
            .select()
            .single()
            .execute()
            .value

        // 更新缓存
        if let index = cache.firstIndex(where: { $0.id == item.id }) {
            cache[index] = updatedItem
        }
    }

    // 软删除
    func softDelete(id: UUID) async throws {
        let _: Item = try await supabase
            .from("items")
            .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id.uuidString)
            .select()
            .execute()
            .value

        // 从缓存移除
        cache.removeAll { $0.id == id }
    }
}

// MARK: - Categories Repository
class CategoriesRepository: Repository {
    private let supabase: SupabaseClient
    private var cache: [Category] = []

    func fetchCategories() async throws -> [Category] {
        let response: [Category] = try await supabase
            .from("categories")
            .select()
            .eq("user_id", value: supabase.auth.currentUser?.id)
            .order("sort_order", ascending: true)
            .execute()
            .value

        cache = response
        return response
    }

    func create(_ category: Category) async throws {
        let _: Category = try await supabase
            .from("categories")
            .insert(category)
            .select()
            .single()
            .execute()
            .value

        cache.append(category)
    }

    // ... 其他方法
}

// MARK: - Auth Repository
class AuthRepository {
    private let supabase: SupabaseClient

    // Apple 登录
    func signInWithApple() async throws -> User {
        let signInWithApple = await SignInWithApple()
        let tokens = try await signInWithApple.getCredentials()

        let authData = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: tokens.idToken,
                accessToken: tokens.accessToken
            )
        )

        return authData.user
    }

    // 登出
    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    // 获取当前用户
    func getCurrentUser() -> User? {
        return supabase.auth.currentUser
    }
}
```

---

## ViewModel 层设计

```swift
// MARK: - Items ViewModel
@MainActor
class ItemsViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: ItemsRepository
    private var cancellables = Set<AnyCancellable>()

    init(repository: ItemsRepository) {
        self.repository = repository

        // 设置 Realtime 订阅
        setupRealtimeSubscription()
    }

    // 加载数据
    func loadItems() async {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await repository.fetchItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 按分类加载
    func loadItems(categoryId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await repository.fetchItems(categoryId: categoryId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 创建项目
    func createItem(_ item: Item) async {
        do {
            try await repository.create(item)
            // Realtime 会自动更新，无需手动添加
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 更新项目
    func updateItem(_ item: Item) async {
        do {
            try await repository.update(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 删除项目
    func deleteItem(id: UUID) async {
        do {
            try await repository.softDelete(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Realtime 订阅
    private func setupRealtimeSubscription() {
        let userId = repository.supabase.auth.currentUser?.id

        repository.supabase
            .channel("items_changes")
            .on("postgres_changes", filter: SupabaseRealtimeFilter(
                event: .all,
                schema: "public",
                table: "items",
                filter: "user_id=eq.\(userId?.uuidString ?? "")"
            )) { [weak self] payload in
                Task { @MainActor in
                    await self?.handleRealtimeUpdate(payload)
                }
            }
            .subscribe()
    }

    private func handleRealtimeUpdate(_ payload: RealtimePayload) async {
        switch payload.eventType {
        case .insert:
            if let newItem = payload.decode(Item.self) {
                items.insert(newItem, at: 0)
            }
        case .update:
            if let updatedItem = payload.decode(Item.self) {
                if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
                    items[index] = updatedItem
                }
            }
        case .delete:
            if let deletedItem = payload.decode(Item.self) {
                items.removeAll { $0.id == deletedItem.id }
            }
        default:
            break
        }
    }
}
```

---

## UI 层示例

```swift
// MARK: - Items List View
struct ItemsListView: View {
    @StateObject private var viewModel: ItemsViewModel
    let category: Category?

    init(category: Category? = nil) {
        let repository = ItemsRepository(supabase: .supabase)
        _viewModel = StateObject(wrappedValue: ItemsViewModel(repository: repository))
        self.category = category
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.items) { item in
                    ItemRow(item: item)
                }
            }
            .padding()
        }
        .task {
            if let category = category {
                await viewModel.loadItems(categoryId: category.id)
            } else {
                await viewModel.loadItems()
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Item Row
struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            Circle()
                .fill(item.category.color.toColor())
                .frame(width: 44, height: 44)
                .overlay {
                    Text(item.category.emoji)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let content = item.content {
                    Text(content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // 日程时间
                if let start = item.scheduledStart {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(start.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
```

---

## 完整的 App 启动流程

```swift
@main
struct SortieApp: SwiftUI.App {
    @StateObject private var authState = AuthState()

    init() {
        // 配置 Supabase
        SupabaseClient.supabase = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authState.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .task {
                await authState.checkAuthState()
            }
        }
    }
}

// MARK: - Auth State
@MainActor
class AuthState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?

    private let authRepository = AuthRepository()

    func checkAuthState() async {
        isAuthenticated = authRepository.getCurrentUser() != nil
        currentUser = authRepository.getCurrentUser()
    }

    func signInWithApple() async {
        do {
            let user = try await authRepository.signInWithApple()
            isAuthenticated = true
            currentUser = user
        } catch {
            print("Sign in error: \(error)")
        }
    }

    func signOut() async {
        try? await authRepository.signOut()
        isAuthenticated = false
        currentUser = nil
    }
}
```

---

## 文件上传

```swift
// MARK: - File Upload Service
class FileUploadService {
    private let supabase: SupabaseClient

    func uploadFile(_ fileURL: URL, userId: String) async throws -> String {
        let fileName = "\(UUID().uuidString)_\(fileURL.lastPathComponent)"
        let path = "user-files/\(userId)/\(fileName)"

        // 读取文件数据
        let data = try Data(contentsOf: fileURL)

        // 上传到 Supabase Storage
        try await supabase
            .storage
            .from("user-files")
            .upload(path, file: data)

        // 获取公共 URL
        let url = try await supabase
            .storage
            .from("user-files")
            .createSignedUrl(path: path, expiresIn: 31536000) // 1 年

        return URL(string: url)?.absoluteString ?? ""
    }

    func deleteFile(_ fileURL: String) async throws {
        // 从 URL 提取路径
        guard let url = URL(string: fileURL) else {
            throw UploadError.invalidURL
        }

        let path = url.path.replacingOccurrences(of: "/storage/v1/object/public/user-files/", with: "")

        try await supabase
            .storage
            .from("user-files")
            .remove(paths: [path])
    }
}

enum UploadError: Error {
    case invalidURL
    case uploadFailed
}
```

---

## 性能优化

### 1. 内存缓存
```swift
class CachedItemsRepository {
    private let cache = NSCache<NSString, [Item]>()
    private let repository: ItemsRepository

    func fetchItems(type: ItemType) async throws -> [Item] {
        let cacheKey = "items_\(type.rawValue)" as NSString

        // 检查缓存
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        // 从数据库加载
        let items = try await repository.fetchItems(type: type)

        // 缓存结果
        cache.setObject(items, forKey: cacheKey)

        return items
    }
}
```

### 2. 分页加载
```swift
func fetchItems(page: Int, pageSize: Int = 20) async throws -> [Item] {
    let response: [Item] = try await supabase
        .from("items")
        .select()
        .eq("user_id", value: userId)
        .not("deleted_at", operator: .is, value: nil)
        .order("created_at", ascending: false)
        .range(from: page * pageSize, to: (page + 1) * pageSize - 1)
        .execute()
        .value

    return response
}
```

### 3. 请求去重
```swift
class DebouncedRepository {
    private var ongoingTasks: [String: Task<[Item], Error>] = [:]

    func fetchItems(type: ItemType) async throws -> [Item] {
        let key = "fetch_\(type.rawValue)"

        // 如果已有任务在执行，等待它
        if let existingTask = ongoingTasks[key] {
            return try await existingTask.value
        }

        // 创建新任务
        let task = Task {
            try await repository.fetchItems(type: type)
        }

        ongoingTasks[key] = task

        defer { ongoingTasks.removeValue(forKey: key) }

        return try await task.value
    }
}
```

---

## 错误处理

```swift
enum SortieError: LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case serverError(message: String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "请先登录"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .notFound:
            return "未找到相关内容"
        }
    }
}

// 使用
class ItemsViewModel {
    func loadItems() async {
        do {
            items = try await repository.fetchItems()
        } catch let error as SortieError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "未知错误"
        }
    }
}
```

---

## 下一步

Phase 1 实施清单：

- [ ] 创建 Supabase 项目并执行 Schema
- [ ] 配置 Apple OAuth
- [ ] 搭建 iOS 项目基础结构
- [ ] 实现 Auth Repository
- [ ] 实现 Items/Categories Repository
- [ ] 创建 ViewModel 层
- [ ] 构建 UI 组件
- [ ] 集成 Realtime 订阅
- [ ] 实现文件上传功能
- [ ] Edge Functions: Apple 日历同步
- [ ] 测试与调试

准备好开始实施了吗？需要我提供具体的代码实现吗？
