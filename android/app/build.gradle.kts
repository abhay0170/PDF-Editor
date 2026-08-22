plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.pdf"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.pdf"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // cunning_document_scanner (Scan to PDF) requires minSdk 24.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Real Android devices are always armeabi-v7a or arm64-v8a; x86/x86_64
        // only exist for emulators. This trims the native libraries plugins
        // (ML Kit, pdfium, sqlite3) ship for every ABI in their AAR — the
        // Flutter engine's own per-ABI binaries are separately controlled by
        // `flutter build apk --target-platform android-arm,android-arm64`.
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // Belt-and-suspenders on top of ndk.abiFilters above: ML Kit's OCR model
    // pipeline (play-services-mlkit-text-recognition-bundled) packages its
    // x86_64 .so directly rather than through the normal per-ABI jniLibs path
    // abiFilters covers, so it survives that filter alone. Explicitly
    // excluding the emulator-only ABIs here catches it too.
    packaging {
        jniLibs {
            excludes += setOf("lib/x86_64/**", "lib/x86/**")
        }
    }
}

flutter {
    source = "../.."
}
