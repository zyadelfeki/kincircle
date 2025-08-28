import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.GradleException
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Required for Firebase to read google-services.json and generate resources
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties().apply {
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (!keystorePropertiesFile.exists()) {
        throw GradleException("Missing key.properties for release signing (expected at android/key.properties).")
    }
    load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.zyad.kincircle"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
    applicationId = "com.zyad.kincircle"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            val storeFileProp = keystoreProperties.getProperty("storeFile")
                ?: throw GradleException("key.properties missing 'storeFile'")
            val storePasswordProp = keystoreProperties.getProperty("storePassword")
                ?: throw GradleException("key.properties missing 'storePassword'")
            val keyAliasProp = keystoreProperties.getProperty("keyAlias")
                ?: throw GradleException("key.properties missing 'keyAlias'")
            val keyPasswordProp = keystoreProperties.getProperty("keyPassword")
                ?: throw GradleException("key.properties missing 'keyPassword'")

            val normalizedPath = storeFileProp.removePrefix("android/")
            val candidate = File(normalizedPath)
            storeFile = if (candidate.isAbsolute) candidate else rootProject.file(normalizedPath)
            storePassword = storePasswordProp
            keyAlias = keyAliasProp
            keyPassword = keyPasswordProp
        }
    }

    buildTypes {
        release {
            // Force production keystore; fail fast if missing
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.tensorflow:tensorflow-lite-gpu:2.12.0")
}
