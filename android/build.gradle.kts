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
        val previewLibs = rootProject.layout.projectDirectory.dir("../build/tdlib-preview/jniLibs")
        val checkPreview = tasks.register("checkTdlibPreviewLibrary") {
            doLast {
                val nativeLibrary = previewLibs.file("arm64-v8a/libtdjson.so").asFile
                check(nativeLibrary.isFile && nativeLibrary.length() > 0) {
                    "缺少新版 TDLib 原生库；请先按 docs/tdlib-android-params.md 构建预览库。"
                }
            }
        }
        tasks.matching {
            it.name.startsWith("mergeTdlibPreview") && it.name.endsWith("JniLibFolders")
        }.configureEach { dependsOn(checkPreview) }

        extensions.getByType<LibraryAndroidComponentsExtension>().finalizeDsl {
            it.namespace = it.namespace ?: "org.naji.td.tdlib"
            it.compileSdk = appCompileSdk
            it.flavorDimensions += "tdlib"
            it.productFlavors.create("stable") { dimension = "tdlib" }
            it.productFlavors.create("tdlibPreview") { dimension = "tdlib" }
            it.sourceSets.getByName("main").jniLibs.directories.clear()
            it.sourceSets.getByName("stable").jniLibs.directories.add("src/main/jniLibs")
            it.sourceSets.getByName("tdlibPreview").jniLibs.directories.add(previewLibs.asFile.absolutePath)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
