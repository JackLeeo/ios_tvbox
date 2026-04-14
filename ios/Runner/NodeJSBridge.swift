import Foundation
import Flutter
// 无需 import NodeMobile，桥接头文件已暴露
@objc class NodeJSBridge: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NodeJSBridge()
        instance.channel = FlutterMethodChannel(name: "com.tvbox.nodejs", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.channel!)
        instance.setupNodeListener()
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startEngine":
            startNodeEngine(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startNodeEngine(result: FlutterResult) {
        let mainJsPath = Bundle.main.path(forResource: "main", ofType: "js") ?? ""
        NodeMobile.startEngine(withArguments: [mainJsPath])
        // 启动后，给Node.js发送nativeServerPort消息，兼容js层代码
        let portMsg: [String: Any] = [
            "action": "nativeServerPort",
            "port": 0
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: portMsg),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            result(true)
            return
        }
        NodeMobile.channel?.send(jsonString)
        result(true)
    }

    private func setupNodeListener() {
        NodeMobile.channel?.setEventListener { [weak self] message in
            guard let self = self, let msg = message,
                  let data = msg.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }

            if let action = json["action"] as? String, action == "onCatPawOpenPort",
               let port = json["port"] as? Int {
                // Node.js的http服务启动了，把端口发送给Dart层
                self.channel?.invokeMethod("onNodeServerReady", arguments: port)
                return
            }
            
            if let action = json["action"] as? String, action == "log",
               let logData = json["data"] as? String {
                self.channel?.invokeMethod("onLog", arguments: logData)
                return
            }
            
            if msg == "ready" {
                // Node.js层已经准备就绪
                self.channel?.invokeMethod("onNodeReady", arguments: nil)
            }
        }
    }
}
