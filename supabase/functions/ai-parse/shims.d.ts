// 仅用于编辑器类型检查兜底：
// - 没安装 Deno 扩展 / 无法解析远程模块时，避免 “找不到模块…或其类型声明”
// - 不影响 Supabase Edge Function 运行时（运行时仍由 Deno 解析 import map / 远程模块）

declare module '@supabase/supabase-js' {
  // 这里用最小类型即可满足当前文件的使用（createClient + 链式调用）。
  // 如果你后续要更严格类型，可以改为引入真实类型（需要 Deno/npm 解析能力）。
  export type SupabaseClient = any
  export function createClient(
    supabaseUrl: string,
    supabaseKey: string,
    options?: any
  ): SupabaseClient
}

// 兜底 Deno 全局（当非 Deno 语言服务在解析时）
declare const Deno: {
  env: {
    get(key: string): string | undefined
  }
  serve: (handler: (req: Request) => Response | Promise<Response>) => void
}

