package com.jackwallner.quitzyn.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.quitzyn.DebugLaunchOptions
import com.jackwallner.quitzyn.data.ConversionEvent
import com.jackwallner.quitzyn.data.OnboardingTrialResolution
import com.jackwallner.quitzyn.data.PitchPolicy
import com.jackwallner.quitzyn.data.PurchaseException
import com.jackwallner.quitzyn.data.PurchaseOutcome
import com.jackwallner.quitzyn.data.StoreLinks
import com.jackwallner.quitzyn.data.SubscriptionService
import com.jackwallner.quitzyn.data.TrialSubsequentPitchGate
import com.jackwallner.quitzyn.model.JourneyDays
import com.jackwallner.quitzyn.ui.Format
import com.jackwallner.quitzyn.ui.LocalGraph
import com.jackwallner.quitzyn.ui.findActivity
import com.jackwallner.quitzyn.ui.openUrl
import com.jackwallner.quitzyn.ui.theme.ProgressSpinner
import com.jackwallner.quitzyn.ui.theme.SoberAlert
import com.jackwallner.quitzyn.ui.theme.SoberBrushes
import com.jackwallner.quitzyn.ui.theme.SoberColors
import com.jackwallner.quitzyn.ui.theme.SoberSheet
import com.jackwallner.quitzyn.ui.theme.SoberSlider
import com.jackwallner.quitzyn.ui.theme.SoberType
import com.jackwallner.quitzyn.ui.theme.Space
import com.jackwallner.quitzyn.ui.theme.SymbolIcon
import com.jackwallner.quitzyn.ui.theme.pressable
import com.jackwallner.quitzyn.ui.theme.testTagCompat
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneOffset
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val White88 = Color.White.copy(alpha = 0.88f)

/** Phones shorter than an iPhone SE get the compact hero: smaller glyph and type. */
@Composable
private fun compactHeight(): Boolean = androidx.compose.ui.platform.LocalConfiguration.current.screenHeightDp < 700

/** `OnboardingView`: welcome, start date, spend, the offer, reminder hour, then the pledge. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnboardingScreen() {
    val graph = LocalGraph.current
    val store = graph.store
    val subscriptions = graph.subscriptions
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var step by rememberSaveable { mutableIntStateOf(0) }
    var startDay by rememberSaveable { mutableStateOf(graph.clock.today().toString()) }
    var pouchesPerDay by rememberSaveable { mutableFloatStateOf(8f) }
    var costPerCan by rememberSaveable { mutableDoubleStateOf(6.0) }
    var pouchesPerCan by rememberSaveable { mutableIntStateOf(15) }
    var reminderHour by rememberSaveable { mutableIntStateOf(9) }
    var trialInFlight by remember { mutableStateOf(false) }
    var resolutionInFlight by remember { mutableStateOf(false) }
    var resolutionError by remember { mutableStateOf<String?>(null) }
    var trialError by remember { mutableStateOf<String?>(null) }
    var restoreInFlight by remember { mutableStateOf(false) }
    var showPaywallFallback by remember { mutableStateOf(false) }
    var didShowTrial by rememberSaveable { mutableStateOf(false) }
    var madeCommitment by rememberSaveable { mutableStateOf(false) }
    var offerIncludesTrial by rememberSaveable { mutableStateOf(true) }
    var showSkipConfirm by remember { mutableStateOf(false) }

    // Cost is derived from real purchase units (a can has a fixed pouch count at a
    // fixed price), so the dollars and pouches the user sees can never disagree.
    val derivedCostPerDay = if (pouchesPerCan > 0) pouchesPerDay * costPerCan / pouchesPerCan else 0.0
    val costCents = Math.round(derivedCostPerDay * 100).toInt()

    val startDate = LocalDate.parse(startDay)
    fun startInstant(): Instant =
        minOf(startDate.atTime(LocalTime.now(graph.clock.zone())).atZone(graph.clock.zone()).toInstant(), graph.clock.now())

    fun persistSetup() = store.persistSetup(startInstant(), costCents, pouchesPerDay.toInt(), reminderHour, madeCommitment)

    /** Every exit from the offer step lands here; the pledge completes onboarding. */
    fun finishOfferStep() {
        if (step >= 4) return
        persistSetup()
        step = 4
    }

    /** Flip onboarding complete, then ask for notifications, after the paid decision. */
    fun completeOnboarding(committed: Boolean) {
        madeCommitment = committed
        persistSetup()
        if (store.settings.hasCompletedOnboarding) return
        graph.diagnostics.record(ConversionEvent.ONBOARDING_COMPLETED)
        store.completeOnboarding()
        val hour = reminderHour
        val streak = JourneyDays.since(startInstant(), graph.clock.now(), graph.clock.zone())
        scope.launch {
            graph.notifications.ensureAuthorized()
            graph.notifications.scheduleDailyReminder(hour, committed, streak)
        }
        // Only queue the Home popup when the offer step never ran.
        if (!didShowTrial) graph.defaults.putBoolean(TrialSubsequentPitchGate.POST_ONBOARDING_PAYWALL_KEY, true)
        graph.refreshWidgets()
    }

    LaunchedEffect(Unit) {
        graph.diagnostics.record(ConversionEvent.ONBOARDING_REACHED)
        if (subscriptions.isConfigured && subscriptions.plans.isEmpty()) subscriptions.fetchProducts()
        DebugLaunchOptions.onboardingStep?.let {
            offerIncludesTrial = subscriptions.directTrialPlan != null
            step = it
        }
    }

    // A pending purchase approved after the call returned lands here.
    LaunchedEffect(subscriptions.isPro) {
        if (subscriptions.isPro && step == 3) finishOfferStep()
    }

    fun resolveTrialAndContinue() {
        if (resolutionInFlight) return
        persistSetup()
        resolutionError = null
        resolutionInFlight = true
        scope.launch {
            try {
                if (!subscriptions.isConfigured) {
                    resolutionError = PLANS_UNAVAILABLE
                    return@launch
                }
                var resolution = subscriptions.resolveOnboardingTrial()
                if (resolution == OnboardingTrialResolution.FAILED || resolution == OnboardingTrialResolution.UNAVAILABLE) {
                    delay(1_200)
                    resolution = subscriptions.resolveOnboardingTrial()
                }
                when (resolution) {
                    OnboardingTrialResolution.ELIGIBLE -> {
                        offerIncludesTrial = true
                        step = 3
                    }
                    OnboardingTrialResolution.INELIGIBLE -> {
                        if (subscriptions.isPro || subscriptions.directOfferPlan == null) finishOfferStep()
                        else {
                            offerIncludesTrial = false
                            step = 3
                        }
                    }
                    else -> resolutionError = PLANS_UNAVAILABLE
                }
            } finally {
                resolutionInFlight = false
            }
        }
    }

    fun startOnboardingTrial() {
        // Products failing to load falls back to the full paywall rather than a dead button.
        val plan = subscriptions.directOfferPlan
        if (plan == null) {
            showPaywallFallback = true
            return
        }
        val activity = context.findActivity() ?: return
        graph.diagnostics.record(ConversionEvent.TRIAL_CTA_TAPPED)
        trialError = null
        trialInFlight = true
        scope.launch {
            try {
                when (subscriptions.purchase(activity, plan)) {
                    PurchaseOutcome.PURCHASED -> {
                        graph.diagnostics.record(ConversionEvent.PURCHASE_SUCCEEDED)
                        finishOfferStep()
                    }
                    PurchaseOutcome.PENDING -> {
                        graph.diagnostics.record(ConversionEvent.PURCHASE_PENDING)
                        trialError = SubscriptionService.PENDING_APPROVAL_MESSAGE
                    }
                    PurchaseOutcome.CANCELLED -> graph.diagnostics.record(ConversionEvent.PURCHASE_CANCELLED)
                }
            } catch (_: PurchaseException) {
                graph.diagnostics.record(ConversionEvent.PURCHASE_FAILED)
                trialError = TRIAL_FAILURE
            } finally {
                trialInFlight = false
            }
        }
    }

    fun restore() {
        if (restoreInFlight) return
        restoreInFlight = true
        scope.launch {
            trialError = null
            subscriptions.restorePurchases()
            restoreInFlight = false
            if (subscriptions.isPro) finishOfferStep()
            else trialError = subscriptions.lastError ?: "No active Bloom+ purchase was found for this Google Play account."
        }
    }

    val legal: @Composable () -> Unit = {
        LegalFooter(restoreInFlight, onRestore = ::restore)
    }

    Box(Modifier.fillMaxSize().background(SoberBrushes.brand)) {
        AnimatedContent(step, transitionSpec = { fadeIn(tween(300)) togetherWith fadeOut(tween(300)) }, label = "step") { current ->
            Column(
                Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(horizontal = Space.l, vertical = Space.l),
            ) {
                when (current) {
                    1 -> StartDateStep(startDate, graph.clock.today(), onPick = { startDay = it.toString() }) { step = 2 }
                    2 -> SpendStep(
                        pouchesPerDay = pouchesPerDay,
                        costPerCan = costPerCan,
                        pouchesPerCan = pouchesPerCan,
                        dailyCost = derivedCostPerDay,
                        onPouches = { pouchesPerDay = it },
                        onCostPerCan = { costPerCan = it },
                        onPouchesPerCan = { pouchesPerCan = it },
                        inFlight = resolutionInFlight,
                        error = resolutionError,
                        onContinueFree = {
                            graph.diagnostics.record(ConversionEvent.FREE_VERSION_CHOSEN)
                            finishOfferStep()
                        },
                        onContinue = ::resolveTrialAndContinue,
                    )
                    3 -> TrialStep(
                        subscriptions = subscriptions,
                        offerIncludesTrial = offerIncludesTrial,
                        dailyCost = derivedCostPerDay,
                        trialInFlight = trialInFlight,
                        trialError = trialError,
                        habitNoun = graph.content.words.habitGerund,
                        legal = legal,
                        onAppear = {
                            didShowTrial = true
                            graph.diagnostics.record(ConversionEvent.TRIAL_OFFER_REACHED)
                            subscriptions.trackPaywallImpression(
                                if (offerIncludesTrial) "quitzyn_onboarding_trial_v2" else "quitzyn_onboarding_offer_no_trial",
                                oncePerSession = true,
                            )
                            graph.nudges.markShown()
                        },
                        onSkip = { showSkipConfirm = true },
                        onStart = ::startOnboardingTrial,
                    )
                    4 -> ReminderStep(reminderHour, onHour = { reminderHour = it }) { step = 5 }
                    5 -> CommitStep(
                        onNotNow = { completeOnboarding(committed = false) },
                        onCommit = { completeOnboarding(committed = true) },
                    )
                    else -> WelcomeStep { step = 1 }
                }
            }
        }
    }

    if (showSkipConfirm) {
        SoberAlert(
            title = "Keep the free version?",
            message = "You'll keep the day counter, the calendar, craving mode, and your tree. Your year-ahead projection, the full health timeline, the journal, and the other species stay locked.",
            confirmTitle = if (offerIncludesTrial) "Keep my free trial" else "Go back",
            dismissTitle = "Get started",
            onConfirm = { showSkipConfirm = false },
            onDismiss = {
                showSkipConfirm = false
                graph.diagnostics.record(ConversionEvent.FREE_VERSION_CHOSEN)
                finishOfferStep()
            },
        )
    }

    SoberSheet(visible = showPaywallFallback, onDismiss = {
        showPaywallFallback = false
        finishOfferStep()
    }) {
        PaywallScreen(
            focus = null,
            impressionId = "quitzyn_onboarding_trial_fallback",
            displayCloseButton = true,
            onClose = {
                showPaywallFallback = false
                finishOfferStep()
            },
        )
    }
}

private const val PLANS_UNAVAILABLE = "Bloom+ plans are temporarily unavailable. You can retry or continue free."
private const val TRIAL_FAILURE = "Couldn't start your trial. Please try again."

/** Scrolls when a short phone can't fit the hero, centred when it can. */
@Composable
private fun ColumnScope.Hero(content: @Composable ColumnScope.() -> Unit) {
    val gap = if (compactHeight()) Space.m else Space.xl
    BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
        val viewport = maxHeight
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min = viewport),
            verticalArrangement = Arrangement.spacedBy(gap, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
            content = content,
        )
    }
}

@Composable
private fun WelcomeStep(onNext: () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        Hero {
            SymbolIcon("leaf.fill", Color.White, if (compactHeight()) 72.dp else 96.dp)
            Text("Quit Zyn", style = SoberType.display(if (compactHeight()) 40.sp else 52.sp), color = Color.White, textAlign = TextAlign.Center)
            Text(
                "Track your nicotine-free days, grow your garden, watch your health return.",
                style = SoberType.body(), color = Color.White, textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = Space.m),
            )
        }
        Dock(primaryTitle = "Get Started", tag = "onboarding.start", onPrimary = onNext)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StartDateStep(selected: LocalDate, today: LocalDate, onPick: (LocalDate) -> Unit, onNext: () -> Unit) {
    val todayMillis = today.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    val state = rememberDatePickerState(
        initialSelectedDateMillis = selected.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        selectableDates = object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= todayMillis
            override fun isSelectableYear(year: Int) = year <= today.year
        },
    )
    LaunchedEffect(state.selectedDateMillis) {
        state.selectedDateMillis?.let { onPick(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()) }
    }
    Column(Modifier.fillMaxSize()) {
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val viewport = maxHeight
            val pickerWidth = maxOf(maxWidth, 360.dp)
            Column(
                Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min = viewport),
                verticalArrangement = Arrangement.spacedBy(Space.l, Alignment.CenterVertically),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("When did your nicotine-free journey begin?", style = SoberType.display(if (compactHeight()) 28.sp else 34.sp), color = Color.White, textAlign = TextAlign.Center)
                androidx.compose.runtime.CompositionLocalProvider(androidx.compose.material3.LocalContentColor provides Color.White) { DatePicker(
                    state = state,
                    title = null,
                    headline = null,
                    showModeToggle = false,
                    colors = DatePickerDefaults.colors(
                        containerColor = Color.Transparent,
                        weekdayContentColor = Color.White.copy(alpha = 0.6f),
                        subheadContentColor = Color.White,
                        navigationContentColor = Color.White,
                        yearContentColor = Color.White,
                        currentYearContentColor = Color.White,
                        selectedYearContentColor = SoberColors.brandPrimary,
                        selectedYearContainerColor = Color.White,
                        dayContentColor = Color.White,
                        disabledDayContentColor = Color.White.copy(alpha = 0.3f),
                        selectedDayContentColor = SoberColors.brandPrimary,
                        selectedDayContainerColor = Color.White,
                        todayContentColor = Color.White,
                        todayDateBorderColor = Color.White,
                    ),
                    // Material's calendar needs 360dp; on a 360dp phone let it use the step's side padding.
                    modifier = Modifier.testTagCompat("onboarding.datePicker").requiredWidth(pickerWidth),
                ) }
            }
        }
        Dock(primaryTitle = "Continue", tag = "onboarding.continue", onPrimary = onNext)
    }
}

/**
 * Two inputs, not three sliders: the daily amount the user knows by heart and
 * one compact "can" card (price and count) that defines the unit.
 */
@Composable
private fun SpendStep(
    pouchesPerDay: Float,
    costPerCan: Double,
    pouchesPerCan: Int,
    dailyCost: Double,
    onPouches: (Float) -> Unit,
    onCostPerCan: (Double) -> Unit,
    onPouchesPerCan: (Int) -> Unit,
    inFlight: Boolean,
    error: String?,
    onContinueFree: () -> Unit,
    onContinue: () -> Unit,
) {
    Column(Modifier.fillMaxSize()) {
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val viewport = maxHeight
            Column(
                Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min = viewport),
                verticalArrangement = Arrangement.spacedBy(Space.l, Alignment.CenterVertically),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("How much were you using?", style = SoberType.display(if (compactHeight()) 28.sp else 34.sp), color = Color.White, textAlign = TextAlign.Center)
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color.White.copy(alpha = 0.12f)).padding(Space.l),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(Space.s),
                ) {
                    Text("${pouchesPerDay.toInt()}", style = SoberType.rounded(if (compactHeight()) 44.sp else 56.sp, FontWeight.Bold), color = Color.White)
                    Text("pouches a day", style = SoberType.body(), color = Color.White.copy(alpha = 0.85f))
                    SoberSlider(pouchesPerDay, onPouches, 0f..40f, 1f, Color.White, Color.White.copy(alpha = 0.3f),
                        modifier = Modifier.padding(horizontal = Space.s).testTagCompat("onboarding.pouchesSlider")
                            .semantics { contentDescription = "Pouches a day" })
                }
                CanCard(costPerCan, pouchesPerCan, onCostPerCan, onPouchesPerCan)
                SpendProjection(dailyCost, pouchesPerDay.toInt())
            }
        }
        Dock(
            primaryTitle = if (inFlight) "Checking trial availability…" else "Continue",
            busy = inFlight,
            tag = "onboarding.savingsContinue",
            above = {
                if (error != null) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.s)) {
                        Text(error, style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.onBrandError, textAlign = TextAlign.Center)
                        Text("Continue free", style = SoberType.subhead(FontWeight.SemiBold), color = Color.White,
                            modifier = Modifier.pressable(onClick = onContinueFree).padding(4.dp))
                    }
                }
            },
            onPrimary = onContinue,
        )
    }
}

/** "Your usual can": price stepper on the left, pouch count on the right. */
@Composable
private fun CanCard(costPerCan: Double, pouchesPerCan: Int, onCost: (Double) -> Unit, onCount: (Int) -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color.White.copy(alpha = 0.12f)).padding(Space.l),
        verticalArrangement = Arrangement.spacedBy(Space.s),
    ) {
        Text("Your usual can", style = SoberType.subhead(FontWeight.SemiBold), color = Color.White)
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("Price", style = SoberType.caption(), color = Color.White.copy(alpha = 0.75f))
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.m)) {
                    StepButton("minus", "Lower can price") { onCost(maxOf(1.0, costPerCan - 0.5)) }
                    Text(Format.currencyDecimal(costPerCan), style = SoberType.rounded(22.sp, FontWeight.Bold), color = Color.White,
                        textAlign = TextAlign.Center, modifier = Modifier.widthIn(min = 56.dp))
                    StepButton("plus", "Raise can price") { onCost(minOf(20.0, costPerCan + 0.5)) }
                }
            }
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("Pouches", style = SoberType.caption(), color = Color.White.copy(alpha = 0.75f))
                Row(
                    Modifier.width(132.dp).height(32.dp).clip(RoundedCornerShape(9.dp)).background(Color.White.copy(alpha = 0.16f)).padding(2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    listOf(15, 20, 24).forEach { count ->
                        val active = count == pouchesPerCan
                        Box(
                            Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(7.dp))
                                .background(if (active) Color.White.copy(alpha = 0.34f) else Color.Transparent)
                                .semantics { contentDescription = "$count pouches per can" }
                                .pressable(role = Role.Tab) { onCount(count) },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text("$count", style = SoberType.rounded(13.sp, if (active) FontWeight.SemiBold else FontWeight.Medium), color = Color.White)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun StepButton(icon: String, label: String, onClick: () -> Unit) {
    Box(
        Modifier.size(36.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.18f))
            .semantics { contentDescription = label }
            .pressable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { SymbolIcon(icon, Color.White, 16.dp) }
}

@Composable
private fun SpendProjection(dailyCost: Double, pouches: Int) {
    if (dailyCost <= 0 && pouches <= 0) return
    val yearlyDollars = Math.round(dailyCost * 365).toInt()
    val yearlyPouches = pouches * 365
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.15f))
            .padding(vertical = Space.m, horizontal = Space.m),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text("That's about ${Format.currencyDecimal(dailyCost)} / day", style = SoberType.subhead(FontWeight.SemiBold), color = Color.White)
        Text("In a year, that's", style = SoberType.caption(), color = Color.White.copy(alpha = 0.75f))
        if (yearlyDollars > 0) Text(Format.currency(yearlyDollars.toDouble()), style = SoberType.rounded(if (compactHeight()) 32.sp else 40.sp, FontWeight.Bold), color = Color.White)
        if (pouches > 0) {
            Text(
                if (yearlyDollars > 0) "plus ${Format.number(yearlyPouches)} pouches you won't put in. That's the nicotine your body never has to process."
                else "${Format.number(yearlyPouches)} pouches you won't put in. That's nicotine your body never has to process.",
                style = SoberType.caption(), color = Color.White.copy(alpha = 0.75f), textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun TrialStep(
    subscriptions: SubscriptionService,
    offerIncludesTrial: Boolean,
    dailyCost: Double,
    trialInFlight: Boolean,
    trialError: String?,
    habitNoun: String,
    legal: @Composable () -> Unit,
    onAppear: () -> Unit,
    onSkip: () -> Unit,
    onStart: () -> Unit,
) {
    LaunchedEffect(Unit) { onAppear() }
    val trialDays = subscriptions.trialOfferDayCount
    val headline = when {
        !offerIncludesTrial -> "Unlock Bloom+"
        trialDays == null -> "Bloom+, free to try"
        else -> "$trialDays days of Bloom+ free"
    }
    val subhead = when {
        !offerIncludesTrial -> "Every tool that keeps the streak visible, unlocked today."
        trialDays == null -> "Every tool that keeps the streak visible. Nothing is charged today."
        else -> "Every tool that keeps the streak visible. Nothing is charged for $trialDays days."
    }
    val cta = when {
        !offerIncludesTrial -> "Unlock Bloom+"
        trialDays == null -> "Start my free trial"
        else -> "Start my $trialDays-day free trial"
    }
    val yearly = Math.round(dailyCost * 365).toInt()
    val savingsText = if (yearly > 0) "Project the ${Format.currency(yearly.toDouble())} you'd keep over the next year"
    else "Project the year ahead, not just the days behind"
    val chargeLine = if (offerIncludesTrial && trialDays != null) {
        "Free until ${Format.monthDay(LocalDate.now().plusDays(trialDays.toLong()))}. We'll remind you before it ends. Reminder needs notifications turned on."
    } else null
    val habitLine = subscriptions.directOfferPlan?.habitComparisonSentence(Math.round(dailyCost * 100).toInt(), habitNoun)

    Column(Modifier.fillMaxSize()) {
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val viewport = maxHeight
            Column(
                Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min = viewport),
                verticalArrangement = Arrangement.spacedBy(Space.l, Alignment.CenterVertically),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                SymbolIcon("sparkles", Color.White, if (compactHeight()) 40.dp else 60.dp)
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.s)) {
                    Text(headline, style = SoberType.display(if (compactHeight()) 30.sp else 40.sp, FontWeight.Bold), color = Color.White, textAlign = TextAlign.Center, maxLines = 2)
                    Text(subhead, style = SoberType.body(), color = White88, textAlign = TextAlign.Center)
                }
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color.White.copy(alpha = 0.13f)).padding(Space.m),
                    verticalArrangement = Arrangement.spacedBy(Space.m),
                ) {
                    TrialBenefit("tree.fill", "Grow and switch every bonsai species")
                    TrialBenefit("heart.text.square.fill", "Follow 13 sourced nicotine-recovery milestones")
                    TrialBenefit("chart.line.uptrend.xyaxis", savingsText)
                    TrialBenefit("book.closed.fill", "Journal privately through the hard days")
                }
            }
        }
        Dock(
            primaryTitle = cta,
            busy = trialInFlight,
            tag = "onboarding.trialCTA",
            showLegal = true,
            legal = legal,
            above = {
                Column(verticalArrangement = Arrangement.spacedBy(Space.s), horizontalAlignment = Alignment.CenterHorizontally) {
                    if (habitLine != null) {
                        Row(
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.16f))
                                .padding(horizontal = 13.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            SymbolIcon("arrow.left.arrow.right", Color.White, 13.dp)
                            Spacer(Modifier.width(7.dp))
                            Text(habitLine, style = SoberType.subhead(FontWeight.SemiBold), color = Color.White)
                        }
                    }
                    subscriptions.directTrialPriceHeadline?.let {
                        Text(it, style = SoberType.body(FontWeight.Bold), color = Color.White, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                    }
                    StatusSlot(chargeLine, trialError)
                    Text(
                        "Get started",
                        style = SoberType.caption(FontWeight.SemiBold),
                        color = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.testTagCompat("onboarding.skipTrial").pressable(enabled = !trialInFlight, onClick = onSkip).padding(vertical = 6.dp, horizontal = 12.dp),
                    )
                }
            },
            below = {
                subscriptions.directTrialRenewalDisclosure?.let { DisclosureLine(it) }
            },
            onPrimary = onStart,
        )
    }
}

/** Reassurance and a real purchase error share one slot sized to the taller. */
@Composable
private fun StatusSlot(reassurance: String?, error: String?) {
    if (reassurance != null) {
        Box {
            Box(Modifier.alpha(0f)) { ReassuranceLine(reassurance) }
            Box(Modifier.alpha(0f)) { ErrorLine(SubscriptionService.PENDING_APPROVAL_MESSAGE) }
            if (error != null) ErrorLine(error) else ReassuranceLine(reassurance)
        }
    } else if (error != null) {
        ErrorLine(error)
    }
}

@Composable
private fun ReassuranceLine(text: String) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp)) {
        SymbolIcon("bell.badge.fill", Color.White.copy(alpha = 0.72f), 11.dp, Modifier.padding(top = 3.dp))
        Spacer(Modifier.width(6.dp))
        Text(text, style = SoberType.caption(), color = Color.White.copy(alpha = 0.72f))
    }
}

@Composable
private fun ErrorLine(text: String) {
    Text(text, style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.onBrandError, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
}

@Composable
private fun DisclosureLine(text: String) {
    Text(text, style = SoberType.caption(), color = Color.White.copy(alpha = 0.7f), textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = Space.s))
}

@Composable
private fun TrialBenefit(icon: String, text: String) {
    Row(Modifier.fillMaxWidth()) {
        SymbolIcon(icon, Color.White, 20.dp, Modifier.width(24.dp).padding(top = 2.dp))
        Spacer(Modifier.width(Space.m))
        Text(text, style = SoberType.body(), color = Color.White)
    }
}

@Composable
private fun ReminderStep(hour: Int, onHour: (Int) -> Unit, onNext: () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        Hero {
            Text("Daily reminder time", style = SoberType.display(if (compactHeight()) 28.sp else 34.sp), color = Color.White, textAlign = TextAlign.Center)
            HourWheel(hour, onHour)
        }
        Dock(primaryTitle = "Continue", tag = "onboarding.reminderContinue", onPrimary = onNext)
    }
}

/** The iOS hour wheel: a snapping list with the centred row selected. */
@Composable
private fun HourWheel(hour: Int, onHour: (Int) -> Unit) {
    val rowHeight = 44.dp
    val visibleRows = 5
    val listState = rememberLazyListState(initialFirstVisibleItemIndex = hour)
    val fling = rememberSnapFlingBehavior(lazyListState = listState)
    val centred by remember {
        derivedStateOf {
            val info = listState.layoutInfo
            val middle = (info.viewportStartOffset + info.viewportEndOffset) / 2
            info.visibleItemsInfo.minByOrNull { kotlin.math.abs(it.offset + it.size / 2 - middle) }?.index ?: hour
        }
    }
    val selected = if (listState.isScrollInProgress) centred else hour
    LaunchedEffect(listState.isScrollInProgress) {
        if (!listState.isScrollInProgress && centred != hour) onHour(centred.coerceIn(0, 23))
    }
    Box(Modifier.fillMaxWidth().height(rowHeight * visibleRows), contentAlignment = Alignment.Center) {
        Box(Modifier.fillMaxWidth().height(rowHeight).clip(RoundedCornerShape(10.dp)).background(Color.White.copy(alpha = 0.14f)))
        LazyColumn(
            state = listState,
            flingBehavior = fling,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = rowHeight * (visibleRows / 2)),
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxSize().testTagCompat("onboarding.hourWheel"),
        ) {
            items(24) { h ->
                Box(
                    Modifier.fillMaxWidth().height(rowHeight)
                        .semantics { contentDescription = Format.hour(h) }
                        .pressable { onHour(h) },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        Format.hour(h),
                        style = SoberType.body(if (h == selected) FontWeight.SemiBold else FontWeight.Normal),
                        color = Color.White.copy(alpha = if (h == selected) 1f else 0.5f),
                    )
                }
            }
        }
    }
    // Tapping a row (or an outside change) scrolls it into the centre.
    LaunchedEffect(hour) {
        if (!listState.isScrollInProgress && centred != hour) listState.animateScrollToItem(hour)
    }
}

/**
 * Final step: a deliberate commitment. A quieter "Not now" lets reluctant users
 * finish without a pledge they don't mean; the answer tunes the reminder tone.
 */
@Composable
private fun CommitStep(onNotNow: () -> Unit, onCommit: () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        Hero {
            SymbolIcon("hand.raised.fill", Color.White.copy(alpha = 0.92f), if (compactHeight()) 56.dp else 72.dp)
            Text("Make it official", style = SoberType.display(if (compactHeight()) 28.sp else 34.sp), color = Color.White, textAlign = TextAlign.Center)
            Text(
                "Recovery starts with a decision. This is yours, for today and the days that follow.",
                style = SoberType.body(), color = Color.White.copy(alpha = 0.9f), textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = Space.m),
            )
        }
        Dock(
            primaryTitle = "I commit to getting better",
            tag = "onboarding.commit",
            above = {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.s)) {
                    Text(
                        "Not now",
                        style = SoberType.subhead(FontWeight.Medium).copy(textDecoration = TextDecoration.Underline),
                        color = Color.White.copy(alpha = 0.8f),
                        modifier = Modifier.testTagCompat("onboarding.notNow").pressable(onClick = onNotNow).padding(vertical = 6.dp, horizontal = 12.dp),
                    )
                    Text(
                        "Either way is fine. You can revisit this any time in Settings.",
                        style = SoberType.caption(), color = Color.White.copy(alpha = 0.7f), textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = Space.m),
                    )
                }
            },
            onPrimary = onCommit,
        )
    }
}

@Composable
private fun LegalFooter(restoreInFlight: Boolean, onRestore: () -> Unit) {
    val context = LocalContext.current
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        val style = SoberType.caption()
        val color = Color.White.copy(alpha = 0.75f)
        Text(if (restoreInFlight) "Restoring…" else "Restore", style = style, color = color,
            modifier = Modifier.pressable(enabled = !restoreInFlight, onClick = onRestore).padding(vertical = 6.dp))
        Text("·", style = style, color = color)
        Text("Terms", style = style, color = color, modifier = Modifier.pressable { context.openUrl(StoreLinks.TERMS_URL) }.padding(vertical = 6.dp))
        Text("·", style = style, color = color)
        Text("Privacy", style = style, color = color, modifier = Modifier.pressable { context.openUrl(StoreLinks.PRIVACY_URL) }.padding(vertical = 6.dp))
    }
}

/**
 * Every step docks its primary button on the same pixel: the slot under it
 * always reserves the offer step's disclosure and legal footer, invisibly.
 */
@Composable
private fun Dock(
    primaryTitle: String,
    busy: Boolean = false,
    tag: String,
    showLegal: Boolean = false,
    legal: (@Composable () -> Unit)? = null,
    above: @Composable () -> Unit = {},
    below: @Composable () -> Unit = {},
    onPrimary: () -> Unit,
) {
    Column(Modifier.fillMaxWidth().padding(top = Space.s), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.s)) {
        above()
        Box(
            Modifier.fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(Color.White.copy(alpha = 0.25f))
                .testTagCompat(tag)
                .semantics { contentDescription = primaryTitle }
                .pressable(enabled = !busy, onClick = onPrimary)
                .padding(vertical = Space.l),
            contentAlignment = Alignment.Center,
        ) {
            Text(primaryTitle, style = SoberType.body(FontWeight.SemiBold), color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.alpha(if (busy) 0f else 1f))
            if (busy) ProgressSpinner(Color.White)
        }
        Box(contentAlignment = Alignment.TopCenter) {
            // The reserve: what the offer step puts under its button, laid out hidden on every step.
            Column(Modifier.alpha(0f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.s)) {
                DisclosureLine(SubscriptionService.AUTO_RENEW_DISCLOSURE)
                LegalFooter(false) {}
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.s)) {
                below()
                if (showLegal) legal?.invoke()
            }
        }
    }
}
