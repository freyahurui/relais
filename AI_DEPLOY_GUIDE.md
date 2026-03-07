# Sortie AI识别功能 - 部署指南

## 文件结构

```
E:\PhD\Coding\test\
├── supabase\
│   └── functions\
│       └── ai-parse\
│           └── index.ts          # Supabase Edge Function
├── Sortie_UI_RealData.html       # 前端页面（已更新）
└── AI_DEPLOY_GUIDE.md            # 本文档
```

---

## 部署步骤

### 1. 安装 Supabase CLI

```bash
# 使用 npm 安装
npm install -g supabase

# 或使用 homebrew (Mac)
brew install supabase/tap/supabase

# 验证安装
supabase --version
```

### 2. 登录 Supabase

```bash
supabase login
```

### 3. 关联你的项目

```bash
# 进入项目目录
cd E:\PhD\Coding\test

# 关联项目（使用你的项目引用ID）
supabase projects link --project-ref usmsbiunhnzroqweyokh
```

### 4. 部署 Edge Function

```bash
# 部署 ai-parse 函数
supabase functions deploy ai-parse
```

### 5. 验证部署

访问 Supabase Dashboard → Edge Functions，应该能看到 `ai-parse` 函数。

---

## 测试 AI 功能

### 方法1：在网页中测试

1. 打开 `Sortie_UI_RealData.html`
2. 登录后点击 **+** 添加内容
3. 输入测试内容：
   - `明天下午3点开会，地点在会议室A`
   - `完成项目报告，本周五截止`
   - `突然想到一个好点子`
4. 保存后会自动调用AI分析

### 方法2：使用 curl 测试

```bash
curl -X POST 'https://usmsbiunhnzroqweyokh.supabase.co/functions/v1/ai-parse' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "itemId": "your-item-id",
    "userId": "your-user-id"
  }'
```

---

## AI 提示词说明

当前 AI 提示词会识别三种类型的内容：

| 类型 | 说明 | 提取字段 |
|------|------|----------|
| **todo** (待办) | 需要完成的任务 | dueDate - 截止日期 |
| **schedule** (日程) | 有时间安排的活动 | startTime - 开始时间<br>endTime - 结束时间<br>location - 地点 |
| **inspiration** (灵感) | 临时想法、笔记 | 无额外字段 |

### 识别示例

| 输入 | 输出类型 | 提取信息 |
|------|----------|----------|
| `明天下午3点开会，地点在会议室A` | schedule | startTime: 明天15:00, location: 会议室A |
| `完成项目报告，本周五截止` | todo | dueDate: 本周五23:59 |
| `突然想到一个好点子` | inspiration | 无 |
| `下周三和客户吃饭` | schedule | startTime: 下周三（时间待定） |

---

## 故障排查

### 问题：函数部署失败

**解决方法：**
```bash
# 查看详细日志
supabase functions deploy ai-parse --debug

# 检查函数列表
supabase functions list
```

### 问题：AI解析失败

**检查步骤：**

1. 确认智谱API Key有效
2. 检查浏览器控制台日志
3. 在 Supabase Dashboard → Edge Functions → ai-parse → Logs 查看错误

**常见错误：**
- `401 Unauthorized` - API Key错误
- `429 Too Many Requests` - API调用频率超限
- `模型不存在` - 检查模型名称是否正确

### 问题：数据库没有更新

**检查 RLS 策略：**
```sql
-- 确认 Edge Function 可以更新 items 表
ALTER TABLE items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role can update items"
  ON items FOR UPDATE
  TO service_role
  USING (true);
```

---

## 费用说明

### Supabase Edge Function
- 免费额度：500,000 次/月
- 超出后：$2/百万次调用

### 智谱 AI API
- glm-4-flash：免费 1M tokens
- glm-4-plus：按量计费

---

## 自定义 AI 提示词

如需修改识别逻辑，编辑 `supabase/functions/ai-parse/index.ts` 中的 `AI_SYSTEM_PROMPT` 常量，然后重新部署：

```bash
supabase functions deploy ai-parse
```

---

## 下一步优化建议

1. **批量解析** - 在用户"同步"时批量解析所有未分类内容
2. **手动修正** - 允许用户手动修改AI识别结果
3. **学习反馈** - 记录用户修正，优化提示词
4. **Webhook触发** - 使用数据库触发器自动调用AI
