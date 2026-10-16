import catArt from "../assets/companion-cat@3x.png";
import dogArt from "../assets/companion-dog@3x.png";
import type { Species } from "../lib/variables";

/**
 * The companion rig — the app's own dog and cat.
 *
 * These PNGs are rendered from the app's SwiftUI drawing code
 * (`CompanionExport`, DEBUG-only, `-ExportCompanions`), not redrawn here. The
 * rigs are `CompanionCanvas` geometry with no image assets behind them, so a
 * hand-built SVG copy would be a second source of truth that drifts the first
 * time the rig changes. Re-export rather than edit these by hand; they are the
 * same files `onboarding-flow` ships.
 *
 * Transparent, so the art composites onto whichever ground the page is using —
 * which differs between light and dark.
 *
 * The native rig animates (a staggered entrance, a tap-to-perk one-shot). This
 * is the resting frame, and the animation is not load-bearing: natively it is
 * `accessibilityHidden` and the tap deliberately does nothing to the flow.
 */
export function Companion({ species, alt }: { species: Species; alt: string }) {
  return (
    <img
      className={`companion companion--${species}`}
      src={species === "cat" ? catArt : dogArt}
      alt={alt}
    />
  );
}
