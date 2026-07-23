package com.pick1.app.ui.share

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.Sport
import com.pick1.app.ui.theme.*
import com.posthog.PostHog
import kotlin.math.roundToInt

/**
 * Share-your-win — port of `ShareWinSheet` (Views/ShareWin.swift).
 *
 * Renders a live preview of the card, lets the user set their hypothetical
 * stake, and shares it out.
 *
 * DELIBERATELY NOT PORTED YET: the share REWARD (iOS grants Pro days via the
 * `claim_share_reward` RPC on `share_reward_claims`). Wiring that here would
 * let the same person claim on both platforms unless the RPC de-dupes by
 * user rather than device — an entitlement change that deserves its own
 * review rather than riding along with a UI port. The hint copy is shown but
 * no grant is made.
 */
@Composable
fun ShareWinSheet(pick: Pick, isPro: Boolean, onClose: () -> Unit) {
    val ctx = LocalContext.current
    var amountText by remember { mutableStateOf("100") }
    val amount = amountText.replace(',', '.').toDoubleOrNull() ?: 100.0
    val returned = (amount * pick.decimalOdds).roundToInt()

    LaunchedEffect(Unit) {
        PostHog.capture("share_win_opened", properties = mapOf("league" to pick.league))
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(P1.Ink)
            .safeDrawingPadding(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Box(Modifier.padding(top = 10.dp)) {
            Box(Modifier.width(42.dp).height(5.dp).clip(CircleShape).background(P1.Line2))
        }
        Text(stringResource(R.string.sw_share_win), style = anton(26), color = Color.White)

        // Live preview of the exact card that gets shared.
        ShareWinCard(pick, amount, returned, Modifier.widthIn(max = 340.dp))

        // Amount input
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 24.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                stringResource(R.string.sw_your_amount),
                style = archivoNarrow(11, FontWeight.Bold, tracking = 1.6f),
                color = Color(0xFF8A8D94),
            )
            Spacer(Modifier.weight(1f))
            Row(
                Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(P1.Panel2)
                    .border(1.dp, P1.Lime.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text("$", style = mono(16, FontWeight.Bold), color = P1.Lime)
                BasicTextField(
                    value = amountText,
                    onValueChange = { amountText = it.filter { c -> c.isDigit() || c == '.' } },
                    textStyle = mono(18, FontWeight.Bold).copy(
                        color = Color.White,
                        textAlign = TextAlign.End,
                    ),
                    cursorBrush = SolidColor(P1.Lime),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = androidx.compose.ui.text.input.KeyboardType.Decimal,
                    ),
                    modifier = Modifier.width(90.dp),
                )
            }
        }

        if (!isPro) {
            Text(
                stringResource(R.string.sw_reward_hint),
                style = archivo(12, FontWeight.Medium),
                color = P1.Ink2,
            )
        }

        Text(
            stringResource(R.string.sw_share_cta),
            style = anton(17, tracking = 0.4f),
            color = P1.Ink,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(P1.Lime)
                .clickable {
                    val text = "${pick.pick.uppercase()} · ${pick.probability.roundToInt()}% " +
                        "— $${amount.roundToInt()} → $$returned · Pick1"
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                    }
                    runCatching { ctx.startActivity(Intent.createChooser(send, null)) }
                    PostHog.capture(
                        "share_win_completed",
                        properties = mapOf("reward_granted" to false),
                    )
                }
                .padding(vertical = 16.dp),
        )

        Text(
            stringResource(R.string.sw_disclaimer),
            style = archivo(10, FontWeight.Medium),
            color = P1.Mute,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 30.dp),
        )

        Spacer(Modifier.weight(1f))
        Text(
            stringResource(R.string.action_close),
            style = archivo(13, FontWeight.Bold),
            color = P1.Mute,
            modifier = Modifier.clickable { onClose() }.padding(bottom = 20.dp),
        )
    }
}

/** The shareable card — port of `ShareWinCard`. */
@Composable
fun ShareWinCard(pick: Pick, amount: Double, returned: Int, modifier: Modifier = Modifier) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(
                Brush.linearGradient(
                    listOf(Color(0xFF16200A), Color(0xFF0A0B0D)),
                    start = Offset.Zero, end = Offset.Infinite,
                )
            )
            .border(1.dp, P1.Lime.copy(alpha = 0.5f), RoundedCornerShape(22.dp))
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("PICK", style = anton(18), color = P1.Foreground)
            Text("1", style = anton(18), color = P1.Lime)
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(R.string.rd_won),
                style = archivoNarrow(10, FontWeight.Bold, tracking = 1.6f),
                color = P1.Ink,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(P1.Lime)
                    .padding(horizontal = 10.dp, vertical = 4.dp),
            )
        }
        Text(
            pick.pick.uppercase(),
            style = anton(30),
            color = P1.Lime,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            "${Sport.emoji(pick.sport)} ${pick.league.uppercase()} · ${pick.probability.roundToInt()}%",
            style = archivoNarrow(11, FontWeight.Bold, tracking = 1.6f),
            color = Color(0xFF8A8D94),
        )
        Box(Modifier.fillMaxWidth().height(1.dp).background(P1.Line))
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                "$${amount.roundToInt()} →",
                style = mono(14, FontWeight.Bold),
                color = P1.Ink2,
            )
            Spacer(Modifier.width(8.dp))
            Text("$$returned", style = anton(28), color = P1.Lime)
        }
    }
}
