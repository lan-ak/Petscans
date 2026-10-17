import raw from "./demoResults.json";
import type { ScoredFlag, ScoredFood, Species } from "./callbacks";

/**
 * The cold result for each `DemoFoods` row — step 2, baked into the surface.
 *
 * With no pet, no allergens and a fixed catalogue row, these never change, so
 * the result page needs no callback at all. `demoResults.json` is written by
 * the app itself (`DemoResultExport`, DEBUG, `-ExportDemoResults`) from the
 * real `OnboardingFoodScorer` and `IngredientDatabase`. **Regenerate it; never
 * edit it** — after a catalogue, matcher or scorer change, re-export and copy
 * it over, or the demo will disagree with the scanner.
 *
 * Only the personalised re-score goes back to the app (`rescoreForPet`).
 */

/** What `ScoreExplanationCard` draws. */
export interface ScoreCardData {
  score: number;
  /** The `RatingLabel` the card shows — a label override wins over the score. */
  label: string;
  /** Bar width, 0-100. Not always `score`: an override pins it (Caution = 35). */
  bar: number;
  summary: string;
  factors: { impact: "positive" | "negative" | "neutral"; name: string; text: string }[];
}

export type RiskTierToken = "toxic" | "caution" | "moderation" | "mostlySafe" | "safe";

/** What `IngredientDetailSheet` shows with no pet and no History. */
export interface IngredientDetail {
  name: string;
  scientific: string;
  function: string;
  tier: RiskTierToken;
  tierName: string;
  notes: string;
  symptoms: string[];
  dose: string;
  about?: { whatItIs: string; whyItsHere: string; watch: string };
  composed?: string;
  perSpecies?: { dog: string; dogTier: RiskTierToken; cat: string; catTier: RiskTierToken };
  rules: { severity: string; severityName: string; evidence: string; explain: string; source: string }[];
  origin: string;
  allergenRisk: string;
  suitableFor: ("dog" | "cat")[];
  sources: string[];
  processing?: { name: string; tone: "excellent" | "good" | "moderate" | "poor"; level: number };
}

export interface DemoResult {
  gtin: string;
  species: Species;
  name: string;
  brand: string;
  score: number;
  verdict: string;
  hasConcerns: boolean;
  flagCount: number;
  flags: ScoredFlag[];
  safety: ScoreCardData;
  processing: ScoreCardData | null;
  /** Label order. `detail` is absent for a token the matcher couldn't place. */
  ingredients: { label: string; detail?: IngredientDetail }[];
  /** Step 5's banner and watch list, per profile item. `{pet}` is the name. */
  personal: {
    /** Keyed by allergen id; only the ones that flag something on this food. */
    allergens: Record<string, { flags: PersonalFlag[]; names: string[] }>;
    /** Keyed by `AvoidanceGroup` raw value; each line is one matched ingredient. */
    groups: Record<string, string[]>;
    noAllergenSummary: string;
  };
}

/** A `WarningFlag`, as `WarningFlagView` draws it. */
export interface PersonalFlag {
  title: string;
  explain: string;
  severity: "info" | "warn" | "high" | "critical";
  severityName: string;
  source: string;
}

const DATA = raw as unknown as { foods: Record<string, DemoResult>; ingredients: SearchIngredient[] };
const RESULTS = DATA.foods;

/** `IngredientSearchSheet`'s list. `id` is what the app stores: the lowercased name. */
export interface SearchIngredient {
  id: string;
  name: string;
  scientific: string;
  function: string;
  dogTier: RiskTierToken;
  catTier: RiskTierToken;
}

/**
 * `key` is the row's position in the app's list. `id` is not unique: the
 * database has distinct ingredients sharing a common name (two "Beef", two
 * "Chicken"), and native lists them all, so the rows have to stay distinct
 * even though picking either stores the same id.
 */
export const SEARCH_INGREDIENTS: (SearchIngredient & { key: number })[] = DATA.ingredients.map(
  (ing, key) => ({ ...ing, key }),
);

export function demoResult(gtin: string): DemoResult | undefined {
  return RESULTS[gtin];
}

/**
 * The same result in the shape a `rescoreForPet` answer has, so the
 * personalised page compares like with like. Suitability is `-1`: it is the
 * allergen axis, and there is no pet yet.
 */
export function asScoredFood(r: DemoResult): ScoredFood {
  return {
    gtin: r.gtin,
    name: r.name,
    brand: r.brand,
    score: r.score,
    verdict: r.verdict,
    safety: r.safety.score,
    processing: r.processing?.score ?? -1,
    suitability: -1,
    flags: r.flags,
  };
}
