import { useEffect, useRef, useState } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { Companion } from "../components/Companions";
import { GroupIcon } from "../components/GroupIcon";
import { VerdictBadge } from "../components/Verdict";
import { useCallbacks } from "../lib/callbacks";
import type { PersonalFlag } from "../lib/demoResults";
import { petLabel, state } from "../lib/state";
import { useStep, useTrack } from "../lib/track";
import { capitalise } from "./pet-setup";

/**
 * Step 5 — `OnboardingPersonalizedResultView`.
 *
 * The verdict is the app's: `rescoreForPet` runs the real scorer against the
 * profile the owner just built, so the word and the score match what every
 * later scan will say. What the 1.4.8 callback doesn't return — *which*
 * ingredients hit the allergens and the watch list — is baked per profile
 * item in `demoResults.json` and combined here; flags are per matched
 * ingredient, so the profile's list is the union of its items'.
 *
 * Native order: "Now scored for Max", the food with its before → after, the
 * allergen banner, "On your watch list", then "From now on, every scan
 * checks". Continue hands the profile back to the app and goes on to the
 * plans — the paywall is the flow's last step now, not a second
 * presentation after it.
 */
export default function Personalised() {
  const { t } = useTranslation();
  const router = useRouter();
  const haptics = useHaptics();
  const call = useCallbacks();
  const track = useTrack();
  useStep("personalised");

  const [verdict, setVerdict] = useState<string | null>(state.personalised?.verdict ?? null);
  const [scoring, setScoring] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const [bannerOpen, setBannerOpen] = useState(false);
  const ran = useRef(false);

  const demo = state.demo;
  const pet = petLabel();
  const fill = (s: string) => s.split("{pet}").join(pet);

  // The banner and the watch list, from the baked per-item results.
  const personal = demo?.personal;
  const allergenFlags: PersonalFlag[] = [];
  const allergenNames: string[] = [];
  const seenFlag = new Set<string>();
  const seenName = new Set<string>();
  for (const id of state.allergens) {
    const hit = personal?.allergens[id];
    if (!hit) continue;
    for (const f of hit.flags) {
      if (seenFlag.has(f.explain)) continue;
      seenFlag.add(f.explain);
      allergenFlags.push(f);
    }
    for (const n of hit.names) {
      if (seenName.has(n.toLowerCase())) continue;
      seenName.add(n.toLowerCase());
      allergenNames.push(n);
    }
  }
  const groupLines = [
    ...new Set(state.groups.flatMap((g) => personal?.groups[g] ?? [])),
  ];

  /** Re-score once against the finished profile. */
  useEffect(() => {
    if (ran.current || !state.food) return;
    ran.current = true;
    setScoring(true);
    void (async () => {
      const food = state.food!;
      const result = await call.rescore(food.gtin, state.species, state.petName, state.allergens, state.groups);
      setScoring(false);
      // Keep the general verdict rather than blanking if the app can't answer.
      const next = result.ok ? result.value : null;
      state.personalised = next;
      setVerdict(next?.verdict ?? food.verdict);
      if (allergenFlags.length) haptics.warning();
      else haptics.success();
    })();
    // Once per arrival.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const changed = Boolean(verdict && demo && verdict !== demo.verdict);

  const finish = async () => {
    if (leaving || scoring) return;
    setLeaving(true);
    haptics.success();
    const final = state.personalised ?? state.food;
    track("completed", { score: final?.score, path: "sample" });
    // Handed over before the plans, not after them: every way off the plans
    // step closes the surface, and the app reads this outcome on close.
    await call.finish("completed", {
      species: state.species,
      petName: state.petName,
      allergens: state.allergens,
      groups: state.groups,
      food: state.food,
      personalised: state.personalised,
      isExample: state.isExample,
    });
    router.push("plans");
  };

  return (
    <div className="page page--nonav">
      <div className="page__body">
        <div className="scroller">
          <div className="scored-head">
            <Companion species={state.species ?? "dog"} />
            <h1 className="page__title page__title--center">
              {state.petName ? t("personalised.title", { pet }) : t("personalised.titleBare")}
            </h1>
          </div>

          {demo ? (
            <section className="card card--centre">
              <p className="scored__food">{demo.name}</p>
              {verdict ? (
                <div className="scored__verdict">
                  {changed ? (
                    <>
                      <span className="scored__caption">{t("personalised.inGeneral", { verdict: demo.verdict })}</span>
                      <span className="scored__arrow" aria-hidden="true">↓</span>
                    </>
                  ) : null}
                  <span className="scored__caption">{t("personalised.forPet", { pet })}</span>
                  <VerdictBadge verdict={verdict} />
                </div>
              ) : (
                // The companion above is already the "waiting".
                <div className="scored__wait" />
              )}
              {verdict && allergenFlags.length === 0 && state.allergens.length > 0 && personal?.noAllergenSummary ? (
                <p className="card__body">{fill(personal.noAllergenSummary)}</p>
              ) : null}
            </section>
          ) : null}

          {verdict && allergenFlags.length > 0 ? (
            <section className="banner">
              <button
                type="button"
                className="banner__head"
                aria-expanded={bannerOpen}
                onClick={() => {
                  haptics.light();
                  setBannerOpen((v) => !v);
                }}
              >
                <span className="banner__mark" aria-hidden="true">
                  <GroupIcon id="commonAllergens" size={26} />
                </span>
                <span className="banner__text">
                  <span className="banner__title">{t("personalised.bannerTitle", { pet })}</span>
                  <span className="banner__names">{allergenNames.join(", ")}</span>
                </span>
                <span className="banner__chev" aria-hidden="true">{bannerOpen ? "⌃" : "⌄"}</span>
              </button>
              {bannerOpen ? (
                <div className="banner__flags">
                  {allergenFlags.map((f) => (
                    <div key={f.explain} className={`wflag wflag--${f.severity}`}>
                      <div className="wflag__head">
                        <span className="wflag__title">{f.title}</span>
                        <span className={`wflag__badge wflag__badge--${f.severity}`}>{f.severityName}</span>
                      </div>
                      <p className="wflag__explain">{fill(f.explain)}</p>
                    </div>
                  ))}
                </div>
              ) : null}
            </section>
          ) : null}

          {verdict && groupLines.length > 0 ? (
            <section className="card">
              <h2 className="watch__title">
                <EyeGlyph />
                {t("personalised.watchTitle")}
              </h2>
              {groupLines.map((line) => (
                <p key={line} className="watch__row">
                  <span className="watch__mark" aria-hidden="true">!</span>
                  <span>{fill(line)}</span>
                </p>
              ))}
            </section>
          ) : null}

          <section className="card">
            <h2 className="plan__title">{t("personalised.planTitle")}</h2>
            {state.allergens.length === 0 && state.groups.length === 0 ? (
              <PlanRow glyph="paw" text={t("personalised.planUnsafe", { pet })} />
            ) : null}
            {state.allergens.length > 0 ? (
              <PlanRow glyph="warn" text={[...state.allergens].sort().map(capitalise).join(", ")} />
            ) : null}
            {state.groups.length > 0 ? (
              <PlanRow
                glyph="eye"
                text={t(state.groups.length === 1 ? "personalised.planGroupsOne" : "personalised.planGroups", {
                  count: String(state.groups.length),
                })}
              />
            ) : null}
            <PlanRow glyph="shield" text={t("personalised.planToxic")} />
          </section>
        </div>

        <div className="actions">
          <button
            type="button"
            className="btn btn--primary pressable"
            onClick={finish}
            // Only while the re-score runs, as natively: gating on its result
            // instead would trap the user if it never answered.
            disabled={scoring || leaving}
          >
            {leaving ? <span className="btn__spinner" /> : null}
            {t("common.continue")}
          </button>
        </div>
      </div>
    </div>
  );
}

function EyeGlyph() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" aria-hidden="true">
      <path fill="currentColor" d="M12 5C6.5 5 2.7 9.2 1.5 12c1.2 2.8 5 7 10.5 7s9.3-4.2 10.5-7C21.3 9.2 17.5 5 12 5zm0 11a4 4 0 1 1 0-8 4 4 0 0 1 0 8z" />
      <circle cx="12" cy="12" r="2" fill="currentColor" />
    </svg>
  );
}

/** `planRow`: a brand-green glyph and one line of secondary text. */
function PlanRow({ glyph, text }: { glyph: "paw" | "warn" | "eye" | "shield"; text: string }) {
  return (
    <p className="plan__row">
      <span className="plan__glyph" aria-hidden="true">
        {glyph === "eye" ? (
          <EyeGlyph />
        ) : glyph === "warn" ? (
          <GroupIcon id="commonAllergens" size={16} />
        ) : glyph === "shield" ? (
          <svg width="16" height="16" viewBox="0 0 24 24">
            <path fill="currentColor" d="M12 2.5l8 3v6.2c0 5-3.4 8.6-8 9.8-4.6-1.2-8-4.8-8-9.8V5.5z" />
            <path fill="var(--surface)" d="M12 5v14.3c-3.3-1.1-5.6-3.9-5.6-7.6V7.1z" opacity="0.45" />
          </svg>
        ) : (
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
            <ellipse cx="6" cy="10" rx="2.2" ry="2.8" />
            <ellipse cx="10" cy="6" rx="2.2" ry="2.8" />
            <ellipse cx="14.5" cy="6" rx="2.2" ry="2.8" />
            <ellipse cx="18.5" cy="10" rx="2.2" ry="2.8" />
            <path d="M12.2 11.5c2.7 0 6 3.6 6 6.2 0 1.7-1.3 2.6-2.9 2.6-1.3 0-2-.6-3.1-.6s-1.8.6-3.1.6c-1.6 0-2.9-.9-2.9-2.6 0-2.6 3.3-6.2 6-6.2z" />
          </svg>
        )}
      </span>
      <span>{text}</span>
    </p>
  );
}
