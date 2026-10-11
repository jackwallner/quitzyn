package com.jackwallner.quitzyn.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.quitzyn.DebugLaunchOptions
import androidx.compose.ui.platform.LocalContext
import com.jackwallner.quitzyn.data.BloomFeature
import com.jackwallner.quitzyn.data.ConversionEvent
import com.jackwallner.quitzyn.data.PurchaseException
import com.jackwallner.quitzyn.data.PurchaseOutcome
import com.jackwallner.quitzyn.data.SubscriptionService
import com.jackwallner.quitzyn.ui.findActivity
import kotlinx.coroutines.launch
import com.jackwallner.quitzyn.data.NotificationService
import com.jackwallner.quitzyn.data.PitchPolicy
import com.jackwallner.quitzyn.data.PitchRequest
import com.jackwallner.quitzyn.data.TrialSubsequentPitchGate
import com.jackwallner.quitzyn.ui.LocalGraph
import com.jackwallner.quitzyn.ui.theme.Hairline
import com.jackwallner.quitzyn.ui.theme.SheetHeight
import com.jackwallner.quitzyn.ui.theme.SoberColors
import com.jackwallner.quitzyn.ui.theme.SoberSheet
import com.jackwallner.quitzyn.ui.theme.SoberType
import com.jackwallner.quitzyn.ui.theme.SymbolIcon
import com.jackwallner.quitzyn.ui.theme.pressable
import com.jackwallner.quitzyn.ui.theme.testTagCompat

private data class TabItem(val title: String, val icon: String, val tag: String)

/**
 * `MainTabView`: Home, Timeline, Health, Journal, and the Bloom+ tab. Owns
 * the pitch paywall, resolving every `TrialOfferCoordinator` request here so
 * two pitches can never stack.
 */
@Composable
fun MainTabs(deepLink: String?, onDeepLinkConsumed: () -> Unit) {
    val graph = LocalGraph.current
    val subscriptions = graph.subscriptions
    val coordinator = graph.coordinator
    var tab by rememberSaveable { mutableIntStateOf(DebugLaunchOptions.launchTab ?: 0) }
    var showTrialOffer by rememberSaveable { mutableStateOf(false) }
    var showPaywall by rememberSaveable { mutableStateOf(false) }
    var paywallFocus by rememberSaveable { mutableStateOf<BloomFeature?>(null) }
    var trialInFlight by remember { mutableStateOf(false) }
    var trialError by remember { mutableStateOf<String?>(null) }
    val holder = rememberSaveableStateHolder()
    val isPro = subscriptions.isPro
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    LaunchedEffect(deepLink) {
        when (deepLink) {
            NotificationService.DEEP_LINK_CHECK_IN -> tab = 0
            NotificationService.DEEP_LINK_BLOOM_PLUS -> tab = 4
            else -> return@LaunchedEffect
        }
        onDeepLinkConsumed()
    }

    LaunchedEffect(tab, isPro) {
        if (tab == 4 && !isPro) subscriptions.trackPaywallImpression("quitzyn_bloom_tab", oncePerSession = true)
    }
    LaunchedEffect(isPro) { if (isPro) showTrialOffer = false }

    fun presentPaywall(focus: BloomFeature?) {
        paywallFocus = focus
        showPaywall = true
    }

    /** The small trial sheet when a trial is on offer, the full paywall otherwise. */
    fun presentTrialOffer(focus: BloomFeature?) {
        if (subscriptions.isPro || !subscriptions.hasTrialOfferAvailable) {
            presentPaywall(focus)
            return
        }
        paywallFocus = focus
        trialError = null
        showTrialOffer = true
    }

    fun closeTrialOffer(thenPaywall: Boolean = false) {
        showTrialOffer = false
        trialInFlight = false
        trialError = null
        if (thenPaywall) showPaywall = true
    }

    fun handle(request: PitchRequest) {
        if (subscriptions.isPro) return
        val focus = request.intent.focusFeature
        when (request.policy) {
            PitchPolicy.INITIAL, PitchPolicy.EXPLICIT_UPGRADE -> presentTrialOffer(focus)
            PitchPolicy.SUBSEQUENT_LOCKED -> {
                val count = graph.pitchGate.recordAction(request.intent)
                if (count >= TrialSubsequentPitchGate.LOCKED_FEATURE_THRESHOLD &&
                    subscriptions.hasTrialOfferAvailable &&
                    graph.pitchGate.canPresentTrialPitch(request.intent)
                ) {
                    graph.pitchGate.markTrialPitchPresented(request.intent)
                    presentTrialOffer(focus)
                } else {
                    presentPaywall(focus)
                }
            }
            PitchPolicy.SUBSEQUENT_PASSIVE -> {
                if (!subscriptions.hasTrialOfferAvailable || !graph.pitchGate.canPresentTrialPitch(request.intent)) {
                    presentPaywall(focus)
                    return
                }
                graph.pitchGate.markTrialPitchPresented(request.intent)
                presentTrialOffer(focus)
            }
        }
    }

    fun startDirectTrial() {
        val plan = subscriptions.directTrialPlan
        val activity = context.findActivity()
        if (plan == null || activity == null) {
            closeTrialOffer(thenPaywall = true)
            return
        }
        trialError = null
        trialInFlight = true
        graph.diagnostics.record(ConversionEvent.TRIAL_CTA_TAPPED)
        scope.launch {
            try {
                when (subscriptions.purchase(activity, plan)) {
                    PurchaseOutcome.PURCHASED -> {
                        graph.diagnostics.record(ConversionEvent.PURCHASE_SUCCEEDED)
                        closeTrialOffer()
                    }
                    PurchaseOutcome.PENDING -> {
                        graph.diagnostics.record(ConversionEvent.PURCHASE_PENDING)
                        trialError = SubscriptionService.PENDING_APPROVAL_MESSAGE
                    }
                    PurchaseOutcome.CANCELLED -> {
                        graph.diagnostics.record(ConversionEvent.PURCHASE_CANCELLED)
                        trialError = "Trial start cancelled. Tap again to continue."
                    }
                }
            } catch (_: PurchaseException) {
                graph.diagnostics.record(ConversionEvent.PURCHASE_FAILED)
                trialError = "Couldn't start your trial. Please try again."
            } finally {
                trialInFlight = false
            }
        }
    }

    LaunchedEffect(coordinator.pendingRequest) {
        val request = coordinator.pendingRequest ?: return@LaunchedEffect
        coordinator.clear()
        handle(request)
    }
    LaunchedEffect(showPaywall, showTrialOffer) { coordinator.isPresentingSheet = showPaywall || showTrialOffer }

    val tabs = listOf(
        TabItem("Home", "leaf.fill", "tab.home"),
        TabItem("Timeline", "calendar", "tab.timeline"),
        TabItem("Health", "heart.fill", "tab.health"),
        TabItem("Journal", "book.fill", "tab.journal"),
        TabItem(if (isPro) "Bloom+" else "Upgrade", if (isPro) "sparkles" else "lock.fill", "tab.bloom"),
    )

    Column(Modifier.fillMaxSize().background(SoberColors.background)) {
        Box(Modifier.weight(1f).fillMaxWidth()) {
            holder.SaveableStateProvider(tab) {
                when (tab) {
                    0 -> HomeScreen()
                    1 -> TimelineScreen()
                    2 -> HealthScreen()
                    3 -> JournalScreen()
                    else -> BloomPlusTab()
                }
            }
        }
        TabBar(tabs, tab) { tab = it }
    }

    SoberSheet(showTrialOffer, onDismiss = { if (!trialInFlight) closeTrialOffer() }, height = SheetHeight.LARGE, dismissible = !trialInFlight) {
        val plan = subscriptions.directTrialPlan
        TrialOfferSheet(
            focus = paywallFocus,
            offerLabel = plan?.introOfferLabel,
            priceLabel = plan?.priceLabel,
            isPurchasing = trialInFlight,
            errorMessage = trialError,
            onStartTrial = ::startDirectTrial,
            onSeeAllPlans = { closeTrialOffer(thenPaywall = true) },
            onDismiss = { closeTrialOffer() },
        )
    }

    SoberSheet(showPaywall, onDismiss = { showPaywall = false }, height = SheetHeight.LARGE) {
        PaywallScreen(
            focus = paywallFocus,
            impressionId = "quitzyn_trial_sheet",
            displayCloseButton = true,
            onClose = { showPaywall = false },
        )
    }
}

@Composable
private fun TabBar(tabs: List<TabItem>, selected: Int, onSelect: (Int) -> Unit) {
    Column(Modifier.fillMaxWidth().background(Color(0xFFFBF8F1))) {
        Hairline()
        Row(
            Modifier.fillMaxWidth().navigationBarsPadding().height(56.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            tabs.forEachIndexed { index, item ->
                val active = index == selected
                val tint = if (active) SoberColors.brandPrimary else Color(0xFF9A958C)
                Column(
                    Modifier.weight(1f)
                        .testTagCompat(item.tag)
                        .semantics {
                            contentDescription = item.title
                            this.selected = active
                        }
                        .pressable(role = Role.Tab) { onSelect(index) }
                        .padding(vertical = 6.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    SymbolIcon(item.icon, tint, 24.dp)
                    Spacer(Modifier.height(2.dp))
                    Text(item.title, style = SoberType.rounded(10.sp, androidx.compose.ui.text.font.FontWeight.Medium), color = tint)
                }
            }
        }
    }
}
