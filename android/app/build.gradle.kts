plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // ← RE-ENABLE GOOGLE SERVICES!
}

android {
    namespace = "com.example.aurora_viking_app"  // ← MATCH FIREBASE REGISTRATION!
    compileSdk = 35
    ndkVersion = "27.0.12077973"


    compileOptions {
        isCoreLibraryDesugaringEnabled = true  // ← CORRECT Kotlin DSL syntax!
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "com.example.aurora_viking_app"  // ← MATCH FIREBASE REGISTRATION!
        minSdk = 24 // Updated from 23 to 24 for camerawesome compatibility
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Add Google Maps API key configuration
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = project.findProperty("GOOGLE_MAPS_API_KEY") as String? ?: ""
    }

    buildTypes {
        getByName("release") {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}