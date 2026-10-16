import { useEffect, useRef, useState } from "react";
import { useActions, useHaptics, useTranslation } from "superwall/hooks";
import { Companion } from "../components/Companions";
import { ScoreBar, VerdictCard } from "../components/Verdict";
import { useCallbacks } from "../lib/callbacks";
import { petLabel, state } from "../lib/state";
import { useTrack } from "../lib/track";

/**
 * Step 5 — the same food, re-scored against the finished profile.
 *
 * The last thing before the paywall is an answer about the user's own pet
 * rather than a generic offer. The comparison is the point: when the profile
 * changed the verdict, that is the moment worth showing, because it is the
 * proof that the questions they just answered do something.
 *
 * Exits by handing the whole profile to the app, which persists the pet and
 * fires `onboarding_complete` — campaign 64348 then presents the paywall
 * exactly as it does today. This surface never shows a paywall itself.
 */
export default function Personalised() {
  const { t } = useTranslation();
  const { close } = useActions();
  const haptics = useHaptics();
  const call = useCallbacks();
  const track = useTrack();

  const [food, setFood] = useState(state.personalised);
  const [scoring, setScoring] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const ran = useRef(false);

  const demo = state.food;

  useEffect(() => {
    track("step", { step: "personalised" });
  }, [track]);

  /**
   * Re-score once. An example food is not theirs, so there is nothing to
   * personalise — those users fall through to the demo card and the same CTA.
   */
  useEffect(() => {
    if (ran.current) return;
    ran.current = true;
    if (!demo || state.isExample) return;

    setScoring(true);
    void (async () => {
      const result = await call.rescore(
        demo.gtin,
        state.species,
        state.petName,
        state.allergens,
        state.groups,
      );
      setScoring(false);
      if (!result.ok) return; // Keep the demo verdict rather than blanking.
      state.personalised = result.value;
      setFood(result.value);
    })();
  }, [call, demo]);

  const shown = food ?? demo;
  // Worth calling out only when the profile actually moved the answer.
  const changed = Boolean(food && demo && food.verdict !== demo.verdict);

  const finish = async () => {
    if (leaving) return;
    setLeaving(true);
    haptics.success();
    track("completed", {
      score: shown?.score,
      path: state.isExample ? "example" : undefined,
    });
    await call.finish("completed", {
      species: state.species,
      petName: state.petName,
      allergens: state.allergens,
      groups: state.groups,
      food: state.food,
      personalised: state.personalised,
      isExample: state.isExample,
    });
    close();
  };

  return (
    <div className="page">
      <div className="page__body">
        <div className="scroller">
          {shown ? null : (
            <h1 className="page__title">{t("personalised.titleBare", { pet: petLabel() })}</h1>
          )}

          {shown ? (
            <>
              <div className="payoff">
                <Companion species={state.species ?? "dog"} />
                <h1 className="payoff__name">{shown.name}</h1>
                {shown.brand ? <p className="payoff__brand">{shown.brand}</p> : null}
              </div>

              <VerdictCard verdict={shown.verdict} />

              <div className="axes">
                <ScoreBar titleKey="result.safety" score={shown.safety} />
                <ScoreBar titleKey="result.processing" score={shown.processing} />
                {/* The axis this screen exists for: it was -1 on the cold demo
                    because there was no pet for it to be about, and the profile
                    the user just filled in is what turns it on. */}
                <ScoreBar titleKey="result.suitability" score={shown.suitability} />
              </div>

              {scoring ? (
                <p className="nudge">{t("personalised.rescoring")}</p>
              ) : changed && demo ? (
                /* The before/after. Only rendered when it says something. */
                <div className="delta">
                  <span className="delta__was">
                    {t("personalised.was", { verdict: demo.verdict })}
                  </span>
                  <span className="delta__arrow" aria-hidden="true">
                    →
                  </span>
                  <span className="delta__now">
                    {t("personalised.now", { verdict: shown.verdict, pet: petLabel() })}
                  </span>
                </div>
              ) : (
                <p className="nudge">
                  {state.isExample
                    ? t("personalised.exampleNudge")
                    : t("personalised.steadyNudge", { pet: petLabel() })}
                </p>
              )}

              {shown.flags.length > 0 ? (
                <div className="flags">
                  {shown.flags.map((flag) => {
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
            </>
          ) : (
            /* Skipped or missed the food check — there is no verdict to show,
               so this becomes a plain hand-off rather than a blank result. */
            <p className="nudge">{t("personalised.noFood", { pet: petLabel() })}</p>
          )}
        </div>

        <div className="actions">
          <button
            type="button"
            className="btn btn--primary pressable"
            onClick={finish}
            disabled={leaving}
          >
            {leaving ? <span className="btn__spinner" /> : null}
            {t("personalised.cta", { pet: petLabel() })}
          </button>
        </div>
      </div>
    </div>
  );
}
