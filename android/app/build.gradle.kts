import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release: android/key.properties (fuera de git) apunta a la keystore
// propia. En CI lo crea release.yml desde los secretos ANDROID_KEYSTORE_*.
// Sin el archivo se firma con la clave de depuración (solo para pruebas).
val propiedadesFirma =
    Properties().apply {
        val archivo = rootProject.file("key.properties")
        if (archivo.exists()) archivo.inputStream().use { load(it) }
    }
val hayFirmaPropia = propiedadesFirma.getProperty("storeFile") != null

android {
    namespace = "com.example.opaego"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Identificador propio de la app (el namespace del código Kotlin no cambia).
        applicationId = "co.paego.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hayFirmaPropia) {
            create("release") {
                storeFile = rootProject.file(propiedadesFirma.getProperty("storeFile"))
                storePassword = propiedadesFirma.getProperty("storePassword")
                keyAlias = propiedadesFirma.getProperty("keyAlias")
                keyPassword = propiedadesFirma.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.getByName(if (hayFirmaPropia) "release" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
