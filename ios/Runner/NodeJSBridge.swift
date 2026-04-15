import Foundation
import Flutter
// 无需 import NodeMobile，桥接头文件已暴露
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
        // 加载assets中的nodejs主文件，来自tvbox-source的nodejs-project
        let mainJsPath = Bundle.main.path(forResource: "main", ofType: "js", inDirectory: "nodejs-project/src") ?? "";
        NodeMobile.startEngine(withArguments: [mainJsPath]);
        // 启动后，给Node.js发送nativeServerPort消息，把Dart端的HTTP服务端口传过去
        let portMsg: [String: Any] = [
            "action": "nativeServerPort",
            "port": port
        ];
        guard let jsonData = try? JSONSerialization.data(withJSONObject: portMsg),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            result(true);
            return;
        }
        NodeMobile.channel?.send(jsonString);
        result(true);
    }
    private func setupNodeListener() {
        NodeMobile.channel?.setEventListener { [weak self] message in
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
