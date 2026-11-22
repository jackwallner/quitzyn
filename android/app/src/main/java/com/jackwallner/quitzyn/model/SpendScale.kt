package com.jackwallner.quitzyn.model

import java.util.Currency
import java.util.Locale
import kotlin.math.floor

/**
 * Sizes the spend steppers to the device currency. A can of pouches costs
 * about 6 dollars or euros, but about 120 koruna, 60 kronor or 600 yen, and
 * steppers built for dollars capped those users at a fifth of a real price.
 */
class SpendScale(currencyCode: String?) {
    /**
     * Local units that buy about what one US dollar buys, rounded to a 1, 2, 5
     * step so the stepper lands on round prices. Only the order of magnitude
     * matters, so rate drift does not need updates.
     */
    val unit: Double = UNITS[currencyCode?.uppercase(Locale.ROOT).orEmpty()] ?: 1.0

    // Onboarding can price

    val canPriceRange: ClosedFloatingPointRange<Double> get() = unit..(20 * unit)
    val canPriceStep: Double get() = 0.5 * unit
    val defaultCanPrice: Double get() = 6 * unit

    /** A price snapped to the stepper's grid and kept inside its range. */
    fun clampedCanPrice(price: Double): Double {
        val snapped = floor(price / canPriceStep + 0.5) * canPriceStep
        return snapped.coerceIn(canPriceRange.start, canPriceRange.endInclusive)
    }

    // Settings cost per day, in hundredths of the currency

    val dailyCostMaxCents: Int get() = 20_000 * unit.toInt()
    val dailyCostStepCents: Int get() = 100 * unit.toInt()

    companion object {
        val current: SpendScale
            get() = SpendScale(runCatching { Currency.getInstance(Locale.getDefault()).currencyCode }.getOrNull())

        private val UNITS = mapOf(
            "BGN" to 2.0, "GEL" to 2.0, "AZN" to 2.0,
            "PLN" to 5.0, "RON" to 5.0, "BRL" to 5.0, "ILS" to 5.0, "AED" to 5.0, "SAR" to 5.0, "QAR" to 5.0,
            "MYR" to 5.0, "PEN" to 5.0, "TND" to 5.0,
            "SEK" to 10.0, "NOK" to 10.0, "DKK" to 10.0, "CNY" to 10.0, "HKD" to 10.0, "MAD" to 10.0,
            "CZK" to 20.0, "MXN" to 20.0, "ZAR" to 20.0,
            "UAH" to 50.0, "TRY" to 50.0, "THB" to 50.0, "TWD" to 50.0, "PHP" to 50.0, "EGP" to 50.0,
            "RUB" to 100.0, "JPY" to 100.0, "INR" to 100.0, "ISK" to 100.0, "RSD" to 100.0, "KES" to 100.0,
            "MKD" to 50.0, "BYN" to 5.0, "KZT" to 500.0, "HUF" to 500.0, "PKR" to 200.0, "LKR" to 200.0,
            "KRW" to 1000.0, "CLP" to 1000.0, "NGN" to 1000.0, "ARS" to 1000.0, "COP" to 5000.0,
            "IDR" to 10000.0, "VND" to 20000.0,
        )
    }
}
