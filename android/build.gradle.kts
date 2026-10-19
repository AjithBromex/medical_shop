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
    val configureAndroid: (Project) -> Unit = { p ->
        p.extensions.findByName("android")?.let { androidExt ->
            val methods = androidExt.javaClass.methods
            for (m in methods) {
                if ((m.name == "compileSdkVersion" || m.name == "setCompileSdkVersion") && m.parameterTypes.size == 1) {
                    try {
                        if (m.parameterTypes[0] == Int::class.javaPrimitiveType || m.parameterTypes[0] == java.lang.Integer::class.java) {
                            m.invoke(androidExt, 36)
                        } else if (m.parameterTypes[0] == String::class.java) {
                            m.invoke(androidExt, "android-36")
                        }
                    } catch (_: Exception) {}
                }
                if (m.name == "setCompileSdk" && m.parameterTypes.size == 1) {
                    try {
                        if (m.parameterTypes[0] == Int::class.javaPrimitiveType || m.parameterTypes[0] == java.lang.Integer::class.java) {
                            m.invoke(androidExt, 36)
                        }
                    } catch (_: Exception) {}
                }
            }
        }
    }

    if (state.executed) {
        configureAndroid(this)
    } else {
        afterEvaluate {
            configureAndroid(this)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
