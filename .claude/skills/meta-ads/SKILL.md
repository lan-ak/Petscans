---
name: meta-ads
description: Run Meta (Facebook/Instagram) Ads for PickleGo via the Marketing API — launch campaigns, upload creative, build audiences, read performance, pause underperformers. Use for anything about Meta ads, ad spend, campaigns, ad sets, creatives, CPI, ROAS, or Facebook/Instagram advertising.
---

# Meta Ads

A CLI that gives you full control of PickleGo's Meta ads. It lives in `functions/scripts/meta/`.

```bash
cd functions
npm run meta -- doctor          # ALWAYS run this first
npm run meta -- help
```

**The `--` is mandatory.** Without it npm swallows the flags and the command silently does the wrong thing. Every example below has it. Add `--json` whenever you need to parse the output.

## The contract you must not break

**Everything this CLI creates is created PAUSED and cannot spend a cent.** That is enforced in `client.ts`, not by your good behaviour — but the part that *is* on you:

- **Never run `campaign resume`, `adset resume`, or `ad resume` unless the human asks you to activate something in the current turn.** Those commands are the only path to spending real money.
- **Never pass `--max-daily-budget`** unless the human has said a specific number in the current turn. It exists to raise the safety ceiling; raising it on your own initiative defeats the entire point.
- **Never use `--force` on a delete.** It exists to override the "this campaign has spend history" guard.
- When you finish creating something, tell the human **which id to activate and what it will cost per day.** Do not activate it for them.

If a guardrail blocks you, that is the system working. Report it and its suggested fix. Do not route around it (e.g. by using `graph --method POST` to bypass a typed command — that is guardrailed too, and trying is a red flag).

## Money is integer minor units

`3000` means **$30.00**, not $3,000 and not 30 cents. This is the single most expensive mistake available to you.

**This ad account bills in CAD**, not USD. `doctor` prints the currency and the account minimum. Always say the dollar amount back to the human in words before creating anything: *"that's CAD $30.00/day"*.

## Workflows

### Launch a campaign
Never hand-build a campaign with four separate commands. Use a spec — it validates as one unit and is resumable.

```bash
npm run meta -- spec example > /tmp/launch.json   # edit it
npm run meta -- spec validate --spec /tmp/launch.json    # offline, no network
npm run meta -- launch --spec /tmp/launch.json --validate # Meta checks it, creates nothing
npm run meta -- launch --spec /tmp/launch.json            # creates it all, PAUSED
npm run meta -- ad preview <adId>                         # render it — free
```
Then tell the human the campaign id and the daily budget, and stop. See `references/launch-spec.md`.

**If a launch fails partway:** everything already created is PAUSED and harmless. Re-run with `--resume` — never a bare re-run, which would duplicate. `npm run meta -- runs` lists runs; `rollback --run-key <k>` deletes one.

### Weekly optimization
```bash
npm run meta -- report --days 7 --level adset --json
```
Read the numbers, reason out loud, then act with `adset pause <id>` or `adset duplicate <id> --daily-budget <cents>`.

There is deliberately **no `pause-underperformers` command.** You do the judging in the open so the human can veto it. Before you judge anything, read `references/optimization.md` — the two rules that matter most:
- **Do not judge an ad set before ~50 conversions or 3–4 days.** Below that you are reading noise.
- **Do not change a live budget by more than ~20% in a day.** It resets the learning phase and wastes the spend that got it out. To test a bigger change, `adset duplicate` instead.

### Upload creative
```bash
npm run meta -- image upload ./creative/rally.png          # → hash
npm run meta -- video upload ./creative/rally.mp4 --wait   # → id (--wait is not optional)
npm run meta -- creative create --name "..." --primary-text "..." --headline "..." --image-hash <hash>
```

### Audiences
Read `references/audiences.md` first — there is a trap. An app-activity Custom Audience **cannot be used for inclusion targeting on an iOS SKAdNetwork campaign** (subcode 1870125), and every iOS install campaign here is one. Audiences are useful for *seeding a lookalike* and for *exclusions*, not for direct targeting.

## PickleGo's fixed values

Never guess these; they come from `functions/.env.local` and the CLI injects them.

| | |
|---|---|
| Campaign objective | `OUTCOME_APP_PROMOTION` — always |
| Ad set optimization goal | `APP_INSTALLS` (or `OFFSITE_CONVERSIONS` + an event) |
| Billing event | `IMPRESSIONS` — never `APP_INSTALLS` (CPA billing is blocked on SKAN) |
| App Store URL | `https://apps.apple.com/app/id6743630735` |
| Meta app | PickleGo, `1656110792721831` |

**`APP_INSTALLS` is an optimization goal, not an objective.** Putting it in `campaign.objective` is the most common error; the validator catches it, but know the difference.

## Things that will bite you

- **`promoted_object` and the SKAN flag are immutable once a campaign is live.** There is no edit path — only delete-and-recreate, which burns one of the app's **9 SKAdNetwork campaign slots**. Get them right the first time. `doctor` shows how many slots remain.
- **A campaign can be created even when the app is misconfigured; the AD SET is what fails** (subcode 1885093). So a green campaign create means nothing. Run `doctor`.
- Max **5 ad sets per campaign**, and they must all share one optimization goal.
- **Never invent an interest id.** Use `npm run meta -- interests search "pickleball"`.
- Prefer `pause` over `delete`. Deleting an object with spend history destroys its reporting.
- If a write times out, **do not retry it** — it may have landed. The CLI raises `unknown_state` (exit 4) and reconciles by name on `--resume`.

## Verifying without spending

| | |
|---|---|
| `--dry-run` | prints the request body, sends nothing. Catches *shape* errors. |
| `--validate` | Meta validates it server-side and creates nothing. Catches *API* errors. |
| `selftest` | offline, no token. Checks every request builder and every guardrail. |
| a real `launch` | creates everything **PAUSED** → zero delivery, zero spend. Then `ad preview`. |

`--dry-run` and `--validate` are not the same thing and catch different bugs. Use both before a first launch.

## Reference files

- `references/launch-spec.md` — the full spec schema and worked examples
- `references/objectives.md` — valid objective × goal × billing combinations, and the SKAdNetwork rules
- `references/optimization.md` — how to read `report`, and when to act
- `references/audiences.md` — custom audiences, lookalikes, and the SKAN trap
- `references/troubleshooting.md` — Graph error code → cause → fix
