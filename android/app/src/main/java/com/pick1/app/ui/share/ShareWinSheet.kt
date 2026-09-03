package com.pick1.app.ui.share

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import com.pick1.app.ui.components.confidenceTierText
import com.pick1.app.ui.components.P1PickTicket
import androidx.compose.ui.draw.rotate
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
    val returned = if (pick.isLoss) 0 else (amount * pick.decimalOdds).roundToInt()

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
        Text(stringResource(if (pick.isWin) R.string.sw_share_win else R.string.sw_share_result), style = anton(26), color = Color.White)

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

        // The disclaimer lives on the CARD, not the sheet. It has to travel
        // with the money: an image that leaves the app showing a return
        // without saying it is hypothetical and that Pick1 takes no bets is
        // exactly the asset that gets an ad account into trouble. Printing it
        // here as well just said it twice on one screen.

        Spacer(Modifier.weight(1f))
        Text(
            stringResource(R.string.action_close),
            style = archivo(13, FontWeight.Bold),
            color = P1.Mute,
            modifier = Modifier.clickable { onClose() }.padding(bottom = 20.dp),
        )
    }
}

/**
 * The shareable card, port of `ShareWinCard`.
 *
 * The shared image is the SAME ticket the detail page shows, tilted a few
 * degrees so it reads as a slip someone is holding rather than a screenshot
 * of a row. Reusing the component instead of drawing a second card means the
 * thing people pass around cannot drift away from the thing the app shows,
 * which is the whole point of a public record.
 *
 * It is shared for LOSSES too. A record you can only pass on when it flatters
 * you is not a record.
 */
@Composable
fun ShareWinCard(pick: Pick, amount: Double, returned: Int, modifier: Modifier = Modifier) {
    val accent = if (pick.isWin) Color(0xFFC6FF34) else Color(0xFFFF6B57)

    // The logged time is stamped in the pipeline's timezone, not the reader's,
    // or two people sharing the same call would show different times on the
    // same ticket.
    val loggedText = pick.createdAt?.let { raw ->
        runCatching {
            val inst = java.time.Instant.parse(raw)
            java.time.format.DateTimeFormatter.ofPattern("h:mm a")
                .withZone(java.time.ZoneId.of("America/New_York"))
                .format(inst)
        }.getOrDefault("PRE-GAME")
    } ?: "PRE-GAME"

    // NO frame. The ticket already has an edge, a bite and a border of its
    // own, so wrapping it in a second bordered card produced a box inside a
    // box and made the ticket look like a screenshot of a screenshot. The
    // canvas is flat and the ticket is the object.
    Column(
        modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            Modifier
                .rotate(-2.5f)
                // The tilt swings the corners out; this keeps them inside the
                // rendered image instead of clipping them off.
                .padding(horizontal = 10.dp, vertical = 12.dp),
        ) {
            P1PickTicket(
                pick = pick,
                homeScore = pick.homeScore,
                awayScore = pick.awayScore,
                confidence = confidenceTierText(pick),
                loggedAt = loggedText,
            )
        }

        // The stake the sharer chose, and what it came back as. $0 on a loss,
        // never a hypothetical dressed as a return.
        Row(verticalAlignment = Alignment.Bottom) {
            Text("$${amount.roundToInt()}", style = anton(26), color = P1.Foreground)
            Text("  →  ", style = anton(15), color = accent)
            Text("$$returned", style = anton(34), color = accent)
        }

        Text(
            stringResource(R.string.sw_disclaimer),
            style = archivo(8, FontWeight.Medium),
            color = Color(0xFF6E6F75),
            maxLines = 2,
        )
    }
}
