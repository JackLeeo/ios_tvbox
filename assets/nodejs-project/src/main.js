const {createServer} = require('http');
const axios = require('axios');
const {builtinModules} = require('module');
const addon = process._linkedBinding('myaddon')

builtinModules.forEach(mod => {
  if (!['trace_events'].includes(mod)) {
    globalThis[mod] = require(mod);
  }
});

let sourceModule;
let nativeServerPort = 0
globalThis.catServerFactory = handle => {
  let port = 0;
  const server = createServer((req, res) => {
    handle(req, res);
  });
  server.on('listening', () => {
    port = server.address().port;
    axios.get(`http://127.0.0.1:${globalThis.catDartServerPort()}/onCatPawOpenPort?port=${port}`);
    console.log('Run on ' + port);
  });
  server.on('close', () => {
    console.log('Close on ' + port);
  });
  return server;
};

globalThis.catDartServerPort = () => {
  return nativeServerPort;
};

function loadScript(path) {
  try {
    const indexJSPath = `${path}/index.js`;
    const indexConfigJSPath = `${path}/index.config.js`;
    delete require.cache[require.resolve(indexJSPath)];
    delete require.cache[require.resolve(indexConfigJSPath)];
    sourceModule = require(indexJSPath);
    const config = require(indexConfigJSPath);
    sourceModule.start(config.default || config);
  } catch (e) {
    console.log(e);
  }
}

process.on('uncaughtException', function (err) {
  console.error('Caught exception: ' + err);
});

addon.registerCallback(async (msg) => {
  console.log('Message from Native:', msg);
  try {
    const data = JSON.parse(msg);
    switch (data.action) {
      case 'run':
        await sourceModule?.stop?.();
        loadScript(data.path);
        break;
      case 'nativeServerPort':
        nativeServerPort = data.port;
        break;
      default:
        break;
    }
  } catch (e) {
    console.log(e);
  }
});

// Function to send a message to the native side
function sendMessageToNative(message) {
  addon.sendMessageToNative(message);
}

sendMessageToNative('ready');