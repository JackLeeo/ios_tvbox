const http = require('http');
const url = require('url');
const path = require('path');
const fs = require('fs');

const server = http.createServer((req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    const query = parsedUrl.query;

    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

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

    if (pathname === '/list') {
        try {
            const homePath = path.join(__dirname, '../home.json');
            const data = fs.readFileSync(homePath, 'utf8');
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(data);
        } catch (e) {
            res.writeHead(500);
            res.end(JSON.stringify({ error: e.message }));
        }
        return;
    }

    if (pathname === '/detail') {
        try {
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

    if (pathname === '/play') {
        try {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({
                parse: query.url,
                headers: {}
            }));
        } catch (e) {
            res.writeHead(500);
            res.end(JSON.stringify({ error: e.message }));
        }
        return;
    }

    res.writeHead(404);
    res.end('Not Found');
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
