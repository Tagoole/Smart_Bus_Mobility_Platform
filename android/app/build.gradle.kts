import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    
}

android {
    namespace = "com.example.smart_bus_mobility_platform1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"
    signingConfigs {
        create("release") {
            val storeFilePath = System.getenv("KEYSTORE_FILE")
                ?: keystoreProperties["storeFile"] as String?
                ?: "android/app/my-release-key.jks"

            storeFile = file(storeFilePath)

            storePassword = System.getenv("KEYSTORE_PASSWORD")
                ?: keystoreProperties["storePassword"] as String?
                ?: "smartbus"

            keyAlias = System.getenv("KEY_ALIAS")
                ?: keystoreProperties["keyAlias"] as String?
                ?: "my-key-alias"

            keyPassword = System.getenv("KEY_PASSWORD")
                ?: keystoreProperties["keyPassword"] as String?
                ?: "smartbus"
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.smart_bus_mobility_platform1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}



dependencies {
  // Import the Firebase BoM
  implementation(platform("com.google.firebase:firebase-bom:33.15.0"))


  // TODO: Add the dependencies for Firebase products you want to use
  // When using the BoM, don't specify versions in Firebase dependencies
  implementation("com.google.firebase:firebase-analytics")


  // Add the dependencies for any other desired Firebase products
  // https://firebase.google.com/docs/android/setup#available-libraries
}

