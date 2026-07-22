package com.pick1.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.pick1.app.data.PicksRepository
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.theme.*
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            Pick1Theme { BoardScreen() }
        }
    }
}

/**
 * Temporary smoke-test screen: proves the Compose theme, the ported fonts,
 * and the live Supabase connection all work end to end. This gets replaced
 * by the real home screen (a port of Pick1HomeHiFi) as screens land.
 */
class BoardViewModel : ViewModel() {
    private val repo = PicksRepository()
    var picks by mutableStateOf<List<Pick>>(emptyList())
        private set
    var loading by mutableStateOf(true)
        private set
    var error by mutableStateOf<String?>(null)
        private set

    init {
        viewModelScope.launch {
            runCatching { repo.latestWins(limit = 20) }
                .onSuccess { picks = it }
                .onFailure { error = it.message }
            loading = false
        }
    }
}

@Composable
fun BoardScreen(vm: BoardViewModel = viewModel()) {
    Column(
        Modifier
            .fillMaxSize()
            .background(P1.Ink)
            .safeDrawingPadding()
            .padding(horizontal = 20.dp),
    ) {
        Spacer(Modifier.height(16.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text("PICK", style = anton(34, tracking = -0.34f), color = P1.Foreground)
            Text("1", style = anton(34, tracking = -0.34f), color = P1.Lime)
        }
        Text(
            stringResourceSafe(R.string.rd_picks_stats_glory),
            style = archivoNarrow(10, FontWeight.Bold, tracking = 2.2f),
            color = P1.Mute,
        )
        Spacer(Modifier.height(20.dp))

        when {
            vm.loading -> Box(Modifier.fillMaxSize(), Alignment.Center) {
                CircularProgressIndicator(color = P1.Lime)
            }
            vm.error != null -> Text(
                vm.error!!,
                style = archivo(13),
                color = P1.Loss,
            )
            else -> LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(vm.picks) { PickRow(it) }
            }
        }
    }
}

@Composable
private fun PickRow(p: Pick) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(P1.Panel)
            .padding(16.dp),
    ) {
        Text(
            "${p.league} · ${p.gameDate}",
            style = archivoNarrow(9, FontWeight.Bold, tracking = 1.6f),
            color = P1.Mute,
        )
        Spacer(Modifier.height(6.dp))
        Text(p.pick, style = anton(20), color = P1.Foreground)
        Spacer(Modifier.height(4.dp))
        Text(
            "${p.probability.toInt()}%",
            style = mono(11, FontWeight.Bold),
            color = if (p.isWin) P1.WinLime else P1.Ink2,
        )
    }
}

/** Small helper so previews don't crash when a resource is missing. */
@Composable
private fun stringResourceSafe(id: Int): String =
    runCatching { androidx.compose.ui.res.stringResource(id) }.getOrDefault("")
