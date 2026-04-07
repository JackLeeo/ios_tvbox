import Foundation
import Flutter
// 无需 import NodeMobile，桥接头文件已暴露
@objc class NodeJSBridge: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var nodeRunner: NodeMobileRunner?
    
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
        let mainJsPath = Bundle.main.path(forResource: "main", ofType: "js") ?? ""
        NodeMobile.startEngine(withArguments: [mainJsPath])
        result(true)
    }
    
    private func executeScript(api: String, ext: String, method: String, params: [Any], result: @escaping FlutterResult) {
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
        
        let callbackId = message["callbackId"] as! String
        let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            if let (callback, _) = self?.pendingCallbacks.removeValue(forKey: callbackId) {
                callback(FlutterError(code: "TIMEOUT", message: "脚本执行超时（30秒）", details: nil))
            }
        }
        pendingCallbacks[callbackId] = (result, timer)
        NodeMobile.channel?.send(jsonString)
    }
    
    private var pendingCallbacks: [String: (FlutterResult, Timer?)] = [:]
    
    private func setupNodeListener() {
        NodeMobile.channel?.setEventListener { [weak self] message in
            guard let self = self, let msg = message,
                  let data = msg.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            
            if let action = json["action"] as? String, action == "log",
               let logData = json["data"] as? String {
                self.channel?.invokeMethod("onLog", arguments: logData)
                return
            }
            
            if let callbackId = json["callbackId"] as? String,
               let success = json["success"] as? Bool,
               let resultData = json["data"] {
                if let (callback, timer) = self.pendingCallbacks.removeValue(forKey: callbackId) {
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
