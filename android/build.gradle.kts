import java.io.File

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

subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExt = extensions.findByName("android") ?: return@withPlugin
        val getNamespace = androidExt.javaClass.methods.firstOrNull {
            it.name == "getNamespace" && it.parameterCount == 0
        } ?: return@withPlugin
        val setNamespace = androidExt.javaClass.methods.firstOrNull {
            it.name == "setNamespace" && it.parameterCount == 1
        } ?: return@withPlugin

        val namespace = getNamespace.invoke(androidExt) as? String
        if (!namespace.isNullOrBlank()) {
            return@withPlugin
        }

        val manifestFile = File(project.projectDir, "src/main/AndroidManifest.xml")
        if (!manifestFile.exists()) {
            return@withPlugin
        }
        val match = Regex("""package\s*=\s*"([^"]+)"""")
            .find(manifestFile.readText())
            ?: return@withPlugin
        val manifestPackage = match.groupValues[1]
        setNamespace.invoke(androidExt, manifestPackage)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
