import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties =
    Properties().apply {
        val localPropertiesFile = rootProject.file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { stream ->
                load(stream)
            }
        }
    }

val keystoreProperties =
    Properties().apply {
        val keystorePropertiesFile = rootProject.file("key.properties")
        if (keystorePropertiesFile.exists()) {
            keystorePropertiesFile.inputStream().use { stream ->
                load(stream)
            }
        }
    }

val hasReleaseSigning =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
        keystoreProperties.getProperty(it)?.isNotBlank() == true
    }

fun dartDefineValue(name: String): String? {
    val encodedDefines = project.findProperty("dart-defines") as? String
    return encodedDefines
        ?.split(",")
        ?.mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull()
        }
        ?.firstOrNull { it.startsWith("$name=") }
        ?.substringAfter("=")
        ?.takeIf { it.isNotBlank() }
}

val backgroundGeolocation = project(":flutter_background_geolocation")
apply(from = "${backgroundGeolocation.projectDir}/background_geolocation.gradle")

val baiduAndroidKey =
    dartDefineValue("BAIDU_ANDROID_KEY")
        ?: localProperties.getProperty("baidu.apiKey")
        ?: localProperties.getProperty("BAIDU_ANDROID_KEY")
        ?: ""

if (baiduAndroidKey.isBlank()) {
    throw GradleException(
        "Missing Baidu Android AK. Set baidu.apiKey=your_key in android/local.properties " +
            "or pass --dart-define=BAIDU_ANDROID_KEY=your_key."
    )
}

android {
    namespace = "com.example.geofence_reminder"
    compileSdk = flutter.compileSdkVersion
    buildToolsVersion = "35.0.0"
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.geofence_reminder"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["BAIDU_API_KEY"] = baiduAndroidKey
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
