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
val envKeyStorePath = System.getenv("KEYSTORE_PATH") ?: keystoreProperties.getProperty("storeFilePath")
val envKeyStorePass = System.getenv("KEYSTORE_PASSWORD") ?: keystoreProperties.getProperty("storePassword")
val envKeyAlias = System.getenv("KEYSTORE_ALIAS") ?: keystoreProperties.getProperty("keyAlias")
val envKeyPass = System.getenv("KEYSTORE_KEYPASSWORD") ?: keystoreProperties.getProperty("keyPassword")
val hasSigning = envKeyStorePath != null && envKeyStorePass != null && envKeyAlias != null

configure<com.android.build.api.dsl.ApplicationExtension> {
    namespace = "com.cbtsekolah.cbt_sekolah"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.cbtsekolah.cbt_sekolah"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasSigning) {
                storeFile = rootProject.file(envKeyStorePath!!)
                storePassword = envKeyStorePass
                keyAlias = envKeyAlias
                keyPassword = envKeyPass
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

androidComponents {
    onVariants { variant ->
        variant.signingConfig.enableV1Signing.set(true)
        variant.signingConfig.enableV2Signing.set(true)
        variant.signingConfig.enableV3Signing.set(true)
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
