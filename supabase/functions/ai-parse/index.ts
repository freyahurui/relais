// Supabase Edge Function - AI解析服务
// 部署位置: supabase/functions/ai-parse/index.ts
// @deno-types="https://deno.land/std@0.208.0/types/n.d.ts"

const API_KEY = Deno.env.get('AI_API_KEY')!
const API_URL = 'https://open.bigmodel.cn/api/paas/v4/chat/completions'

// CORS 头配置
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
}

// AI提示词 - 用于内容分类和信息提取
const AI_SYSTEM_PROMPT = `你是一个智能内容分类助手。请分析用户输入的内容，完成以下三件事：

1. 生成标题：为内容提炼一个简洁的标题（10字以内），抓住核心含义，不要简单截取原文。
2. 判断格式类型（必选其一）：
   - schedule (日程) - 有具体时间安排的活动、会议、约会
   - todo (待办) - 需要完成的任务，通常有截止日期
   - note (笔记) - 普通文本记录、想法、备忘等
3. 判断文件分类（根据内容性质自动选择）：
   - 💡 灵感：创意想法、灵感、心得体会
   - 💼 工作：工作相关的内容、会议、项目
   - 📚 学习：学习笔记、阅读记录、课程相关
   - 🏠 生活：日常生活、购物清单、个人事项
4. 提取时间和地点信息

请严格以以下JSON格式返回（不要输出其他任何内容）：
{
  "title": "提炼的标题，10字以内",
  "formatType": "schedule|todo|note",
  "folderCategory": "💡灵感|💼工作|📚学习|🏠生活",
  "dueDate": "ISO格式的日期时间或null",
  "startTime": "ISO格式的日期时间或null",
  "endTime": "ISO格式的日期时间或null",
  "location": "地点名称或null"
}

规则：
- title字段必须填写，不能为空。要提炼核心含义，例如"明天下午3点开会"→标题为"下午开会"
- 如果提到"明天"、"下周"、"下午3点"等相对时间，请转换为绝对时间（使用当前日期）
- 如果没有明确时间，dueDate/startTime/endTime设为null
- schedule类型：有具体开始时间的活动
- todo类型：需要完成的任务，通常有截止时间
- note类型：普通文本记录，无特定时间要求
- location只在schedule类型且有明确地点时提取
- 根据内容关键词智能选择文件分类文件夹

示例：
输入："明天下午3点开会，地点在会议室A"
{"title":"下午开会","formatType":"schedule","folderCategory":"💼工作","startTime":"2026-03-05T15:00:00","endTime":null,"location":"会议室A"}

输入："完成项目报告，本周五截止"
{"title":"完成项目报告","formatType":"todo","folderCategory":"💼工作","dueDate":"2026-03-07T23:59:59","startTime":null,"endTime":null,"location":null}

输入："突然想到一个好点子"
{"title":"灵感记录","formatType":"note","folderCategory":"💡灵感","dueDate":null,"startTime":null,"endTime":null,"location":null}

输入：《三体》读后感：这是一部关于宇宙社会学的科幻小说
{"title":"《三体》读后感","formatType":"note","folderCategory":"📚学习","dueDate":null,"startTime":null,"endTime":null,"location":null}

输入："周末去超市购物清单：牛奶、面包、鸡蛋"
{"title":"超市购物","formatType":"todo","folderCategory":"🏠生活","dueDate":null,"startTime":null,"endTime":null,"location":null}
`

// 调用AI API
async function callAI(content: string): Promise<any> {
  const now = new Date()
  const pad = (n: number) => String(n).padStart(2, '0')
  const currentDate = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`

  const requestBody = {
    model: 'GLM-4-Flash-250414',
    messages: [
      {
        role: 'system',
        content: AI_SYSTEM_PROMPT
      },
      {
        role: 'user',
        content: `当前时间：${currentDate}\n\n请分析以下内容：\n${content}`
      }
    ],
    temperature: 0.3,
    top_p: 0.7,
    max_tokens: 500,
    stream: false
  }

  const response = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${API_KEY}`
    },
    body: JSON.stringify(requestBody)
  })

  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(`AI API调用失败: ${response.status} ${errorText}`)
  }

  const data = await response.json()

  if (!data.choices || data.choices.length === 0) {
    throw new Error('AI API返回无效响应')
  }

  const aiResponse = data.choices[0].message.content

  // 尝试解析JSON响应
  try {
    // 移除可能的markdown代码块标记
    const cleanJson = aiResponse.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()
    return JSON.parse(cleanJson)
  } catch (parseError) {
    console.error('AI响应解析失败:', aiResponse)
    // 返回默认值
    return {
      title: '',
      formatType: 'note',
      folderCategory: '💡灵感',
      dueDate: null,
      startTime: null,
      endTime: null,
      location: null
    }
  }
}

Deno.serve(async (req) => {
  // 处理 CORS 预检请求
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  // 只允许 POST 请求
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }

  try {
    // 解析请求
    const { itemId, userId, content } = await req.json()

    // ===== 新模式：直接传入 content，返回 AI 解析结果（不写数据库）=====
    if (content && !itemId) {
      console.log('直接解析模式，内容:', content)
      const aiResult = await callAI(content)
      console.log('AI解析结果:', aiResult)

      return new Response(
        JSON.stringify({
          success: true,
          result: aiResult
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ===== 原有模式：通过 itemId 从数据库读取并解析 =====
    if (!itemId || !userId) {
      return new Response(
        JSON.stringify({ error: '缺少必要参数: itemId 或 userId' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 从请求头获取用户的 JWT token
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: '缺少 Authorization 头' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const userToken = authHeader.replace('Bearer ', '')

    // 调试：记录 token 信息
    console.log('收到用户Token长度:', userToken?.length)
    console.log('Token前50字符:', userToken?.substring(0, 50))

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!

    console.log('Supabase URL:', supabaseUrl)
    console.log('开始获取项目...')

    // 获取项目内容（使用 REST API）
    const itemResponse = await fetch(`${supabaseUrl}/rest/v1/items?id=eq.${itemId}&user_id=eq.${userId}&select=content,title`, {
      headers: {
        'apikey': supabaseKey,
        'Authorization': `Bearer ${userToken}`
      }
    })

    console.log('获取项目响应状态:', itemResponse.status)

    if (!itemResponse.ok) {
      const errorText = await itemResponse.text()
      console.error('获取项目失败:', errorText)
      return new Response(
        JSON.stringify({ error: `获取项目失败: ${errorText}` }),
        {
          status: itemResponse.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const items = await itemResponse.json()
    const item = items[0]

    if (!item) {
      return new Response(
        JSON.stringify({ error: '项目不存在' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('开始AI解析:', item.content)

    // 调用AI进行解析
    const aiResult = await callAI(item.content || item.title)
    console.log('AI解析结果:', aiResult)

    // 获取用户的所有分类
    const categoriesResponse = await fetch(`${supabaseUrl}/rest/v1/categories?user_id=eq.${userId}&select=*`, {
      headers: {
        'apikey': supabaseKey,
        'Authorization': `Bearer ${userToken}`
      }
    })

    if (!categoriesResponse.ok) {
      console.error('获取分类失败:', await categoriesResponse.text())
    }

    const categories = categoriesResponse.ok ? await categoriesResponse.json() : []
    console.log('用户分类:', categories)

    // 根据AI推荐的分类emoji查找对应的category_id
    let targetCategoryId = null
    if (aiResult.folderCategory && categories.length > 0) {
      console.log('AI返回的文件分类:', aiResult.folderCategory)
      console.log('用户的所有分类:', categories.map(c => ({ id: c.id, emoji: c.emoji, name: c.name })))

      // AI返回的格式可能是 "💡灵感"，需要提取emoji部分
      const aiEmoji = aiResult.folderCategory.substring(0, 2) // 提取前两个字符作为emoji

      // 方法1: 通过AI返回的emoji直接匹配数据库中的emoji
      const matchedByEmoji = categories.find(c => c.emoji === aiEmoji || c.emoji === aiResult.folderCategory)
      if (matchedByEmoji) {
        targetCategoryId = matchedByEmoji.id
        console.log('通过emoji匹配到分类:', matchedByEmoji)
      } else {
        // 方法2: 通过名称关键词匹配
        const categoryMapping: Record<string, string[]> = {
          '💡': ['灵感', '想法'],
          '💼': ['工作', '项目', '会议', '公司'],
          '📚': ['学习', '阅读', '课程', '笔记'],
          '🏠': ['生活', '购物', '日常', '个人']
        }

        for (const [emoji, keywords] of Object.entries(categoryMapping)) {
          const aiCategoryLower = aiResult.folderCategory.toLowerCase()
          if (keywords.some(k => aiCategoryLower.includes(k))) {
            const found = categories.find(c => c.emoji === emoji)
            if (found) {
              targetCategoryId = found.id
              console.log('通过关键词匹配到分类:', found)
              break
            }
          }
        }
      }

      console.log('最终匹配的分类ID:', targetCategoryId)
    }

    // 构建更新数据
    const updateData: any = {
      item_type: aiResult.formatType,
      ai_parsed_data: aiResult,
      confidence_score: aiResult.confidence,
      source_type: 'ai_parsed'
    }

    // 如果AI生成了标题，更新标题
    if (aiResult.title) {
      updateData.title = aiResult.title
    }

    // 如果找到了匹配的分类，更新category_id
    if (targetCategoryId) {
      updateData.category_id = targetCategoryId
      console.log('更新分类ID:', targetCategoryId)
    }

    // 根据格式类型添加特定字段
    if (aiResult.formatType === 'todo' && aiResult.dueDate) {
      updateData.scheduled_start = aiResult.dueDate
    }

    if (aiResult.formatType === 'schedule') {
      if (aiResult.startTime) updateData.scheduled_start = aiResult.startTime
      if (aiResult.endTime) updateData.scheduled_end = aiResult.endTime
      if (aiResult.location) updateData.location = aiResult.location
    }

    // 更新数据库（使用 REST API）
    const updateResponse = await fetch(`${supabaseUrl}/rest/v1/items?id=eq.${itemId}&user_id=eq.${userId}`, {
      method: 'PATCH',
      headers: {
        'apikey': supabaseKey,
        'Authorization': `Bearer ${userToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(updateData)
    })

    console.log('更新项目响应状态:', updateResponse.status)

    if (!updateResponse.ok) {
      const errorText = await updateResponse.text()
      console.error('更新项目失败:', errorText)
      return new Response(
        JSON.stringify({ error: `更新项目失败: ${errorText}` }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // 记录活动日志（使用 REST API）
    try {
      await fetch(`${supabaseUrl}/rest/v1/activity_logs`, {
        method: 'POST',
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${userToken}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal'
        },
        body: JSON.stringify({
          user_id: userId,
          action: 'ai_parse',
          item_formatType: aiResult.formatType,
          item_id: itemId,
          details: {
            original_formatType: 'note',
            new_formatType: aiResult.formatType,
            confidence: aiResult.confidence
          }
        })
      })
    } catch (logError) {
      console.error('记录日志失败:', logError)
    }

    return new Response(
      JSON.stringify({
        success: true,
        result: aiResult
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('AI解析错误:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || '未知错误'
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
