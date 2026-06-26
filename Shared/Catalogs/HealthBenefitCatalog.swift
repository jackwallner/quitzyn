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
        if hoursRequired < 24 { return "\(Int(hoursRequired))h" }
        let days = Int(hoursRequired / 24)
        if days < 7 { return "\(days)d" }
        if days < 30 { return "\(days / 7)w" }
        if days < 365 { return "\(days / 30)mo" }
        return "\(days / 365)y"
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
            title: "Heart Rate Steadies",
            summary: "Pulse and blood pressure ease.",
            detail: "Within a couple of hours of your last pouch, the nicotine spike fades and your heart rate and blood pressure start drifting back toward baseline.",
            sourceLabel: "American Cancer Society",
            sourceURL: URL(string: "https://www.cancer.org/cancer/risk-prevention/tobacco/benefits-of-quitting-smoking-over-time.html")
        ),
        HealthBenefit(
            id: "nicotine-falling",
            hoursRequired: 8,
            title: "Nicotine Levels Falling",
            summary: "Blood nicotine drops sharply.",
            detail: "Nicotine has a short half-life, so within several hours the level in your blood falls by more than half as your body clears the last dose.",
            sourceLabel: "NCI · Nicotine Withdrawal",
            sourceURL: URL(string: "https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet")
        ),
        HealthBenefit(
            id: "nicotine-cleared",
            hoursRequired: 24,
            title: "Nicotine Cleared",
            summary: "Most nicotine is out of your system.",
            detail: "Within about a day the bulk of nicotine has left your body. Cotinine, its longer-lasting byproduct, keeps clearing over the next few days.",
            sourceLabel: "NCI · Nicotine Withdrawal",
            sourceURL: URL(string: "https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet")
        ),
        HealthBenefit(
            id: "taste-smell",
            hoursRequired: 48,
            title: "Taste & Smell Sharpen",
            summary: "Nerve endings begin to recover.",
            detail: "After two days, nerve endings dulled by nicotine start to regrow and many people notice food tasting fuller and smells becoming sharper.",
            sourceLabel: "American Cancer Society",
            sourceURL: URL(string: "https://www.cancer.org/cancer/risk-prevention/tobacco/benefits-of-quitting-smoking-over-time.html")
        ),
        HealthBenefit(
            id: "cravings-peak",
            hoursRequired: 72,
            title: "Cravings Peak & Ease",
            summary: "The hardest stretch passes.",
            detail: "Around three days in, physical withdrawal tends to peak as the last nicotine leaves — then cravings begin getting shorter and less intense.",
            sourceLabel: "Truth Initiative",
            sourceURL: URL(string: "https://truthinitiative.org/research-resources/quitting-smoking-vaping")
        ),
        HealthBenefit(
            id: "sleep-focus",
            hoursRequired: 24 * 7,
            title: "Better Sleep & Focus",
            summary: "Concentration returns.",
            detail: "By one week, sleep and concentration usually improve as your brain adapts to running without regular nicotine hits. Experiences vary.",
            sourceLabel: "NCI · Nicotine Withdrawal",
            sourceURL: URL(string: "https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet")
        ),
        HealthBenefit(
            id: "gums-healing",
            hoursRequired: 24 * 14,
            title: "Gums Begin Healing",
            summary: "Mouth irritation subsides.",
            detail: "Around two weeks without pouches packed against your gums, irritation and inflammation in the mouth start to settle and tissue begins to heal.",
            sourceLabel: "NIH · Oral Health & Tobacco",
            sourceURL: URL(string: "https://www.nidcr.nih.gov/health-info/smoking-tobacco")
        ),
        HealthBenefit(
            id: "mood-stabilizes",
            hoursRequired: 24 * 30,
            title: "Mood Stabilizes",
            summary: "Irritability and anxiety ease.",
            detail: "By about a month, the anxiety and irritability of early withdrawal typically fade as your brain's dopamine signaling rebalances. Experiences vary.",
            sourceLabel: "Truth Initiative",
            sourceURL: URL(string: "https://truthinitiative.org/research-resources/quitting-smoking-vaping")
        ),
        HealthBenefit(
            id: "blood-pressure",
            hoursRequired: 24 * 60,
            title: "Blood Pressure Normalizes",
            summary: "Cardiovascular strain eases.",
            detail: "By around two months without nicotine's repeated pressure spikes, many people see resting blood pressure and heart rate settle lower. Effects vary.",
            sourceLabel: "American Heart Association",
            sourceURL: URL(string: "https://www.heart.org/en/healthy-living/healthy-lifestyle/quit-smoking-tobacco")
        ),
        HealthBenefit(
            id: "circulation",
            hoursRequired: 24 * 90,
            title: "Circulation Improves",
            summary: "Blood flow and energy rise.",
            detail: "Three months in, circulation tends to improve as nicotine no longer constricts your blood vessels, and many people report steadier energy.",
            sourceLabel: "American Cancer Society",
            sourceURL: URL(string: "https://www.cancer.org/cancer/risk-prevention/tobacco/benefits-of-quitting-smoking-over-time.html")
        ),
        HealthBenefit(
            id: "oral-health",
            hoursRequired: 24 * 180,
            title: "Oral Health Restored",
            summary: "Gum and mouth tissue recover.",
            detail: "By around six months free of pouches, the risk of gum recession and mouth lesions drops and oral tissue continues to recover.",
            sourceLabel: "NIH · Oral Health & Tobacco",
            sourceURL: URL(string: "https://www.nidcr.nih.gov/health-info/smoking-tobacco")
        ),
        HealthBenefit(
            id: "stress-resilience",
            hoursRequired: 24 * 270,
            title: "Stress Resilience",
            summary: "Baseline stress lowers.",
            detail: "After several months without nicotine's spike-and-crash cycle, many people find their baseline stress is lower and calm comes more easily.",
            sourceLabel: "Truth Initiative",
            sourceURL: URL(string: "https://truthinitiative.org/research-resources/quitting-smoking-vaping")
        ),
        HealthBenefit(
            id: "heart-risk-drops",
            hoursRequired: 24 * 365,
            title: "Heart Risk Drops",
            summary: "Long-term risk eases.",
            detail: "After a year nicotine-free, research links staying off tobacco with meaningfully lower cardiovascular risk. Talk to a doctor about your health.",
            sourceLabel: "American Heart Association",
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
