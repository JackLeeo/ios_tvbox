import Foundation
import Flutter

@objc class NodeJSBridge: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NodeJSBridge();
        instance.channel = FlutterMethodChannel(name: "nodejs_channel", binaryMessenger: registrar.messenger());
        registrar.addMethodCallDelegate(instance, channel: instance.channel!);
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
        
        // 调用官方的node_start函数启动nodejs，这是官方框架唯一支持的API
        var args = [
            "node",
            mainJsPath
        ]
        // 转成C的argv参数
        var cArgs = args.map { strdup($0) }
        node_start(Int32(args.count), &cArgs)
        
        // 我们的nodejs代码会自己启动HTTP服务器，Dart层直接通过localhost访问即可
        // 不需要任何原生层的消息传递，所有通信都走HTTP
        result(true);
    }
}
