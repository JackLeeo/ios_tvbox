android {
    compileSdkVersion 33
    defaultConfig {
        applicationId "com.yourname.tvbox" // 与AndroidManifest.xml的package一致
        minSdkVersion 21 // 支持Android 5.0+
        targetSdkVersion 33
        versionCode 1
        versionName "1.0.0"
    }
    buildTypes {
        release {
            signingConfig signingConfigs.debug // 无签名打包（用debug签名）
        }
    }
}