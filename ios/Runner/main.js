const https = require('https');
const http = require('http');
const channel = require('nodejs-mobile').channel;

// 脚本缓存，根据api/ext的哈希缓存，避免重复加载
const scriptCache = new Map();

// 重写console.log，将日志转发到Flutter侧
const originalLog = console.log;
console.log = function(...args) {
    // 先输出到原生控制台
    originalLog(...args);
    // 同时发送到Flutter侧，方便UI调试
    try {
        channel.send(JSON.stringify({
            action: 'log',
            data: args.map(a => typeof a === 'string' ? a : JSON.stringify(a)).join(' ')
        }));
    } catch(e) {
        // 忽略发送失败的情况
    }
};

// 实现Node.js原生的fetch
function fetchUrl(url) {
    return new Promise((resolve, reject) => {
        const client = url.startsWith('https') ? https : http;
        client.get(url, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => resolve(data));
        }).on('error', reject);
    });
}

// 存储当前加载的爬虫实例
let currentSpider = null;

channel.on('message', async (msg) => {
    try {
        const data = JSON.parse(msg);
        if (data.action === 'run') {
            const { api, ext, method, params, callbackId } = data;
            // 动态加载爬虫代码，优先从缓存获取
            const cacheKey = api || ext;
            let MySpider;
            
            if (scriptCache.has(cacheKey)) {
                // 缓存命中，直接复用实例
                currentSpider = scriptCache.get(cacheKey);
                console.log(`复用缓存的爬虫实例: ${cacheKey}`);
            } else {
                // 缓存未命中，加载并执行脚本
                let spiderCode = '';
                if (api && api.trim() !== '') {
                    spiderCode = await fetchUrl(api);
                } else if (ext && ext.trim() !== '') {
                    spiderCode = ext;
                } else {
                    throw new Error('No script provided');
                }
                
                // 创建爬虫实例
                MySpider = eval(`(function() { ${spiderCode}; return MySpider; })()`);
                currentSpider = new MySpider();
                // 存入缓存
                scriptCache.set(cacheKey, currentSpider);
                console.log(`加载并缓存新的爬虫实例: ${cacheKey}`);
            }
            
            // 调用对应方法
            const args = params.map(p => JSON.parse(p));
            const result = await currentSpider[method](...args);
            
            // 返回结果
            channel.send(JSON.stringify({
                callbackId,
                success: true,
                data: result
            }));
        }
    } catch (err) {
        channel.send(JSON.stringify({
            callbackId: data?.callbackId,
            success: false,
            error: err.message
        }));
    }
});
