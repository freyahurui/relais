/**
 * Supabase Edge Function 部署脚本
 *
 * 使用方法：
 * 1. 在 Supabase Dashboard 获取你的 Access Token:
 *    Settings → API → create a new access token (or use existing)
 *
 * 2. 运行脚本:
 *    node deploy-function.js YOUR_ACCESS_TOKEN
 *
 * 或者直接修改下面的 ACCESS_TOKEN 常量后运行:
 *    node deploy-function.js
 */

const SUPABASE_PROJECT_ID = 'usmsbiunhnzroqweyokh';
const ACCESS_TOKEN = ''; // 在这里填入你的 Access Token，或作为命令行参数传入

const path = require('path');
const fs = require('fs');
const https = require('https');

// 读取函数代码
const functionCode = fs.readFileSync(
    path.join(__dirname, 'supabase', 'functions', 'ai-parse', 'index.ts'),
    'utf8'
);

// 部署函数
async function deployFunction(accessToken) {
    if (!accessToken) {
        console.error('❌ 请提供 Access Token');
        console.log('\n获取方式：');
        console.log('1. 打开 https://supabase.com/dashboard');
        console.log('2. 选择你的项目');
        console.log('3. 进入 Settings → API');
        console.log('4. 在 "Access tokens" 部分创建新 token');
        console.log('\n然后运行: node deploy-function.js YOUR_TOKEN\n');
        process.exit(1);
    }

    console.log('🚀 开始部署 ai-parse 函数...\n');

    const data = JSON.stringify({
        name: 'ai-parse',
        files: [
            {
                name: 'index.ts',
                content: functionCode
            }
        ],
        verify_jwt: false
    });

    const options = {
        hostname: 'api.supabase.com',
        port: 443,
        path: `/v1/projects/${SUPABASE_PROJECT_ID}/functions`,
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
            'Content-Length': data.length
        }
    };

    return new Promise((resolve, reject) => {
        const req = https.request(options, (res) => {
            let body = '';

            res.on('data', (chunk) => {
                body += chunk;
            });

            res.on('end', () => {
                if (res.statusCode === 200 || res.statusCode === 201) {
                    console.log('✅ 部署成功！\n');
                    console.log('函数 URL:');
                    console.log(`https://${SUPABASE_PROJECT_ID}.supabase.co/functions/v1/ai-parse\n`);
                    resolve(JSON.parse(body));
                } else {
                    console.error('❌ 部署失败');
                    console.error(`状态码: ${res.statusCode}`);
                    console.error(`响应: ${body}\n`);
                    reject(new Error(body));
                }
            });
        });

        req.on('error', (error) => {
            console.error('❌ 请求失败:', error.message);
            reject(error);
        });

        req.write(data);
        req.end();
    });
}

// 主函数
async function main() {
    const token = process.argv[2] || ACCESS_TOKEN;

    try {
        await deployFunction(token);
        console.log('🎉 完成！现在你可以在网页中测试AI识别功能了。');
    } catch (error) {
        console.error('\n❌ 部署失败');
        process.exit(1);
    }
}

main();
