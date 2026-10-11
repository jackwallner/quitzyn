package com.jackwallner.quitzyn.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.quitzyn.BuildConfig
import com.jackwallner.quitzyn.data.BloomFeature
import com.jackwallner.quitzyn.data.ConversionEvent
import com.jackwallner.quitzyn.data.PackageKind
import com.jackwallner.quitzyn.data.Plan
import com.jackwallner.quitzyn.data.PurchaseException
import com.jackwallner.quitzyn.data.PurchaseOutcome
import com.jackwallner.quitzyn.data.StoreLinks
import com.jackwallner.quitzyn.data.SubscriptionService
import com.jackwallner.quitzyn.data.capitalizeWords
import com.jackwallner.quitzyn.ui.Format
import com.jackwallner.quitzyn.ui.LocalGraph
import com.jackwallner.quitzyn.ui.findActivity
import com.jackwallner.quitzyn.ui.openUrl
import com.jackwallner.quitzyn.ui.theme.ProgressSpinner
import com.jackwallner.quitzyn.ui.theme.SoberBrushes
import com.jackwallner.quitzyn.ui.theme.SoberColors
import com.jackwallner.quitzyn.ui.theme.SoberFonts
import com.jackwallner.quitzyn.ui.theme.SoberType
import com.jackwallner.quitzyn.ui.theme.SymbolIcon
import com.jackwallner.quitzyn.ui.theme.card
import com.jackwallner.quitzyn.ui.theme.pressable
import com.jackwallner.quitzyn.ui.theme.softShadow
import com.jackwallner.quitzyn.ui.theme.testTagCompat
import kotlinx.coroutines.launch

private fun rounded(size: TextUnit, weight: FontWeight = FontWeight.Normal) =
    TextStyle(fontFamily = SoberFonts.rounded, fontWeight = weight, fontSize = size, lineHeight = size * 1.18f)

/**
 * `PaywallView`: savings hero, everything Bloom+ unlocks, the plan stack (the
 * real price on every card), then the purchase block, trust line, and legal
 * links. One page at ordinary sizes; it scrolls only when the blocks need more
 * room than the device has, so the CTA and footer are always reachable.
 */
@Composable
fun PaywallScreen(
    focus: BloomFeature?,
    impressionId: String,
    displayCloseButton: Boolean,
    onClose: () -> Unit,
) {
    val graph = LocalGraph.current
    val subscriptions = graph.subscriptions
    val store = graph.store
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var selectedId by rememberSaveable { mutableStateOf<String?>(null) }
    var isPurchasing by remember { mutableStateOf(false) }
    var isRestoring by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var restoreMessage by remember { mutableStateOf<String?>(null) }

    // Yearly, then monthly, then lifetime: the yearly discount reads against the line below it.
    val order = mapOf(PackageKind.YEARLY to 0, PackageKind.MONTHLY to 1, PackageKind.LIFETIME to 2)
    val plans = subscriptions.plans.sortedBy { order[it.kind] ?: 9 }
    val monthly = subscriptions.plans.firstOrNull { it.kind == PackageKind.MONTHLY }
    val selected = plans.firstOrNull { it.packageId == selectedId }

    LaunchedEffect(Unit) {
        graph.diagnostics.record(ConversionEvent.TRIAL_OFFER_REACHED)
        subscriptions.trackPaywallImpression(impressionId)
        if (subscriptions.isConfigured && subscriptions.plans.isEmpty()) subscriptions.fetchProducts()
    }
    LaunchedEffect(plans.size) {
        // Yearly by default: whoever reaches this screen has decided Bloom+ is worth paying for.
        if (selectedId == null && plans.isNotEmpty()) {
            selectedId = (plans.firstOrNull { it.kind == PackageKind.YEARLY } ?: plans.firstOrNull { it.kind == PackageKind.MONTHLY } ?: plans.first()).packageId
        }
    }
    LaunchedEffect(subscriptions.isPro) {
        // Only a sheet closes itself; the Bloom+ tab swaps to the subscriber hub.
        if (subscriptions.isPro && displayCloseButton) onClose()
    }

    val days = store.days
    val heroDays = maxOf(store.lifetimeSoberDays, days)
    val cents = store.state.settings.costPerDayCents

    fun purchase() {
        val plan = selected ?: return
        val activity = context.findActivity() ?: return
        graph.diagnostics.record(ConversionEvent.TRIAL_CTA_TAPPED)
        errorMessage = null
        restoreMessage = null
        isPurchasing = true
        scope.launch {
            try {
                when (subscriptions.purchase(activity, plan)) {
                    PurchaseOutcome.PURCHASED -> graph.diagnostics.record(ConversionEvent.PURCHASE_SUCCEEDED)
                    PurchaseOutcome.PENDING -> {
                        graph.diagnostics.record(ConversionEvent.PURCHASE_PENDING)
                        restoreMessage = SubscriptionService.PENDING_APPROVAL_MESSAGE
                    }
                    PurchaseOutcome.CANCELLED -> {
                        graph.diagnostics.record(ConversionEvent.PURCHASE_CANCELLED)
                        errorMessage = "Purchase cancelled. Tap again to continue."
                    }
                }
            } catch (_: PurchaseException) {
                graph.diagnostics.record(ConversionEvent.PURCHASE_FAILED)
                errorMessage = "Couldn't complete the purchase. Please try again."
            } finally {
                isPurchasing = false
            }
        }
    }

    fun restore() {
        errorMessage = null
        restoreMessage = null
        isRestoring = true
        scope.launch {
            subscriptions.restorePurchases()
            isRestoring = false
            if (!subscriptions.isPro) restoreMessage = subscriptions.lastError ?: "No active Bloom+ purchase found for this Google Play account."
        }
    }

    val footer: @Composable () -> Unit = { FooterLinks(isRestoring || isPurchasing, isRestoring, ::restore) }

    Box(Modifier.fillMaxSize().background(SoberColors.background)) {
        when {
            !subscriptions.isConfigured -> if (BuildConfig.DEBUG) {
                DevPlaceholder(focus, heroDays, cents, displayCloseButton) {
                    subscriptions.setLocalOverride(true)
                    if (displayCloseButton) onClose()
                }
            } else {
                EmptyState(subscriptions.lastError, displayCloseButton, footer) { scope.launch { subscriptions.fetchProducts() } }
            }
            subscriptions.isLoadingProducts && plans.isEmpty() -> LoadingState(displayCloseButton, footer)
            plans.isEmpty() -> EmptyState(subscriptions.lastError, displayCloseButton, footer) { scope.launch { subscriptions.fetchProducts() } }
            else -> BoxWithConstraints(Modifier.fillMaxSize().navigationBarsPadding()) {
                val viewport = maxHeight
                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).heightIn(min = viewport)
                        .padding(horizontal = 22.dp).padding(top = if (displayCloseButton) 40.dp else 12.dp, bottom = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    SavingsHeader(focus, heroDays, cents)
                    BenefitShowcase(focus)
                    plans.forEach { plan ->
                        PlanCard(
                            plan = plan,
                            selected = plan.packageId == selectedId,
                            showsTrialBadge = subscriptions.isEligibleForIntroOffer(plan),
                            monthly = monthly,
                        ) { selectedId = plan.packageId }
                    }
                    Spacer(Modifier.weight(1f).heightIn(min = 2.dp))
                    PurchaseSection(selected, isPurchasing, errorMessage, restoreMessage, ::purchase)
                    TrustRow(selected?.let(subscriptions::isEligibleForIntroOffer) ?: false)
                    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { footer() }
                }
            }
        }
        if (displayCloseButton) {
            Box(
                Modifier.align(Alignment.TopEnd).padding(8.dp).size(44.dp)
                    .semantics { contentDescription = "Close" }
                    .testTagCompat("paywall.close")
                    .pressable(onClick = onClose),
                contentAlignment = Alignment.Center,
            ) { SymbolIcon("xmark.circle.fill", SoberColors.textTertiary, 28.dp) }
        }
    }
}

@Composable
private fun Eyebrow(text: String) {
    Text(text, style = rounded(11.sp, FontWeight.ExtraBold).copy(letterSpacing = 1.2.sp), color = SoberColors.brandPrimary.copy(alpha = 0.9f))
}

/** Savings-led hero: money already saved, a yearly projection, or a feature pitch. */
@Composable
private fun SavingsHeader(focus: BloomFeature?, heroDays: Int, cents: Int) {
    val words = LocalGraph.current.content.words
    val hasSavings = heroDays > 0 && cents > 0
    val saved = Format.currency(heroDays * cents / 100.0)
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(3.dp)) {
        when {
            focus != null -> {
                Text(focus.pitchHeadline, style = rounded(26.sp, FontWeight.Bold), color = SoberColors.textPrimary)
                Text(
                    if (hasSavings) "You've already saved $saved staying nicotine-free. Treat yourself to the tools that keep it growing." else focus.pitchSubheadline(words),
                    style = SoberType.subhead(), color = SoberColors.textSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis,
                )
            }
            hasSavings -> {
                Eyebrow("YOU'VE SAVED SO FAR")
                Text(saved, style = rounded(44.sp, FontWeight.ExtraBold), color = SoberColors.brandPrimary, maxLines = 1)
                Text("Across $heroDays nicotine-free day${if (heroDays == 1) "" else "s"}. You've earned this. Put a fraction toward staying nicotine-free for good.",
                    style = SoberType.subhead(), color = SoberColors.textSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
            cents > 0 -> {
                Eyebrow("YOUR MONEY, KEPT")
                Text("Up to ${Format.currency(Math.round(cents * 365 / 100.0).toDouble())}/yr", style = rounded(40.sp, FontWeight.ExtraBold), color = SoberColors.brandPrimary, maxLines = 1)
                Text("Stays in your pocket, not on pouches. Bloom+ keeps the streak that gets you there.",
                    style = SoberType.subhead(), color = SoberColors.textSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
            else -> {
                Eyebrow("BLOOM+")
                Text("Unlock the full toolkit", style = rounded(28.sp, FontWeight.Bold), color = SoberColors.textPrimary)
                Text("Your garden, journal, health timeline, and savings. Everything that keeps you nicotine-free.",
                    style = SoberType.subhead(), color = SoberColors.textSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

@Composable
private fun BenefitShowcase(focus: BloomFeature?) {
    val words = LocalGraph.current.content.words
    Column(
        Modifier.fillMaxWidth()
            .softShadow(Color.Black.copy(alpha = 0.05f), 10.dp, 4.dp, 18.dp)
            .card(SoberColors.cardSurface, 18.dp, SoberColors.ringTrack.copy(alpha = 0.6f))
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text("Everything you unlock", style = SoberType.subhead(FontWeight.Bold), color = SoberColors.textPrimary)
        BloomFeature.entries.forEach { feature ->
            val highlighted = feature == focus
            Row(
                Modifier.fillMaxWidth().height(38.dp)
                    .then(if (highlighted) Modifier.clip(RoundedCornerShape(12.dp)).background(SoberColors.brandPrimary.copy(alpha = 0.08f)).padding(horizontal = 8.dp) else Modifier),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(Modifier.size(30.dp).clip(CircleShape).background(SoberBrushes.brand), contentAlignment = Alignment.Center) {
                    SymbolIcon(feature.icon, Color.White, 15.dp)
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text(feature.title(words), style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(feature.detail, style = SoberType.caption(), color = SoberColors.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                SymbolIcon("checkmark", SoberColors.brandPrimary.copy(alpha = if (highlighted) 1f else 0.55f), 13.dp)
            }
        }
    }
}

@Composable
private fun PlanCard(plan: Plan, selected: Boolean, showsTrialBadge: Boolean, monthly: Plan?, onTap: () -> Unit) {
    val savings = if (plan.kind == PackageKind.YEARLY) plan.savingsPercent(monthly) else null
    val anchor = if (plan.kind == PackageKind.YEARLY) plan.anchorPriceLabel(monthly) else null
    val trial = plan.introOfferLabel
    val subtitle = when {
        plan.kind == PackageKind.YEARLY && plan.perMonthLabel != null ->
            if (showsTrialBadge && trial != null) "${trial.capitalizeWords()} · ${plan.perMonthLabel}" else plan.perMonthLabel
        plan.kind == PackageKind.MONTHLY && showsTrialBadge && trial != null -> trial.capitalizeWords()
        plan.kind == PackageKind.LIFETIME -> "One-time · no subscription"
        else -> null
    }
    val badge = when {
        plan.kind == PackageKind.YEARLY && savings != null -> "SAVE $savings%"
        plan.kind == PackageKind.LIFETIME -> "BEST DEAL"
        showsTrialBadge && plan.kind == PackageKind.MONTHLY -> "FREE TRIAL"
        else -> null
    }
    val badgeFill = if (plan.kind == PackageKind.LIFETIME) SoberColors.accent else SoberColors.brandPrimary
    Row(
        Modifier.fillMaxWidth().heightIn(min = 60.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(if (selected) SoberColors.brandPrimary.copy(alpha = 0.08f) else SoberColors.cardSurface)
            .border(if (selected) 2.dp else 1.dp, if (selected) SoberColors.brandPrimary else SoberColors.ringTrack.copy(alpha = 0.6f), RoundedCornerShape(16.dp))
            .semantics(mergeDescendants = true) {
                contentDescription = "${plan.displayName}, ${plan.priceLabel}" + (subtitle?.let { ", $it" } ?: "") + (badge?.let { ", $it" } ?: "")
                this.selected = selected
            }
            .testTagCompat("plan.${plan.kind.name.lowercase()}")
            .pressable(role = Role.RadioButton, onClick = onTap)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            Modifier.size(22.dp).border(2.dp, if (selected) SoberColors.brandPrimary else SoberColors.ringTrack, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (selected) Box(Modifier.size(12.dp).clip(CircleShape).background(SoberColors.brandPrimary))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(plan.displayName, style = SoberType.subhead(FontWeight.Bold), color = SoberColors.textPrimary, maxLines = 1)
                if (badge != null) {
                    Text(
                        badge,
                        style = rounded(10.sp, FontWeight.ExtraBold),
                        color = Color.White,
                        maxLines = 1,
                        modifier = Modifier.clip(CircleShape).background(badgeFill).padding(horizontal = 7.dp, vertical = 3.dp),
                    )
                }
            }
            if (subtitle != null) Text(subtitle, style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Column(Modifier.width(112.dp), horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(plan.priceLabel, style = SoberType.subhead(FontWeight.Bold), color = SoberColors.textPrimary, maxLines = 1)
            if (anchor != null) {
                Text(anchor, style = SoberType.caption().copy(textDecoration = TextDecoration.LineThrough), color = SoberColors.textTertiary, maxLines = 1)
            }
        }
    }
}

@Composable
private fun PurchaseSection(selected: Plan?, isPurchasing: Boolean, errorMessage: String?, restoreMessage: String?, onPurchase: () -> Unit) {
    val subscriptions = LocalGraph.current.subscriptions
    val eligible = selected?.let(subscriptions::isEligibleForIntroOffer) ?: false
    val cta = when {
        selected == null -> "Continue"
        selected.kind == PackageKind.LIFETIME -> "Unlock Lifetime"
        eligible && selected.introOfferLabel != null ->
            "Start ${selected.introOfferLabel!!.replace(" free trial", "", ignoreCase = true).capitalizeWords()} Free Trial"
        else -> "Continue with Bloom+"
    }
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(
            Modifier.fillMaxWidth().height(52.dp)
                .softShadow(SoberColors.brandPrimary.copy(alpha = 0.3f), 12.dp, 6.dp, 16.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(SoberBrushes.brand, RoundedCornerShape(16.dp))
                .graphicsLayer { alpha = if (selected == null) 0.6f else 1f }
                .semantics { contentDescription = cta }
                .testTagCompat("paywall.cta")
                .pressable(enabled = !isPurchasing && selected != null, onClick = onPurchase),
            contentAlignment = Alignment.Center,
        ) {
            Text(cta, style = SoberType.body(FontWeight.Bold), color = Color.White, maxLines = 1, modifier = Modifier.alpha(if (isPurchasing) 0f else 1f))
            if (isPurchasing) ProgressSpinner(Color.White)
        }
        selected?.let {
            Text(disclosure(it, eligible), style = SoberType.caption(), color = SoberColors.textTertiary, textAlign = TextAlign.Center, maxLines = 4)
        }
        if (errorMessage != null) {
            Text(errorMessage, style = SoberType.caption(), color = SoberColors.danger, textAlign = TextAlign.Center)
        } else if (restoreMessage != null) {
            Text(restoreMessage, style = SoberType.caption(), color = SoberColors.textSecondary, textAlign = TextAlign.Center)
        }
    }
}

/** The full billed price, trial terms, auto-renewal, and how to manage it. */
private fun disclosure(plan: Plan, eligible: Boolean): String {
    if (plan.kind == PackageKind.LIFETIME) return "${plan.priceLabel}. One-time purchase. Lifetime access, no subscription."
    val trial = plan.introOfferLabel
    val renew = SubscriptionService.AUTO_RENEW_DISCLOSURE
    return if (eligible && trial != null) "${trial.capitalizeWords()}, then ${plan.priceLabel}. $renew" else "${plan.priceLabel}. $renew"
}

@Composable
private fun TrustRow(trial: Boolean) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
    ) {
        SymbolIcon(if (trial) "bell.fill" else "lock.fill", SoberColors.brandPrimary.copy(alpha = 0.8f), 12.dp)
        Text(
            if (trial) "No payment now · Cancel any time · Data stays on-device" else "Your data stays on this device",
            style = SoberType.caption(), color = SoberColors.textSecondary, textAlign = TextAlign.Center, maxLines = 2,
        )
    }
}

@Composable
private fun FooterLinks(disabled: Boolean, restoring: Boolean, onRestore: () -> Unit) {
    val context = LocalContext.current
    val style = SoberType.caption()
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(if (restoring) "Restoring…" else "Restore Purchases", style = style.copy(textDecoration = TextDecoration.Underline), color = SoberColors.textTertiary,
            modifier = Modifier.testTagCompat("paywall.restore").pressable(enabled = !disabled, onClick = onRestore).padding(vertical = 8.dp))
        Text("·", style = style, color = SoberColors.textTertiary)
        Text("Terms", style = style, color = SoberColors.brandPrimary, modifier = Modifier.pressable { context.openUrl(StoreLinks.TERMS_URL) }.padding(vertical = 8.dp))
        Text("·", style = style, color = SoberColors.textTertiary)
        Text("Privacy Policy", style = style, color = SoberColors.brandPrimary, modifier = Modifier.pressable { context.openUrl(StoreLinks.PRIVACY_URL) }.padding(vertical = 8.dp))
    }
}

@Composable
private fun LoadingState(close: Boolean, footer: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxSize().navigationBarsPadding().padding(horizontal = 22.dp).padding(top = if (close) 52.dp else 20.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Spacer(Modifier.weight(1f))
        ProgressSpinner()
        Text("Loading plans…", style = SoberType.caption(), color = SoberColors.textSecondary)
        Spacer(Modifier.weight(1f))
        footer()
    }
}

@Composable
private fun EmptyState(error: String?, close: Boolean, footer: @Composable () -> Unit, onRetry: () -> Unit) {
    Column(
        Modifier.fillMaxSize().navigationBarsPadding().padding(horizontal = 22.dp).padding(top = if (close) 52.dp else 20.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Spacer(Modifier.weight(1f))
        SymbolIcon("wifi.exclamationmark", SoberColors.textTertiary, 40.dp)
        Text("Couldn't Load Plans", style = SoberType.body(FontWeight.SemiBold), color = SoberColors.textPrimary)
        Text(error ?: "Check your connection and try again.", style = SoberType.subhead(), color = SoberColors.textSecondary,
            textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 32.dp))
        Text("Try Again", style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.brandPrimary,
            modifier = Modifier.pressable(onClick = onRetry).padding(8.dp))
        Spacer(Modifier.weight(1f))
        footer()
    }
}

/** Debug only: no store key in this build, so a local unlock stands in. */
@Composable
private fun DevPlaceholder(focus: BloomFeature?, heroDays: Int, cents: Int, close: Boolean, onContinue: () -> Unit) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 22.dp).padding(top = if (close) 56.dp else 24.dp, bottom = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        SavingsHeader(focus, heroDays, cents)
        BenefitShowcase(focus)
        Text("Prices come from Google Play and aren't available in this build.", style = SoberType.caption(FontWeight.SemiBold),
            color = SoberColors.textSecondary, textAlign = TextAlign.Center)
        Box(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(SoberBrushes.brand).pressable(onClick = onContinue).padding(vertical = 16.dp),
            contentAlignment = Alignment.Center,
        ) { Text("Continue (dev)", style = SoberType.body(FontWeight.Bold), color = Color.White) }
    }
}
