import { useTranslation } from "superwall/hooks";
import pairArt from "../assets/companion-pair@3x.png";
import dogArt from "../assets/companion-dog@3x.png";
import catArt from "../assets/companion-cat@3x.png";
import type { Species } from "../lib/callbacks";

/**
 * The companion rigs.
 *
 * These are PNGs rendered from the app's own SwiftUI drawing code
 * (`CompanionExport`, DEBUG-only, `-ExportCompanions`), not redrawn here. The
 * rigs are `CompanionCanvas` geometry with no image assets behind them, so a
 * hand-built SVG copy would be a second source of truth that drifts the first
 * time the rig changes. Re-export rather than edit these by hand.
 *
 * Transparent, so they composite onto whichever ground the page is using —
 * which differs between light and dark.
 *
 * The native pair animates (a staggered entrance, and a tap-to-perk one-shot).
 * These are the resting frame. The animation is not load-bearing: it is
 * explicitly `accessibilityHidden` natively and the tap deliberately does
 * nothing to the flow.
 */

/** Both animals, for the promise screen. Decorative — the copy carries it. */
export function CompanionPair() {
  return <img className="companion companion--pair" src={pairArt} alt="" aria-hidden="true" />;
}

/** One animal, for the profile page: the pet the form is about. */
export function Companion({ species }: { species: Species }) {
  const { t } = useTranslation();
  return (
    <img
      className="companion"
      src={species === "cat" ? catArt : dogArt}
      alt={t(species === "cat" ? "index.cat" : "index.dog")}
    />
  );
}
