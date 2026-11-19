import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.variant.LibraryAndroidComponentsExtension

plugins {
    id("com.android.application") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

project(":tdlib") {
    pluginManager.withPlugin("com.android.library") {
        val appCompileSdk = project(":app").extensions.getByType<ApplicationExtension>().compileSdk
        // tdlib 1.6.0 仅在 Manifest 声明包名，且旧 compileSdk 低于其 AndroidX 依赖要求。
        extensions.getByType<LibraryAndroidComponentsExtension>().finalizeDsl {
            it.namespace = it.namespace ?: "org.naji.td.tdlib"
            it.compileSdk = appCompileSdk
            // Android 仅打包应用提供的官方 TDLib。此插件仍提供 Dart 类型和桌面绑定。
            it.sourceSets.getByName("main").jniLibs.directories.clear()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
