# PetScans — Meta Campaign Status

At-a-glance tracker for the PetScans Meta ad campaigns. Newest work at the bottom.

---

## ✅ Round 1 — Concept Test (Installs) — COMPLETED

Five-angle creative test to find the winning message. Ran live ~Jul 22–29, 2026, CA+US, ABO.

- **Campaign:** `120248321252990056` — "PetScans | Concept Test | Installs"
- **Spec:** [campaign-installs.json](campaign-installs.json)
- **Result:** ~$340 spend, 13 installs. Winner on CTR (the only trustworthy metric at this volume):

  | Ad set | CTR | Clicks |
  |---|---|---|
  | **04 Allergen** 🏆 | **6.26%** | 141 |
  | 01 Toxic Reveal | 5.13% | 115 |
  | 05 Ultra-Processed | 4.77% | 93 |
  | 06 Carousel | 1.63% | 31 |

- **Takeaway:** the **Allergen / personalized-protection** angle won. Specific + personal beats generic fear.
- **Note:** 03 Vet Science was disapproved (pharma false-positive). 02 Instant Demo dropped as redundant.

---

## ⏸️ Round 2 — Allergen Winner — PAUSED (pending new app release)

Iterate on the Round 1 winner: 3 statics + 1 UGC video, all on the allergen angle.

- **Status:** PAUSED 2026-07-30 pending a new app release. Campaign `120248427667800056` — ran Jul 29 4:52 PM → paused Jul 30, ~$28 spent.
- **Early read (small sample, directional):** V1 UGC Video led hard at **15.8% CTR**; statics 6.7–8.1%. 0 installs yet (too early). Video format looks like the winner.
- **End dates extended to 2027-06-30** (open-ended) so it's resumable whenever the release ships. start_time is in the past, so on resume it delivers immediately.
- **To relaunch:** resume campaign **+ all 4 ad sets + all 4 ads** (resume does NOT cascade). Mind the $100/day account cap if Round 1/PickleGo are live then. Judge on install→scan activation, not just CPI.
- **Spec:** [campaign-allergen-2026-08.json](campaign-allergen-2026-08.json) · runKey `petscans-allergen-winner-2026-08b`
- **Creative brief:** [Allergen-Winner-Creative-Brief.md](briefs/v2/Allergen-Winner-Creative-Brief.md) · UGC marketplace brief: [Allergen-UGC-Marketplace-Brief.md](Allergen-UGC-Marketplace-Brief.md)
- **Build params:** OUTCOME_APP_PROMOTION · ABO · CA+US · age 25+ (Advantage drops the 65 cap) · **CAD $13.75/ad set × 4 = $55/day**
- **⚠️ Account cap raised** `META_MAX_ACCOUNT_DAILY_CENTS` 10000 → **11000** in `tools/meta/.env.local` to fit both campaigns during the scheduling overlap window. Actual spend never exceeds ~$55/day (they don't overlap). **Revert to 10000 after Jul 29** once Round 1 has ended.
- **Note:** first allergen campaign `120248427590330056` was deleted (couldn't back-date start_time); replaced by `...667800056` created with the schedule baked in.

### Creative assets — DONE (2026-07-28, rev 2: barcode scan + Chicken By-Product)
Creative assets live in `creatives/v2/` (v2 = Round 2; Round 1 creatives archived in `creatives/v1/`):

| File | Size |
|---|---|
| `a-chicken__1x1.png` | 1080×1080 |
| `b-symptoms__1x1.png` | 1080×1080 |
| `c-flip__1x1.png` | 1080×1080 |
| `v1-ugc__9x16.mp4` | 1080×1920 |
| `v1-ugc__thumb.png` | 1080×1920 |

### Follow-ups after Jul 29 (when Round 1 ends)
```bash
cd tools/meta
# 1. Revert the account safety cap
#    edit tools/meta/.env.local → META_MAX_ACCOUNT_DAILY_CENTS=10000
# 2. Sanity-check delivery started and Round 1 stopped
npm run meta -- report --days 3 --level adset --json
```
Round 2 is already armed and scheduled — no further activation needed. Judge it on **install→scan activation**, not just CPI.
