import type { ScoredFood, Species } from "./callbacks";

/**
 * Cross-route state for the whole onboarding flow.
 *
 * A plain module, not `useState` in a route: the collecting page is popped
 * long before the answers are used — the name is typed on `pet-setup` and
 * read on `personalised` and again by the app at the end — and module state
 * survives that where route state would not. (A web funnel would have to use
 * `useQueryState`; this one never leaves the app.)
 *
 * Every read guards, so a revisited page never renders against a half-filled
 * object.
 */
interface OnboardingState {
  /** Chosen on the food-check screen. Null until the owner actually taps one. */
  species: Species | null;
  /** The demo verdict, scored before anything is known about the pet. */
  food: ScoredFood | null;
  /** True when `food` came from `exampleFood` rather than the user's own pick. */
  isExample: boolean;
  /** The query or barcode that missed, echoed on the recovery screens. */
  missedTerm: string;

  /** Step 3. The one required answer in the whole flow. */
  petName: string;
  /** Ingredient ids from the quick-pick chips — `beef`, `chicken`, … */
  allergens: string[];
  /** Step 4. `AvoidanceGroup` raw values. */
  groups: string[];

  /** Step 5: the same food re-scored against the finished profile. */
  personalised: ScoredFood | null;
}

export const state: OnboardingState = {
  species: null,
  food: null,
  isExample: false,
  missedTerm: "",
  petName: "",
  allergens: [],
  groups: [],
  personalised: null,
};

export function reset() {
  state.species = null;
  state.food = null;
  state.isExample = false;
  state.missedTerm = "";
  state.petName = "";
  state.allergens = [];
  state.groups = [];
  state.personalised = null;
}

/** The pet's name once given, else the wording the native screens use. */
export function petLabel(): string {
  return state.petName.trim() || "your pet";
}

/**
 * The app's own thresholds, from `ColorTokens.colorForScore`. Kept here rather
 * than inferred from the verdict string so the ring and the native results
 * screen can never disagree about where green becomes orange.
 */
export function scoreTone(score: number): "excellent" | "good" | "moderate" | "poor" {
  if (score >= 75) return "excellent";
  if (score >= 50) return "good";
  if (score >= 25) return "moderate";
  return "poor";
}

/**
 * `RatingLabel.color`, from `Models+UI.swift`.
 *
 * The verdict carries its own colour and it is **not** the score ramp: a
 * suitability override can drop the word to "Avoid" while the total stays
 * high, so colouring the verdict card from `scoreTone` produces a green card
 * reading "Caution". The word and its colour are one decision.
 */
export function verdictTone(verdict: string): "excellent" | "good" | "moderate" | "poor" {
  switch (verdict.trim().toLowerCase()) {
    case "excellent": return "excellent";
    case "good": return "good";
    case "avoid": return "poor";
    case "caution": return "moderate";
    // An unknown verdict from a newer binary: stay neutral-ish rather than
    // claiming the food is fine.
    default: return "moderate";
  }
}

/**
 * The quick-pick allergens, from `QuickPickAllergens.list(for:)`.
 *
 * Ranked from Mueller & Olivry (BMC Vet Res 2016) — beef/dairy/chicken/wheat
 * dominate dogs, beef/fish/chicken/wheat dominate cats. The ids are what the
 * scorer matches on, so they must stay lowercase and exactly these strings.
 */
export function quickPickAllergens(species: Species | null): { id: string; name: string }[] {
  if (species === "cat") {
    return [
      { id: "beef", name: "Beef" },
      { id: "fish", name: "Fish" },
      { id: "chicken", name: "Chicken" },
      { id: "wheat", name: "Wheat" },
      { id: "dairy", name: "Dairy" },
      { id: "corn", name: "Corn" },
    ];
  }
  return [
    { id: "beef", name: "Beef" },
    { id: "dairy", name: "Dairy" },
    { id: "chicken", name: "Chicken" },
    { id: "wheat", name: "Wheat" },
    { id: "soy", name: "Soy" },
    { id: "lamb", name: "Lamb" },
  ];
}

/**
 * The eight avoidance groups, from `AvoidanceGroup`. Ids are the Swift raw
 * values — the app turns each into `avoids_<snake_case>` for targeting, so a
 * typo here silently breaks an audience rule rather than failing loudly.
 *
 * The examples are not decoration: the category names alone mean little to a
 * lay owner, which is why the native picker carries them too.
 */
export const AVOIDANCE_GROUPS: { id: string; name: string; examples: string }[] = [
  { id: "ultraProcessed", name: "Ultra-processed ingredients", examples: "Hydrolyzed proteins, artificial flavours" },
  { id: "artificialColours", name: "Artificial colours", examples: "Red 40, Yellow 5, Titanium dioxide" },
  { id: "artificialPreservatives", name: "Artificial preservatives", examples: "BHA, BHT, Ethoxyquin, TBHQ" },
  { id: "commonAllergens", name: "Common allergens", examples: "Chicken, beef, wheat, dairy, soy" },
  { id: "addedSugars", name: "Added sugars & sweeteners", examples: "Corn syrup, cane molasses, sucrose" },
  { id: "meatByproducts", name: "Meat by-products", examples: "By-product meal, meat & bone meal" },
  { id: "grainFillers", name: "Grains & fillers", examples: "Corn, wheat, soy, brewers rice" },
  { id: "gumsThickeners", name: "Gums & thickeners", examples: "Carrageenan, guar gum, cellulose" },
];
