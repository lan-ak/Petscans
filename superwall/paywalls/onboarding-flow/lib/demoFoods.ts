import pedigree from "../assets/foods/00023100143408.jpg";
import proPlanSensitive from "../assets/foods/00038100100757.jpg";
import royalCaninMedium from "../assets/foods/00030111174550.jpg";
import whiskas from "../assets/foods/00058496701246.jpg";
import proPlanIndoor from "../assets/foods/00038100103949.jpg";
import royalCaninIndoor from "../assets/foods/00030111430403.jpg";
import type { Species } from "./callbacks";

/**
 * The three foods step 1 demos against, per species — a copy of `DemoFoods`
 * in `OnboardingFoodCheckPage.swift`. Keep the two lists identical: the
 * native fallback and this surface must offer the same picks, or the funnel
 * comparison between them measures the foods rather than the screens.
 *
 * Only the GTIN crosses the bridge. The app scores the row through
 * `scoreProduct`, the same `OnboardingFoodScorer` the native result screen
 * runs, so the number and the flags are the app's own.
 *
 * The pack shots are the catalogue's `image_url` for each row, bundled here
 * rather than hot-linked: chewy.com is not in the surface's CSP, and an
 * image that fails to load turns the first screen into three grey boxes.
 */
export interface DemoFood {
  gtin: string;
  brand: string;
  detail: string;
  image: string;
}

const DOG: DemoFood[] = [
  { gtin: "00023100143408", brand: "Pedigree", detail: "Complete Nutrition, Roasted Chicken", image: pedigree },
  { gtin: "00038100100757", brand: "Purina Pro Plan", detail: "Sensitive Skin & Stomach, Salmon", image: proPlanSensitive },
  { gtin: "00030111174550", brand: "Royal Canin", detail: "Medium Adult", image: royalCaninMedium },
];

const CAT: DemoFood[] = [
  { gtin: "00058496701246", brand: "Whiskas", detail: "Meaty Selections, Chicken", image: whiskas },
  { gtin: "00038100103949", brand: "Purina Pro Plan", detail: "Indoor, Chicken & Rice", image: proPlanIndoor },
  { gtin: "00030111430403", brand: "Royal Canin", detail: "Indoor Adult", image: royalCaninIndoor },
];

/** Dog while the picker is unanswered, matching native `effectiveSpecies`. */
export function demoFoods(species: Species | null): DemoFood[] {
  return species === "cat" ? CAT : DOG;
}
