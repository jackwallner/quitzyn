import Foundation

struct HealthBenefit: Identifiable, Hashable {
    let id: String
    let hoursRequired: Double
    let title: String
    let summary: String
    let detail: String
    let sourceLabel: String
    let sourceURL: URL?

    var displayWait: String {
        var parts = DateComponents()
        let days = Int(hoursRequired / 24)
        if hoursRequired < 24 { parts.hour = Int(hoursRequired) }
        else if days < 7 { parts.day = days }
        else if days < 30 { parts.weekOfMonth = days / 7 }
        else if days < 365 { parts.month = days / 30 }
        else { parts.year = days / 365 }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        return formatter.string(from: parts) ?? ""
    }
}

enum HealthBenefitCatalog {
    // Nicotine recovery timeline. Applies to nicotine pouches (Zyn, snus),
    // vaping, dip, and cigarettes — the milestones track nicotine clearance and
    // the body's recovery once you stop. Times are typical; individual
    // experiences vary.
    static let all: [HealthBenefit] = [
        HealthBenefit(
            id: "heart-rate-steadies",
            hoursRequired: 2,
            title: String(localized: "Heart Rate Steadies"),
            summary: String(localized: "Pulse and blood pressure ease."),
            detail: String(localized: "Within a couple of hours of your last pouch, the nicotine spike fades and your heart rate and blood pressure start drifting back toward baseline."),
            sourceLabel: String(localized: "American Cancer Society"),
            sourceURL: URL(string: "https://www.cancer.org/cancer/risk-prevention/tobacco/benefits-of-quitting-smoking-over-time.html")
        ),
        HealthBenefit(
            id: "nicotine-falling",
            hoursRequired: 8,
            title: String(localized: "Nicotine Levels Falling"),
            summary: String(localized: "Blood nicotine drops sharply."),
            detail: String(localized: "Nicotine has a short half-life, so within several hours the level in your blood falls by more than half as your body clears the last dose."),
            sourceLabel: String(localized: "NCI · Nicotine Withdrawal"),
            sourceURL: URL(string: "https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet")
        ),
        HealthBenefit(
            id: "nicotine-cleared",
            hoursRequired: 24,
            title: String(localized: "Nicotine Cleared"),
            summary: String(localized: "Most nicotine is out of your system."),
            detail: String(localized: "Within about a day the bulk of nicotine has left your body. Cotinine, its longer-lasting byproduct, keeps clearing over the next few days."),
            sourceLabel: String(localized: "NCI · Nicotine Withdrawal"),
            sourceURL: URL(string: "https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet")
        ),
        HealthBenefit(
            id: "taste-smell",
            hoursRequired: 48,
            title: String(localized: "Taste & Smell Sharpen"),
            summary: String(localized: "Nerve endings begin to recover."),
            detail: String(localized: "After two days, nerve endings dulled by nicotine start to regrow and many people notice food tasting fuller and smells becoming sharper."),
            sourceLabel: String(localized: "American Cancer Society"),
            sourceURL: URL(string: "https://www.cancer.org/cancer/risk-prevention/tobacco/benefits-of-quitting-smoking-over-time.html")
        ),
        HealthBenefit(
            id: "cravings-peak",
            hoursRequired: 72,
            title: String(localized: "Cravings Peak & Ease"),
            summary: String(localized: "The hardest stretch passes."),
            detail: String(localized: "Around three days in, physical withdrawal tends to peak as the last nicotine leaves. Then cravings begin getting shorter and less intense."),
            sourceLabel: String(localized: "Truth Initiative"),
            sourceURL: URL(string: "https://truthinitiative.org/research-resources/quitting-smoking-vaping")
        ),
        HealthBenefit(
            id: "sleep-focus",
            hoursRequired: 24 * 7,
            title: String(localized: "Better Sleep & Focus"),
            summary: String(localized: "Concentration returns."),
            detail: String(localized: "By one week, sleep and concentration usually improve as your brain adapts to running without regular nicotine hits. Experiences vary."),
            sourceLabel: String(localized: "NCI · Nicotine Withdrawal"),
            sourceURL: URL(string: "https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet")
        ),
        HealthBenefit(
            id: "gums-healing",
            hoursRequired: 24 * 14,
            title: String(localized: "Gums Begin Healing"),
            summary: String(localized: "Mouth irritation subsides."),
            detail: String(localized: "Around two weeks without pouches packed against your gums, irritation and inflammation in the mouth start to settle and tissue begins to heal."),
            sourceLabel: String(localized: "NIH · Oral Health & Tobacco"),
            sourceURL: URL(string: "https://www.nidcr.nih.gov/health-info/smoking-tobacco")
        ),
        HealthBenefit(
            id: "mood-stabilizes",
            hoursRequired: 24 * 30,
            title: String(localized: "Mood Stabilizes"),
            summary: String(localized: "Irritability and anxiety ease."),
            detail: String(localized: "By about a month, the anxiety and irritability of early withdrawal typically fade as your brain's dopamine signaling rebalances. Experiences vary."),
            sourceLabel: String(localized: "Truth Initiative"),
            sourceURL: URL(string: "https://truthinitiative.org/research-resources/quitting-smoking-vaping")
        ),
        HealthBenefit(
            id: "blood-pressure",
            hoursRequired: 24 * 60,
            title: String(localized: "Blood Pressure Normalizes"),
            summary: String(localized: "Cardiovascular strain eases."),
            detail: String(localized: "By around two months without nicotine's repeated pressure spikes, many people see resting blood pressure and heart rate settle lower. Effects vary."),
            sourceLabel: String(localized: "American Heart Association"),
            sourceURL: URL(string: "https://www.heart.org/en/healthy-living/healthy-lifestyle/quit-smoking-tobacco")
        ),
        HealthBenefit(
            id: "circulation",
            hoursRequired: 24 * 90,
            title: String(localized: "Circulation Improves"),
            summary: String(localized: "Blood flow and energy rise."),
            detail: String(localized: "Three months in, circulation tends to improve as nicotine no longer constricts your blood vessels, and many people report steadier energy."),
            sourceLabel: String(localized: "American Cancer Society"),
            sourceURL: URL(string: "https://www.cancer.org/cancer/risk-prevention/tobacco/benefits-of-quitting-smoking-over-time.html")
        ),
        HealthBenefit(
            id: "oral-health",
            hoursRequired: 24 * 180,
            title: String(localized: "Oral Health Restored"),
            summary: String(localized: "Gum and mouth tissue recover."),
            detail: String(localized: "By around six months free of pouches, the risk of gum recession and mouth lesions drops and oral tissue continues to recover."),
            sourceLabel: String(localized: "NIH · Oral Health & Tobacco"),
            sourceURL: URL(string: "https://www.nidcr.nih.gov/health-info/smoking-tobacco")
        ),
        HealthBenefit(
            id: "stress-resilience",
            hoursRequired: 24 * 270,
            title: String(localized: "Stress Resilience"),
            summary: String(localized: "Baseline stress lowers."),
            detail: String(localized: "After several months without nicotine's spike-and-crash cycle, many people find their baseline stress is lower and calm comes more easily."),
            sourceLabel: String(localized: "Truth Initiative"),
            sourceURL: URL(string: "https://truthinitiative.org/research-resources/quitting-smoking-vaping")
        ),
        HealthBenefit(
            id: "heart-risk-drops",
            hoursRequired: 24 * 365,
            title: String(localized: "Heart Risk Drops"),
            summary: String(localized: "Long-term risk eases."),
            detail: String(localized: "After a year nicotine-free, research links staying off tobacco with meaningfully lower cardiovascular risk. Talk to a doctor about your health."),
            sourceLabel: String(localized: "American Heart Association"),
            sourceURL: URL(string: "https://www.heart.org/en/healthy-living/healthy-lifestyle/quit-smoking-tobacco")
        ),
    ]

    static func benefit(id: String) -> HealthBenefit? {
        all.first { $0.id == id }
    }

    static func unlocked(hoursSober: Double) -> [HealthBenefit] {
        all.filter { hoursSober >= $0.hoursRequired }
    }

    static func next(after hoursSober: Double) -> HealthBenefit? {
        all.first { hoursSober < $0.hoursRequired }
    }
}
