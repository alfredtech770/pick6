package com.pick1.app.ui.home

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.Sport
import com.pick1.app.ui.components.TeamLogo
import com.pick1.app.ui.theme.*
import kotlin.math.roundToInt

/**
 * The board, ported from `Pick1HomeV4.swift`.
 *
 * The previous Android home was a port of `Pick1HomeHiFi`, which iOS replaced:
 * a hero with a sport dropdown, and free/pro proof stacks below it. This is
 * the shape iOS actually ships now — an orb rail across all ten sports, one
 * hero, and game cards whose subject is the money rather than the verdict.
 *
 * Deliberate difference: the orbs carry the sport emoji rather than iOS's SF
 * Symbol vocabulary, because Android has no equivalent glyph set for cricket,
 * F1 or golf. The per-sport glow colour and the selected-state ring are the
 * same, so the rail reads the same at a glance.
 */

// MARK: - v4 palette

object V4 {
    val ink = Color(0xFF07080A)
    val lift = Color(0xFF181C23)
    val panelTop = Color(0xFF1B1F27)
    val panelBot = Color(0xFF0B0D11)
    val rowTop = Color(0xFF14171D)
    val line = Color.White.copy(alpha = 0.09f)
    val mute = Color(0xFF63666D)
    val ink2 = Color(0xFFB9B7B0)
    val gold = Color(0xFFFFD84D)
    val win = Color(0xFF4ADE80)

    /** Per-sport glow, used on the orb mark and the card bloom. */
    fun glow(sport: String): Color = when (sport) {
        "basketball" -> Color(0xFF3EC96F)
        "soccer" -> Color(0xFFC9FF43)
        "hockey" -> Color(0xFF4F8DFF)
        "tennis" -> Color(0xFFB98CFF)
        "football" -> Color(0xFFE2543E)
        "baseball" -> Color(0xFFFF6FA0)
        "combat" -> Color(0xFFFF9F43)
        "f1" -> Color(0xFF8FA3BF)
        "golf" -> Color(0xFF48E0A0)
        "cricket" -> Color(0xFF22C9B7)
        else -> P1.Lime
    }

    /** The three factor-bar gradients, in order. */
    val barGradients: List<List<Color>> = listOf(
        listOf(Color(0xFFFF7A3C), Color(0xFFFFD84D)),
        listOf(Color(0xFF8B5CF6), Color(0xFFC4A8FF)),
        listOf(Color(0xFF3AA5FF), Color(0xFF7EE7FF)),
    )
}

/**
 * The ten sports, always all of them, in iOS order.
 *
 * This is the product's coverage claim, so the rail shows every one whether
 * or not today's board happens to carry it. A sport with nothing on it reads
 * quiet rather than disappearing, which is what made the old rail look like
 * the app had lost half its sports on a light day.
 */
val P1_SPORTS: List<String> = listOf(
    "basketball", "football", "soccer", "hockey", "baseball",
    "combat", "f1", "tennis", "cricket", "golf",
)

/**
 * The sentinel for "no sport filter".
 *
 * MUST match what the ViewModel's filter compares against. It was "__all__"
 * here and "all" there, so tapping the ALL orb set a value no pick could ever
 * carry and emptied the whole board. It only looked fine on launch because
 * the ViewModel's own default was already "all".
 */
const val ALL_SPORTS = "all"

/** Display names, Ethan's: "Fight" not MMA, "Race" not Racing or F1. */
fun v4Name(sport: String): String = when (sport) {
    ALL_SPORTS -> "All"
    "basketball" -> "Basketball"
    "baseball" -> "Baseball"
    "hockey" -> "Hockey"
    "football" -> "Football"
    "soccer" -> "Soccer"
    "combat" -> "Fight"
    "f1" -> "Race"
    "golf" -> "Golf"
    "cricket" -> "Cricket"
    "tennis" -> "Tennis"
    else -> sport.replaceFirstChar { it.uppercase() }
}

// MARK: - Top bar

@androidx.compose.runtime.Composable
fun P1V4TopBar(onProfile: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(start = 18.dp, end = 22.dp, top = 8.dp),
    ) {
        Pick1Wordmark(size = 28)
        Spacer(Modifier.weight(1f))
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(
                    Brush.linearGradient(listOf(V4.panelTop, V4.panelBot)),
                )
                .border(1.dp, V4.line, CircleShape)
                .clickable(onClick = onProfile),
        ) {
            Text("👤", style = archivo(13, FontWeight.Bold), color = V4.ink2)
        }
    }
}

/** The canonical wordmark, hard against the leading edge. */
@androidx.compose.runtime.Composable
fun Pick1Wordmark(size: Int) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("PICK", style = anton(size), color = P1.Foreground)
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .padding(start = 3.dp)
                .size((size * 1.05f).dp)
                .clip(RoundedCornerShape((size * 0.28f).dp))
                .background(P1.Lime),
        ) {
            Text("1", style = anton((size * 0.82f).roundToInt()), color = P1.LimeInk)
        }
    }
}

// MARK: - Segment

enum class P1V4Tab(val title: String) {
    TONIGHT("Tonight"), LIVE("Live"), YOURS("Your Picks"), RESULTS("Results")
}

@androidx.compose.runtime.Composable
fun P1V4Segment(selection: P1V4Tab, onSelect: (P1V4Tab) -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
    ) {
        P1V4Tab.entries.forEach { tab ->
            val on = tab == selection
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.clickable { onSelect(tab) },
            ) {
                if (on) {
                    Box(Modifier.size(5.dp).clip(CircleShape).background(P1.Lime))
                }
                Text(
                    tab.title.uppercase(),
                    style = archivoNarrow(12, FontWeight.Bold, tracking = 0.96f),
                    color = if (on) P1.Foreground else V4.mute,
                    maxLines = 1,
                )
            }
        }
    }
}

// MARK: - Orb selector

@androidx.compose.runtime.Composable
fun P1V4Orb(
    sport: String,
    isOn: Boolean,
    hasPicks: Boolean,
    onClick: () -> Unit,
) {
    val scale by animateFloatAsState(if (isOn) 1.12f else 1f, spring(), label = "orb")
    val tint = if (sport == ALL_SPORTS) P1.Lime else V4.glow(sport)

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.width(62.dp).clickable(onClick = onClick),
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(56.dp)
                .scale(scale)
                .clip(CircleShape)
                .background(Brush.linearGradient(listOf(V4.panelTop, V4.panelBot)))
                .border(1.5.dp, if (isOn) P1.Lime else V4.line, CircleShape)
                .alpha(if (hasPicks) 1f else 0.45f),
        ) {
            // A tinted vector, not an emoji. iOS moved to a symbol
            // vocabulary on Aug 31 and Material Icons Extended, already a
            // dependency here, carries a mark for all ten sports.
            com.pick1.app.ui.components.P1SportMark(
                sport = sport,
                size = 23,
                active = isOn,
            )
        }
        Text(
            v4Name(sport).uppercase(),
            style = archivoNarrow(8, FontWeight.Bold, tracking = 0.85f),
            color = if (isOn) P1.Lime else V4.mute,
            maxLines = 1,
            modifier = Modifier.padding(top = 6.dp).alpha(if (hasPicks) 1f else 0.5f),
        )
        Box(
            Modifier
                .padding(top = 4.dp)
                .size(5.dp)
                .clip(CircleShape)
                .background(if (isOn) P1.Lime else Color.Transparent),
        )
    }
}

// MARK: - Factor bar

@androidx.compose.runtime.Composable
fun P1V4FactorRow(label: String, note: String, value: Int, colors: List<Color>) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
    ) {
        Column(Modifier.weight(1f)) {
            Text(label, style = archivo(13, FontWeight.Bold), color = P1.Foreground, maxLines = 1)
            Text(note, style = mono(10, FontWeight.Medium), color = V4.mute, maxLines = 1)
        }
        Box(
            Modifier
                .width(96.dp)
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(Color.White.copy(alpha = 0.08f)),
        ) {
            Box(
                Modifier
                    .fillMaxWidth((value.coerceIn(0, 100)) / 100f)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(3.dp))
                    .background(Brush.horizontalGradient(colors)),
            )
        }
        Text(
            "$value%",
            style = anton(13),
            color = P1.Foreground,
            modifier = Modifier.padding(start = 10.dp).width(38.dp),
        )
    }
}

// MARK: - Hero pick

@androidx.compose.runtime.Composable
fun P1V4Hero(pick: Pick, onTap: () -> Unit) {
    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 22.dp)
            .padding(top = 26.dp)
            .clip(RoundedCornerShape(26.dp))
            .background(Brush.linearGradient(listOf(V4.panelTop, V4.panelBot)))
            .border(1.dp, P1.Lime.copy(alpha = 0.35f), RoundedCornerShape(26.dp))
            .clickable(onClick = onTap),
    ) {
        Column(Modifier.padding(20.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Text("⚡", style = archivo(9, FontWeight.Black), color = P1.Lime)
                Text(
                    "TODAY'S #1 PICK",
                    style = archivoNarrow(10, FontWeight.Bold, tracking = 2.0f),
                    color = P1.Lime,
                )
            }
            Text(
                pick.pick.uppercase(),
                style = anton(26),
                color = P1.Foreground,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 8.dp).fillMaxWidth(0.66f),
            )

            val factors = pick.factors.orEmpty()
            if (factors.isNotEmpty()) {
                Text(
                    "WHY THE AI LIKES IT",
                    style = archivoNarrow(11, FontWeight.Bold, tracking = 1.54f),
                    color = V4.ink2,
                    modifier = Modifier.padding(top = 20.dp),
                )
                factors.take(3).forEachIndexed { i, f ->
                    P1V4FactorRow(
                        label = f.label,
                        note = f.value,
                        value = f.strength,
                        colors = V4.barGradients[i % V4.barGradients.size],
                    )
                }
            }
        }

        // Confidence sits outside the padded content, top-right.
        Column(
            horizontalAlignment = Alignment.End,
            modifier = Modifier.align(Alignment.TopEnd).padding(top = 16.dp, end = 18.dp),
        ) {
            Text(
                buildAnnotatedString {
                    withStyle(SpanStyle(fontSize = 44.sp)) {
                        append(pick.probability.roundToInt().toString())
                    }
                    withStyle(SpanStyle(fontSize = 17.sp)) { append("%") }
                },
                style = anton(44),
                color = P1.Lime,
            )
            Text(
                "AI CONFIDENCE",
                style = archivoNarrow(8, FontWeight.Bold, tracking = 1.28f),
                color = V4.mute,
            )
        }
    }
}

// MARK: - Game row

/**
 * A game card, not a list row. The compact row buried the two things that
 * make someone act: who the model backs, and what the pick returns. Both get
 * their own band, and the payout is money rather than a bare multiple.
 */
@androidx.compose.runtime.Composable
fun P1V4GameRow(
    pick: Pick,
    isLocked: Boolean = false,
    isBiggestWin: Boolean = false,
    onTap: () -> Unit,
    onTrack: () -> Unit,
) {
    /** The reference stake the return is quoted against, same as the detail. */
    val referenceStake = 100.0
    val isFieldEvent = pick.sport == "f1" || pick.sport == "golf"
    val calledIsHome = pick.pick.equals(pick.homeTeam, ignoreCase = true)
    val called = if (isFieldEvent) pick.pick else if (calledIsHome) pick.homeTeam else pick.awayTeam
    val other = if (isFieldEvent) {
        if (pick.homeTeam.equals("field", true)) pick.awayTeam else pick.homeTeam
    } else if (calledIsHome) pick.awayTeam else pick.homeTeam
    val returns = (referenceStake * pick.decimalOdds).roundToInt()
    val blur = if (isLocked) 8.dp else 0.dp

    val oddsNote = if (pick.oddsSource != null && pick.marketOdds != null) {
        String.format("%.2f× · %s", pick.decimalOdds, pick.oddsSource!!.uppercase())
    } else {
        String.format("%.2f× · IMPLIED", pick.decimalOdds)
    }
    val time = pick.startTime?.let { " · $it" } ?: ""
    val metaLine = when {
        isLocked -> "${pick.league.uppercase()}$time · PREMIUM"
        isFieldEvent -> "TO WIN · ${other.uppercase()}$time"
        else -> "vs ${Sport.short(other)} · ${pick.league.uppercase()}$time"
    }

    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(
                Brush.linearGradient(
                    if (isBiggestWin) listOf(V4.gold.copy(alpha = 0.10f), V4.panelBot)
                    else listOf(V4.rowTop, V4.panelBot),
                ),
            )
            .border(
                1.dp,
                if (isBiggestWin) V4.gold.copy(alpha = 0.5f) else V4.line,
                RoundedCornerShape(22.dp),
            )
            .clickable { if (isLocked) onTrack() else onTap() },
    ) {
        Column(Modifier.padding(horizontal = 16.dp, vertical = 15.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                // Crests. No second portrait on a field event: there is no
                // opponent, and a placeholder shield invents one.
                Box(
                    Modifier
                        .width(if (isFieldEvent) 43.dp else 63.dp)
                        .height(42.dp)
                        .blur(if (isLocked) 6.dp else 0.dp),
                ) {
                    if (!isFieldEvent) {
                        Box(Modifier.offset(x = 23.dp).align(Alignment.CenterStart)) {
                            TeamLogo(pick.sport, other, pick.awayLogo, size = 35)
                        }
                    }
                    Box(Modifier.align(Alignment.CenterStart)) {
                        TeamLogo(pick.sport, called, pick.homeLogo, size = 40)
                    }
                }

                Column(Modifier.weight(1f).padding(start = 13.dp)) {
                    Text(
                        Sport.short(called).uppercase(),
                        style = anton(21),
                        color = P1.Foreground,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.blur(blur),
                    )
                    Text(
                        metaLine,
                        style = mono(9, FontWeight.Bold, tracking = 0.54f),
                        color = V4.mute,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }

                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        buildAnnotatedString {
                            withStyle(SpanStyle(fontSize = 26.sp)) {
                                append(pick.probability.roundToInt().toString())
                            }
                            withStyle(SpanStyle(fontSize = 12.sp)) { append("%") }
                        },
                        style = anton(26),
                        color = V4.win,
                        modifier = Modifier.blur(blur),
                    )
                    Text(
                        "WIN PROB",
                        style = archivoNarrow(7, FontWeight.Bold, tracking = 1.05f),
                        color = V4.mute,
                    )
                }
            }

            Box(Modifier.fillMaxWidth().height(1.dp).padding(top = 13.dp).background(V4.line))

            // Money left, action right.
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            ) {
                Column(Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text("$100", style = anton(17), color = V4.mute)
                        Text(
                            "  →  ",
                            style = anton(15),
                            color = V4.mute,
                        )
                        Text(
                            "$$returns",
                            style = anton(33),
                            color = P1.Lime,
                            maxLines = 1,
                            modifier = Modifier.blur(blur),
                        )
                    }
                    Text(
                        oddsNote,
                        style = mono(8, FontWeight.Bold),
                        color = V4.mute,
                        maxLines = 1,
                        modifier = Modifier.blur(blur),
                    )
                }

                Spacer(Modifier.width(12.dp))

                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(P1.Lime)
                        .clickable { if (isLocked) onTrack() else onTrack() }
                        .padding(horizontal = if (isLocked) 16.dp else 18.dp, vertical = 12.dp),
                ) {
                    Text(
                        if (isLocked) "🔒 UNLOCK" else "TRACK THIS",
                        style = archivoNarrow(11, FontWeight.Bold, tracking = 1.1f),
                        color = V4.ink,
                        maxLines = 1,
                    )
                }
            }
        }

        if (isBiggestWin && !isLocked) {
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = (-14).dp, y = (-2).dp)
                    .clip(RoundedCornerShape(50))
                    .background(V4.gold)
                    .padding(horizontal = 10.dp, vertical = 4.dp),
            ) {
                Text(
                    "BIGGEST WIN",
                    style = archivoNarrow(9, FontWeight.Bold, tracking = 1.4f),
                    color = V4.ink,
                )
            }
        }
    }
}

// MARK: - Pay bar

@androidx.compose.runtime.Composable
fun P1V4PayBar(perDay: String, sports: Int, onTap: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 22.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(Brush.linearGradient(listOf(P1.Lime, Color(0xFF9FDC16))))
            .clickable(onClick = onTap)
            .padding(horizontal = 18.dp, vertical = 15.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "GO PREMIUM · $perDay/DAY",
                style = anton(16, tracking = 0.32f),
                color = V4.ink,
                maxLines = 1,
                modifier = Modifier.weight(1f),
            )
            Text("→", style = anton(16), color = V4.ink)
        }
        Text(
            "$sports SPORTS · ALL MARKETS · PUBLIC LEDGER",
            style = archivoNarrow(9, FontWeight.Bold, tracking = 0.36f),
            color = V4.ink.copy(alpha = 0.65f),
            maxLines = 1,
        )
    }
}

// MARK: - Orb rail

@androidx.compose.runtime.Composable
fun P1V4OrbRail(
    sports: List<String>,
    active: String,
    hasPicks: (String) -> Boolean,
    onSelect: (String) -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            // Headroom for the selected orb's halo, as on iOS: the rail clips
            // to its own bounds, so a glow with nowhere to go gets sliced off
            // flat along the top edge.
            .padding(start = 22.dp, end = 8.dp, top = 24.dp, bottom = 12.dp),
    ) {
        sports.forEach { s ->
            P1V4Orb(
                sport = s,
                isOn = s == active,
                hasPicks = hasPicks(s),
                onClick = { onSelect(s) },
            )
        }
    }
}
