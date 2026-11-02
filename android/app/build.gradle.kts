import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ng.educore.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (notices shown while the app is open) needs newer Java classes on older phones.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "ng.educore.app"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing. A production APK is signed with the permanent release keystore, never the debug key.
    // The keystore and its passwords live outside Git: locally in android/key.properties (see key.properties.example and
    // tool/create-release-keystore.sh), on GitHub from the KEYSTORE_* variables the workflow fills from repository secrets.
    val keyProps = Properties().apply {
        val f = rootProject.file("key.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
    fun signingValue(property: String, variable: String): String? =
        (keyProps.getProperty(property) ?: System.getenv(variable))?.takeIf { it.isNotBlank() }
    val storePath = signingValue("storeFile", "KEYSTORE_FILE")
    val storePass = signingValue("storePassword", "KEYSTORE_PASSWORD")
    val keyAliasName = signingValue("keyAlias", "KEY_ALIAS")
    val keyPass = signingValue("keyPassword", "KEY_PASSWORD")
    val hasReleaseKey = storePath != null && storePass != null && keyAliasName != null && keyPass != null
    // Only a build that says so (the test-only workflow path) may fall back to the debug key.
    val allowDebugSigning = System.getenv("ALLOW_DEBUG_SIGNING") == "true"

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(storePath!!)
                storePassword = storePass
                keyAlias = keyAliasName
                keyPassword = keyPass
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                hasReleaseKey -> signingConfigs.getByName("release")
                allowDebugSigning -> signingConfigs.getByName("debug")
                else -> null
            }
        }
    }

    // A release build with no release keystore stops with a clear message, so a debug-signed file is never mistaken for production.
    gradle.taskGraph.whenReady {
        val releasing = allTasks.any { it.project == project && it.name in setOf("assembleRelease", "bundleRelease", "packageRelease") }
        if (releasing && !hasReleaseKey && !allowDebugSigning) {
            throw GradleException(
                "No release keystore found. Create android/key.properties (copy key.properties.example and fill it in, " +
                    "or run tool/create-release-keystore.sh), or set KEYSTORE_FILE, KEYSTORE_PASSWORD, KEY_ALIAS and KEY_PASSWORD."
            )
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// Push notifications: only when the Firebase file is there, so a build without it still works (it just gets no notices).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
