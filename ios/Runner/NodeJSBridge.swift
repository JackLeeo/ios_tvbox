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
            let dartPort = call.arguments as? Int ?? 0;
            // 先返回，不阻塞主线程
            result(true);
            // 把nodejs启动放到后台线程，解决启动崩溃
            DispatchQueue.global().async {
                self.startNodeInBackground(dartPort: dartPort);
            }
        default:
            result(FlutterMethodNotImplemented);
        }
    }
    
    private func startNodeInBackground(dartPort: Int) {
        // 加载nodejs主脚本
        guard let mainJsPath = Bundle.main.path(forResource: "main", ofType: "js", inDirectory: "nodejs-project/src") else {
            return;
        }
        
        // 把Dart的端口通过环境变量传给nodejs，这样nodejs就能通过HTTP通知我们它的端口了
        setenv("DART_HTTP_PORT", String(dartPort), 1);
        
        // 调用官方的node_start启动nodejs
        var args = [
            "node",
            mainJsPath
        ]
        var cArgs = args.map { strdup($0) }
        node_start(Int32(args.count), &cArgs)
    }
}
