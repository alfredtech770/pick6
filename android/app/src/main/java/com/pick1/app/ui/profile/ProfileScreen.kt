package com.pick1.app.ui.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.pick1.app.R
import com.pick1.app.data.*
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.calibration.CalibrationCard
import com.pick1.app.ui.theme.*
import com.pick1.app.ui.tracker.MyBetsCard
import kotlinx.coroutines.launch

/**
 * Profile — currently hosts the two "receipts" surfaces: the user's own
 * bet ledger (MyBetsCard) and the public calibration proof.
 * Settings rows land with the settings port.
 */
class ProfileViewModel : ViewModel() {
    private val bets = BetRepository()
    private val cal = CalibrationRepository()
    private val picksRepo = PicksRepository()

    var summary by mutableStateOf(BetSummary()); private set
    var bands by mutableStateOf<List<CalibrationBand>>(emptyList()); private set
    var avgGap by mutableStateOf<String?>(null); private set

    init {
        viewModelScope.launch {
            val picks: List<Pick> = runCatching { picksRepo.latestWins(limit = 60) }.getOrDefault(emptyList())
            val myBets = bets.load()
            summary = bets.summary(myBets.values, picks)

            val b = cal.bands()
            bands = b
            avgGap = cal.avgGapText(b)
        }
    }
}

@Composable
fun ProfileScreen(vm: ProfileViewModel = viewModel()) {
    Column(
        Modifier
            .fillMaxSize()
            .background(P1.Ink)
            .safeDrawingPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Spacer(Modifier.height(12.dp))
        Text(
            stringResource(R.string.nav_profile).uppercase(),
            style = anton(28),
            color = P1.Foreground,
        )
        MyBetsCard(vm.summary)
        CalibrationCard(bands = vm.bands, avgGap = vm.avgGap)
        Spacer(Modifier.height(32.dp))
    }
}
