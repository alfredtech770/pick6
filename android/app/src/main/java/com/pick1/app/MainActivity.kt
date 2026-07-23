package com.pick1.app

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.pick1.app.ui.RootScaffold
import com.pick1.app.ui.theme.Pick1Theme

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // DEBUG ONLY: `adb shell am start ... --ez skipOnboarding true` jumps
        // straight to the board, mirroring the iOS -hasFinishedOnboarding
        // launch arg. Never reachable in a release build.
        val skipOnboarding = BuildConfig.DEBUG &&
            intent?.getBooleanExtra("skipOnboarding", false) == true
        // DEBUG ONLY: open a specific screen for review, mirroring the iOS
        // -PreviewStep launch arg. e.g. `--es screen summerFootball`.
        val debugScreen = if (BuildConfig.DEBUG) intent?.getStringExtra("screen") else null
        setContent {
            Pick1Theme {
                RootScaffold(
                    forceSkipOnboarding = skipOnboarding,
                    debugScreen = debugScreen,
                )
            }
        }
    }
}
