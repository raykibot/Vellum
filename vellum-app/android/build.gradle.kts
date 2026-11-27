allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    plugins.withId("com.android.library") {
        val androidComponents = project.extensions.findByName("androidComponents")
        if (androidComponents != null) {
            val finalizeDslMethod = androidComponents.javaClass.methods.firstOrNull {
                (it.name == "finalizeDsl" || it.name == "finalizeDSl") &&
                    it.parameterCount == 1 &&
                    it.parameterTypes[0] == org.gradle.api.Action::class.java
            }
            finalizeDslMethod?.invoke(
                androidComponents,
                object : org.gradle.api.Action<Any> {
                    override fun execute(ext: Any) {
                        val getCompileSdk = ext.javaClass.methods.firstOrNull {
                            it.name == "getCompileSdk" && it.parameterCount == 0
                        }
                        val currentSdk = getCompileSdk?.invoke(ext) as? Int
                        if (currentSdk == null || currentSdk < 36) {
                            val setCompileSdk = ext.javaClass.methods.firstOrNull {
                                it.name == "setCompileSdk" &&
                                    it.parameterCount == 1 &&
                                    (it.parameterTypes[0] == Int::class.javaObjectType ||
                                        it.parameterTypes[0] == Int::class.java)
                            }
                            setCompileSdk?.invoke(ext, 36)
                        }
                    }
                }
            )
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
