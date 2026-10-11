package com.jackwallner.quitzyn.ui.screens

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.StartOffset
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.quitzyn.data.BloomFeature
import com.jackwallner.quitzyn.data.NotificationService
import com.jackwallner.quitzyn.ui.Format
import com.jackwallner.quitzyn.ui.LocalGraph
import com.jackwallner.quitzyn.ui.theme.ProgressSpinner
import com.jackwallner.quitzyn.ui.theme.SoberBrushes
import com.jackwallner.quitzyn.ui.theme.SoberColors
import com.jackwallner.quitzyn.ui.theme.SoberType
import com.jackwallner.quitzyn.ui.theme.SymbolIcon
import com.jackwallner.quitzyn.ui.theme.pressable
import com.jackwallner.quitzyn.ui.theme.softShadow
import com.jackwallner.quitzyn.ui.theme.testTagCompat

/**
 * `TrialOfferSheet`: one tap starts the free trial. Leads with the free days,
 * keeps the price small, shows how the trial works, and anchors the eventual
 * price against a year of habit spend. The full plan picker is secondary.
 */
@Composable
fun TrialOfferSheet(
    focus: BloomFeature?,
    offerLabel: String?,
    priceLabel: String?,
    isPurchasing: Boolean,
    errorMessage: String?,
    onStartTrial: () -> Unit,
    onSeeAllPlans: () -> Unit,
    onDismiss: () -> Unit,
) {
    val graph = LocalGraph.current
    val words = graph.content.words
    val cents = graph.store.state.settings.costPerDayCents
    val yearlySpend = Math.round(cents * 365 / 100.0).toInt()
    val showsAnchor = yearlySpend >= 60
    val hasTrial = offerLabel != null
    // Parsed from the store's label; a length the offer may not have is never guessed.
    val trialDays = offerLabel?.let { Regex("\\d+").find(it)?.value?.toIntOrNull() }
    val billingNote = when {
        !hasTrial || priceLabel == null -> null
        trialDays == null -> "When the trial ends, $priceLabel unless you cancel."
        else -> "After $trialDays days, $priceLabel unless you cancel."
    }
    val cleanPrice = priceLabel?.substringBefore(" /")?.trim()
    val headline = when {
        !hasTrial -> focus?.pitchHeadline ?: "Try Bloom+ free"
        trialDays == null -> "Bloom+, free to try"
        else -> "$trialDays days free"
    }
    val cta = when {
        !hasTrial -> "Continue"
        trialDays == null -> "Start My Free Trial"
        else -> "Start My $trialDays-Day Free Trial"
    }
    val subheadline = focus?.pitchSubheadline(words)
        ?: "Full access to your garden, journal, health timeline, and savings. Free until your trial ends."

    val pulse = rememberInfiniteTransition(label = "glow")
    val glow by pulse.animateFloat(0f, 1f, infiniteRepeatable(tween(2_400), RepeatMode.Reverse), label = "glow")

    Column(Modifier.fillMaxSize().background(SoberColors.background)) {
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(top = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Hero(glow, if (hasTrial) "gift.fill" else (focus?.icon ?: "sparkles"))
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(headline, style = SoberType.display(34.sp, FontWeight.Bold), color = SoberColors.textPrimary, textAlign = TextAlign.Center, maxLines = 1)
                Text(subheadline, style = SoberType.subhead(), color = SoberColors.textSecondary, textAlign = TextAlign.Center, maxLines = 3,
                    modifier = Modifier.padding(horizontal = 8.dp).padding(top = 2.dp))
            }
            if (hasTrial && trialDays != null) {
                Box(Modifier.padding(horizontal = 4.dp)) { TrialTimeline(trialDays, billingNote) }
            }
            if (showsAnchor) {
                SavingsAnchorCard(
                    yearlySpend = yearlySpend,
                    habitName = words.habitGerund,
                    trialDays = if (hasTrial) trialDays else null,
                    priceLabel = if (hasTrial) null else cleanPrice,
                    rightCaption = if (hasTrial) "full Bloom+ access" else "a year of Bloom+",
                )
            }
            if (errorMessage != null) {
                Text(errorMessage, style = SoberType.caption(), color = SoberColors.danger, textAlign = TextAlign.Center)
            }
        }
        Column(
            Modifier.fillMaxWidth().background(SoberColors.cardSurface.copy(alpha = 0.92f)).navigationBarsPadding()
                .padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                Modifier.fillMaxWidth()
                    .softShadow(SoberColors.brandPrimary.copy(alpha = 0.25f + 0.2f * glow), (10 + 8 * glow).dp, 6.dp, 16.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(SoberBrushes.brand)
                    .semantics { contentDescription = cta }
                    .testTagCompat("trialSheet.cta")
                    .pressable(enabled = !isPurchasing, onClick = onStartTrial)
                    .padding(vertical = 16.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(cta, style = SoberType.body(FontWeight.Bold), color = Color.White, maxLines = 1, modifier = Modifier.alpha(if (isPurchasing) 0f else 1f))
                if (isPurchasing) ProgressSpinner(Color.White)
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                ReassurancePill("checkmark.shield.fill", "No payment now", Modifier.weight(1f))
                ReassurancePill("bell.fill", "Reminder before billing", Modifier.weight(1f))
            }
            Text("See all plans", style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.brandPrimary,
                modifier = Modifier.testTagCompat("trialSheet.allPlans").pressable(onClick = onSeeAllPlans).padding(4.dp))
            Text("Not now", style = SoberType.caption(), color = SoberColors.textTertiary,
                modifier = Modifier.testTagCompat("trialSheet.notNow").pressable(onClick = onDismiss).padding(4.dp))
            if (billingNote != null) {
                Text(billingNote, style = SoberType.caption().copy(fontSize = 11.sp), color = SoberColors.textTertiary,
                    textAlign = TextAlign.Center, modifier = Modifier.padding(top = 2.dp))
            }
        }
    }
}

@Composable
private fun Hero(glow: Float, icon: String) {
    val sparkles = rememberInfiniteTransition(label = "sparkles")
    Box(Modifier.fillMaxWidth().height(116.dp), contentAlignment = Alignment.Center) {
        // A soft radial glow (a blur would clip to a hard square and needs API 31).
        Box(
            Modifier.requiredSize(240.dp).scale(0.85f + 0.2f * glow).alpha(0.45f + 0.35f * glow)
                .background(Brush.radialGradient(listOf(SoberColors.brandPrimary.copy(alpha = 0.55f), SoberColors.brandPrimary.copy(alpha = 0f)))),
        )
        Box(
            Modifier.size(72.dp).softShadow(SoberColors.brandPrimary.copy(alpha = 0.5f), 16.dp, 6.dp, 36.dp).clip(CircleShape).background(SoberBrushes.brand),
            contentAlignment = Alignment.Center,
        ) { SymbolIcon(icon, Color.White, 30.dp) }
        listOf(
            Triple(16.dp, -58 to -36, 0),
            Triple(11.dp, 60 to -20, 500),
            Triple(13.dp, 46 to 44, 1_000),
            Triple(9.dp, -52 to 40, 1_500),
        ).forEach { (size, offset, delay) ->
            val t by sparkles.animateFloat(0f, 1f, infiniteRepeatable(tween(1_800), RepeatMode.Reverse, StartOffset(delay)), label = "sparkle")
            Sparkle(size, offset.first.dp, offset.second.dp, t)
        }
    }
}

@Composable
private fun Sparkle(size: Dp, x: Dp, y: Dp, t: Float) {
    Box(Modifier.offset(x, y).scale(0.6f + 0.4f * t).alpha(0.25f + 0.65f * t)) {
        SymbolIcon("sparkle", SoberColors.brandPrimary.copy(alpha = 0.85f), size)
    }
}

@Composable
private fun ReassurancePill(icon: String, text: String, modifier: Modifier) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
        SymbolIcon(icon, SoberColors.brandPrimary, 13.dp)
        Text(text, style = SoberType.caption(), color = SoberColors.textSecondary, maxLines = 1)
    }
}

/** "How your free trial works": a three-step vertical timeline. */
@Composable
fun TrialTimeline(trialDays: Int, billingNote: String?) {
    val reminderDay = reminderDay(trialDays)
    val steps = listOf(
        Triple("lock.open.fill", "Today", "Everything unlocks. Full access, \$0 due now."),
        Triple("bell.fill", "Day $reminderDay", "We'll remind you before the trial ends, if notifications are on."),
        Triple("flag.checkered", "Day $trialDays", billingNote ?: "Cancel anytime before it ends. No surprise charges."),
    )
    val accent = SoberColors.brandPrimary
    Column(Modifier.fillMaxWidth()) {
        steps.forEachIndexed { index, (icon, title, detail) ->
            val highlight = index == 0
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(
                        Modifier.size(30.dp).clip(CircleShape).background(if (highlight) accent else accent.copy(alpha = 0.15f)),
                        contentAlignment = Alignment.Center,
                    ) { SymbolIcon(icon, if (highlight) Color.White else accent, 14.dp) }
                    if (index < steps.size - 1) Box(Modifier.width(2.dp).height(26.dp).background(accent.copy(alpha = 0.25f)))
                }
                Column(Modifier.weight(1f).padding(bottom = if (index < steps.size - 1) 8.dp else 0.dp), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text(title, style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.textPrimary)
                    Text(detail, style = SoberType.caption(), color = SoberColors.textSecondary)
                }
            }
        }
    }
}

/** Mirrors the reminder's real lead time, so the day shown can never drift from the day it fires. */
fun reminderDay(trialDays: Int): Int = maxOf(1, trialDays - NotificationService.TRIAL_REMINDER_LEAD_DAYS.toInt())

/** Savings-first price anchor: the money kept each year against the trial or price. */
@Composable
fun SavingsAnchorCard(yearlySpend: Int, habitName: String, trialDays: Int?, priceLabel: String?, rightCaption: String) {
    val savings = Format.currency(yearlySpend.toDouble())
    val accent = SoberColors.brandPrimary
    val right = trialDays?.let { "$it days free" } ?: priceLabel.orEmpty()
    val summary = if (trialDays != null) "You keep $savings in your pocket each year not spent on $habitName. Try Bloom+ free for $trialDays days."
    else "You keep $savings in your pocket each year. Bloom+ is ${priceLabel.orEmpty()} $rightCaption."
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(accent.copy(alpha = 0.08f))
            .border(1.dp, accent.copy(alpha = 0.18f), RoundedCornerShape(16.dp))
            .semantics(mergeDescendants = true) { contentDescription = summary }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            SymbolIcon("banknote.fill", accent.copy(alpha = 0.9f), 12.dp)
            Text("YOUR SAVINGS", style = SoberType.rounded(10.sp, FontWeight.Black).copy(letterSpacing = 1.1.sp), color = accent.copy(alpha = 0.9f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text("You keep", style = SoberType.caption(FontWeight.SemiBold), color = accent)
                Text(savings, style = SoberType.rounded(28.sp, FontWeight.Black), color = SoberColors.textPrimary, maxLines = 1)
                Text("in your pocket each year", style = SoberType.caption(), color = SoberColors.textSecondary)
                Text("not spent on $habitName", style = SoberType.caption(FontWeight.Medium).copy(fontSize = 11.sp), color = SoberColors.textSecondary.copy(alpha = 0.85f))
            }
            Box(Modifier.padding(top = 8.dp)) { SymbolIcon("arrow.right", accent.copy(alpha = 0.75f), 16.dp) }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text("Try Bloom+", style = SoberType.caption(FontWeight.SemiBold), color = accent)
                Text(right, style = SoberType.rounded(24.sp, FontWeight.Black), color = SoberColors.textPrimary, maxLines = 1)
                Text(rightCaption, style = SoberType.caption(), color = SoberColors.textSecondary)
            }
        }
    }
}
