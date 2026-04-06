import Foundation
import Flutter

@objc class NodeJSBridge: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var nodeRunner: NodeJSMobileRunner?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NodeJSBridge()
        instance.channel = FlutterMethodChannel(name: "com.tvbox.nodejs", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.channel!)
        // 自动设置Node.js消息监听器，确保实例一致
        instance.setupNodeListener()
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startEngine":
            startNodeEngine(result: result)
        case "executeScript":
            guard let args = call.arguments as? [String: Any],
                  let api = args["api"] as? String,
                  let ext = args["ext"] as? String,
                  let method = args["method"] as? String,
                  let params = args["params"] as? [Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing parameters", details: nil))
                return
            }
            executeScript(api: api, ext: ext, method: method, params: params, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startNodeEngine(result: FlutterResult) {
        // 启动 Node.js 引擎，main.js 放在 Bundle 中
        let mainJsPath = Bundle.main.path(forResource: "main", ofType: "js") ?? ""
        NodeJSMobile.startEngine(withArguments: [mainJsPath])
        result(true)
    }
    
    private func executeScript(api: String, ext: String, method: String, params: [Any], result: @escaping FlutterResult) {
        // 通过 channel 发送消息给 Node.js 进程
        let message: [String: Any] = [
            "action": "run",
            "api": api,
            "ext": ext,
            "method": method,
            "params": params,
            "callbackId": UUID().uuidString
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            result(FlutterError(code: "MSG_ERROR", message: "Failed to serialize message", details: nil))
            return
        }
        
        // 注册一次性回调，等待 Node.js 返回结果，30秒超时
        let callbackId = message["callbackId"] as! String
        let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            // 超时处理，自动清理回调并返回错误
            if let (callback, _) = self?.pendingCallbacks.removeValue(forKey: callbackId) {
                callback(FlutterError(code: "TIMEOUT", message: "脚本执行超时（30秒）", details: nil))
            }
        }
        pendingCallbacks[callbackId] = (result, timer)
        NodeJSMobile.channel?.send(jsonString)
    }
    
    // 存储等待回调的 FlutterResult，附带超时定时器
    private var pendingCallbacks: [String: (FlutterResult, Timer?)] = [:]
    
    // 在注册时自动设置Node.js消息监听器，确保实例一致
    public func setupNodeListener() {
        NodeJSMobile.channel?.setEventListener { message in
            guard let msg = message,
                  let data = msg.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            
            // 处理日志消息
            if let action = json["action"] as? String, action == "log",
               let logData = json["data"] as? String {
                // 将日志转发给Flutter
                self.channel?.invokeMethod("onLog", arguments: logData)
                return
            }
            
            // 处理执行结果消息
            if let callbackId = json["callbackId"] as? String,
               let success = json["success"] as? Bool,
               let resultData = json["data"] {
                if let (callback, timer) = self.pendingCallbacks.removeValue(forKey: callbackId) {
                    // 清理超时定时器
                    timer?.invalidate()
                    if success {
                        callback(resultData)
                    } else {
                        let errorMsg = json["error"] as? String ?? "Unknown error"
                        callback(FlutterError(code: "JS_ERROR", message: errorMsg, details: nil))
                    }
                }
            }
        }
    }
}
