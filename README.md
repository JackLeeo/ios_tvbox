TVBox Flutter 项目文档

一、项目简介

TVBox Flutter 是将 tvbox-Swift 项目转换为 Flutter 跨平台实现的 TVBox 客户端，完整支持 type1（JSON）、type2（XPath）、type3（Spider） 三类数据源，集成 JavaScript/Python 多语言爬虫引擎，提供跨平台（Android/iOS/Windows）播放能力，并通过 GitHub Actions 实现自动化无签名打包（支持 TrollStore 安装）。  

二、核心功能

功能模块 说明
多源支持 兼容 type1（标准 JSON API）、type2（XPath 规则解析）、type3（JS/Python 动态脚本）
爬虫引擎 集成 flutter_js（执行 CatJS 脚本）和 flutter_python（执行 Py 脚本），支持动态网络请求与数据处理
状态管理 基于 Provider 实现首页/详情页/播放页状态同步，支持源切换、数据加载、错误处理
本地存储 用 SQLite 缓存视频详情（24 小时有效期），SharedPrefs 存储用户配置
跨平台播放 集成 media_kit 播放器，支持全屏、进度控制、倍速播放
源调试工具 提供可视化界面测试源配置（API 地址、脚本内容），实时查看返回结果
自动化打包 通过 GitHub Actions 配置 Android（APK）、iOS（无签名 IPA）、Windows（EXE）构建
  

三、项目结构

tvbox_flutter/                  # 项目根目录
├── lib/                        # 核心代码
│   ├── core/                   # 引擎与管理器
│   │   ├── js_engine.dart      # JavaScript 爬虫引擎（支持 CatJS）
│   │   ├── python_engine.dart  # Python 爬虫引擎（支持 Py 源）
│   │   ├── spider_manager.dart # 统一爬虫源管理器
│   │   └── network_service.dart# 网络请求服务（Dio 封装）
│   ├── models/                 # 数据模型
│   │   ├── spider_source.dart  # 爬虫源模型（type1/2/3）
│   │   ├── video_model.dart    # 视频数据模型（兼容 TVBox 标准字段）
│   │   └── category_model.dart # 分类模型（含筛选器）
│   ├── viewmodels/             # 状态管理（Provider）
│   │   ├── home_viewmodel.dart # 首页状态（加载/错误/数据列表）
│   │   ├── detail_viewmodel.dart# 详情页状态（视频详情加载）
│   │   └── player_viewmodel.dart# 播放页状态（播放地址解析）
│   ├── views/                  # 界面组件
│   │   ├── home_view.dart      # 首页（网格展示视频卡片）
│   │   ├── detail_view.dart    # 详情页（封面+播放源列表）
│   │   ├── player_view.dart    # 播放页（MediaKit 集成）
│   │   └── source_debugger.dart# 源调试工具（测试源配置）
│   ├── persistence/            # 本地存储
│   │   └── cache_service.dart  # 缓存服务（SQLite+SharedPrefs）
│   └── utils/                  # 工具类
│       ├── string_utils.dart   # 字符串处理（MD5/Base64/HTML 过滤）
│       └── date_utils.dart     # 日期格式化（相对时间/解析）
├── assets/                     # 资源文件
│   ├── js/                     # JavaScript 库（CryptoJS/Lodash/Cheerio）
│   └── images/                 # 应用图标、启动图、默认封面
├── ios/                       # iOS 配置（TrollStore 兼容）
│   ├── Runner/Info.plist       # 应用配置（网络权限、文件共享）
│   ├── Podfile                 # CocoaPods 依赖（最低 iOS 12.0）
│   └── ExportOptions.plist     # 无签名 IPA 导出配置
├── android/                    # Android 配置
│   └── app/src/main/AndroidManifest.xml  # 应用清单（网络权限、明文请求）
├── .github/workflows/          # GitHub Actions 配置
│   └── build_unsigned_ios.yml  # 无签名 IPA 打包流水线
├── pubspec.yaml                # 依赖管理（Flutter/Dart 包）
└── README.md                   # 项目说明（本文档）
  

四、环境配置

1. 开发环境

• Flutter SDK: >=3.13.0（推荐 3.19.6，与 GitHub Actions 配置一致）  

• Dart SDK: >=3.0.0 <4.0.0  

• IDE: VS Code（推荐）或 Android Studio（需安装 Flutter 插件）  

• 系统依赖:  

  • iOS 打包：macOS 14+、Xcode 15+  

  • Android 打包：JDK 11+、Android SDK 33+  

  • Windows 打包：Visual Studio 2022（含 C++ 桌面开发组件）  

2. 依赖安装

# 克隆项目
git clone https://github.com/你的用户名/tvbox-flutter.git
cd tvbox-flutter

# 安装 Flutter 依赖
flutter pub get

# 安装 iOS 依赖（CocoaPods）
cd ios && pod install && cd ..
  

五、快速开始

1. 添加数据源

通过 源调试工具 或代码添加源（以 type3 JS 源为例）：  
// 在 main.dart 或任意初始化逻辑中添加
await spiderManager.addSource(SpiderSource(
  key: "my_js_source",
  name: "我的 JS 源",
  type: 3,
  api: "https://example.com/source.js", // 远程脚本地址（可选）
  ext: """
    class MySpider extends CatVodSpider {
      async homeContent(filter) {
        return { list: [{ id: '1', name: '测试视频', pic: 'https://example.com/pic.jpg' }] };
      }
    }
  """, // 明文脚本内容
));
  

2. 运行项目

# 运行 iOS 模拟器（需先启动模拟器）
flutter run -d iPhone 14

# 运行 Android 设备（需连接设备或启动模拟器）
flutter run -d android

# 运行 Windows 桌面端
flutter run -d windows
  

3. 界面导航

• 首页（/）：网格展示视频卡片，支持下拉刷新、源切换（通过调试工具添加源后）。  

• 源调试工具（/debug）：测试源配置（API 地址、脚本内容），实时查看返回数据。  

• 详情页（/detail）：展示视频封面、简介、播放源列表（点击播放源跳转播放页）。  

• 播放页（/player）：集成 media_kit 播放器，支持全屏、倍速、音量控制。  

六、打包与部署

1. 无签名 IPA 打包（TrollStore 安装）

通过 GitHub Actions 自动构建，步骤如下：  
1. 将项目推送到 GitHub 仓库。  
2. 在仓库 Actions 页面选择 “打包无签名 iOS IPA（TrollStore 兼容）” 工作流，点击 “Run workflow” 手动触发。  
3. 构建完成后，在 Artifacts 中下载 tvbox_unsigned_ios_ipa，通过 TrollStore 安装到 iOS 设备。  

2. Android APK 打包

# 生成发布版 APK
flutter build apk --release

# 输出路径：build/app/outputs/flutter-apk/app-release.apk
  

3. Windows EXE 打包

# 生成发布版 EXE
flutter build windows --release

# 输出路径：build/windows/runner/Release/
  

七、常见问题

Q1：源返回数据格式错误？

• 检查源类型与配置是否匹配（type1 需返回标准 JSON，type2 需配置 XPath 规则）。  

• 使用 源调试工具 测试源，查看返回结果是否符合预期。  

Q2：iOS 打包提示“签名错误”？

• 确保 GitHub Actions 配置中 --no-codesign 参数正确，且 ExportOptions.plist 中签名相关字段留空。  

Q3：播放器无法加载视频？

• 检查视频 URL 是否有效，网络权限是否开启（iOS Info.plist 中 NSAllowsArbitraryLoads: true）。  

八、后续协助

• 若需 添加新源类型 或 优化爬虫引擎性能，可参考 spider_manager.dart 扩展 _executeTypeX 方法。  

• 若需 自定义播放器 UI，可修改 player_view.dart 中的 MaterialVideoControls 配置。  

• 若需 调整 GitHub Actions 打包策略（如自动发布到 TestFlight），可编辑 .github/workflows/build.yml。  

项目维护者：包子  
最后更新：2026-04-04  
许可证：MIT（可自由修改与分发）  
