# Weekly price test

A five-way split on the onboarding paywall: the current yearly offer as a 12%
control against four weekly prices.

## Arms

| Arm | Paywall (directory) | Plans page | Exit offer | Share |
|---|---|---|---|---|
| Control | `onboarding-flow-hard` (281659, no close button) | `annual_39.99` ($0.99 for 30 days, then $39.99/yr) + `monthly_499` | none | 12% |
| A | `onboarding-weekly-a` (283646) | `weekly_399` ($3.99/wk) + `monthly_899` | none | 22% |
| B | `onboarding-weekly-b` (283647) | `weekly_499` ($4.99/wk) + `monthly_899` | none | 22% |
| C | `onboarding-weekly-c` (283648) | `weekly_599` ($5.99/wk) + `monthly_899` | none | 22% |
| D | `onboarding-weekly-d` (283649) | `weekly_699` ($6.99/wk) + `monthly_899` | none | 22% |

The weekly products have no trial and no intro offer: `weekly_399` (A),
`weekly_499` (B), `weekly_599` (C) and `weekly_699` (D). They are listed in
`superwall-products.md`.

All five arms run the same pages: the weekly directories re-export
`onboarding-flow`'s routes, chrome and messages, so a copy or design change
made there reaches every arm. What differs is the plans step. The weekly arms
sell a weekly plan with `monthly_899` beside it, where the control sells the
annual with `monthly_499`, and they provide the `weekly` lineup
(`lib/lineup.ts`), which drops the "Save X%" badge. No arm has an exit offer.
The weekly plans have no trial, so the plans page takes the no-offer branch
(reviews instead of the trial timeline), the same branch the monthly row
already uses.

## Setup

1. `npm run typecheck`.
2. `npm run push`. The four arms already exist (283646–283649, in
   `superwall.lock`); a push uploads new drafts and leaves production alone.
3. Preview each arm in the studio and make one sandbox purchase of its weekly
   plan.
4. In campaign **Onboarding V2** (111017), on the audience that serves 275901
   today, add the four weekly paywalls and set the split to 12 / 22 / 22 /
   22 / 22 (whole numbers only). Superwall keeps each user in their arm for good.
5. Check what the later placements sell to these users, so nobody is quoted
   weekly in onboarding and yearly afterwards:
   - `analysis_complete`: campaign **In-App** (65702). If it presents a yearly
     paywall to non-subscribers on 1.4.8+, either exclude them from it for the
     length of the test or give it the same arms.
   - `scan_gate`: campaign 64348, which only answers versions below 1.4.8. On
     1.4.8+ the flow's own plans step already marks the paywall as seen, so
     the gate passes straight through. Nothing to change.
6. Promote (`npm run promote`).

## Reading it

- **Metric: proceeds per user who saw the paywall**, per arm, not conversion.
  Weekly converts better on day 0 and loses more people to cancellation
  later, so conversion alone would pick the wrong winner.
- **Run for at least 4–6 weeks** before calling it, so the first weekly
  renewals and cancellations are in the numbers.
- Weekly prices run above $8.99 a month at most price points ($2.99 a week is
  about $13 a month), so on the weekly arms the monthly row is the cheaper
  plan. Watch the weekly/monthly mix per arm. If monthly takes most of the
  purchases, the test is measuring the monthly plan, not the weekly price.
- Each arm gets under a quarter of onboarding traffic. If paywall views are
  too few to separate four prices after a few weeks, drop to the two best
  arms and restart the count.
