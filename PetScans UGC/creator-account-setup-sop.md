# Creator Account Setup — Internal SOP

The one internal document. Self-contained; nothing else to cross-reference.

- **Send the creator:** `PetScans-Account-Setup-Quickstart.pdf`
- **Edit that PDF via:** `creator-account-setup-quickstart.html` → re-print with Chrome (command at
  the bottom of this file). `creator-account-setup-quickstart.md` is the readable copy of the same text.
- **Not in use yet:** `account-register-template.csv` — see §7.

Four platforms: **Instagram, TikTok, YouTube, Snapchat.** No Facebook. All four are ordinary
personal accounts, created by the creator, owned by us.

---

## 1. Why it's built this way

Three decisions drive everything below.

**Company-owned accounts.** Clause 8.6: accounts the creator already had stay theirs, anything set
up for this program is ours — handle, login, following. Ownership comes almost entirely from one
thing: *the accounts are registered to an email we control.* That's the spine.

**Personal-type accounts, not Business or Professional.** TikTok Business loses the full audio
library outright, and no platform's feed treats a business account the way it treats a person. We
buy reach and pay for it in ownership hedges — §9 is the honest bill.

**The creator creates them, on their own phone, on their own wifi.** Every platform weighs where an
account was created against where it's used. An account born on our IP and then opened on their
phone in another country is the signature of a bought or farmed account. We lose nothing by having
them do it: the ownership levers are all in the email and the vault, which are ours either way.

---

## 2. One-time setup — about an hour, once

**Google Workspace on a domain you own.** Not consumer Gmail. As super-admin you can reset any
password and reclaim any mailbox from the console immediately, which is what makes the rest of this
survivable. ~$7/user/month.

**A password manager with shared vaults** — 1Password or Bitwarden, either. You need two, and the
split matters more than the product:

| Vault | Contains | Creator access |
|---|---|---|
| `PetScans — Ops` | Mailbox A, and anything else that controls other things | **Never** |
| `PetScans — [creator]` | The four account logins, mailbox B | Shared |

**If you remember one thing from this document:** the creator must not be able to read the mailbox
that Instagram, TikTok and Snapchat send password resets to. Whoever reads that inbox controls every
account registered to it, regardless of what any contract says.

---

## 3. Two mailboxes, and why it isn't one

| | **A — control mailbox** | **B — YouTube account** |
|---|---|---|
| Example | `ops.molly@yourdomain` | `molly@yourdomain` |
| Registers | Instagram, TikTok, Snapchat | YouTube only |
| Creator holds the password? | **Never** | **Yes** — it's how they sign in to post |
| Vault | Ops | Shared |

The split exists because YouTube has no Brand Account here, so the creator needs a real Google
password to upload. One mailbox for everything plus a creator who holds it means they can reset all
four accounts at will. Two mailboxes costs you $7/month and removes the problem.

Workspace admin is the backstop on both. You don't need recovery-address ceremony on top of it.

---

## 4. Per creator — about 20 minutes of your time

1. **Create mailboxes A and B** as Workspace users. Put A in Ops, B in the shared vault. Check twice
   that A is not in the shared one.
2. **Generate the four account passwords** into the shared vault now, so the creator pastes rather
   than invents.
3. **Agree the handle.** They post 3 candidates; you check for trademark collisions and pick one.
   Confirm it's free on all four platforms *before* claiming any, then claim everywhere the same day.
   Lowercase, one separator at most, under 20 characters, reads like a person — `mollys.kibble.check`,
   not `petscans_ugc_02`. Display names can vary; the handle shouldn't.
4. **Send the quickstart PDF and the vault invite**, and open their Discord setup thread.
5. **Relay verification codes** from mailbox A while they work. That's your only live involvement.
6. **Fill in Exhibit B** with the four handles once they're live, and countersign.

---

## 5. What they do, and the gotcha on each platform

They have the step-by-step. These are the four things that go wrong:

**YouTube** — sign into mailbox B, create the channel from the avatar. An ordinary channel. **Not a
Brand Account**, and don't migrate it into one later.

**Instagram** — created at **instagram.com in a browser**, not the app, and never "log in with
Facebook". Left **personal**; don't switch to Professional. Skip any prompt to connect a Page.

**TikTok** — email and password, not phone-first. Left **personal**; Business accounts are limited
to the Commercial Music Library. Turn on ad authorization under Settings → Creator tools, which
works on a personal account and doesn't change its type — that's what clause 8.3's Spark Ad codes
run through.

**Snapchat** — a **Public Profile** is required; without it there's no public Spotlight posting at
all. Snapchat also usually demands a phone number and usually rejects VoIP.

**On all four:** 2FA via authenticator app, not SMS. On the QR screen there's a "can't scan?" link
with a **setup key** — that string goes into the vault item before setup is finished, along with the
**backup codes**. It's the most-skipped step and the most expensive one to miss.

**Phone numbers:** use theirs, record it in the thread. See §7 for when that changes.

---

## 6. The five things that must be true when they're done

Run this before the first script ships.

- [ ] Instagram, TikTok and Snapchat are registered to **mailbox A**, which the creator cannot read.
- [ ] YouTube is on **mailbox B**, an ordinary channel, and you're Workspace admin over it.
- [ ] Every account has 2FA on, with the **setup key and recovery codes in the shared vault**.
- [ ] All four are personal. No Professional, no Business, no Brand Account, no Facebook Page.
- [ ] **Exhibit B is filled in and countersigned** with the four handles.

Pass all five and you own the accounts in every way that matters. Fail one and fix it now — each is
far cheaper today than in month four.

Then, per account, have them post the handle, the profile link, a screenshot of the live profile and
the date into the thread. Thirty seconds, and it's your only dated proof of when an account started
and for whom.

---

## 7. What you're deliberately not doing yet

Not "never" — just not at one creator. Each has a trigger.

| Skipped | Start when |
|---|---|
| The Account Register CSV | **3+ creators.** Below that it duplicates the vault and Exhibit B |
| TikTok Business Center claim | An account has real value — a video past **100k**, or recurring Spark Ads |
| Snapchat Business Manager claim | Same, or Snapchat starts actually producing |
| A company-controlled phone number | An account is valuable enough that SMS recovery on their handset is a live risk. Until then TOTP does the real work |
| Instagram Business Portfolio claim | You switch that account to Creator for Partnership Ads — claim it in the same sitting |
| Monthly vault spot-checks | You have more accounts than you can hold in your head |

---

## 8. The rules the creator actually has to follow

**The one rule: never change the email, password, phone number, or 2FA.** Changes go through Discord
and get done together. Everything else is recoverable; this isn't.

Then, from the agreement: `#ad` at the **start** of every caption plus spoken or on-screen in the
first 3 seconds (clause 6.1 — personal accounts have no paid-partnership toggle, so the caption is
carrying the entire FTC obligation); no bought views or engagement pods (clause 7.4 voids the bonus
and risks the ban); posts stay up 12 months (clause 4.3); single-purpose accounts, no other brands
(clause 8.6).

**Discord carries everything except credentials.** No passwords, setup keys or recovery codes — not
in a channel, not in a DM, not in a screenshot. Six-digit verification codes are fine; they expire in
minutes. One setup thread per creator, kept for the life of the accounts, is the audit trail.

**When something breaks:** they post in `#help` within 24 hours and don't act alone. No retrying a
lockout, no replacement account on the same device after a ban, no password change mid-compromise.

---

## 9. The honest risks you're carrying

**Instagram has no platform-level backstop** while it's personal — it can't be claimed into the
Business Portfolio the way a professional account can. Ownership there is the vault credentials plus
email recovery through mailbox A. That's why the setup key and recovery codes are non-negotiable on
that one specifically.

**On YouTube the creator holds a full Google password**, so there's no version where they can post
but can't damage the channel. Workspace admin is what makes it survivable — you take the account back
in one click. It's the reason to use Workspace rather than reaching for a quick Gmail address.

**Dropping Facebook has two contract knock-ons.** Clause 4.1 names five platforms including Facebook,
and Exhibit A defines bonus views as the total across all five. Dropping one reduces what the creator
owes, so nothing breaks — but it shrinks the pool their 100k/1M bonuses count against. Facebook Reels
on a cold Page contributes close to nothing in practice, so the real effect is small. Say it at
onboarding rather than letting them find out at bonus time, note the four-platform list in the
thread, and issue Exhibit B with four rows.

Clause 7.2 is unaffected: personal accounts still show per-post view counts, which is what you count.

---

## 10. Handover, when it ends

- [ ] Rotate mailbox B's password and all four account passwords; revoke their vault access.
- [ ] Confirm you can still log into all four afterwards.
- [ ] Any account verifying to their phone number: swap it, or accept it and note the date.
- [ ] Posts stay up per clause 4.3 — handover is not deletion.
- [ ] Final statement per clause 7.5, less anything genuinely outstanding.

Their portfolio rights under clause 8.2 survive it — they keep the videos as examples of their work.

---

## Rebuilding the creator PDF

```
cd "PetScans UGC" && "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="PetScans-Account-Setup-Quickstart.pdf" \
  "file://$PWD/creator-account-setup-quickstart.html"
```

The `.html` is the source of truth for the PDF; `creator-account-setup-quickstart.md` is a parallel
copy of the same text, so edit both or neither.
