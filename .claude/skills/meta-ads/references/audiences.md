# Audiences

## The trap, first

**An app-activity Custom Audience cannot be used for INCLUSION targeting on an iOS SKAdNetwork campaign** (subcode 1870125). Every iOS install campaign this repo creates is one.

So you cannot do the obvious thing — build an audience of engaged users and target a lookalike-free campaign at it. What you *can* do:

| Use | Works under SKAN? |
|---|---|
| Seed a **Lookalike**, then target the lookalike | ✅ yes — this is the main path |
| **Exclude** an audience (e.g. don't advertise to existing subscribers) | ⚠️ allowed by the CLI; Meta's error text names *inclusion* only and the docs don't settle exclusion. Confirm with `--validate` before relying on it. |
| **Include** an app-activity audience directly | ❌ rejected |
| Anything on Android / web (non-SKAN) | ✅ all of it |

The CLI enforces this: `buildTargeting` refuses an inclusion audience on a SKAN ad set rather than letting Meta reject it three steps later.

## Prerequisite

The ad account must have accepted the **Custom Audience Terms of Service** in Business Settings. Until a human clicks it, every `/customaudiences` call fails with subcode 1885183. `doctor` checks this.

## Events you can actually build on

Only events PickleGo really fires. An audience built on an event nobody sends stays empty forever, and nothing tells you.

From `src/services/meta.ts` (`MetaEvents`):

- `fb_mobile_activate_app` — app open (everyone)
- `fb_mobile_complete_registration` — signup
- `fb_mobile_purchase` — subscription purchase (sent server-side via CAPI)
- `fb_mobile_add_to_cart`, `fb_mobile_achievement_unlocked`, `fb_mobile_level_achieved`, `fb_mobile_tutorial_completion`

The CLI rejects any other event name.

## Recipes

**Installed but never subscribed** — the classic exclusion seed:
```bash
npm run meta -- audience create-app \
  --name "Installed, never purchased — 90d" \
  --event fb_mobile_activate_app \
  --exclude-event fb_mobile_purchase \
  --retention-days 90
```

**Lookalike from purchasers** — the highest-value targeting you can build:
```bash
npm run meta -- audience create-app --name "Purchasers — 180d" --event fb_mobile_purchase --retention-days 180
npm run meta -- audience create-lookalike --name "LAL 1% CA — purchasers" --seed <id> --country CA --ratio 0.01
```
Then target it: `adset create --include-audience <lookalikeId> ...`

## Sizing

- **Hard minimum seed: 100 people.** The CLI blocks below this.
- **Meta recommends 1,000–50,000.** The CLI warns below 1,000 — a lookalike from a tiny seed is statistically meaningless, and it will not tell you that itself.
- `ratio` 0.01 = top 1% (most similar, smallest). 0.20 = broadest. Start at 0.01.
- Populating takes 1–6 hours. `audience list` shows a `READY` column.
- Max 200 custom audiences per ad account.

Given PickleGo's current scale, you likely do **not** have 1,000 purchasers yet. Check `audience list` before promising a lookalike will work — seeding one from 40 people is worse than broad targeting.
