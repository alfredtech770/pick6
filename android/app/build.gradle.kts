import java.io.FileInputStream
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.google.services)
}

// Release signing — read from the gitignored keystore.properties so the upload
// key + passwords never enter version control. Absent on CI/fresh clones, in
// which case the release build stays unsigned (debug is unaffected).
val keystorePropsFile = rootProject.file("keystore.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) FileInputStream(keystorePropsFile).use { load(it) }
}

android {
    namespace = "com.pick1.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.pick1.app"
        minSdk = 26          // matches the iOS feature floor; covers ~95%+ of devices
        targetSdk = 36
        // 1 and 2 are taken. 1 went to the internal testing track on
        // 2026-08-04; 2 was uploaded to production on 2026-09-15 and rejected
        // by Play for targeting API 35 and Billing 7. Play never lets a
        // versionCode be reused, even for a bundle nobody ever installed.
        versionCode = 3
        versionName = "1.0.18"   // keep in step with the iOS release train

        // Same backend as iOS. The anon key is a publishable client credential
        // (RLS-enforced) and is designed to ship in the binary.
        buildConfigField("String", "SUPABASE_URL", "\"https://lgnjawngkiamlngcffrk.supabase.co\"")
        buildConfigField(
            "String", "SUPABASE_ANON_KEY",
            "\"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxnbmphd25na2lhbWxuZ2NmZnJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczNzE5MTIsImV4cCI6MjA5Mjk0NzkxMn0.JgIspzgxL3YaMuq_I5gdvh67AJN09kimJSOnM_uJaD4\""
        )
        buildConfigField("String", "POSTHOG_KEY", "\"phc_yzgtib4eMMgg9dRGfujgECRiBrVhArkZMDAoLWMZk3Dv\"")
        buildConfigField("String", "POSTHOG_HOST", "\"https://us.i.posthog.com\"")

        // Locales the app ships (mirrors the iOS L10n tables).
        resourceConfigurations += listOf("en", "es", "fr", "de", "it", "pt", "ar")
    }

    signingConfigs {
        create("release") {
            if (keystoreProps.isNotEmpty()) {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // No applicationIdSuffix: debug uses com.pick1.app so it matches
            // the single Firebase app in google-services.json. (Register a
            // com.pick1.app.debug app in Firebase if you later want debug +
            // release installed side by side.)
            isDebuggable = true
        }
        release {
            // R8 on since 2026-09-15, with real keep rules in proguard-rules.pro
            // for kotlinx.serialization, ktor, Supabase, Firebase and Billing.
            // Un-minified the bundle was 20.2 MB, most of it unused
            // material-icons-extended vectors. Verify on the internal testing
            // track before the production rollout completes.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    buildFeatures {
        compose = true
        buildConfig = true
    }
    packaging {
        resources { excludes += "/META-INF/{AL2.0,LGPL2.1}" }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material.icons.extended)
    implementation(libs.androidx.navigation.compose)
    debugImplementation(libs.androidx.ui.tooling)

    // Supabase — same project/tables the iOS app reads
    implementation(platform(libs.supabase.bom))
    implementation(libs.supabase.postgrest)
    implementation(libs.supabase.auth)
    implementation(libs.supabase.realtime)
    implementation(libs.ktor.client.okhttp)

    implementation(libs.coil.compose)
    implementation(libs.androidx.datastore.preferences)

    // Monetization / push / analytics
    implementation(libs.billing.ktx)
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)
    implementation(libs.androidx.credentials)
    implementation(libs.androidx.credentials.play.services)
    implementation(libs.googleid)
    implementation(libs.posthog)
    implementation(libs.facebook.core)

    // Home-screen widget + win sound
    implementation(libs.androidx.glance.appwidget)
    implementation(libs.androidx.glance.material3)
    implementation(libs.androidx.media3.exoplayer)
}
