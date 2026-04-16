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
            result(true);
            DispatchQueue.global(qos: .background).async {
                self.startNodeEngineBackground(dartPort: dartPort);
            }
        default:
            result(FlutterMethodNotImplemented);
        }
    }
    
    private func startNodeEngineBackground(dartPort: Int) {
        guard let mainJsPath = Bundle.main.path(forResource: "main", ofType: "js", inDirectory: "nodejs-project/dist") else {
            return;
        }
        setenv("DART_SERVER_PORT", String(dartPort), 1);
        var args = [
            "node",
            mainJsPath
        ]
        var cArgs = args.map { strdup($0) }
        node_start(Int32(args.count), &cArgs)
    }
}
