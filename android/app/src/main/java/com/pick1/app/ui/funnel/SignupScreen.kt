package com.pick1.app.ui.funnel

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.data.AuthManager
import com.pick1.app.ui.components.FnlHeadline
import com.pick1.app.ui.theme.*
import com.posthog.PostHog
import kotlinx.coroutines.launch

/**
 * Account step — port of `SignupScreen` (Pick1OnboardingFunnel.swift).
 *
 * Sits AFTER the quiz + analysis on purpose, so the ask reads as "save your
 * results" rather than a cold registration wall. Two paths: Google (the
 * Android stand-in for Sign in with Apple) and email OTP, both landing on
 * the same Supabase user as iOS.
 */
@Composable
fun SignupScreen(onNext: () -> Unit) {
    var email by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var otpSent by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    // Already signed in (returning user mid-funnel) — don't trap them here.
    LaunchedEffect(Unit) {
        AuthManager.refreshSession()
        if (AuthManager.isAuthenticated) onNext()
    }

    fun primary() {
        scope.launch {
            if (!otpSent) {
                if (!email.contains("@") || !email.contains(".")) return@launch
                if (AuthManager.sendOtp(email.trim())) otpSent = true
            } else {
                if (AuthManager.verifyOtp(email.trim(), code.trim())) {
                    // Meta CompleteRegistration fires at account creation —
                    // not at the end of the funnel (which sits past the paywall).
                    PostHog.capture("signup_completed")
                    onNext()
                }
            }
        }
    }

    FnlScreen(
        bottom = {
            FnlCTA(
                if (AuthManager.busy) "…"
                else stringResource(
                    if (otpSent) R.string.funnel_signup_cta_verify
                    else R.string.funnel_signup_cta_email
                )
            ) { primary() }
            if (!otpSent) {
                Spacer(Modifier.height(14.dp))
                Text(
                    stringResource(R.string.funnel_signup_terms),
                    style = mono(11, FontWeight.Bold),
                    color = P1.Mute,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
    ) {
        FnlKick(
            stringResource(
                if (otpSent) R.string.funnel_signup_kicker_otp else R.string.funnel_signup_kicker
            )
        )
        Spacer(Modifier.height(14.dp))
        FnlHeadline(
            stringResource(
                if (otpSent) R.string.funnel_signup_headline_otp else R.string.funnel_signup_headline
            ),
            size = 40,
        )

        if (!otpSent) {
            Spacer(Modifier.height(26.dp))
            // Google Sign-In replaces Sign in with Apple on Android. The
            // credential flow needs a Firebase/Google client ID, which
            // arrives with the google-services.json setup.
            FnlCTA(stringResource(R.string.auth_google_button), style = CtaStyle.DARK) {
                AuthManager.clearError()
            }
            Row(
                Modifier.padding(vertical = 18.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(Modifier.weight(1f).height(1.dp).background(P1.Line))
                Text(
                    stringResource(R.string.funnel_signup_or),
                    style = archivoNarrow(10, FontWeight.Bold, tracking = 2f),
                    color = P1.Mute,
                )
                Box(Modifier.weight(1f).height(1.dp).background(P1.Line))
            }
            FnlField(
                label = stringResource(R.string.funnel_signup_email_label),
                value = email,
                placeholder = stringResource(R.string.funnel_signup_email_ph),
                keyboard = KeyboardType.Email,
            ) { email = it }
        } else {
            Spacer(Modifier.height(22.dp))
            FnlLead(
                stringResource(R.string.funnel_signup_otp_sent).replace("{email}", email)
            )
            Spacer(Modifier.height(14.dp))
            FnlField(
                label = stringResource(R.string.funnel_signup_code_label),
                value = code,
                placeholder = stringResource(R.string.funnel_signup_code_ph),
                keyboard = KeyboardType.Number,
            ) { code = it.filter(Char::isDigit).take(6) }
            Spacer(Modifier.height(12.dp))
            Text(
                stringResource(R.string.funnel_signup_diff_email),
                style = archivo(13, FontWeight.Medium),
                color = P1.LimeFunnel,
                modifier = Modifier.clickable { otpSent = false; code = "" },
            )
        }

        AuthManager.error?.takeIf { it.isNotBlank() }?.let {
            Spacer(Modifier.height(10.dp))
            Text(it, style = archivo(13), color = P1.Hot)
        }
    }
}

/** Labelled input — the funnel's `fnlField`. */
@Composable
private fun FnlField(
    label: String,
    value: String,
    placeholder: String,
    keyboard: KeyboardType,
    onChange: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            label,
            style = archivoNarrow(10, FontWeight.Bold, tracking = 2f),
            color = P1.Mute,
        )
        Box(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(P1.Panel)
                .border(1.dp, P1.Line, RoundedCornerShape(14.dp))
                .padding(horizontal = 16.dp, vertical = 15.dp),
        ) {
            if (value.isEmpty()) {
                Text(placeholder, style = archivo(15), color = P1.Mute)
            }
            BasicTextField(
                value = value,
                onValueChange = onChange,
                textStyle = archivo(15).copy(color = P1.Foreground),
                cursorBrush = SolidColor(P1.LimeFunnel),
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = keyboard,
                    capitalization = KeyboardCapitalization.None,
                ),
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
