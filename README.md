# Relais

[中文](#中文) | [English](#english)

---

## 中文

驿站 — 一款 AI 增强的智能信息中转站。

随手粘贴，AI 自动分类存放并解析关键信息，灵感、日程、待办各取所需，告别备忘录和聊天框的杂乱存储。

**名称由来**：Relais 源自法语，意为"驿站"或"中继站"，寓意临时存放、各取所需的信息中转体验。

### 核心特性

- **智能归档** — AI 自动判断内容类型（灵感 / 笔记 / 待办 / 日程），无需手动选择文件夹
- **信息提取** — 自动识别时间、日期、地点等关键信息
- **事项归档** — 支持手动归档和自动归档（完成后/过期待办自动隐藏），开关可控
- **分类管理** — 预设 + 自定义分类，所有分类支持拖拽排序
- **日历视图** — 按月查看日程和待办，日期点标记一览
- **简约高效** — 粘贴即存，零负担记录

### 项目结构

```
relais/
├── index.html                  # Web 应用主页
├── docs/                       # 项目文档
│   ├── Relais_PRD.md           # 产品需求文档
│   └── Relais_DataModel.md     # 数据模型设计
├── preview/                    # UI 预览
│   └── relais-ui-preview.html
└── supabase/                   # 后端服务
    ├── schema/                 # 数据库 Schema
    └── functions/              # Edge Functions (AI 解析等)
```

### 技术栈

| 层级 | 技术 |
|------|------|
| 前端 | React 18, Tailwind CSS |
| 后端 | Supabase (Auth, Database, Edge Functions) |
| AI | AI 驱动的内容识别与分类 |

### 在线体验

访问 [GitHub Pages](https://freyahurui.github.io/relais/) 查看最新版本。

---

## English

Relais — An AI-enhanced smart information relay.

Just paste, and AI automatically categorizes and parses key information. Ideas, schedules, to-dos — each finds its place. Say goodbye to cluttered memos and chat histories.

**Origin**: Relais comes from French, meaning "relay station" or "waystation," symbolizing a temporary storage where information is deposited and retrieved as needed.

### Key Features

- **Smart Archiving** — AI auto-detects content type (ideas / notes / to-dos / schedules), no manual sorting needed
- **Information Extraction** — Automatically identifies dates, times, locations, and other key details
- **Item Archive** — Manual and auto-archiving (completed/overdue items auto-hide), toggle-controlled
- **Category Management** — Preset + custom categories, all support drag-to-reorder
- **Calendar View** — Monthly view of schedules and to-dos with date dot indicators
- **Simple & Efficient** — Paste to save, zero-friction recording

### Project Structure

```
relais/
├── index.html                  # Web app main page
├── docs/                       # Project documentation
│   ├── Relais_PRD.md           # Product requirements
│   └── Relais_DataModel.md     # Data model design
├── preview/                    # UI preview
│   └── relais-ui-preview.html
└── supabase/                   # Backend services
    ├── schema/                 # Database schema
    └── functions/              # Edge Functions (AI parsing, etc.)
```

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 18, Tailwind CSS |
| Backend | Supabase (Auth, Database, Edge Functions) |
| AI | AI-powered content recognition and categorization |

### Live Demo

Visit [GitHub Pages](https://freyahurui.github.io/relais/) to see the latest version.
