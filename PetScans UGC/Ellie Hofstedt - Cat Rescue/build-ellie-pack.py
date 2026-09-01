#!/usr/bin/env python3
"""Render Ellie Hofstedt's cat UGC script pack as a creator-facing .docx.

Usage:  ../../PetScans-Meta-Campaign/venv/bin/python build-ellie-pack.py

This file holds the creator-facing copy and is the source of truth for the
dialogue. Verification data — scores, labels, flags, and which allergens are
safe to name — is in ugc-scripts-cat-rescue.md in this folder, produced with
`verify-products.py check`.

Creator: runs a small cat rescue, multiple cats. Rescue mentioned once, lightly.
Posts organically to her own account; nothing here is an ad.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ugc_docx import (bullets, callout, cover, cut_label, heading, new_doc,
                      rich, rule, script_header, shotlist, table, vo)

OUT = Path(__file__).parent / "PetScans-UGC-Scripts-Ellie-Hofstedt.docx"

doc = new_doc()

cover(doc, "PetScans", "UGC Script Pack — Ellie Hofstedt", [
    "Five scripts. Each has a **30-second version** and a **60-second version** of "
    "the same story — shoot both back to back, same setup, same day. Do the 30 first.",
    "**You don't need to buy any of this food.** Everything happens inside the app's "
    "search: type the product name and the whole ingredient list and score come up. "
    "All you need is your phone and your cats.",
    "These are posts to your own account, in your own voice. They are not ads and "
    "they shouldn't sound like ads.",
])

rule(doc)

heading(doc, "Before you shoot", size=16, before=4)
rich(doc, "**What you need:** your phone, your cats, and a profile set up in the app for "
          "each cat — name, and whatever they react to.", after=6)
rich(doc, "**If you happen to have a bag or a can on hand**, there are optional shots marked "
          "[BAG] and [YOUR FOOD]. Bonus, not required. Every script works without them.", after=10)

heading(doc, "How to talk on camera", size=13, before=8, after=4)
bullets(doc, [
    "**Say it how you actually feel it.** This isn't medical advice and you're not a vet. You "
    "don't have to be careful, balanced or clinical about your own cats, your own opinion, or "
    "how angry any of this makes you. Be as blunt as you are in real life.",

    "**Just never make anything up.** No cat that doesn't exist, no symptom that didn't happen, "
    "no vet visit that wasn't. Anywhere you see [SQUARE BRACKETS], that's a blank only you can "
    "fill — put something real in it.",

    "**Anything you say the app said has to match the screen.** The score, the Caution or Avoid "
    "label, the warnings it lists, where an ingredient sits in the list. Call an ingredient "
    "whatever you like — just don't put words in the app's mouth.",

    "**Chicken only works on Scripts 1 and 4.** On those two the app genuinely flags chicken. "
    "On 2, 3 and 5 it doesn't — it records the by-product differently — so use corn there. You "
    "can still read \"chicken by-product meal\" off the list in any script. That's just reading "
    "the label out loud, and it's true.",

    "**No medical claims.** No diagnosing, no treatment advice, no \"this caused it\" or \"this "
    "cured it.\" What happened to your cats is yours to tell. What'll happen to someone else's "
    "isn't.",

    "**Film the real app.** Real screen recordings, real numbers. If something on your screen "
    "doesn't match this document, film what's on your screen and tell us — we'll fix the script, "
    "never the footage.",

    "**The profile switch is one unbroken take.** Don't cut between the two scores and don't "
    "search the product again in between, or the comments will say it was two different foods.",

    "**Show the app as long as it's interesting — but the logo gets 2 seconds.** Hold the "
    "ingredient list still so people can pause and screenshot it. The branded end card at the "
    "finish is two seconds, once, and that's it.",

    "**If your own food scores well, say so.** Genuinely. A clean result is a better video than "
    "a bad one. Don't act disappointed.",
])

rule(doc)

heading(doc, "The five foods", size=16, before=8)
rich(doc, "Type the name into the app's search exactly as written. The score is what shows "
          "**before** you pick a cat.", size=10, after=8)
table(doc,
      ("", "Search for this", "Score before you pick a cat", "Warnings it shows"),
      [("1", "Purina ONE Tender Selects Salmon", "91 · Caution", "menadione"),
       ("2", "Meow Mix Tender Centers", "89 · Caution",
        "BHA, menadione, titanium dioxide, Red 40, Yellow 5, Yellow 6"),
       ("3", "Meow Mix Original Choice", "93 · Caution", "Red 40, Yellow 5, Yellow 6, Blue 2"),
       ("4", "9Lives Meaty Pate with Real Chicken", "89 · Caution",
        "menadione, sodium nitrite, titanium dioxide"),
       ("5", "Friskies Gravy Swirl'd", "93 · Caution", "menadione, Red 40, Yellow 5")],
      widths=(0.3, 2.3, 1.55, 2.45), bold_col=1)

rich(doc, "In every script that score drops to **0 out of 100 — \"Avoid\"** the second you pick "
          "a cat who reacts to something in the list. **That flip is the whole video.** "
          "Everything before it exists to set it up.", before=10, after=4)

rich(doc, "Every script ends by asking people to go check their own bag. That line is not "
          "optional — it's the thing that makes people comment, and the comments are what make "
          "these travel.", before=4, after=4)

doc.add_page_break()

# ------------------------------------------------------------ 1 · betrayal

script_header(
    doc, 1, "The bag says salmon",
    "Search: Purina ONE Tender Selects Salmon  ·  Cat who reacts to: chicken  ·  No props",
    "Salmon really is the first ingredient — say so, it's what makes the rest land. But "
    "**chicken by-product meal is #4** and plain **chicken is #13**. The salmon food you bought "
    "*because* your cat can't do chicken is four ingredients deep in it. **91 · Caution → 0 · Avoid.**")

cut_label(doc, "30-second version")
shotlist(doc, [
    ("0–5s", "Cat in your lap. You're already annoyed. No phone in shot yet.",
     "\"If your cat can't do chicken, you have bought the salmon one. Everybody buys the salmon one.\"\nOn screen: everybody buys the salmon one"),
    ("5–10s", "You pick up the phone, type the name into search.",
     "\"I didn't even need the bag. I just searched the name.\""),
    ("10–18s", "The ingredient list. Hold it still on #4, then #13.",
     "\"Salmon is genuinely first, I'll give them that. Fourth — chicken by-product meal. Thirteenth — chicken.\"\nOn screen: #4 · #13"),
    ("18–23s", "The score.",
     "\"Ninety-one. Caution. Which tells me exactly nothing.\""),
    ("23–28s", "Tap [CAT NAME]'s profile. Red zero. One take, no cut.",
     "\"Then I pick [CAT NAME], who can't do chicken. Zero. Avoid.\"\nOn screen: 0/100 · AVOID"),
    ("28–30s", "Cat. Two-second end card.",
     "\"Go and read the back of yours.\""),
])

cut_label(doc, "60-second version")
vo(doc, "0–9s · Hook — no phone, just you and the cat",
   "This is for everybody who's got a cat that can't do chicken. You have done exactly what I "
   "did. You stood in that aisle, and you picked up the salmon one. Because it says salmon on it.")
vo(doc, "9–20s · Rescue, once, then move past it",
   "I run a small rescue, so I have bought more bags of the salmon one than I could count. And "
   "not once did I turn one over. Why would you? It says salmon. Enormous letters. Picture of a "
   "fish.")
vo(doc, "20–38s · The list — hold it still, let people read",
   "Here's what's actually in it. Salmon, first — genuinely, that's real, I'm not going to "
   "pretend otherwise. Rice flour. Corn gluten meal. Then number four: **chicken by-product "
   "meal.** And keep going, because number thirteen is just... chicken. The word chicken.")
vo(doc, "38–52s · The two scores",
   "App says ninety-one. Caution. Fine — that's a score for cats as a concept, and I don't own a "
   "concept, I own [CAT NAME]. So I pick him. Same food, same screen, one tap: **zero. Avoid.**")
vo(doc, "52–60s · Close — the ask is the point",
   "Nobody lied to me on the front of that bag. They just didn't answer the question I was "
   "asking. Go and read the back of whatever's in your cupboard. It's free and it takes a minute.")

doc.add_page_break()

# ------------------------------------------------------- 2 · curiosity gap

script_header(
    doc, 2, "Six warnings on one bag",
    "Search: Meow Mix Tender Centers  ·  Cat who reacts to: corn  ·  No props  ·  NOT chicken here",
    "The most-flagged food in the pack: **BHA, menadione, titanium dioxide, Red 40, Yellow 5, "
    "Yellow 6.** Corn is **#1**, chicken by-product meal is **#2**. **89 · Caution → 0 · Avoid.**")

cut_label(doc, "30-second version")
shotlist(doc, [
    ("0–4s", "Straight to camera. Flat delivery — let the number do it.",
     "\"I found a cat food with six separate warnings on it. Six.\"\nOn screen: six. one bag."),
    ("4–9s", "Search, the product loads.",
     "\"And it's not obscure. You've walked past this in a normal shop.\""),
    ("9–14s", "Top of the ingredient list, held still.",
     "\"Corn first. Chicken by-product meal second.\""),
    ("14–23s", "The warnings. Read them off as each appears.",
     "\"BHA. Menadione. Titanium dioxide. Red 40. Yellow 5. Yellow 6.\"\nOn screen: each one stamps on as you say it"),
    ("23–28s", "Score, then [CAT NAME]'s profile. Red zero.",
     "\"Eighty-nine, caution. For [CAT NAME] — corn — zero. Avoid.\""),
    ("28–30s", "Two-second end card.", "\"Go count yours.\""),
])

cut_label(doc, "60-second version")
vo(doc, "0–8s · Hook — hold the number, don't rush it",
   "Six. Six separate ingredient warnings, on one bag, and it is a brand you have absolutely "
   "walked past in an ordinary supermarket without thinking about it.")
vo(doc, "8–20s · The list  [BAG] — use the real bag if you've got one",
   "Whole ground corn. Chicken by-product meal. Corn gluten meal. Soybean meal. Animal fat. Whole "
   "wheat. Animal digest — which is a genuine term that means what you think it means.")
vo(doc, "20–38s · The warnings, slowly. This is the payload.",
   "Now the six. **BHA** — preservative. **Menadione** — synthetic vitamin K. **Titanium "
   "dioxide**, which is a whitener. Then **Red 40, Yellow 5, Yellow 6.** So four of the six "
   "things flagged on this bag are there to change what it *looks* like. My cat is colourblind. "
   "That's not for her. That's for me.")
vo(doc, "38–50s · Be fair — this is what makes people trust you",
   "And I'll be straight with you: it still scores eighty-nine. The app is not calling this "
   "dangerous and neither am I. It says caution. But then I put [CAT NAME] in — corn, first "
   "ingredient — and it's **zero. Avoid.** That's the first number in this that was about her.")
vo(doc, "50–60s · Close  [YOUR FOOD] optional — be honest either way",
   "I ran the one I actually feed through it too. [Say what really happened — a good score is a "
   "better video.] Go count the warnings on yours.")

doc.add_page_break()

# --------------------------------------------------------------- 3 · fear

script_header(
    doc, 3, "Four months of her chewing herself",
    "Search: Meow Mix Original Choice  ·  Cat who reacts to: corn  ·  No props  ·  NOT chicken here",
    "**The most important video in the pack.** Corn is **#1**, chicken by-product meal is **#2**, "
    "and the app flags **four dyes**. **93 · Caution → 0 · Avoid.**")

callout(doc,
        "**Do not soften this one.** Every other script in this pack is you being annoyed. This "
        "one is you being frightened, and that's allowed — it's your cat and it's your story, and "
        "you don't have to be measured about it. The only rule that still applies is the same as "
        "everywhere else: don't invent anything, and don't say the app called it something it "
        "didn't. Be as raw as it actually was.",
        fill="FDF3F1")

cut_label(doc, "30-second version")
shotlist(doc, [
    ("0–6s", "Close on the cat. Or on the patch, if she'll let you. Quiet delivery.",
     "\"There's a sound a cat makes when she's been licking the same patch of skin for months. I can still hear it.\"\nOn screen: [MONTHS] months"),
    ("6–12s", "You, to camera. Don't perform it.",
     "\"[FILL — what you tried. Vets, sprays, the cone, the special shampoo.] Nobody once asked what she was eating.\""),
    ("12–19s", "Phone: search, the ingredient list, held still on #1.",
     "\"Corn. First ingredient. Then chicken by-product meal. Then more corn.\""),
    ("19–25s", "Score, then her profile. Red zero. One take.",
     "\"Ninety-three, caution. Her profile — corn — zero. Avoid.\"\nOn screen: 0/100 · AVOID"),
    ("25–30s", "The cat now. Two-second end card.",
     "\"Four months. It was on the bag the whole time.\""),
])

cut_label(doc, "60-second version")
vo(doc, "0–10s · Hook — quiet, not dramatic. Let it be uncomfortable.",
   "There is a specific sound a cat makes when she has been licking the same patch of skin for "
   "months. If you have lived with it you know exactly the sound I mean, and you probably hear it "
   "at two in the morning.")
vo(doc, "10–26s · Your real story. This is the whole video — don't rush to the app.",
   "[FILL IN — the real one. How long it went on. What she looked like. What you tried: the vet, "
   "the cone, the spray, the shampoo everybody swears by, the steroids.] And the entire time I "
   "was standing in my own kitchen twice a day putting the cause of it in a bowl.")
vo(doc, "26–40s · The list — hold it, don't scroll",
   "Ground corn — first ingredient. Chicken by-product meal, second. Soybean meal. Corn protein "
   "meal. Four things in and nothing has been meat yet. Plus four dyes, for an animal that cannot "
   "see colour.")
vo(doc, "40–52s · The flip",
   "The app scores it ninety-three. Caution. For cats in general — sure. Then I put **her** in, "
   "with the corn on her profile, and the same bag goes to **zero. Avoid.** That took about a "
   "second. It took me [FILL — months] to get there on my own.")
vo(doc, "52–60s · Close — no promises, just the ask",
   "I'm not telling you food fixes everything, because it doesn't. I'm telling you I spent [FILL] "
   "not knowing what was in the bag. Go and read yours tonight.")

doc.add_page_break()

# --------------------------------------------------------- 4 · guilt/love

script_header(
    doc, 4, "The donation bin",
    "Search: 9Lives Meaty Pate with Real Chicken  ·  Cat who reacts to: chicken  ·  No props",
    "Wet food, so a different shelf and a different audience. Front of the can says \"with real "
    "chicken\" — the **first ingredient is meat by-products**, and chicken is **#3**. Flags: "
    "**menadione, sodium nitrite, titanium dioxide**. **89 · Caution → 0 · Avoid.**")

cut_label(doc, "30-second version")
shotlist(doc, [
    ("0–5s", "You, with donated tins if you have them. Warm, not cross.",
     "\"People drop food off for the rescue constantly and it is genuinely kind. I still check every single tin.\"\nOn screen: every tin gets checked"),
    ("5–10s", "Search the wet food, the list loads.",
     "\"Front of this one says 'with real chicken.'\""),
    ("10–17s", "Ingredient list, held still on #1.",
     "\"First ingredient is meat by-products. Chicken's third.\""),
    ("17–23s", "The warnings.",
     "\"Menadione. Sodium nitrite. Titanium dioxide — that one's a whitener. It's there to make it look pinker.\""),
    ("23–28s", "Score, then a chicken-sensitive cat's profile. Red zero.",
     "\"Eighty-nine, caution. For a cat who reacts to chicken — zero. Avoid.\""),
    ("28–30s", "Cat. Two-second end card.", "\"Check what's in your cupboard.\""),
])

cut_label(doc, "60-second version")
vo(doc, "0–9s · Hook — be genuinely warm here, it's the whole point",
   "People bring food to the rescue all the time, and I want to be really clear that it's kind and "
   "we are grateful for every tin of it. I also check every single one before it goes near a cat, "
   "and here's why.")
vo(doc, "9–20s · The real problem a rescue has",
   "A donated tin arrives with no story. I don't know if it came from a cat who was fine on it or "
   "a cat who stopped eating it. I can't ask the cat. All I've got is the list on the back, and "
   "I'm not a nutritionist — I'm somebody with a spare room full of animals.")
vo(doc, "20–38s · The can",
   "So — this one. Front of it says **with real chicken**, big picture. Turn it over: first "
   "ingredient, meat by-products. Chicken is third. And the flags are menadione, sodium nitrite, "
   "and **titanium dioxide** — which is a whitener. It is in there so the pate is a nicer colour "
   "for the person holding the tin. The cat could not care less.")
vo(doc, "38–52s · The flip",
   "Eighty-nine, caution. Then I pull up a profile for one of mine who reacts to chicken — and "
   "chicken **is** in there, third — and it's **zero. Avoid.** Thirty seconds, on a tin somebody "
   "handed me in a car park.")
vo(doc, "52–60s · Close",
   "If somebody gives you food for your animal, take it, be grateful — and then read the back of "
   "it. Go do the one you've already got open.")

doc.add_page_break()

# ------------------------------------------------------------- 5 · relief

script_header(
    doc, 5, "Same tin. Four cats. Four different answers.",
    "Search: Friskies Gravy Swirl'd  ·  Your actual cats — at least one who reacts, one who doesn't  ·  No props",
    "Corn **#1**, corn protein meal **#2**, chicken by-product meal **#3**. Flags menadione, Red "
    "40, Yellow 5. **93 · Caution** with a cat who's fine — **0 · Avoid** the instant you switch "
    "to one who isn't. Same food, no re-searching. **This is the one to pin to your profile.**")

cut_label(doc, "30-second version")
shotlist(doc, [
    ("0–5s", "As many cats in frame as you can manage.",
     "\"I've got [NUMBER] cats and every app I've ever tried thinks they're the same animal.\""),
    ("5–11s", "Product on screen, [CAT A] selected. 93.",
     "\"Same bag. For [CAT A] it's a caution. She's fine.\""),
    ("11–19s", "DO NOT search again. Only tap the profile switcher. Score flips red.",
     "\"Switch to [CAT B]. Same bag, same screen. Zero. Avoid.\"\nOn screen: 0/100 · AVOID"),
    ("19–25s", "Switch again to [CAT C].",
     "\"[CAT C]. Different again. I didn't change the food. I changed whose stomach it's going into.\""),
    ("25–30s", "To camera. Two-second end card.",
     "\"One score for every cat alive is just a guess with a number on it.\""),
])

cut_label(doc, "60-second version")
vo(doc, "0–10s · Hook — cats visible, affectionate not exasperated",
   "I have [NUMBER] cats. One is [FILL — e.g. seventeen and has four teeth]. One arrived [FILL — "
   "e.g. off a building site with a stomach that hated everything]. One is a completely ordinary "
   "cat with no problems whatsoever, who I resent slightly. They all eat out of the same bag.")
vo(doc, "10–24s · Name the actual gap",
   "And every food app I've tried gives that bag one score. One number, for every cat that has "
   "ever existed. Which means it is answering a question I have genuinely never asked. I don't "
   "need to know if this is good cat food. I need to know if it's alright for the one currently "
   "sitting in my sink.")
vo(doc, "24–44s · The demo — ONE continuous recording, no cuts, don't re-search",
   "So watch, because this is the only reason the app is still on my phone. Here's the bag. "
   "Ninety-three, caution — it's flagging menadione, Red 40, Yellow 5. With [CAT A] selected, "
   "that's my answer and she's fine. Now I'm not searching anything again. I'm just tapping her "
   "face and choosing [CAT B]. Same bag, same screen, one second — **zero. Avoid.** Because corn "
   "is the first thing in it. Tap again — [CAT C] — different answer again.")
vo(doc, "44–54s · Land it on relief. This is the one that ends well.",
   "And that's the bit I actually wanted. Not a list of everything that's wrong with the "
   "cupboard. Just: which of them is this one for. I know that now, in about four seconds, "
   "standing in the kitchen.")
vo(doc, "54–60s · Close",
   "If there's more than one animal in your house, this is the bit that'll get you. Go and put "
   "them in.")

doc.add_page_break()

# ----------------------------------------------------------------- brief

heading(doc, "What we need from you", size=18, before=0)
rich(doc, "Every [SQUARE BRACKET] is a blank only you can fill. Nothing in these scripts should "
          "be invented — the entire reason they work is that they're true.", after=10)
bullets(doc, [
    "**Your cats' names and how many you have.** Used in every script.",
    "**One real sensitivity per script.** It has to be **corn** or **chicken** — those are what "
    "these foods actually flag — and chicken only works on Scripts 1 and 4.",
    "**If none of your cats has a known sensitivity**, that's completely fine — say so on "
    "camera. \"Let me show you what happens if I put corn in\" is honest. \"[CAT] reacts to "
    "corn\" when she doesn't, isn't. Tell us and we'll reword it.",
    "**Script 3 needs a real story** — how long it went on, what she looked like, what you tried. "
    "That's the one that will travel furthest, and it only works if it actually happened.",
    "**What you actually feed** (Scripts 2 and 5, optional) — and read out whatever score it "
    "gets. A clean result makes a better video.",
    "**Your median views per post** — not follower count. It's the only way we can tell whether "
    "a video worked because of the idea rather than the audience. A screenshot of your analytics "
    "after each post is ideal.",
])

heading(doc, "Filming notes", size=14, before=14, after=4)
bullets(doc, [
    "**Search, don't scan.** You don't need the bag, and searching is the better demo anyway — it "
    "proves you can check a food you don't own while standing in the shop.",
    "**Hold the ingredient list still for a couple of seconds.** People pause and screenshot it. "
    "A list that's scrolling can't be either.",
    "**The profile switch is the shot.** One take, no cut between the two scores, no re-searching.",
    "**Shoot the 30 first, then the 60.** Same setup, same day, same clothes.",
    "**Vertical, natural light, your normal voice.** Cats walking through the shot is a feature. "
    "These should look like you, not like an advert.",
    "**Don't post them all at once** — one a week or so. They compete with each other otherwise.",
    "**Expect arguments in the comments**, especially on Scripts 2 and 3. That's good, it's how "
    "these travel. Answer with the ingredient list rather than an opinion, and don't delete "
    "people.",
])

doc.save(OUT)
print(f"wrote {OUT}")
