plugins {
    id("com.android.application")
    // Flutter 插件须在 Android 插件之后加载。
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.tgsorter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 沿用已验证的应用 ID，保留已登录设备的数据。
        applicationId = "com.example.tgsorter.tdlibpreview"
        ndk.abiFilters += "arm64-v8a"
        resValue("string", "app_name", "TgSorter")
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures.resValues = true
    sourceSets.getByName("main") {
        jniLibs.directories.add(rootProject.file("tdlib/jniLibs").absolutePath)
        assets.directories.add(rootProject.file("tdlib/notices").absolutePath)
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

val checkTdlibAndroid = tasks.register("checkTdlibAndroid") {
    doLast {
        for (path in listOf(
            "jniLibs/arm64-v8a/libtdjson.so",
            "notices/TDLib-LICENSE.txt",
            "notices/OpenSSL-LICENSE.txt",
        )) {
            val artifact = rootProject.file("tdlib/$path")
            check(artifact.isFile && artifact.length() > 0) {
                "缺少 Android TDLib 产物 $path，请参阅 docs/tdlib-android-params.md。"
            }
        }
    }
}
tasks.named("preBuild") { dependsOn(checkTdlibAndroid) }

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
