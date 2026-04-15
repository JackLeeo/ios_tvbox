import Foundation
import Flutter

@objc class NodeJSBridge: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NodeJSBridge();
        instance.channel = FlutterMethodChannel(name: "nodejs_channel", binaryMessenger: registrar.messenger());
        registrar.addMethodCallDelegate(instance, channel: instance.channel!);
        instance.setupNodeListener();
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startNodeEngine":
            let port = call.arguments as? Int ?? 0;
            startNodeEngine(port: port, result: result);
        default:
            result(FlutterMethodNotImplemented);
        }
    }
    
    private func startNodeEngine(port: Int, result: FlutterResult) {
        // 加载assets中的nodejs主文件
        let mainJsPath = Bundle.main.path(forResource: "main", ofType: "js", inDirectory: "nodejs-project/src") ?? "";
        
        // 调用官方的nodeStart函数启动nodejs引擎
        var args = [
            "node",
            mainJsPath
        ]
        // 转成C的argv参数
        var cArgs = args.map { strdup($0) }
        nodeStart(Int32(args.count), &cArgs)
        
        // 给Node.js发送nativeServerPort消息
        let portMsg: [String: Any] = [
            "action": "nativeServerPort",
            "port": port
        ];
        guard let jsonData = try? JSONSerialization.data(withJSONObject: portMsg),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            result(true);
            return;
        }
        // 调用官方的发送消息函数
        nodejs_channel_send(jsonString);
        result(true);
    }
    
    private func setupNodeListener() {
        // 调用官方的设置监听函数，接收Node.js的消息
        nodejs_channel_set_listener { [weak self] message in
            guard let self = self, let msg = message,
                  let data = msg.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return;
            }
            if let action = json["action"] as? String, action == "onCatPawOpenPort",
               let port = json["port"] as? Int {
                // Node.js的http服务启动了，把端口发送给Dart层
                self.channel?.invokeMethod("onNodeServerReady", arguments: port);
                return;
            }
            
            if let action = json["action"] as? String, action == "log",
               let logData = json["data"] as? String {
                self.channel?.invokeMethod("onLog", arguments: logData);
                return;
            }
            
            if msg == "ready" {
                // Node.js层已经准备就绪
                self.channel?.invokeMethod("onNodeReady", arguments: nil);
            }
        }
    }
}
