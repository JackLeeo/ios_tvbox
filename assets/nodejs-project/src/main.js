// 原来的process.channel代码全部删掉，换成这个
const http = require('http');

// 启动我们的HTTP服务，监听随机端口
const server = http.createServer((req, res) => {
    // 这里是原来的所有业务逻辑，完全不用改
    // ... 你的所有解析、分类、播放的业务代码都保留 ...
});

// 监听随机端口
server.listen(0, '127.0.0.1', () => {
    const nodePort = server.address().port;
    
    // 把我们的端口通过HTTP告诉Dart层，代替原来的process.channel
    const dartPort = process.env.DART_HTTP_PORT;
    if (dartPort) {
        http.get(`http://127.0.0.1:${dartPort}/onCatPawOpenPort?port=${nodePort}`, (res) => {
            // 端口通知成功
        }).on('error', (err) => {
            // 忽略错误，不影响服务运行
        });
    }
});
