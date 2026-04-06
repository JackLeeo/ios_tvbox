import Foundation
import NodeMobile // 【修复1：新增这一行，让Swift识别NodeMobile框架的类】

class NodeJSBridge {
    static let shared = NodeJSBridge()
    private var runner: NodeJSMobileRunner? // 你原本的代码，现在能正常识别了
    
    private init() {
        // 你原本的初始化逻辑，完全保留
        self.runner = NodeJSMobile.createRunner()
    }
    
    // MARK: - 你原本的引擎初始化方法，完全保留
    func setupEngine() {
        NodeJSMobile.startEngine()
        // 你原本的main.js加载逻辑，完全保留
        let mainScriptPath = Bundle.main.path(forResource: "main", ofType: "js")
        if let path = mainScriptPath {
            let mainScript = try? String(contentsOfFile: path, encoding: .utf8)
            if let script = mainScript {
                runner?.executeScript(script)
            }
        }
    }
    
    // MARK: - 你原本的JS脚本执行方法，完全保留
    func runScript(_ script: String, resultCallback: @escaping (String?, Error?) -> Void) {
        guard let runner = runner else {
            resultCallback(nil, NSError(domain: "NodeJSBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "引擎未初始化"]))
            return
        }
        
        // 你原本的脚本执行逻辑，完全保留
        runner.executeScript(script)
        resultCallback("success", nil)
    }
    
    // MARK: - 你原本的本地JS文件执行方法，完全保留
    func runLocalScript(fileName: String, callback: @escaping (String?, Error?) -> Void) {
        guard let path = Bundle.main.path(forResource: fileName, ofType: "js") else {
            callback(nil, NSError(domain: "NodeJSBridge", code: -2, userInfo: [NSLocalizedDescriptionKey: "文件不存在"]))
            return
        }
        
        do {
            let scriptContent = try String(contentsOfFile: path, encoding: .utf8)
            // 【修复2：把你原本错误的Data(.utf8)，改成正确写法，完全保留你的原有逻辑】
            let scriptData = Data(scriptContent.utf8)
            runner?.executeScript(scriptContent)
            callback(String(data: scriptData, encoding: .utf8), nil)
        } catch {
            callback(nil, error)
        }
    }
    
    // MARK: - 你原本的所有其他方法、回调、逻辑，100%全部保留
    func destroyEngine() {
        NodeJSMobile.stopEngine()
        runner = nil
    }
    
    func sendEventToJS(eventName: String, params: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: params, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        let eventScript = "window.dispatchEvent(new CustomEvent('\(eventName)', { detail: \(jsonString) }))"
        runner?.executeScript(eventScript)
    }
}
