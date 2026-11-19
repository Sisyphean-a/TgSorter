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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.tgsorter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures.resValues = true
    flavorDimensions += "tdlib"
    productFlavors {
        create("stable") {
            dimension = "tdlib"
            resValue("string", "app_name", "tgsorter")
        }
        create("tdlibPreview") {
            dimension = "tdlib"
            applicationIdSuffix = ".tdlibpreview"
            ndk.abiFilters += "arm64-v8a"
            resValue("string", "app_name", "TgSorter TDLib Preview")
        }
    }

    sourceSets.getByName("tdlibPreview").assets.directories.add(
        rootProject.file("../build/tdlib-preview/notices").absolutePath,
    )

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
