# Creator intake

Read the media kit before you decide anything. It tells you the species, the formats they
already shoot, and the identity to write in. Adapting scripts to a creator you haven't read
wastes the whole pack — a cat-rescue script handed to a farm-and-dog creator is unusable.

## Reading a Canva media kit

Canva `/edit` links are private (**403**). The `/view` variant loads, but a plain fetch
returns the browser-compat shell — the deck is JS-rendered, and only **page 1** text ends up
in the DOM. To read all pages, pull each one as an image:

```bash
# 1. render the page and capture the thumbnail URLs
firecrawl scrape "https://www.canva.com/design/<ID>/<TOKEN>/view" > kit.md
```

```python
# 2. one signed URL per page, already in kit.md — download and Read them as images
import re, subprocess
md = open('kit.md').read()
urls = re.findall(r'\((https://media\.canva\.com/v2/document-image/[^)]+?page=(\d+)[^)]*)\)', md)
seen = {}
for u, pg in urls:
    seen.setdefault(pg, u)
for pg, u in sorted(seen.items()):
    subprocess.run(['curl', '-sL', '-o', f'kara/page{pg}.png', u])
```

Then `Read` each PNG. Notes:

- **Don't rewrite `width:`/`height:` in the URL** — they're covered by the signature and you
  get a 17-byte error body. Use the URL as-is; ~596×335 is legible enough.
- If the signed URL fails, each one carries a `fallback=` parameter holding a presigned S3
  link to the same page; URL-decode it and fetch that instead.
- Do this in the scratchpad directory, not the repo.

## What to extract

- **Name, handle, location, contact email**
- **Positioning line** — verbatim. It's how they describe themselves and should shape the
  scripts' voice ("MOM & Farm life", "cat rescue").
- **Platforms** and **named content formats** they already shoot. Spec scripts into formats
  they list — a creator who already does "talking-head app promotion" and "voice-over product
  review" should be handed exactly those, named as such. It raises quality and shortens the
  brief.
- **Which animals appear** — and whether they're scannable pets or farm background.
- **Brand partners.** Pet-adjacent ones (Chewy, PetArmor, VetPets+) are proof of category
  fit; they also tell you the register the audience expects.
- **Follower counts and engagement.** See below if absent.

## Questions to ask before writing

Ask in one round, then write. These change the scripts structurally:

1. **What animals can they put on camera?** Decides the whole product set. Never infer this
   from a media kit alone — farm animals in a deck don't mean a scannable dog or cat.
2. **Props:** search-only (zero props), ship 1–2 bags, buy-and-expense, or an in-store scan
   trip. Search-only always works — the app's catalog search pulls the full panel and both
   scores with no bag, no barcode, no network. Treat anything else as an upgrade and mark
   those shots `[BAG]` / `[YOUR FOOD]` so the pack still shoots without them.
3. **Framing:** how hard to lean on their identity — front and centre, mentioned once, or
   left out.
4. **Do they have real health/allergy stories?** If not, write `[FILL]` slots and tell them
   explicitly that a hypothetical said out loud ("let me show you what happens if I add
   corn") is honest, and claiming a symptom the pet doesn't have is not.

## Red flags to report back

- **No follower or engagement numbers anywhere in the kit.** Common in craft-led UGC kits
  that sell production quality and a brand list instead of reach. Fine for UGC-as-assets,
  not fine for an organic-reach deal. Say so before a paid deal is signed.

  **Ask specifically for median views per post, not follower count.** Breakout ratio —
  views ÷ their median — is the only number that tells you the *content* worked rather than
  the audience being big, and it's how `references/virality.md` says to judge every script.
  Without a median you cannot compute it, and the pack becomes unmeasurable. Followers alone
  won't do: the biggest breakouts in the landscape study came from accounts with 242, 1,114
  and 8,279 followers.
- **Competitor seed networks.** Several "review/wellness" accounts run paid distribution for
  Oasis, a rival scanner. Full list in `PetScans UGC/competitor-scanner-apps.md`. Screen every
  candidate's bio and recent posts for scanner-app or supplement plugs before booking.
- **Affiliate entanglement** — creators pushing a supplement brand in most recent posts.

## Pick the angle from the identity

The angle is the thing only that creator can say. It should survive being read aloud by them
and nobody else:

| Identity | Angle that only works for them |
|---|---|
| Cat rescue, many cats | donated food with no history; one bag, many different answers |
| Farm + mom, one dog | the dog is the only animal here that eats out of a bag |
| Vet / nutritionist | permission-to-believe; what they'd buy and wouldn't |
| Multi-pet household | the dual-score switch, demonstrated instead of claimed |

Cat content is the bigger opening: the worst-cat-food query produced more viral outliers than
any other in the landscape study, and the only cat scanner with organic traction is Leo at
215K views. See `PetScans UGC/pet-food-scanner-tiktok-landscape.md`.
