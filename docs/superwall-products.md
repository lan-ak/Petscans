# PetScans — Subscription & IAP Product Reference (Superwall)

All products live on app **PetScans** (`6757314496`). The 6 subscriptions are in the
**Launch** subscription group (`21876391`); the lifetime unlock is a non‑consumable IAP.
Prices are the **US** base price — App Store Connect auto‑equalizes every other territory.
All products are available in **all territories** (auto‑include new territories = on).

Use the **Product ID** column verbatim when wiring products into a Superwall paywall.

## Subscriptions (group: Launch)

| Product ID | Period | Price (US) | Intro offer | Notes |
|---|---|---|---|---|
| `monthly_899_intro` | Monthly | $8.99 / mo | **3‑day free trial** | 3‑day *paid* intro isn't allowed by Apple on a monthly sub — 3 days can only be a free trial. |
| `monthly_899` | Monthly | $8.99 / mo | none | Flat price, no offer. |
| `monthly_999` | Monthly | $9.99 / mo | none | Flat price, no offer. |
| `yearly_6999_intro` | Yearly | $69.99 / yr | **$0.99 first month** (pay up front) | Then renews at $69.99/yr. |
| `yearly_7999_intro` | Yearly | $79.99 / yr | **$0.99 first month** (pay up front) | Then renews at $79.99/yr. |
| `yearly_5999_trial` | Yearly | $59.99 / yr | **3‑day free trial** | Then renews at $59.99/yr. |

## In‑App Purchase (one‑time)

| Product ID | Type | Price (US) | Notes |
|---|---|---|---|
| `lifetime_199` | Non‑consumable | $199 one‑time | Lifetime unlock — buy once, own forever. |

## Notes for wiring into Superwall

- The app integrates Superwall via **placements** (`Superwall.shared.register(placement:)`),
  e.g. `analysis_complete`, `onboarding_complete`. Superwall pulls these products from
  App Store Connect by product ID — there is no hardcoded StoreKit product list in Swift.
- New subscriptions start in `MISSING_METADATA` until they have a review screenshot +
  localization and are submitted with an app version. They are purchasable in the
  **sandbox / Superwall preview** immediately, but must be **Approved** before they can be
  bought in production.
- A user can hold only **one** active subscription per group (Launch) at a time — correct
  for A/B price testing alternatives of the same offering.
