import org.jetbrains.kotlin.gradle.dsl.JvmTarget

fun escapeBuildConfigString(value: String): String =
    value.replace("\\", "\\\\").replace("\"", "\\\"")

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.ross.android"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.ross.android"
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
        val backendBaseUrl = providers.gradleProperty("ROSS_BACKEND_BASE_URL")
            .orElse(providers.environmentVariable("ROSS_BACKEND_BASE_URL"))
            .orElse(providers.gradleProperty("ROSS_BACKEND_URL"))
            .orElse(providers.environmentVariable("ROSS_BACKEND_URL"))
            .orElse("http://10.0.2.2:8080")
            .get()
        val localModelPath = providers.gradleProperty("ROSS_LOCAL_MODEL_PATH")
            .orElse(providers.environmentVariable("ROSS_LOCAL_MODEL_PATH"))
            .orElse("")
            .get()
        val localModelChecksum = providers.gradleProperty("ROSS_LOCAL_MODEL_CHECKSUM")
            .orElse(providers.environmentVariable("ROSS_LOCAL_MODEL_CHECKSUM"))
            .orElse("")
            .get()
        val localModelKind = providers.gradleProperty("ROSS_LOCAL_MODEL_KIND")
            .orElse(providers.environmentVariable("ROSS_LOCAL_MODEL_KIND"))
            .orElse("")
            .get()
        val localRuntime = providers.gradleProperty("ROSS_LOCAL_RUNTIME")
            .orElse(providers.environmentVariable("ROSS_LOCAL_RUNTIME"))
            .orElse("")
            .get()
        val enableRealInference = providers.gradleProperty("ROSS_ENABLE_REAL_LOCAL_INFERENCE")
            .orElse(providers.environmentVariable("ROSS_ENABLE_REAL_LOCAL_INFERENCE"))
            .orElse("false")
            .get()

        buildConfigField("String", "ROSS_BACKEND_BASE_URL", "\"${escapeBuildConfigString(backendBaseUrl)}\"")
        buildConfigField("String", "ROSS_LOCAL_MODEL_PATH", "\"${escapeBuildConfigString(localModelPath)}\"")
        buildConfigField("String", "ROSS_LOCAL_MODEL_CHECKSUM", "\"${escapeBuildConfigString(localModelChecksum)}\"")
        buildConfigField("String", "ROSS_LOCAL_MODEL_KIND", "\"${escapeBuildConfigString(localModelKind)}\"")
        buildConfigField("String", "ROSS_LOCAL_RUNTIME", "\"${escapeBuildConfigString(localRuntime)}\"")
        buildConfigField("boolean", "ROSS_ENABLE_REAL_LOCAL_INFERENCE", enableRealInference.toBoolean().toString())

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.03.00")

    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.activity:activity-compose:1.12.2")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.4")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.9.4")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.biometric:biometric:1.2.0-alpha05")
    implementation("androidx.work:work-runtime-ktx:2.10.5")
    implementation("com.google.android.material:material:1.13.0")
    implementation("com.google.code.gson:gson:2.11.0")
    implementation("com.google.mlkit:text-recognition:16.0.1")
    implementation("com.google.mediapipe:tasks-genai:0.10.27")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.9.0")

    debugImplementation("androidx.compose.ui:ui-tooling")

    testImplementation("junit:junit:4.13.2")
    testImplementation("androidx.test:core:1.6.1")
    testImplementation("org.robolectric:robolectric:4.14.1")
}
