# Reading `report`, and when to act

```bash
npm run meta -- report --days 7 --level adset --json
```

## What you get

Meta returns conversions as an untyped `actions` array whose `action_type` strings vary by objective and attribution setting — picking the wrong key silently reports zero purchases forever. `report` does that extraction once, so each row is already typed:

| Field | Meaning |
|---|---|
| `spend` | in the account's currency (**CAD** here), as a decimal |
| `impressions`, `clicks`, `ctr`, `frequency` | delivery |
| `installs`, `cpi` | `cpi` is `null` when there are no installs — not `0` |
| `signups` | `fb_mobile_complete_registration` |
| `purchases`, `cpa`, `revenue`, `roas` | `roas` is `null` with no spend |

`null` means *no data*, not *zero*. Never render a `null` CPI as "$0.00" — it means nothing has converted yet, which is a completely different fact.

## The two rules that matter most

**1. Do not judge an ad set before ~50 conversions or 3–4 days.**
Below that you are reading noise. Meta's delivery system is still in its learning phase and performance is genuinely unrepresentative. Pausing a good ad set on day one because it has a bad CPI is the most common way to waste money on Meta — you pay for the learning and then throw away the result.

**2. Do not change a live budget by more than ~20% in a day.**
A bigger change re-enters the learning phase and discards the spend that got it out. `adset update --daily-budget` warns you when you cross this. To test a bigger change, **duplicate** instead — the copy learns independently while the original keeps delivering:

```bash
npm run meta -- adset duplicate <id> --name "Broad | CA | 2x budget" --daily-budget 6000
```

## Deciding

There is no `pause-underperformers` command on purpose. A baked-in heuristic is a black box that will one day pause the wrong thing. You reason in the open; the human can veto.

Rough guidance, not rules:

- **CPI far above target, past learning** → pause it. But know the target first — ask the human if you don't. There is no universal "good CPI"; it depends entirely on what a user is worth.
- **Good CPI, no signups** → the ads are attracting the wrong people, or onboarding is broken. Do not scale it. This is a product signal, not an ads one.
- **Good CPI, good ROAS, past learning** → scale, but at ≤20%/day, or duplicate.
- **High frequency (>3–4) with decaying CTR** → creative fatigue. Ship a new creative rather than fiddling with budget.
- **Nothing has spent at all** → nothing is ACTIVE. Check with `campaigns`; an ad set only delivers if its campaign is active too.

Always state the numbers you based a decision on, so the human can disagree with the reasoning rather than just the outcome.

## Attribution caveat (iOS)

These campaigns run on SKAdNetwork. That means:

- Conversion data is **delayed** (24–72h) and **aggregated** — same-day numbers are always incomplete.
- Purchases are reported through the Conversions API from `functions/src/meta/superwallWebhook.ts`, not from the client. If purchases look impossibly low, check the webhook is firing before you conclude the ads are bad.
- Do not reconcile Meta's install count against App Store Connect and expect them to match. They never will.
