allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://maven.transistorsoft.com") }
        maven { url = uri("https://repo1.maven.org/maven2/") }
        maven { url = uri("https://jitpack.io") }
    }
    configurations.all {
        resolutionStrategy {
            force("org.jetbrains.kotlin:kotlin-stdlib:2.1.20")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.1.20")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.1.20")
            force("org.jetbrains.kotlin:kotlin-stdlib-common:2.1.20")
            force("org.jetbrains.kotlin:kotlin-reflect:2.1.20")
            force("com.google.maps.android:android-maps-utils:4.0.0")
        }
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
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            freeCompilerArgs = freeCompilerArgs + listOf("-Xskip-metadata-version-check")
        }
    }
}
// Clean task block removed per project configuration cleanup

// Ensure 3rd-party library has a namespace for AGP 8+
subprojects {
    plugins.withId("com.android.library") {
        if (project.name == "activity_recognition_flutter") {
            val androidExt = extensions.findByName("android")
            if (androidExt != null) {
                try {
                    val setNs = androidExt.javaClass.methods.firstOrNull { it.name == "setNamespace" && it.parameterCount == 1 }
                    setNs?.invoke(androidExt, "dk.cachet.activity_recognition_flutter")
                    val setCompileSdk = androidExt.javaClass.methods.firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
                    setCompileSdk?.invoke(androidExt, 36)
                } catch (_: Exception) {
                    // ignore
                }
            }
        }
    }
}
