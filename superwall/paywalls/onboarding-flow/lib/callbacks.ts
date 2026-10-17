import { useActions } from "superwall/hooks";

/**
 * Typed wrappers over `useActions().requestCallback` — nothing else. Two are
 * left in 1.4.8: `rescoreForPet` (step 5) and `onboardingDone` (the exit).
 * Step 2 is baked in (`lib/demoResults`), and the binary refuses
 * `scanBarcode` / `searchCatalog` until a paywall has opened. Each one
 * is a single call naming a handler in `FoodCheckCallbacks.swift`; the types
 * exist so a renamed field is a compile error rather than an undefined at
 * runtime.
 *
 * These are callbacks rather than `fetch` for one reason: the
 * product catalogue is `catalog.sqlite` bundled in the app and read through
 * GRDB (`LocalCatalogStore`). There is no HTTP endpoint to call and nothing to
 * put in `allowedHosts` — search, scanning and scoring all have to run on the
 * device, in Swift, and hand their answers back.
 *
 * Swift side: `FoodCheckCallbacks.handle(_:)`.
 */

/** One line of `ScoreBreakdown.flags`, already resolved to display strings. */
export interface ScoredFlag {
  label: string;
  /** Mirrors the app's severity ramp; drives the mark colour only. */
  severity: "high" | "warning" | "info" | "ok";
  count: number;
}

/** The shape `OnboardingFoodScorer` produces, flattened. */
export interface ScoredFood {
  gtin: string;
  name: string;
  brand: string;
  /** `ScoreBreakdown.total`, 0-100. */
  score: number;
  /** `RatingLabel.rawValue` — the app's own wording, not ours. */
  verdict: string;
  /**
   * The per-axis scores the payoff screen renders as bars. `-1` means the
   * axis does not apply: `processing` when the food has no processing data,
   * `suitability` on the cold demo, where there is no pet for the allergen
   * axis to be about.
   */
  safety: number;
  processing: number;
  suitability: number;
  flags: ScoredFlag[];
}

export type Species = "dog" | "cat";

/**
 * The callback answers. Intersected with `Record<string, unknown>` because
 * `requestCallback<T>` constrains its generic to one — the app can put extra
 * keys on a reply and the webview must not care.
 */
type ScoreAnswer = {
  food?: ScoredFood;
} & Record<string, unknown>;

/**
 * `requestCallback` resolves `{ status, data }` and never throws for a flow
 * outcome, so every wrapper below returns a discriminated result rather than
 * rejecting. A `failure` from the app is an ordinary answer: the catalogue
 * failed to open, the scanner was dismissed, the score threw.
 */
export type BridgeResult<T> =
  | { ok: true; value: T }
  | { ok: false };

/**
 * No callback may hang the UI.
 *
 * `requestCallback` resolves when the host answers — and a host that never
 * answers (an older binary that doesn't know the name, a protocol change, a
 * Swift error that escapes the handler) leaves the promise pending forever.
 * The surface would sit on a spinner with no way out. Every call is therefore
 * raced against a deadline and a timeout is treated as the failure it is.
 *
 * Generous on purpose: the catalogue is SQLite on the device, so this is a
 * stuck-forever guard, not a latency budget.
 */
const CALLBACK_TIMEOUT_MS = 20_000;
function withDeadline<T>(work: Promise<T>, ms: number): Promise<T | null> {
  return Promise.race([
    work,
    new Promise<null>((resolve) => setTimeout(() => resolve(null), ms)),
  ]);
}

export function useCallbacks() {
  const { requestCallback } = useActions();

  return {
    /**
     * Re-scores the chosen food against the finished profile. The same call
     * the native personalised screen makes, so the before/after the user sees
     * is the app's own arithmetic rather than anything recomputed here.
     */
    async rescore(
      gtin: string,
      species: Species | null,
      petName: string,
      allergens: string[],
      groups: string[],
    ): Promise<BridgeResult<ScoredFood>> {
      const r = await withDeadline(
        requestCallback<ScoreAnswer>("rescoreForPet", {
        variables: {
          gtin,
          species: species ?? "",
          petName,
          // Arrays are not supported as callback variable values, so these
          // cross as comma-joined ids and the app splits them back.
          allergens: allergens.join(","),
          groups: groups.join(","),
        },
      }),
        CALLBACK_TIMEOUT_MS,
      );
      if (!r || r.status !== "success" || !r.data?.food) return { ok: false };
      return { ok: true, value: r.data.food };
    },

    /**
     * Hands the whole profile back on the way into the plans step. The app
     * holds it until the surface closes, then persists the `Pet`, writes the
     * avoidance preferences, pushes every Superwall targeting attribute, and
     * fires `onboarding_complete`, which presents nothing on 1.4.8+ (campaign
     * 64348 only answers older versions).
     */
    async finish(
      // Only ever "completed": the flow has no exit, so the surface never
      // reports a deliberate skip. The app still models an unexpected
      // dismissal separately.
      outcome: "completed",
      detail: {
        species: Species | null;
        petName: string;
        allergens: string[];
        groups: string[];
        food: ScoredFood | null;
        personalised: ScoredFood | null;
        isExample: boolean;
      },
    ) {
      const final = detail.personalised ?? detail.food;
      await withDeadline(
        requestCallback("onboardingDone", {
        variables: {
          outcome,
          species: detail.species ?? "",
          petName: detail.petName,
          allergens: detail.allergens.join(","),
          groups: detail.groups.join(","),
          // Empty for a pick. The surface is live on 1.4.7 as well as 1.4.8,
          // and 1.4.7's handler (built from an uncommitted tree, so its source
          // is gone) may read a gtin as the owner's own food — saving the demo
          // to History and setting `searched_food`, which sends them to the
          // aha paywall about a bag they don't feed. Empty is safe on both.
          gtin: detail.isExample ? "" : (detail.food?.gtin ?? ""),
          score: final?.score ?? -1,
          verdict: final?.verdict ?? "",
          flag_count: final?.flags.length ?? 0,
          personalised: detail.personalised ? "true" : "false",
          example: detail.isExample ? "true" : "false",
        },
      }),
        CALLBACK_TIMEOUT_MS,
      );
    },
  };
}
