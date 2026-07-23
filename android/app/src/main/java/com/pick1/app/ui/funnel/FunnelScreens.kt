package com.pick1.app.ui.funnel

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.ui.components.FnlHeadline
import com.pick1.app.ui.theme.*
import kotlinx.coroutines.delay

// ── Welcome ──────────────────────────────────────────────────────────

@Composable
fun WelcomeScreen(onNext: () -> Unit, onSignIn: () -> Unit) {
    FnlScreen(
        topInset = 40,
        bottom = {
            FnlCTA(stringResource(R.string.funnel_welcome_cta)) { onNext() }
            Spacer(Modifier.height(14.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                Text(
                    stringResource(R.string.funnel_welcome_member),
                    style = archivo(13),
                    color = P1.Mute,
                )
                Text(
                    stringResource(R.string.funnel_welcome_signin),
                    style = archivo(13, FontWeight.Bold),
                    color = P1.LimeFunnel,
                    modifier = Modifier.clickable { onSignIn() },
                )
            }
        },
    ) {
        FnlLockup()
        Spacer(Modifier.weight(1f))
        FnlHeadline(stringResource(R.string.funnel_welcome_headline), size = 54)
        Spacer(Modifier.height(16.dp))
        FnlLead(stringResource(R.string.funnel_welcome_lead))
        Spacer(Modifier.weight(1f))
    }
}

// ── Features ─────────────────────────────────────────────────────────

@Composable
fun FeaturesScreen(onNext: () -> Unit) {
    val feats = listOf(
        R.string.funnel_feat1_title to R.string.funnel_feat1_body,
        R.string.funnel_feat2_title to R.string.funnel_feat2_body,
        R.string.funnel_feat3_title to R.string.funnel_feat3_body,
        R.string.funnel_feat4_title to R.string.funnel_feat4_body,
    )
    FnlScreen(bottom = { FnlCTA(stringResource(R.string.funnel_continue_cta)) { onNext() } }) {
        FnlKick(stringResource(R.string.funnel_feat_kicker))
        Spacer(Modifier.height(14.dp))
        FnlHeadline(stringResource(R.string.funnel_feat_headline), size = 42)
        Spacer(Modifier.height(24.dp))
        Column(
            Modifier.verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            feats.forEach { (t, b) ->
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(stringResource(t), style = anton(20), color = P1.Foreground)
                    Text(stringResource(b), style = archivo(14), color = P1.Ink2)
                }
            }
        }
    }
}

// ── Quiz (5 screens) ─────────────────────────────────────────────────

private data class QuizQ(val q: Int, val opts: List<Pair<String, Int>>)

private val quizQuestions = listOf(
    QuizQ(
        R.string.funnel_quiz1_q,
        listOf("📅" to R.string.funnel_quiz1_opt1, "🗓️" to R.string.funnel_quiz1_opt2,
               "🎲" to R.string.funnel_quiz1_opt3, "🆕" to R.string.funnel_quiz1_opt4),
    ),
    QuizQ(
        R.string.funnel_quiz2_q,
        listOf("🧠" to R.string.funnel_quiz2_opt1, "📰" to R.string.funnel_quiz2_opt2,
               "📊" to R.string.funnel_quiz2_opt3, "🤷" to R.string.funnel_quiz2_opt4),
    ),
    QuizQ(
        R.string.funnel_quiz3_q,
        listOf("📉" to R.string.funnel_quiz3_opt1, "➖" to R.string.funnel_quiz3_opt2,
               "📈" to R.string.funnel_quiz3_opt3, "🤔" to R.string.funnel_quiz3_opt4),
    ),
    QuizQ(
        R.string.funnel_quiz4_q,
        listOf("😤" to R.string.funnel_quiz4_opt1, "🎰" to R.string.funnel_quiz4_opt2,
               "🕳️" to R.string.funnel_quiz4_opt3, "⏱️" to R.string.funnel_quiz4_opt4),
    ),
    QuizQ(
        R.string.funnel_quiz5_q,
        listOf("💵" to R.string.funnel_quiz5_opt1, "💰" to R.string.funnel_quiz5_opt2,
               "💸" to R.string.funnel_quiz5_opt3, "🏦" to R.string.funnel_quiz5_opt4),
    ),
)

@Composable
fun QuizScreen(index: Int, selected: Int?, onPick: (Int) -> Unit) {
    val q = quizQuestions[index]
    FnlScreen {
        Text(
            stringResource(R.string.funnel_quiz_progress, index + 1),
            style = mono(13, FontWeight.Bold, tracking = 1.9f),
            color = P1.LimeFunnel,
        )
        Spacer(Modifier.height(10.dp))
        Text(
            stringResource(q.q).uppercase(),
            style = anton(34),
            color = P1.Foreground,
        )
        Spacer(Modifier.height(26.dp))
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            q.opts.forEachIndexed { i, (emoji, label) ->
                val active = selected == i
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(if (active) P1.LimeFunnel.copy(alpha = 0.10f) else P1.Panel)
                        .border(
                            if (active) 2.dp else 1.dp,
                            if (active) P1.LimeFunnel else P1.Line,
                            RoundedCornerShape(16.dp),
                        )
                        .clickable { onPick(i) }
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Text(emoji, style = archivo(24))
                    Text(stringResource(label), style = archivo(16, FontWeight.Bold), color = P1.Foreground)
                }
            }
        }
    }
}

// ── Analysis (animated build) ────────────────────────────────────────

@Composable
fun AnalysisScreen(onDone: () -> Unit) {
    val rows = listOf(
        R.string.funnel_analysis_row1, R.string.funnel_analysis_row2,
        R.string.funnel_analysis_row3, R.string.funnel_analysis_row4,
    )
    var shown by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        rows.indices.forEach { _ -> delay(700); shown++ }
        delay(500)
        onDone()
    }
    FnlScreen {
        FnlKick(stringResource(R.string.funnel_analysis_kicker))
        Spacer(Modifier.height(28.dp))
        Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
            rows.forEachIndexed { i, r ->
                val done = i < shown
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(
                        Modifier
                            .size(22.dp)
                            .clip(CircleShape)
                            .background(if (done) P1.LimeFunnel else P1.Panel2),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (done) Icon(Icons.Default.Check, null, tint = P1.Ink, modifier = Modifier.size(13.dp))
                    }
                    Text(
                        stringResource(r),
                        style = archivo(15, FontWeight.Medium),
                        color = if (done) P1.Foreground else P1.Mute,
                    )
                }
            }
        }
    }
}

// ── Red "hard truth" screens (4) ─────────────────────────────────────

private data class RedData(val head: Int, val stat: String, val unit: String, val lead: Int, val cta: Int)

private val redScreens = listOf(
    RedData(R.string.funnel_red1_headline, "55", "%", R.string.funnel_red1_lead, R.string.funnel_red1_cta),
    RedData(R.string.funnel_red2_headline, "-32", "%", R.string.funnel_red2_lead, R.string.funnel_red2_cta),
    RedData(R.string.funnel_red3_headline, "0", "", R.string.funnel_red3_lead, R.string.funnel_red3_cta),
    RedData(R.string.funnel_red4_headline, "-5", "", R.string.funnel_red4_lead, R.string.funnel_red4_cta),
)

@Composable
fun RedScreen(index: Int, onNext: () -> Unit) {
    val d = redScreens[index]
    FnlScreen(
        glow = Tone.RED,
        bottom = { FnlCTA(stringResource(d.cta)) { onNext() } },
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            repeat(4) { i ->
                Box(
                    Modifier
                        .width(22.dp)
                        .height(4.dp)
                        .clip(CircleShape)
                        .background(if (i <= index) P1.Hot else P1.Line),
                )
            }
        }
        Spacer(Modifier.height(14.dp))
        FnlKick(stringResource(R.string.funnel_red_kicker, index + 1), tone = Tone.RED)
        Spacer(Modifier.height(14.dp))
        FnlHeadline(stringResource(d.head), accent = P1.Hot, size = 40)
        Spacer(Modifier.height(20.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text(d.stat, style = anton(64), color = P1.Hot)
            Text(d.unit, style = anton(28), color = P1.Hot)
        }
        Spacer(Modifier.height(16.dp))
        FnlLead(stringResource(d.lead))
    }
}

// ── Green "the fix" screens (3) ──────────────────────────────────────

private data class GreenData(val kick: Int, val head: Int, val lead: Int, val cta: Int)

private val greenScreens = listOf(
    GreenData(R.string.funnel_green1_kicker, R.string.funnel_green1_headline, R.string.funnel_green1_lead, R.string.funnel_green1_cta),
    GreenData(R.string.funnel_green2_kicker, R.string.funnel_green2_headline, R.string.funnel_green2_lead, R.string.funnel_green2_cta),
    GreenData(R.string.funnel_green3_kicker, R.string.funnel_green3_headline, R.string.funnel_green3_lead, R.string.funnel_green3_cta),
)

@Composable
fun GreenScreen(index: Int, onNext: () -> Unit) {
    val d = greenScreens[index]
    FnlScreen(
        glow = Tone.WIN,
        bottom = { FnlCTA(stringResource(d.cta)) { onNext() } },
    ) {
        FnlKick(stringResource(d.kick), tone = Tone.WIN)
        Spacer(Modifier.height(14.dp))
        FnlHeadline(stringResource(d.head), accent = P1.Win, size = 40)
        Spacer(Modifier.height(18.dp))
        FnlLead(stringResource(d.lead))
    }
}

// ── Goals ────────────────────────────────────────────────────────────

@Composable
fun GoalsScreen(selected: Int?, onPick: (Int) -> Unit) {
    val goals = listOf(
        R.string.funnel_goal1, R.string.funnel_goal2,
        R.string.funnel_goal3, R.string.funnel_goal4,
    )
    FnlScreen {
        FnlKick(stringResource(R.string.funnel_goals_kicker))
        Spacer(Modifier.height(14.dp))
        FnlHeadline(stringResource(R.string.funnel_goals_headline), size = 40)
        Spacer(Modifier.height(12.dp))
        FnlLead(stringResource(R.string.funnel_goals_lead))
        Spacer(Modifier.height(24.dp))
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            goals.forEachIndexed { i, g ->
                val active = selected == i
                Text(
                    stringResource(g),
                    style = archivo(16, FontWeight.Bold),
                    color = P1.Foreground,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(if (active) P1.LimeFunnel.copy(alpha = 0.10f) else P1.Panel)
                        .border(
                            if (active) 2.dp else 1.dp,
                            if (active) P1.LimeFunnel else P1.Line,
                            RoundedCornerShape(16.dp),
                        )
                        .clickable { onPick(i) }
                        .padding(16.dp),
                )
            }
        }
    }
}

// ── Notifications ────────────────────────────────────────────────────

@Composable
fun NotificationsScreen(onEnable: () -> Unit, onSkip: () -> Unit) {
    val perks = listOf(
        R.string.funnel_notif_perk1, R.string.funnel_notif_perk2, R.string.funnel_notif_perk3,
    )
    FnlScreen(
        bottom = {
            FnlCTA(stringResource(R.string.funnel_notif_cta)) { onEnable() }
            Spacer(Modifier.height(10.dp))
            FnlCTA(stringResource(R.string.funnel_notif_skip), style = CtaStyle.GHOST) { onSkip() }
        },
    ) {
        FnlKick(stringResource(R.string.funnel_notif_kicker))
        Spacer(Modifier.height(14.dp))
        FnlHeadline(stringResource(R.string.funnel_notif_headline), size = 40)
        Spacer(Modifier.height(12.dp))
        FnlLead(stringResource(R.string.funnel_notif_lead))
        Spacer(Modifier.height(24.dp))
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            perks.forEach {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(
                        Modifier.size(20.dp).clip(CircleShape).background(P1.LimeFunnel),
                        contentAlignment = Alignment.Center,
                    ) { Icon(Icons.Default.Check, null, tint = P1.Ink, modifier = Modifier.size(12.dp)) }
                    Text(stringResource(it), style = archivo(14, FontWeight.Medium), color = P1.Foreground)
                }
            }
        }
    }
}

// ── Success ──────────────────────────────────────────────────────────

@Composable
fun SuccessScreen(onDone: () -> Unit) {
    FnlScreen(
        glow = Tone.WIN,
        bottom = { FnlCTA(stringResource(R.string.funnel_success_cta)) { onDone() } },
    ) {
        Spacer(Modifier.weight(1f))
        Box(
            Modifier.size(72.dp).clip(CircleShape).background(P1.Win),
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.Default.Check, null, tint = P1.Ink, modifier = Modifier.size(38.dp)) }
        Spacer(Modifier.height(24.dp))
        FnlHeadline(stringResource(R.string.funnel_success_headline), accent = P1.Win, size = 44)
        Spacer(Modifier.height(14.dp))
        FnlLead(stringResource(R.string.funnel_success_body_free))
        Spacer(Modifier.weight(1f))
    }
}

/** Simple placeholder for steps whose content is a plain kicker+headline+lead. */
@Composable
fun SimpleFunnelScreen(kick: Int, head: Int, lead: Int?, cta: Int, onNext: () -> Unit) {
    FnlScreen(bottom = { FnlCTA(stringResource(cta)) { onNext() } }) {
        FnlKick(stringResource(kick))
        Spacer(Modifier.height(14.dp))
        FnlHeadline(stringResource(head), size = 40)
        lead?.let {
            Spacer(Modifier.height(14.dp))
            FnlLead(stringResource(it))
        }
    }
}
