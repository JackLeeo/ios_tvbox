pluginManagement {
    // 插件仓库配置，国内镜像优化
    repositories {
        maven("https://maven.aliyun.com/repository/gradle-plugin")
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// 全项目依赖仓库管理，新版Flutter的核心配置
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        // 国内阿里云镜像优先
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
        maven("https://maven.aliyun.com/repository/public")
        // 官方仓库兜底
        google()
        mavenCentral()
        // 适配media_kit等插件
        maven("https://jitpack.io")
    }
}

// 保留Flutter自动生成的include配置，不要修改
rootProject.name = "ios_tvbox"
include(":app")
