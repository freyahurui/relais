# Relais 数据模型设计

## 概述

Relais 采用混合存储策略，平衡用户体验与隐私保护：
- **身份识别**：Supabase Auth
- **可选云同步**：用户可选择是否启用云端备份
- **Apple 日历同步**：后端支持与 Apple EventKit 集成
- **隐私优先**：数据加密、最小化收集、用户完全控制

---

## 数据库架构

```
┌─────────────────────────────────────────────────────────────┐
│                        Supabase Cloud                        │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   profiles   │  │  categories  │  │    items     │      │
│  │   (用户)     │  │   (分类)     │  │   (内容)     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │ sync_status  │  │activity_logs │                        │
│  │ (同步状态)   │  │  (活动日志)  │                        │
│  └──────────────┘  └──────────────┘                        │
├─────────────────────────────────────────────────────────────┤
│                    Row Level Security                        │
│              (每个用户只能访问自己的数据)                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     iOS App (本地)                           │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  SwiftData   │  │  EventKit    │  │   Cache      │      │
│  │ (本地存储)   │  │  (日历)      │  │   (缓存)     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## 核心数据表

### 1. profiles - 用户档案

扩展 Supabase Auth 的用户信息：

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 关联 auth.users |
| email | TEXT | 用户邮箱 |
| full_name | TEXT | 用户姓名 |
| avatar_url | TEXT | 头像 URL |
| data_sync_enabled | BOOLEAN | 是否启用云同步 |
| calendar_sync_enabled | BOOLEAN | 是否启用日历同步 |
| analytics_enabled | BOOLEAN | 是否允许统计 |
| apple_refresh_token | TEXT | Apple Token（加密） |
| apple_token_expires_at | TIMESTAMPTZ | Token 过期时间 |

**隐私设计**：
- `data_sync_enabled` 默认 `false`，用户主动开启
- Apple Token 使用 pgcrypto 加密存储

### 2. categories - 分类配置

用户的分类/文件夹配置：

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 所属用户 |
| name | TEXT | 分类名称 |
| emoji | TEXT | 分类图标 |
| color | TEXT | 莫兰迪色代码 |
| sort_order | INTEGER | 排序 |
| is_system | BOOLEAN | 系统预设分类 |

**默认分类**：
- 💡 灵感 (#D4C8D4)
- 📅 日程 (#9CB4B8)
- ✅ 待办 (#B8C4A8)
- 📁 文件 (#C8B8A8)

### 3. items - 内容项（核心表）

所有用户内容的统一存储：

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 所属用户 |
| category_id | UUID | 所属分类 |
| item_type | ENUM | 内容类型 |
| title | TEXT | 标题 |
| content | TEXT | 内容 |
| source_type | ENUM | 来源：manual/ai_parsed/shared |

**日程专用字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| scheduled_start | TIMESTAMPTZ | 开始时间 |
| scheduled_end | TIMESTAMPTZ | 结束时间 |
| location | TEXT | 地点 |
| reminder_sent | BOOLEAN | 提醒已发送 |
| apple_event_id | TEXT | Apple 日历事件 ID |
| calendar_synced | BOOLEAN | 已同步到日历 |

**待办专用字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| is_completed | BOOLEAN | 完成状态 |
| completed_at | TIMESTAMPTZ | 完成时间 |

**归档字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| archived_at | TIMESTAMPTZ | 归档时间（NULL 表示未归档） |
| is_auto_archived | BOOLEAN | 是否为系统自动归档（false = 用户手动归档） |

**文件专用字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| file_url | TEXT | 存储路径 |
| file_type | TEXT | 文件类型 |
| file_size | BIGINT | 文件大小 |
| file_name | TEXT | 文件名 |

**AI 相关字段**：
| 字段 | 类型 | 说明 |
|------|------|------|
| ai_parsed_data | JSONB | AI 提取的结构化数据 |
| confidence_score | NUMERIC | 识别置信度 |

### 4. sync_status - 同步状态

多设备同步状态管理：

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 所属用户 |
| device_id | TEXT | 设备唯一标识 |
| device_name | TEXT | 设备名称 |
| last_sync_at | TIMESTAMPTZ | 最后同步时间 |
| sync_cursor | TEXT | 增量同步游标 |

### 5. activity_logs - 活动日志

用户操作审计（可选）：

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| user_id | UUID | 所属用户 |
| action | ENUM | 操作类型 |
| item_type | TEXT | 操作对象类型 |
| item_id | UUID | 操作对象 ID |
| details | JSONB | 详细信息 |

---

## 数据类型枚举

### item_type（内容类型）
```typescript
enum ItemType {
  INSPIRATION = 'inspiration',    // 灵感
  SCHEDULE = 'schedule',           // 日程
  TODO = 'todo',                  // 待办
  FILE = 'file',                  // 文件
  NOTIFICATION = 'notification'    // 通知
}
```

### source_type（来源类型）
```typescript
enum SourceType {
  MANUAL = 'manual',              // 手动输入
  AI_PARSED = 'ai_parsed',        // AI 解析
  SHARED = 'shared'               // 外部分享
}
```

---

## Row Level Security (RLS)

所有表都启用了 RLS，确保：

```sql
-- 用户只能访问自己的数据
CREATE POLICY "Users can view own items"
    ON public.items FOR SELECT
    USING (auth.uid() = user_id);

-- 系统分类不可删除
CREATE POLICY "Users can delete own categories"
    ON public.categories FOR DELETE
    USING (auth.uid() = user_id AND is_system = false);
```

---

## iOS 数据模型

### SwiftData 本地模型

```swift
// 本地数据模型（与 Supabase 对应）
@Model
final class Item {
    var id: UUID
    var userId: UUID
    var categoryId: UUID
    var itemType: ItemType
    var title: String
    var content: String?
    var sourceType: SourceType

    // 日程
    var scheduledStart: Date?
    var scheduledEnd: Date?
    var location: String?
    var appleEventId: String?
    var calendarSynced: Bool

    // 待办
    var isCompleted: Bool
    var completedAt: Date?

    // 文件
    var fileURL: String?
    var fileType: String?
    var fileSize: Int64?
    var fileName: String?

    // AI
    var aiParsedData: Data?
    var confidenceScore: Double?

    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var category: Category?
}

@Model
final class Category {
    var id: UUID
    var userId: UUID
    var name: String
    var emoji: String
    var color: String
    var sortOrder: Int
    var isSystem: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var items: [Item]?
}
```

---

## Apple 日历集成

### 同步流程

```
┌──────────────┐
│   iOS App    │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│  1. 用户创建日程                                        │
│     └──> 存储到本地 SwiftData                           │
│     └──> 如果启用云同步 ──> 发送到 Supabase            │
└─────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│  2. 云端处理（Supabase Edge Function）                  │
│     └──> 验证用户权限                                    │
│     └──> 调用 Apple EventKit API                        │
│     └──> 创建日历事件                                    │
│     └──> 返回 apple_event_id                            │
└─────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│  3. 同步回本地                                           │
│     └──> 更新本地 Item 的 apple_event_id                │
│     └──> 标记 calendar_synced = true                    │
└─────────────────────────────────────────────────────────┘
```

### Token 管理

```swift
// Apple Token 存储策略
struct AppleTokenManager {
    // 1. 获取 Apple Refresh Token
    func getRefreshToken() -> String? {
        // 从 Keychain 读取（不存本地数据库）
    }

    // 2. 发送到服务器（加密传输）
    func syncTokenToServer(token: String) async {
        // HTTPS + 加密后存储到 Supabase
    }

    // 3. 刷新 Token
    func refreshToken() async throws -> String {
        // 调用 Apple 的刷新 API
        // 更新到服务器
    }
}
```

---

## 同步策略

### 混合同步模式

```
┌─────────────────────────────────────────────────────────┐
│                    同步决策树                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  用户创建内容                                            │
│     │                                                    │
│     ├─> 总是先保存到本地 (SwiftData)                     │
│     │                                                    │
│     ├─> data_sync_enabled = false                        │
│     │    └──> 仅本地存储，不同步云端                      │
│     │                                                    │
│     └─> data_sync_enabled = true                         │
│          └──> 异步同步到 Supabase                         │
│               └──> 失败时标记，后台重试                   │
│                                                         │
│  云端数据变更                                            │
│     │                                                    │
│     └─> 通过 sync_cursor 增量同步                        │
│          └──> 拉取更新 > 合并到本地                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 隐私保护措施

### 1. 数据加密

```sql
-- Apple Token 加密存储
SELECT encrypt_apple_token('raw_token');
-- 返回: encrypted_base64_string
```

### 2. 用户控制

```typescript
// 用户可以随时：
// 1. 关闭云同步
await updateProfile({ data_sync_enabled: false })

// 2. 导出所有数据
const userData = await exportUserData()

// 3. 删除所有数据
await softDeleteUser()
```

### 3. 最小化收集

- 仅收集必要的身份信息
- 不收集行为分析（除非用户允许）
- Token 加密存储
- RLS 确保数据隔离

---

## 实施步骤

### 1. Supabase 设置

```bash
# 1. 创建项目
# 访问 https://supabase.com/dashboard

# 2. 执行 SQL
# 复制 supabase_schema.sql 内容到 SQL Editor 执行

# 3. 配置环境变量
# 在 Supabase Dashboard > Settings > Edge Functions
# 添加: app.encryption_key

# 4. 启用 Apple OAuth
# Authentication > Providers > Apple
```

### 2. iOS 项目集成

```swift
// 使用 supabase-swift
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "YOUR_SUPABASE_URL")!,
    supabaseKey: "YOUR_SUPABASE_ANON_KEY"
)
```

### 3. 本地优先架构

```swift
class DataManager {
    let localStore: SwiftDataContainer
    let remoteStore: SupabaseClient

    func createItem(_ item: Item) async {
        // 1. 总是先保存到本地
        localStore.save(item)

        // 2. 如果启用云同步，异步上传
        if userPrefs.syncEnabled {
            try? await remoteStore.from("items")
                .insert(item dictionaries)
        }
    }
}
```

---

## API 参考

### 查询用户内容

```sql
-- 获取用户的所有日程
SELECT * FROM user_schedule
WHERE user_id = auth.uid();

-- 获取用户统计
SELECT * FROM user_content_stats
WHERE user_id = auth.uid();
```

### 创建内容

```sql
INSERT INTO items (user_id, category_id, item_type, title, scheduled_start, scheduled_end)
VALUES (
    auth.uid(),
    'category-uuid',
    'schedule',
    '产品评审会',
    '2024-02-16 14:00:00',
    '2024-02-16 15:00:00'
)
RETURNING *;
```

---

## 故障排查

### 常见问题

1. **RLS 策略导致查询失败**
   - 检查 `auth.uid()` 是否正确
   - 确保用户已登录

2. **Apple Token 过期**
   - 实现 Token 刷新机制
   - 设置 `apple_token_expires_at` 监控

3. **同步冲突**
   - 使用 `updated_at` 时间戳
   - 服务端以最新时间为准
   - 客户端提供合并界面
