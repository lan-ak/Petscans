# PetScans — Meta campaign creatives

On-brand Meta (Facebook/Instagram) ad creatives for PetScans: **5 test angles + a 5-card carousel**, rendered
from HTML so they can be tweaked and re-exported. Read [`BRIEF.md`](./BRIEF.md) for the strategy, ad copy,
audiences and campaign setup.

## What's here

```
BRIEF.md              Strategy + full ad copy + audiences + test plan + compliance
templates/            Editable HTML creatives (01–05 statics; carousel/card-1…5)
styles/               creative.css (design tokens + components), carousel.css, common.js
assets/               Real app icon + self-hosted Quicksand font
render.mjs            Renders every template to PNG at exact sizes
output/               Rendered PNGs  →  1x1/  4x5/  9x16/  carousel/
contact-sheet.html    Open in a browser to preview the whole set
```

## Regenerate the images

```bash
cd marketing/meta-campaign
npm install            # installs Playwright (uses the system Chromium, no download)
node render.mjs        # writes ~20 PNGs into output/
```

Outputs (all PNG, sRGB):

| Set | Size | Files |
|-----|------|-------|
| Square 1:1 | 1080×1080 | `output/1x1/01…05.png` |
| Portrait 4:5 | 1080×1350 | `output/4x5/01…05.png` |
| Story/Reel 9:16 | 1080×1920 | `output/9x16/01…05.png` |
| Carousel 1:1 | 1080×1080 | `output/carousel/card-1…5.png` |

Upload the **4:5** as the primary feed asset, **1:1** as the universal fallback, **9:16** for Stories/Reels.

## Editing

- Copy lives in each `templates/*.html`; shared look in `styles/creative.css` (all values ported from
  `PetScans/DesignSystem/*`). Change text/colours there, then re-run `node render.mjs`.
- Each static is **ratio-adaptive** via a `?r=1x1|4x5|9x16` query param (handled by `styles/common.js`).
- To drop in a real pet/product photo later, replace a card block with an `<img>` (the layouts leave room);
  no full redesign needed.

## Notes

- If `/opt/pw-browsers/chromium` isn't present in your environment, set `PW_CHROMIUM=/path/to/chromium`
  before running, or `npx playwright install chromium`.
- Fonts are self-hosted (`assets/fonts/Quicksand-*.woff2`) so renders are deterministic offline.
