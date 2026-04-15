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
            // 先返回成功，告诉Dart层我们已经开始启动了
            result(true);
            // 把nodejs的启动放到后台线程，不要阻塞主线程
            DispatchQueue.global().async {
                self.startNodeEngine(port: port);
            }
        default:
            result(FlutterMethodNotImplemented);
        }
    }
    
    private func startNodeEngine(port: Int) {
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
    }
}
