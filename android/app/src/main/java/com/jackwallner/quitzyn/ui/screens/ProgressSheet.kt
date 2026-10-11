package com.jackwallner.quitzyn.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.quitzyn.content.Achievement
import com.jackwallner.quitzyn.content.HealthMilestone
import com.jackwallner.quitzyn.data.PitchIntent
import com.jackwallner.quitzyn.ui.Format
import com.jackwallner.quitzyn.ui.LocalGraph
import com.jackwallner.quitzyn.ui.theme.InsetScope
import com.jackwallner.quitzyn.ui.theme.InsetSection
import com.jackwallner.quitzyn.ui.theme.SheetBar
import com.jackwallner.quitzyn.ui.theme.SoberColors
import com.jackwallner.quitzyn.ui.theme.SoberType
import com.jackwallner.quitzyn.ui.theme.Space
import com.jackwallner.quitzyn.ui.theme.SymbolIcon
import com.jackwallner.quitzyn.ui.theme.TextAction
import com.jackwallner.quitzyn.ui.theme.navBarPadding
import com.jackwallner.quitzyn.ui.theme.testTagCompat

/** `HealthBenefit.displayWait`: "6h", "3d", "2w", "4mo", "1y". */
val HealthMilestone.displayWait: String
    get() {
        if (hoursRequired < 24) return "${hoursRequired.toInt()}h"
        val days = (hoursRequired / 24).toInt()
        return when {
            days < 7 -> "${days}d"
            days < 30 -> "${days / 7}w"
            days < 365 -> "${days / 30}mo"
            else -> "${days / 365}y"
        }
    }

/**
 * The pull-up sheet for the longer horizon: what's next, what Bloom+ has
 * saved, the species, and every badge.
 */
@Composable
fun ProgressSheet(onClose: () -> Unit) {
    val graph = LocalGraph.current
    val store = graph.store
    val subscriptions = graph.subscriptions
    val coordinator = graph.coordinator
    val content = graph.content
    val state = store.state
    val settings = state.settings
    val isPro = subscriptions.isPro
    val days = store.days
    val lifetime = store.lifetimeSoberDays
    val cents = settings.costPerDayCents
    val pouches = settings.pouchesPerDay
    // Trial-led only when a free trial is actually on offer for this account.
    val showTrialNudge = days >= 7 && !isPro && !subscriptions.hasClaimedTrial && subscriptions.hasTrialOfferAvailable
    val lifetimeMoney = Format.currency(lifetime * cents / 100.0)

    Column(Modifier.fillMaxSize()) {
        SheetBar("Your progress", trailing = { TextAction("Done", style = SoberType.body(FontWeight.SemiBold), onClick = onClose) })
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(navBarPadding(8.dp)).padding(top = 8.dp)) {
            if (showTrialNudge) {
                InsetSection {
                    Item(onClick = { coordinator.requestLockedFeature(PitchIntent.PROGRESS_SHEET) }) {
                        LeadingRow("gift.fill", "You've saved $lifetimeMoney so far", "Start your free Bloom+ trial", trailingIcon = "chevron.right", emphasized = true)
                    }
                }
            }
            InsetSection("Next up") {
                val next = content.achievements.firstOrNull { it.kind == "timeMilestone" && days < it.dayThreshold }
                Item { LeadingRow("flag.fill", next?.title ?: "Year One", next?.let { "in ${maxOf(1, it.dayThreshold - days)} days" } ?: "Crushed it") }
                val hours = maxOf(0, days - 1) * 24.0
                val benefit = content.health.firstOrNull { hours < it.hoursRequired }
                Item { LeadingRow("heart.fill", benefit?.title ?: "All unlocked", benefit?.let { "at ${it.displayWait}" } ?: "") }
            }
            if (isPro) {
                InsetSection(
                    "Saved",
                    footer = "Streak counts your current run. Lifetime counts every nicotine-free day you've ever logged, so past progress isn't lost on a reset.",
                ) {
                    Item { SavedRow("Money", Format.currency(days * cents / 100.0), lifetimeMoney, "${Format.currencyFromCents(cents)} / day", "dollarsign.circle.fill") }
                    Item { SavedRow("Pouches", Format.number(days * pouches), Format.number(lifetime * pouches), "$pouches / day", "nosign") }
                    Item { SavedRow("Nicotine", nicotineMg(days * pouches), nicotineMg(lifetime * pouches), "~6 mg per pouch", "drop.fill") }
                }
            }
            Text(
                "BONSAI SPECIES",
                style = SoberType.rounded(androidx.compose.ui.unit.TextUnit(13f, androidx.compose.ui.unit.TextUnitType.Sp)),
                color = SoberColors.textSecondary,
                modifier = Modifier.padding(start = 32.dp, bottom = 7.dp),
            )
            GardenCollection(activeStyleId = state.garden.speciesId, isPro = isPro, modifier = Modifier.padding(horizontal = 16.dp).padding(bottom = 22.dp))
            InsetSection("Time milestones") {
                content.achievements.filter { it.kind == "timeMilestone" }.forEach { AchievementRow(it, days, isPro) }
            }
            InsetSection("Streaks") {
                content.achievements.filter { it.kind == "streak" }.forEach { AchievementRow(it, days, isPro) }
            }
        }
    }
}

/** Pouches as milligrams of nicotine never absorbed, at about 6 mg a pouch. */
private fun nicotineMg(pouches: Int): String = "${Format.number(pouches * 6)} mg"

@Composable
private fun InsetScope.AchievementRow(achievement: Achievement, days: Int, isPro: Boolean) {
    val graph = LocalGraph.current
    val unlocked = achievement.id in graph.store.state.earnedAchievementIds || days >= achievement.dayThreshold
    Item(onClick = if (!unlocked && !isPro) ({ graph.coordinator.requestLockedFeature(PitchIntent.PROGRESS_SHEET) }) else null) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.m)) {
            SymbolIcon(achievement.icon, if (unlocked) SoberColors.brandPrimary else SoberColors.textTertiary, 22.dp, Modifier.width(32.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(achievement.title, style = SoberType.body(), color = if (unlocked) SoberColors.textPrimary else SoberColors.textSecondary)
                Text(achievement.description, style = SoberType.caption(), color = SoberColors.textSecondary)
            }
            if (unlocked) SymbolIcon("checkmark.seal.fill", SoberColors.brandPrimary, 22.dp)
            else if (!isPro) SymbolIcon("lock.fill", SoberColors.textTertiary, 18.dp)
        }
    }
}

/** Leading glyph, title, and caption: the List row most of these sheets use. */
@Composable
fun LeadingRow(icon: String, title: String, detail: String, trailingIcon: String? = null, emphasized: Boolean = false) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.m)) {
        SymbolIcon(icon, SoberColors.brandPrimary, if (emphasized) 24.dp else 20.dp, Modifier.width(32.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = if (emphasized) SoberType.subhead(FontWeight.SemiBold) else SoberType.body(), color = SoberColors.textPrimary)
            if (detail.isNotEmpty()) Text(detail, style = SoberType.caption(), color = SoberColors.textSecondary)
        }
        if (trailingIcon != null) SymbolIcon(trailingIcon, SoberColors.textTertiary, 16.dp)
    }
}

@Composable
private fun SavedRow(label: String, streak: String, lifetime: String, sub: String, icon: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.m)) {
        SymbolIcon(icon, SoberColors.brandPrimary, 20.dp, Modifier.width(32.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(label, style = SoberType.body(), color = SoberColors.textPrimary)
            Text(sub, style = SoberType.caption(), color = SoberColors.textSecondary)
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(streak, style = SoberType.heading(), color = SoberColors.brandPrimary)
            Text("$lifetime lifetime", style = SoberType.caption(), color = SoberColors.textSecondary, textAlign = TextAlign.End)
        }
    }
}
