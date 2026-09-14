import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Loading keystore dari environment (GitHub Actions) atau key.properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}
val storeFile = keystoreProperties.getProperty("storeFilePath")
    ?: System.getenv("KEYSTORE_PATH")
val storePass = keystoreProperties.getProperty("storePassword")
    ?: System.getenv("KEYSTORE_PASSWORD")
val keyAlias = keystoreProperties.getProperty("keyAlias")
    ?: System.getenv("KEYSTORE_ALIAS")
val keyPass = keystoreProperties.getProperty("keyPassword")
    ?: System.getenv("KEYSTORE_PASSWORD")

android {
    namespace = "com.cbtsekolah.cbt_sekolah"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.cbtsekolah.cbt_sekolah"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (storeFile != null && storePass != null && keyAlias != null) {
                storeFile = file(storeFile)
                storePassword = storePass
                keyAlias = keyAlias
                keyPassword = keyPass
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (storeFile != null && storePass != null && keyAlias != null)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
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