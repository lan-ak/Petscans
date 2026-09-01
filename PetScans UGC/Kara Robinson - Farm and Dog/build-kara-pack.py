#!/usr/bin/env python3
"""Render Kara Robinson's dog UGC script pack as a creator-facing .docx.

Usage:  ../../PetScans-Meta-Campaign/venv/bin/python build-kara-pack.py

This file holds the creator-facing copy and is the source of truth for the
dialogue. Verification data — scores, labels, flags, and which allergens are
safe to name — is in ugc-scripts-kara-dog.md in this folder, produced with
`verify-products.py check`.

Creator: Kara Robinson (@crazykararoo), North Carolina. Mom + farm life, UGC and
social media management. Prior pet work: PetArmor voice-over, Chewy, VetPets+.
Already shoots "talking head app promotion" as a named format. Posts organically
to her own account; nothing here is an ad.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ugc_docx import (bullets, callout, cover, cut_label, heading, new_doc,
                      rich, rule, script_header, shotlist, table, vo)

OUT = Path(__file__).parent / "PetScans-UGC-Scripts-Kara-Robinson.docx"

doc = new_doc()

cover(doc, "PetScans", "UGC Script Pack — Kara Robinson", [
    "Five scripts. Each has a **30-second version** and a **60-second version** of the "
    "same story — shoot both back to back, same setup, same day. Do the 30 first.",
    "**No need to buy any of this food.** It all happens in the app's search: type the "
    "name, the full ingredient list and the score come up. Scripts 1 to 4 need nothing "
    "but your phone and your dog.",
    "**Script 5 is the one at the pet store**, scanning bags straight off the shelf — the "
    "most fun to watch, and the only one that needs you to leave the house.",
    "These post to your own account in your own voice. They're not ads and shouldn't "
    "sound like them.",
])

rule(doc)

heading(doc, "Before you shoot", size=16, before=4)
rich(doc, "**What you need:** your phone, your dog, and a profile set up in the app for "
          "[DOG NAME] — name, weight, and whatever he reacts to.", after=6)
rich(doc, "**These are formats you already shoot.** Scripts 1 to 3 are the talking-head style "
          "from your media kit. Script 4 is a voice-over read like your PetArmor one. Script 5 "
          "is a shop-with-me. Shoot them the way you normally shoot.", after=6)
rich(doc, "**The farm is the whole advantage.** Feeding time, the barn, the kids, animals "
          "wandering through frame — leave every bit of it in. Nobody else making pet food "
          "content looks like this, and that's the reason these will travel.", after=10)

heading(doc, "How to talk on camera", size=13, before=8, after=4)
bullets(doc, [
    "**Say it how you actually feel it.** This isn't medical advice and you're not a vet. You "
    "don't need to be careful or balanced about your own dog, your own opinion, or how annoyed "
    "this makes you. Sound like you, not like a brand.",

    "**Just never make anything up.** No symptom that didn't happen, no vet visit that wasn't. "
    "Anywhere you see [SQUARE BRACKETS], that's a blank only you can fill — put something real "
    "in it.",

    "**Anything you say the app said has to match the screen.** The score, the Caution or Avoid "
    "label, the warnings listed, where an ingredient sits. Call an ingredient whatever you want "
    "— just don't put words in the app's mouth.",

    "**Never say chicken is what the app flagged.** On all five of these it isn't — the app "
    "records the by-product differently. Use corn, soy or wheat as the thing your dog reacts to. "
    "You can still read \"chicken by-product meal\" off the list out loud in any script. That's "
    "reading the label, and it's true.",

    "**Script 4 mentions garlic — keep it in proportion.** \"The app flagged garlic and I didn't "
    "expect that\" is true and it's plenty. Don't say it'll poison him: it's a small amount, the "
    "app says caution rather than avoid, and people will come for you.",

    "**No medical claims.** No diagnosing, no treatment advice, no \"this caused it\" or \"this "
    "cured it.\" What happened to your dog is yours to tell. What'll happen to someone else's "
    "isn't.",

    "**Film the real app.** Real screen recordings, real numbers. If something doesn't match this "
    "document, film what's on your screen and tell us — we fix the script, never the footage.",

    "**The profile switch is one unbroken take.** No cut between the two scores, no re-searching "
    "in between, or the comments will say it was two different bags.",

    "**Show the app as long as it's interesting — the logo gets 2 seconds.** Hold the ingredient "
    "list still so people can pause and screenshot. The branded card at the end is two seconds, "
    "once.",

    "**If the food you actually feed scores well, say so.** A good result is a better video than "
    "a bad one. Don't act disappointed.",
])

rule(doc)

heading(doc, "The five foods", size=16, before=8)
rich(doc, "Type the name into the app's search exactly as written. The score is what shows "
          "**before** you pick your dog.", size=10, after=8)
table(doc,
      ("", "Search for this", "Score before you pick your dog", "Warnings it shows"),
      [("1", "Purina ONE Lamb and Rice", "93 · Caution", "menadione"),
       ("2", "Pedigree Adult Beef and Lamb", "90 · Caution",
        "BHA, BHT, Red 40, Yellow 5, Yellow 6, Blue 2"),
       ("3", "Purina Dog Chow Lamb Flavor", "91 · Caution",
        "menadione, Red 40, Yellow 5, Yellow 6, Blue 2"),
       ("4", "Purina Dog Chow Complete Adult", "88 · Caution",
        "garlic, menadione, Red 40, Yellow 5, Yellow 6, Blue 2"),
       ("5", "In store — scan whatever's on the shelf", "varies", "varies")],
      widths=(0.3, 2.25, 1.6, 2.45), bold_col=1)

rich(doc, "In every script that score drops to **0 out of 100 — \"Avoid\"** the moment you pick "
          "a dog who reacts to something in the list. **That flip is the entire video.** "
          "Everything before it is setup.", before=10, after=4)

rich(doc, "Every script ends by asking people to go check their own bag. That line isn't "
          "optional — it's what makes people comment, and comments are what make these spread.",
     before=4, after=4)

doc.add_page_break()

# ------------------------------------------------------------ 1 · betrayal

script_header(
    doc, 1, "Everything here eats what it should. Except the dog.",
    "Search: Purina ONE Lamb and Rice  ·  Your dog reacts to: wheat or corn  ·  No props",
    "Lamb genuinely **is** ingredient #1 — say so, it's what makes the rest land. But corn is "
    "**#3**, wheat is **#4**, and chicken by-product meal is **#5**. The \"lamb and rice\" bag is "
    "corn and wheat by the third line. **93 · Caution → 0 · Avoid.**")

cut_label(doc, "30-second version")
shotlist(doc, [
    ("0–5s", "Outside if you can, animals visible. Gesture at them, then back at the house.",
     "\"Everything on this farm eats exactly what it's meant to eat. Except the dog.\"\nOn screen: except the dog"),
    ("5–10s", "You with the phone, dog in shot if he'll cooperate.",
     "\"He eats whatever I pick up in a shop. So I finally read one.\""),
    ("10–18s", "Ingredient list. Hold still on #3 and #5.",
     "\"Lamb's genuinely first, I'll give them that. Third is corn. Fourth is wheat. Fifth is chicken by-product meal.\"\nOn screen: #3 corn · #4 wheat"),
    ("18–23s", "The score.",
     "\"Ninety-three out of a hundred. Caution. Caution for which dog, though?\""),
    ("23–28s", "Tap [DOG NAME]'s profile. Red zero. One take.",
     "\"Put [DOG NAME] in. Zero. Avoid.\"\nOn screen: 0/100 · AVOID"),
    ("28–30s", "Dog. Two-second end card.",
     "\"Lamb on the front. Corn in the bag.\""),
])

cut_label(doc, "60-second version")
vo(doc, "0–10s · Hook — outside, animals in shot, no phone yet",
   "Everything on this farm eats exactly what it's meant to eat. The [ANIMALS — goats, ducks, "
   "chickens] get what grows here or what I measure out for them. Except the dog. The dog gets "
   "whatever I decide to pick up in a shop that week.")
vo(doc, "10–20s · The admission — the late-discovery beat",
   "And in [NUMBER] years I have never turned one of those bags over. Not once. Why would I? It "
   "says lamb on the front. Big letters, picture of a lamb. That's what I thought I was buying "
   "and that's what [DOG NAME] has been living on.")
vo(doc, "20–38s · The list — hold it still",
   "So here it is. Lamb, first ingredient — that's real, and I'm not going to pretend it isn't. "
   "Rice flour, fine. Then number three is **whole grain corn.** Number four is **whole grain "
   "wheat.** Number five, **chicken by-product meal.** So the lamb and rice food is corn and "
   "wheat before you're four lines down.")
vo(doc, "38–52s · The two scores",
   "It scores ninety-three. Caution. And I'm sure that's perfectly reasonable for the average "
   "dog. I've never met the average dog. I've got [DOG NAME], who [FILL — e.g. has chewed his "
   "feet raw since he was two]. So I put him in — same bag, same screen — **zero. Avoid.**")
vo(doc, "52–60s · Close",
   "I'm not even angry at them, really. The bag did what bags do. I'm annoyed at me, for taking "
   "[NUMBER] years to turn one over. Go and turn over whatever's in your feed bin.")

doc.add_page_break()

# ------------------------------------------------------- 2 · curiosity gap

script_header(
    doc, 2, "Who is the colour for?",
    "Search: Pedigree Adult Beef and Lamb  ·  Your dog reacts to: corn  ·  No props",
    "The most-flagged food in the pack — **BHA, BHT, Red 40, Yellow 5, Yellow 6, Blue 2** — and "
    "four of those six exist only to make it a colour. Corn is **#1**, chicken by-product meal is "
    "**#5**. **90 · Caution → 0 · Avoid.**")

cut_label(doc, "30-second version")
shotlist(doc, [
    ("0–5s", "Kibble poured onto a white plate. Let the colours sit there.",
     "\"There are four dyes in this dog food. Dogs are colourblind. So who's the colour for?\"\nOn screen: who is the colour for?"),
    ("5–9s", "You, holding the plate up.",
     "\"It's for me. It's decoration, for the person paying.\""),
    ("9–16s", "Ingredient list, held still on the first three.",
     "\"Corn's first. Corn again at three. Chicken by-product meal at five.\""),
    ("16–24s", "The warnings.",
     "\"BHA. BHT. Red 40. Yellow 5. Yellow 6. Blue 2. Six things flagged on one bag.\""),
    ("24–28s", "Score, then [DOG NAME]'s profile. Red zero.",
     "\"Ninety, caution. For [DOG NAME] — corn — zero. Avoid.\""),
    ("28–30s", "Two-second end card.", "\"Go tip yours out and look at it.\""),
])

cut_label(doc, "60-second version")
vo(doc, "0–10s · Hook — pour it out on something white first, then talk",
   "There are four separate dyes in this dog food. **Red 40. Yellow 5. Yellow 6. Blue 2.** Dogs "
   "are basically colourblind. So somebody needs to explain to me who the colour is actually for.")
vo(doc, "10–20s · Answer your own question, then widen it",
   "It's for me. It's decoration for the person stood in the aisle deciding whether this looks "
   "like food. And once you've clocked that, you start wondering what else in the bag is for me "
   "rather than for him.")
vo(doc, "20–38s · The list and the rest of the flags",
   "Ground whole grain corn. Meat and bone meal. Corn protein meal — that's corn twice in the "
   "first three. Soybean meal. Chicken by-product meal. Then animal fat, which the label itself "
   "says is preserved with **BHA**, and there's **BHT** further down. Six separate things flagged "
   "on one bag. And this isn't a weird brand off the internet — it's on the shelf at [STORE].")
vo(doc, "38–50s · Be fair. It's what keeps people listening.",
   "And to be straight about it — ninety. That's what it scores. Nobody is calling this stuff "
   "dangerous, me least of all. It's caution, and most of what got flagged had no business being "
   "in there to begin with. Then I add [DOG NAME], corn on his profile: **zero. Avoid.**")
vo(doc, "50–60s · Close  [YOUR FOOD] optional — honest either way",
   "Then I did the bag in my own feed bin. [Say what really happened.] Either way I'd sooner know "
   "than not. Tip yours out on a white plate and have a proper look.")

doc.add_page_break()

# --------------------------------------------------------------- 3 · fear

script_header(
    doc, 3, "Two in the morning, every night",
    "Search: Purina Dog Chow Lamb Flavor  ·  Your dog reacts to: corn  ·  No props",
    "**The most important video in the pack.** Corn is **#1**, chicken by-product meal is **#2** "
    "— and **lamb meal doesn't turn up until #12, behind the salt.** Flags: menadione and four "
    "dyes. **91 · Caution → 0 · Avoid.**")

callout(doc,
        "**Don't soften this one.** The rest of the pack is you being irritated. This one is you "
        "being worried, and that's allowed — it's your dog and your house and you don't have to "
        "be measured about it. Same rules as everywhere else and no others: don't invent "
        "anything, and don't say the app called it something it didn't. Otherwise, say it "
        "exactly as hard as it felt.",
        fill="FDF3F1")

cut_label(doc, "30-second version")
shotlist(doc, [
    ("0–6s", "Dark, or early morning. You, tired. Quiet delivery — don't perform it.",
     "\"I have listened to my dog scratch himself awake at two in the morning for [NUMBER] years.\"\nOn screen: [NUMBER] years"),
    ("6–13s", "You, to camera.",
     "\"[FILL — what you tried. Vet, ear drops, the wipes, changing his bedding.] Nobody asked what was in the bag.\""),
    ("13–20s", "Phone: the list, held still on #1 — then keep going to #12.",
     "\"Corn, first. Chicken by-product meal, second. Lamb — the thing on the front — is twelfth. Behind the salt.\""),
    ("20–26s", "Score, then his profile. Red zero. One take.",
     "\"Ninety-one, caution. His profile, corn — zero. Avoid.\"\nOn screen: 0/100 · AVOID"),
    ("26–30s", "Dog, asleep. Two-second end card.",
     "\"[NUMBER] years. It was printed on the bag.\""),
])

cut_label(doc, "60-second version")
vo(doc, "0–10s · Hook — quiet and tired, not dramatic",
   "I have lain in bed and listened to my dog scratch himself awake at two in the morning for "
   "[NUMBER] years. If you've got one that does it you know the noise — the collar going, the "
   "thumping against the floor — and you know you're not getting back to sleep either.")
vo(doc, "10–26s · Your real story. Don't rush to the phone.",
   "[FILL IN — the real one. How long. What he looked like. The vet trips, the drops, the "
   "steroids, the special bedding, the thing your mother-in-law swore by.] And the whole time I "
   "was the one filling the bowl. Twice a day. That's the part I can't quite get past.")
vo(doc, "26–42s · The list — hold it, let people count",
   "Whole grain corn, first. Chicken by-product meal, second. Corn gluten meal. Meat and bone "
   "meal. Beef fat. Soybean meal. Ground rice. Natural flavour. Salt. And then — number twelve — "
   "**lamb meal.** The word that's on the front of the bag is the twelfth thing in it, behind the "
   "salt.")
vo(doc, "42–54s · The flip",
   "The app gives it ninety-one. Caution. For dogs as a general concept, fine. Then I put **him** "
   "in, with corn on his profile, and it's **zero. Avoid.** That took a second. It took me "
   "[NUMBER] years to work out on my own.")
vo(doc, "54–60s · Close — no promises",
   "A bag of kibble does not explain a whole dog, and I won't pretend otherwise. What I'll own is "
   "that I never checked. Do yours before bed.")

doc.add_page_break()

# ------------------------------------------------------------ 4 · surprise

script_header(
    doc, 4, "Hang on — there's garlic in it",
    "Search: Purina Dog Chow Complete Adult  ·  Your dog reacts to: corn  ·  No props",
    "Six flags again but a different six, and one of them is **garlic** — the one that stops the "
    "scroll. Also **menadione** and four dyes. Corn **#1**, chicken by-product meal **#6**. "
    "**88 · Caution → 0 · Avoid.**")

callout(doc,
        "**Say this one carefully.** \"The app flagged garlic and I did not expect that\" is true "
        "and it is enough. Do **not** say it will poison him — it's a small amount, the app says "
        "caution rather than avoid, and if you overstate it the comments will correct you and the "
        "video dies. Let the ingredient be surprising on its own.",
        fill="FDF3F1")

cut_label(doc, "30-second version")
shotlist(doc, [
    ("0–5s", "You mid-scroll on the phone, genuine double take.",
     "\"I was reading a dog food label and I had to stop. There is garlic in it.\"\nOn screen: garlic?"),
    ("5–10s", "The warnings list on screen.",
     "\"That's not me saying that. That's the app flagging it.\""),
    ("10–17s", "Scroll the warnings, hold on them.",
     "\"Garlic. Menadione. Then Red 40, Yellow 5, Yellow 6, Blue 2.\""),
    ("17–22s", "Top of the ingredient list.",
     "\"First ingredient's corn. Chicken by-product meal is sixth.\""),
    ("22–28s", "Score, then [DOG NAME]'s profile. Red zero.",
     "\"Eighty-eight, caution. For [DOG NAME] — zero. Avoid.\"\nOn screen: 0/100 · AVOID"),
    ("28–30s", "Two-second end card.", "\"I'd just never looked.\""),
])

cut_label(doc, "60-second version")
vo(doc, "0–10s · Hook — genuine surprise, don't oversell",
   "I was going through dog food labels, which is apparently my life now, and I stopped — because "
   "one of the things this app flagged was **garlic.** In dog food. I read it twice.")
vo(doc, "10–24s · Be fair immediately. This is what keeps you credible.",
   "Now I'm not going to stand here and tell you this bag is going to hurt your dog, because "
   "that's not what it says and it's not what I think. The app doesn't say avoid, it says "
   "caution, and it's a small amount. But I've had dogs my whole life and I did not know garlic "
   "turned up in an ordinary supermarket bag at all.")
vo(doc, "24–40s · The rest of it",
   "And it isn't only that. **Menadione** — a synthetic form of vitamin K. Then **Red 40, Yellow "
   "5, Yellow 6, Blue 2.** Four dyes again. Meanwhile the first ingredient is corn and chicken "
   "by-product meal turns up sixth. Six things flagged on a bag plenty of people are pouring out "
   "tonight.")
vo(doc, "40–52s · The flip",
   "Score's eighty-eight. Caution. Which — for dogs generally, fine. But I picked [DOG NAME]'s "
   "profile, because corn is the first thing in the bag and corn is his entire problem, and it "
   "went to **zero. Avoid.** Same bag, one tap.")
vo(doc, "52–60s · Close",
   "I'm not telling anybody what to feed their dog. I'm telling you I fed mine for years without "
   "ever turning the bag round. Go and turn yours round.")

doc.add_page_break()

# ------------------------------------------------------------- 5 · relief

script_header(
    doc, 5, "I scanned the whole dog food aisle",
    "In store — pet shop, feed store or supermarket  ·  [DOG NAME]'s profile loaded before you go  ·  Shop-with-me",
    "The only script that needs a trip out, and the one to pin to your profile. Here you **scan "
    "the barcodes on the shelf** rather than searching — same result, far better to watch. Scan "
    "four or five, and make sure one of them comes back **well**.")

callout(doc,
        "**Before you leave:** make sure [DOG NAME]'s profile is set up and selected. The entire "
        "point of this one is that the scores are *his*.\n"
        "**In the shop:** don't block the aisle, don't film other customers or staff, don't open "
        "any packaging, and if anyone asks you to stop filming then stop — we'll use whatever you "
        "already got.")

cut_label(doc, "30-second version")
shotlist(doc, [
    ("0–5s", "Walking in, phone up, aisle in shot.",
     "\"I'm going to scan every dog food on this shelf with my dog's actual allergies loaded in.\""),
    ("5–11s", "Scan bag one. Score appears over the shelf.",
     "\"This one — [SCORE]. Caution.\""),
    ("11–18s", "Two more, quickly. Keep the shelf in frame.",
     "\"[SCORE]. [SCORE]. Corn, corn, corn.\""),
    ("18–24s", "Scan one that comes back badly for him. Red zero.",
     "\"Zero. Avoid — for [DOG NAME]. Not for every dog. For mine.\"\nOn screen: 0/100 · AVOID"),
    ("24–30s", "You holding whichever scored best. Two-second end card.",
     "\"Four minutes. I've been guessing for years.\""),
])

cut_label(doc, "60-second version")
vo(doc, "0–10s · Hook — in the car park or at the end of the aisle",
   "I'm about to walk into a pet shop and scan every bag on the dog food shelf. Not to be "
   "dramatic about it — because I've got [DOG NAME]'s allergies loaded into this thing, so "
   "whatever it tells me is about **him**, not about dogs in general.")
vo(doc, "10–26s · First scans — keep moving, keep the shelf visible",
   "Right. This one — [SCORE], caution. This one — [SCORE]. This is the one I nearly bought last "
   "month... [SCORE]. And I'm watching the same words come up over and over again. Corn. Corn "
   "gluten meal. Chicken by-product meal. Dyes.")
vo(doc, "26–40s · The one that flips",
   "Now this one. [SCAN IT.] **Zero. Avoid.** And that's not the app saying it's bad food — it "
   "scores fine for dogs generally. It's saying it's a no for [DOG NAME], because [corn / soy / "
   "wheat] is sat right there in the first few ingredients, which is exactly what he reacts to.")
vo(doc, "40–52s · Land it well. This is the one that ends happy.",
   "And then this one comes back [SCORE] — best thing on the shelf for him. That's what I came in "
   "for. Not a lecture about the aisle. Just which one goes in the trolley.")
vo(doc, "52–60s · Close",
   "Four minutes, stood in a shop, on my phone. I have been guessing for years. Do it on your "
   "next shop — it's free.")

doc.add_page_break()

# ----------------------------------------------------------------- brief

heading(doc, "What we need from you", size=18, before=0)
rich(doc, "Every [SQUARE BRACKET] is a blank only you can fill. Nothing here should be invented "
          "— the whole reason these work is that they're true.", after=10)
bullets(doc, [
    "**[DOG NAME]**, and roughly what he reacts to.",
    "**One real sensitivity.** It needs to be **corn, soy or wheat** — those are what these foods "
    "actually flag. **Not chicken**, on any of the five.",
    "**If he hasn't got a known sensitivity**, that's completely fine — say so on camera. \"Let "
    "me show you what happens if I put corn in\" is honest. \"[DOG] reacts to corn\" when he "
    "doesn't, isn't. Tell us and we'll reword it.",
    "**Script 3 needs a real story** — how long it went on, what you tried, what it was like at "
    "two in the morning. It's the one that'll travel furthest and it only works if it happened.",
    "**What you actually feed** (Scripts 2 and 5, optional) — read out whatever score it gets. A "
    "clean result makes a better video.",
    "**Which store for Script 5**, so we know what's likely to be on the shelf.",
    "**Your median views per post** — not follower count. It's the only way to tell whether a "
    "video worked because of the idea rather than the audience. A screenshot of your analytics "
    "after each post is ideal.",
])

heading(doc, "Filming notes", size=14, before=14, after=4)
bullets(doc, [
    "**Search, don't scan — except Script 5.** You don't need the bag at home, and searching is "
    "the better demo: it proves you can check a food you don't even own yet.",
    "**Hold the ingredient list still for a couple of seconds.** People pause and screenshot it.",
    "**The profile switch is the shot.** One take, no cut between the two scores, no re-searching.",
    "**Shoot the 30 first, then the 60.** Same setup, same day, same clothes.",
    "**Vertical, natural light, your normal voice.** Farm noise, kids, animals wandering through "
    "— all good, all of it helps.",
    "**Don't post them all at once** — one a week or so, or they compete with each other.",
    "**Expect arguments in the comments**, especially on Scripts 2 and 4. That's good, it's how "
    "these travel. Answer with the ingredient list rather than an opinion, and don't delete "
    "people.",
])

doc.save(OUT)
print(f"wrote {OUT}")
