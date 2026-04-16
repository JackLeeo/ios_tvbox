const http = require('http');
const url = require('url');

// 引入tvbox-source的解析函数
const { parse } = require('./parse');
const { getClass } = require('./class');
const { getDetail } = require('./detail');
const { getPlayUrl } = require('./player');

const server = http.createServer(async (req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    const query = parsedUrl.query;

    // 跨域配置
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    try {
        let result;
        // 对应tvbox-source的接口逻辑
        if (pathname === '/category') {
            result = await getClass();
        } else if (pathname === '/list') {
            result = await parse(query);
        } else if (pathname === '/detail') {
            result = await getDetail(query);
        } else if (pathname === '/play') {
            result = await getPlayUrl(query);
        } else {
            res.writeHead(404);
            res.end('Not Found');
            return;
        }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(result));
    } catch (e) {
        res.writeHead(500);
        res.end(JSON.stringify({ error: e.message }));
    }
});

server.listen(0, '127.0.0.1', () => {
    const nodePort = server.address().port;
    const dartPort = process.env.DART_SERVER_PORT;
    if (dartPort) {
        http.get(`http://127.0.0.1:${dartPort}/onCatPawOpenPort?port=${nodePort}`, (res) => {
        }).on('error', () => {
        });
    }
});
