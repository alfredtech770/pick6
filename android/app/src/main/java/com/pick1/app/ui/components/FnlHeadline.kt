package com.pick1.app.ui.components

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import com.pick1.app.ui.theme.P1
import com.pick1.app.ui.theme.anton

/**
 * Funnel headline — port of `FnlHeadline` (Pick1OnboardingFunnel.swift).
 *
 * The localized strings use a tiny markup convention so word order can move
 * freely between languages:
 *   • `\n`      — a line break
 *   • `*...*`   — the accented (lime / red / green) run
 *
 * e.g. `"WIN\nSMARTER.\n*NOT HARDER.*"`. Every funnel screen relies on this,
 * so the parser lives here rather than in any one screen.
 */
@Composable
fun FnlHeadline(
    text: String,
    modifier: Modifier = Modifier,
    accent: Color = P1.LimeFunnel,
    size: Int = 56,
    center: Boolean = false,
) {
    Text(
        parseAccentMarkup(text, accent),
        style = anton(size),
        color = P1.Foreground,
        textAlign = if (center) TextAlign.Center else TextAlign.Start,
        modifier = modifier,
    )
}

/**
 * Walks the string toggling emphasis on each `*`. Newlines are left inline —
 * Compose renders them directly, matching how the iOS renderer re-splits.
 */
fun parseAccentMarkup(text: String, accent: Color): AnnotatedString = buildAnnotatedString {
    var emphasised = false
    val buf = StringBuilder()
    fun flush() {
        if (buf.isEmpty()) return
        if (emphasised) withStyle(SpanStyle(color = accent)) { append(buf.toString()) }
        else append(buf.toString())
        buf.clear()
    }
    for (ch in text) {
        if (ch == '*') {
            flush()
            emphasised = !emphasised
        } else {
            buf.append(ch)
        }
    }
    flush()
}
