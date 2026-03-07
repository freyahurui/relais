# Sortie iOS 项目设置指南

## 项目概述

- **项目名称**: Sortie
- **语言**: Swift
- **UI 框架**: SwiftUI
- **架构**: MVVM + Repository
- **最低版本**: iOS 17.0+
- **IDE**: Xcode 15.0+

---

## 步骤 1: 创建 Xcode 项目

### 1.1 新建项目

1. 打开 Xcode
2. 选择 **File > New > Project**
3. 选择 **iOS > App**
4. 填写项目信息：
   - **Product Name**: `Sortie`
   - **Team**: 选择你的开发团队
   - **Organization Identifier**: `com.yourcompany`
   - **Bundle Identifier**: `com.yourcompany.Sortie`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: None
   - 勾选 **Include Tests**

### 1.2 配置项目设置

在 Xcode 中：
1. 选择项目文件（Sortie）
2. 在 **Signing & Capabilities** 中：
   - 启用 **Automatically manage signing**
   - 添加 **Sign in with Apple** capability
3. 在 **General** 中：
   - **iOS Deployment Target**: 设置为 `17.0`
   - **iPhone Orientation**: 勾选所有方向

---

## 步骤 2: 添加 Swift Package 依赖

### 2.1 添加 Supabase SDK

1. 选择 **File > Add Package Dependencies...**
2. 输入 URL: `https://github.com/supabase-community/supabase-swift.git`
3. 选择版本：`Up to Next Major` (或具体版本如 `2.0.0`)
4. 点击 **Add Package**
5. 确认 **Supabase** 库被添加到 **Sortie** target

### 2.2 验证依赖

在 **Project Navigator** 中应该能看到：
```
Sortie
├── Sortie
├── SortieTests
└── Package Dependencies
    └── supabase-swift
```

---

## 步骤 3: 配置 Apple Sign In

### 3.1 在 Xcode 中启用

1. 选择项目文件
2. 选择 **Signing & Capabilities** 标签
3. 点击 **+ Capability**
4. 添加 **Sign in with Apple**

### 3.2 在 Apple Developer 配置

1. 登录 [Apple Developer](https://developer.apple.com)
2. 进入 **Certificates, Identifiers & Profiles**
3. 创建 **App ID**，启用 **Sign in with Apple**
4. 记录你的 **Bundle Identifier**

---

## 步骤 4: 配置 Supabase

### 4.1 创建 Supabase 项目

1. 访问 [supabase.com](https://supabase.com)
2. 点击 **New Project**
3. 填写信息：
   - **Name**: `Sortie`
   - **Database Password**: (设置强密码并保存)
   - **Region**: 选择离你最近的区域
4. 等待项目创建完成（约 2 分钟）

### 4.2 执行数据库 Schema

1. 在 Supabase Dashboard 中
2. 进入 **SQL Editor**
3. 创建新的 Query
4. 复制 `supabase_schema.sql` 的内容
5. 点击 **Run** 执行

### 4.3 配置 Apple OAuth

1. 在 Supabase Dashboard 中
2. 进入 **Authentication > Providers**
3. 启用 **Apple**
4. 配置：
   - **Client ID**: 从 Apple Developer 获取（Services ID 或 App ID）
   - **Team ID**: 你的 Apple Team ID
   - **Key ID**: 创建的私钥 ID
   - **Private Key**: 上传 `.p8` 文件内容

### 4.4 获取 API 密钥

1. 在 Supabase Dashboard 中
2. 进入 **Project Settings > API**
3. 复制以下信息：
   - **Project URL**
   - **anon public key**

---

## 步骤 5: 创建项目文件夹结构

### 5.1 创建文件夹

在 Xcode **Project Navigator** 中，创建以下文件夹：

```
Sortie/
├── App/
│   └── SortieApp.swift
├── Core/
│   ├── Supabase/
│   │   ├── SupabaseConfig.swift
│   │   └── SupabaseClient.swift
│   └── Extensions/
├── Models/
│   ├── Item.swift
│   ├── Category.swift
│   └── UserProfile.swift
├── Repositories/
│   ├── AuthRepository.swift
│   ├── ItemsRepository.swift
│   └── CategoriesRepository.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── ItemsViewModel.swift
│   └── CategoriesViewModel.swift
├── Views/
│   ├── Auth/
│   │   └── LoginView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── CategoryCard.swift
│   └── Items/
│       ├── ItemsListView.swift
│       └── ItemRow.swift
└── Resources/
    └── Assets.xcassets
```

### 5.2 创建文件夹方法

1. 右键点击 **Sortie** 文件夹
2. 选择 **New Group**
3. 输入文件夹名称（如 `Core`）
4. 重复创建所有文件夹

---

## 步骤 6: 创建核心文件

### 6.1 Supabase 配置文件

创建 `Core/Supabase/SupabaseConfig.swift`:

```swift
import Foundation

enum SupabaseConfig {
    static let supabaseURL = "YOUR_SUPABASE_URL"
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"

    // 在生产环境中，这些应该来自环境变量或配置文件
    // 开发时可以暂时硬编码用于测试
}
```

### 6.2 Supabase Client 单例

创建 `Core/Supabase/SupabaseClient.swift`:

```swift
import Supabase
import Foundation

final class SupabaseClient {
    static let shared = SupabaseClient()

    let client: SupabaseClient

    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.supabaseURL)!,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
    }

    // 便捷访问 auth
    var auth: AuthController {
        client.auth
    }

    // 便捷访问 database
    func from(_ table: String) -> SupabaseQueryBuilder {
        client.from(table)
    }

    // 便捷访问 storage
    var storage: SupabaseStorageClient {
        client.storage
    }
}

// 全局便捷访问
extension SupabaseClient {
    static var auth: AuthController {
        shared.client.auth
    }
}
```

---

## 步骤 7: 配置 Info.plist

在 `Info.plist` 中添加以下内容（右键 > Open As > Source Code）:

```xml
<key>NSFaceIDUsageDescription</key>
<string>用于安全登录验证</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册来选择图片</string>
<key>NSCameraUsageDescription</key>
<string>需要使用相机来拍摄照片</string>
```

---

## 步骤 8: 创建 App 入口

### 8.1 修改 SortieApp.swift

替换默认的 `SortieApp.swift` 内容：

```swift
import SwiftUI
import AuthenticationServices

@main
struct SortieApp: SwiftUI.App {
    @StateObject private var authState = AuthState()

    init() {
        // 配置 Supabase（在开发环境中）
        setupSupabase()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authState.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                        .environmentObject(authState)
                }
            }
            .task {
                await authState.checkAuthState()
            }
        }
    }

    private func setupSupabase() {
        // 在生产环境中，这些值应该来自配置文件或环境变量
        // 目前使用硬编码值进行开发
        print("Supabase configured for development")
    }
}
```

---

## 步骤 9: 配置 Apple Sign In Entitlements

### 9.1 创建 Entitlements 文件

1. **File > New > File**
2. 选择 **Resource > Property List**
3. 命名为 `Sortie.entitlements`
4. 添加以下内容：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
</dict>
</plist>
```

### 9.2 关联 Entitlements

1. 选择项目文件
2. 选择 **Sortie** target
3. 在 **Build Settings** 中搜索 **Code Signing Entitlements**
4. 设置为 `Sortie/Sortie.entitlements`

---

## 步骤 10: 构建和测试

### 10.1 选择模拟器

在 Xcode 顶部工具栏：
- 选择 **Any iOS Device**
- 选择一个模拟器（如 iPhone 15 Pro）

### 10.2 运行项目

1. 按 **Cmd + R** 或点击 **Run** 按钮
2. 等待构建完成
3. 模拟器应该启动并显示登录界面

### 10.3 验证配置

在控制台（Xcode 底部）检查：
- 是否有 Supabase 相关的错误
- 是否成功连接到 Supabase

---

## 步骤 11: 环境变量配置（可选但推荐）

### 11.1 创建 Config.xcconfig

1. **File > New > File**
2. 选择 **Configuration Settings File**
3. 命名为 `Config.xcconfig`
4. 添加内容：

```
// Supabase Configuration
SUPABASE_URL = YOUR_SUPABASE_URL
SUPABASE_ANON_KEY = YOUR_SUPABASE_ANON_KEY
```

### 11.2 使用环境变量

更新 `SupabaseConfig.swift`:

```swift
enum SupabaseConfig {
    static let supabaseURL: String = {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !url.isEmpty else {
            fatalError("Supabase URL not configured")
        }
        return url
    }()

    static let supabaseAnonKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty else {
            fatalError("Supabase Anon Key not configured")
        }
        return key
    }()
}
```

---

## 常见问题

### Q1: 编译错误 "Cannot find 'Supabase' in scope"

**解决方案**：
1. 确认 Supabase package 已添加
2. 清理项目：**Product > Clean Build Folder** (Cmd + Shift + K)
3. 重新构建：**Product > Build** (Cmd + B)

### Q2: Apple Sign In 不工作

**解决方案**：
1. 确认已在 Xcode 中添加 Sign in with Apple capability
2. 确认 Apple Developer 账号中的 App ID 已启用 Sign in with Apple
3. 在模拟器中：**Features > Sign in with Apple** > 勾选

### Q3: Supabase 连接失败

**解决方案**：
1. 检查 `supabaseURL` 和 `supabaseAnonKey` 是否正确
2. 确认 Supabase 项目已启动
3. 检查网络连接
4. 查看 Xcode 控制台的错误信息

---

## 下一步

项目设置完成后，接下来需要：

1. ✅ 创建数据模型（Models）
2. ✅ 实现 Auth Repository（Apple 登录）
3. ✅ 实现 Items/Categories Repository
4. ✅ 创建 ViewModels
5. ✅ 构建 UI 界面
6. ✅ 集成 Realtime

准备好了吗？我可以帮您实现下一步！
