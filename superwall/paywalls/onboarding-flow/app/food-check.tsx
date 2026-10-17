import { useState } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { ChevronRight } from "../components/Icons";
import { SpeciesPicker } from "../components/SpeciesPicker";
import type { Species } from "../lib/callbacks";
import { demoFoods } from "../lib/demoFoods";
import { asScoredFood, demoResult } from "../lib/demoResults";
import { state } from "../lib/state";
import { useStep, useTrack } from "../lib/track";

/**
 * Step 1 — pick one of three popular foods and see it scored. The 1.4.8
 * native step (`OnboardingFoodCheckPage`), screen for screen.
 *
 * This used to offer scan, search or an example. In the week to 2026-10-08
 * that step was where installs were lost: non-US barcodes missed the
 * catalogue, half-typed searches fired `search_no_results` on every
 * keystroke, and users whose scans worked kept scanning instead of moving
 * on. A pick cannot fail and takes one tap.
 *
 * It also keeps the paywall first. Scanning their own food starts in the
 * Scan tab behind `PaywallGate` — 1.4.8 refuses `scanBarcode` and
 * `searchCatalog` from this surface until a paywall has opened, so neither
 * may be offered here.
 *
 * The foods appear once a pet is picked, never before.
 *
 * A pick is an example: the app doesn't save it to History or set
 * `searched_food*`, so these users get the 276012 "What you'll see" paywall.
 */
export default function FoodCheck() {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();
  const track = useTrack();
  const [species, setSpecies] = useState<Species | null>(state.species);

  useStep("food_check");

  const chooseSpecies = (next: Species) => {
    haptics.selection();
    // Tapping the selected one again clears it, and the foods go with it.
    const value = species === next ? null : next;
    setSpecies(value);
    state.species = value;
  };

  /**
   * No callback: the result is baked in (`lib/demoResults`), because a pick
   * scored with no pet never changes. It is the same `OnboardingFoodScorer`
   * output the native screen computes on the spot.
   */
  const pick = (gtin: string) => {
    const result = demoResult(gtin);
    if (!result) return;
    haptics.light();

    state.demo = result;
    state.food = asScoredFood(result);
    state.personalised = null;
    state.isExample = true;
    track("result_shown", { path: "sample", term: gtin, score: result.score });
    router.push("result");
  };

  return (
    <div className="page">
      <div className="page__body">
        <div className="scroller scroller--centred">
        <div className="page__head">
          <h1 className="page__title">{t("index.title")}</h1>
          <p className="page__sub">{t("index.subtitle")}</p>
        </div>

        <div className="species-block species-block--fit">
          <p className="section-label">{t("index.species")}</p>
          <SpeciesPicker value={species} onPick={chooseSpecies} />
        </div>

        {/*
          Foods only once there is a pet. Before that the list would be dog
          food for everyone, and a cat owner would pick from the wrong shelf.
        */}
        {species ? (
          <div className="samples" key={species}>
            <p className="section-label">{t("index.pick")}</p>
            {demoFoods(species).map((food) => (
              <button
                key={food.gtin}
                type="button"
                className="result-row sample"
                aria-label={`${food.brand}, ${food.detail}`}
                onClick={() => pick(food.gtin)}
              >
                <img className="sample__img" src={food.image} alt="" aria-hidden="true" />
                <span className="result-row__text">
                  <span className="sample__brand">{food.brand}</span>
                  <span className="sample__detail">{food.detail}</span>
                </span>
                <span className="sample__chev">
                  <ChevronRight />
                </span>
              </button>
            ))}
            <p className="footnote">{t("index.footnote")}</p>
          </div>
        ) : null}
        </div>
      </div>
    </div>
  );
}
