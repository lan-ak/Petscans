import { useEffect } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { Companion } from "../components/Companions";
import { ScoreBar, VerdictCard } from "../components/Verdict";
import { state } from "../lib/state";
import { useTrack } from "../lib/track";

/**
 * The payoff — `demo_result`, scored before anything is known about the pet.
 *
 * Composed as `OnboardingFoodResultView` is: the companion, the food it is
 * about, the verdict as a *word* on a tinted card, then the axes as bars.
 * Leading with the word rather than a 0-100 dial is the right call and worth
 * keeping — a verdict is an answer, a number is homework — and the number
 * still appears, on the axis it belongs to.
 *
 * Suitability is the allergen axis and means nothing yet: there is no pet for
 * it to be about. The app sends it as `-1` here and `ScoreBar` renders
 * nothing, which is the same thing the native screen does by omitting the
 * card. It arrives on the personalised screen, which is the whole point of
 * that screen existing.
 */
export default function Result() {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();
  const track = useTrack();

  const food = state.food;

  useEffect(() => {
    track("step", { step: "demo_result" });
  }, [track]);

  // A revisited route can outlive its data — guard rather than crash, and
  // send them back to pick again.
  if (!food) {
    return (
      <div className="page">
        <div className="page__body">
          <div className="centre-wrap">
            <button
              type="button"
              className="btn btn--secondary"
              onClick={() => {
                haptics.light();
                router.dismissAll();
              }}
            >
              {t("search.emptyBrowse")}
            </button>
          </div>
        </div>
      </div>
    );
  }

  const clean = food.flags.every((f) => f.severity === "ok" || f.count === 0);

  const cont = () => {
    haptics.medium();
    track("step_done", { step: "demo_result", score: food.score });
    router.push("pet-setup");
  };

  return (
    <div className="page">
      <div className="page__body">
        <div className="scroller">
          {state.isExample ? <span className="badge">{t("result.exampleBadge")}</span> : null}

          <div className="payoff">
            <Companion species={state.species ?? "dog"} />
            <h1 className="payoff__name">{food.name}</h1>
            {food.brand ? <p className="payoff__brand">{food.brand}</p> : null}
          </div>

          <VerdictCard verdict={food.verdict} />

          <div className="axes">
            <ScoreBar titleKey="result.safety" score={food.safety} />
            <ScoreBar titleKey="result.processing" score={food.processing} />
            <ScoreBar titleKey="result.suitability" score={food.suitability} />
          </div>

          {food.flags.length > 0 ? (
            <div className="flags">
              {food.flags.map((flag) => {
                const ok = flag.severity === "ok" || flag.count === 0;
                const tone =
                  flag.severity === "high"
                    ? "var(--score-poor)"
                    : flag.severity === "warning"
                      ? "var(--score-moderate)"
                      : "var(--score-excellent)";
                return (
                  <div className="flag" key={flag.label}>
                    <span
                      className="flag__mark"
                      aria-label={ok ? t("a11y.flagClear") : t("a11y.flagFound")}
                      style={{
                        background: ok ? "var(--surface-2)" : tone,
                        color: ok ? "var(--score-excellent)" : "var(--on-primary)",
                      }}
                    >
                      {ok ? "✓" : "!"}
                    </span>
                    <span className="flag__label">{flag.label}</span>
                    <span className="flag__count">
                      {ok ? t("result.none") : t("result.found", { count: String(flag.count) })}
                    </span>
                  </div>
                );
              })}
            </div>
          ) : null}

          <p className="nudge">{clean ? t("result.cleanNudge") : t("result.flagNudge")}</p>
        </div>

        <div className="actions">
          <button type="button" className="btn btn--primary" onClick={cont}>
            {t("result.continue")}
          </button>
          {state.isExample ? (
            <button
              type="button"
              className="btn btn--tertiary"
              onClick={() => {
                haptics.light();
                router.dismissAll();
              }}
            >
              {t("result.checkOwn")}
            </button>
          ) : null}
        </div>
      </div>
    </div>
  );
}
