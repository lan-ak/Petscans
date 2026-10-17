import { useEffect } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { Companion } from "../components/Companions";
import { ScoreCard } from "../components/ScoreCard";
import { VerdictCard } from "../components/Verdict";
import { state } from "../lib/state";
import { useStep } from "../lib/track";

/**
 * Step 2 — the demo result, `OnboardingFoodResultView` rebuilt in the
 * surface.
 *
 * No callback: a `DemoFoods` pick scored with no pet never changes, so the
 * whole result ships baked in (`lib/demoResults.json`, exported from the app's
 * own scorer). The app is only asked again on step 5, once there are
 * allergens and a watch list to score against.
 *
 * Native order: companion, the food, the verdict, Safety and Processing as
 * expandable cards, the all-clear note when there is nothing to worry about,
 * then every ingredient on the label, each opening its detail sheet.
 * Suitability is left off on purpose: it is the allergen axis, and there is
 * no pet yet for it to be about.
 */
export default function Result() {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();
  const r = state.demo;

  useStep("demo_result", { term: r?.gtin, score: r?.score });

  useEffect(() => {
    // The verdict lands in the hand as well as on the screen, as natively:
    // a warning on a flagged food, success on a clean one.
    if (r) {
      if (r.hasConcerns) haptics.warning();
      else haptics.success();
    }
    // Once per arrival, not on every render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!r) {
    return (
      <div className="page">
        <div className="page__body">
          <button type="button" className="btn btn--secondary" onClick={() => router.back()}>
            {t("index.pick")}
          </button>
        </div>
      </div>
    );
  }

  const cont = () => {
    haptics.medium();
    router.push("pet-setup");
  };

  return (
    <div className="page">
      <div className="page__body">
        <div className="scroller">
          <div className="payoff">
            <Companion species={state.species ?? "dog"} />
            <h1 className="payoff__name">{r.name}</h1>
            {r.brand ? <p className="payoff__brand">{r.brand}</p> : null}
          </div>

          <VerdictCard verdict={r.verdict} />

          <div className="axes">
            <ScoreCard title={t("result.safety")} data={r.safety} />
            {r.processing ? <ScoreCard title={t("result.processing")} data={r.processing} /> : null}
          </div>

          {r.hasConcerns ? null : (
            <div className="clear">
              <p className="clear__head">
                <span className="clear__mark" aria-hidden="true">✓</span>
                {t("result.clearTitle")}
              </p>
              <p className="clear__body">{t("result.clearBody")}</p>
            </div>
          )}

          <div className="inside">
            <h2 className="inside__title">{t("result.inside")}</h2>
            <p className="inside__hint">{t("result.insideHint")}</p>
            <div className="inside__list">
              {r.ingredients.map((ing, i) => (
                <button
                  key={`${i}-${ing.label}`}
                  type="button"
                  className="inside__row"
                  disabled={!ing.detail}
                  onClick={() => {
                    if (!ing.detail) return;
                    haptics.light();
                    state.ingredient = ing.detail;
                    router.push("ingredient");
                  }}
                >
                  <span className="inside__name">{ing.detail?.name ?? ing.label}</span>
                  {ing.detail ? <InfoMark /> : null}
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="actions">
          <button type="button" className="btn btn--primary pressable" onClick={cont}>
            {t("common.continue")}
          </button>
        </div>
      </div>
    </div>
  );
}

/** `info.circle`, in the brand colour, as natively. */
function InfoMark() {
  return (
    <svg className="inside__info" width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="12" r="9.5" stroke="currentColor" strokeWidth="1.8" />
      <path d="M12 11v5.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
      <circle cx="12" cy="7.8" r="1.2" fill="currentColor" />
    </svg>
  );
}
