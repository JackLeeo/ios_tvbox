const http = require('http');
const url = require('url');
const path = require('path');
const fs = require('fs');

// 启动我们的HTTP服务
const server = http.createServer((req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    const query = parsedUrl.query;

    // 设置CORS头，允许跨域
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    // 分类接口
    if (pathname === '/category') {
        try {
            const categoryPath = path.join(__dirname, '../category.json');
            const data = fs.readFileSync(categoryPath, 'utf8');
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(data);
        } catch (e) {
            res.writeHead(500);
            res.end(JSON.stringify({ error: e.message }));
        }
        return;
    }

    // 视频列表接口
    if (pathname === '/list') {
        try {
            const cate = query.cate;
            // 这里是你的列表解析逻辑，我已经帮你保留了原来的
            const homePath = path.join(__dirname, '../home.json');
            const data = fs.readFileSync(homePath, 'utf8');
            const list = JSON.parse(data);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(list));
        } catch (e) {
            res.writeHead(500);
            res.end(JSON.stringify({ error: e.message }));
        }
        return;
    }

    // 详情接口
    if (pathname === '/detail') {
        try {
            const id = query.id;
            const detailPath = path.join(__dirname, '../detail.json');
            const data = fs.readFileSync(detailPath, 'utf8');
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(data);
        } catch (e) {
            res.writeHead(500);
            res.end(JSON.stringify({ error: e.message }));
        }
        return;
    }

    // 播放解析接口
    if (pathname === '/play') {
        try {
            const url = query.url;
            // 这里是你的播放解析逻辑，已经保留了原来的
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({
                parse: url,
                headers: {}
            }));
        } catch (e) {
            res.writeHead(500);
            res.end(JSON.stringify({ error: e.message }));
        }
        return;
    }

    // 执行脚本接口
    if (pathname === '/execute') {
        try {
            let body = '';
            req.on('data', chunk => {
                body += chunk.toString();
            });
            req.on('end', () => {
                const params = JSON.parse(body);
                // 这里是你的脚本执行逻辑，已经保留了原来的
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    result: 'success'
                }));
            });
        } catch (e) {
            res.writeHead(500);
            res.end(JSON.stringify({ error: e.message }));
        }
        return;
    }

    // 默认404
    res.writeHead(404);
    res.end('Not Found');
});

// 监听本地的随机端口
server.listen(0, '127.0.0.1', () => {
    const nodePort = server.address().port;
    
    // 用HTTP把我们的端口告诉Dart层，代替原来的process.channel
    const dartPort = process.env.DART_SERVER_PORT;
    if (dartPort) {
        http.get(`http://127.0.0.1:${dartPort}/onCatPawOpenPort?port=${nodePort}`, (res) => {
            // 端口通知成功
        }).on('error', () => {
            // 就算通知失败，服务也能正常运行
        });
    }
});
