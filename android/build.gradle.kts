// Flutter项目必需的顶级插件配置，严格匹配Flutter 3.41.6兼容版本
plugins {
    id("com.android.application") version "8.1.4" apply false
    id("com.android.library") version "8.1.4" apply false
    id("org.jetbrains.kotlin.android") version "1.9.0" apply false
}

// 全项目仓库配置：解决国内环境依赖拉取超时/失败问题，适配所有插件
allprojects {
    repositories {
        // 国内阿里云镜像优先，解决CI/国内环境依赖拉取失败
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
        maven("https://maven.aliyun.com/repository/public")
        maven("https://maven.aliyun.com/repository/gradle-plugin")
        // 官方仓库兜底，海外环境也能正常构建
        google()
        mavenCentral()
        // 适配media_kit音视频播放器、第三方开源插件的依赖仓库
        maven("https://jitpack.io")
    }
}

// 【保留原有功能】构建目录重定向：统一把构建产物放到Flutter项目根目录的build文件夹
// 修正相对路径写法，兼容Windows/macOS/Linux全平台，避免路径错误
val rootBuildDir: Directory = rootProject.layout.projectDirectory
    .dir("../../build") // 从android/子目录回到项目根目录，指向根目录的build文件夹
    .get()
// 重定向根项目的构建目录
rootProject.layout.buildDirectory.set(rootBuildDir)

// 子项目构建目录配置 + 构建时序修复
subprojects {
    // 每个子模块的构建产物放到 根build/[模块名] 下，和原有逻辑一致
    val subProjectBuildDir = rootBuildDir.dir(project.name)
    project.layout.buildDirectory.set(subProjectBuildDir)

    // 【修复循环依赖问题】排除app模块自身，避免构建时序死锁
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }
}

// 全局clean任务：彻底清理所有构建产物，比原有逻辑更彻底
tasks.register<Delete>("clean") {
    // 清理根构建目录
    delete(rootProject.layout.buildDirectory)
    // 额外清理所有子模块的残留构建文件
    subprojects {
        delete(project.layout.buildDirectory)
    }
}
