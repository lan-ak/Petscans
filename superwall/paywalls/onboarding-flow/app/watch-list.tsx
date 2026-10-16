import { useEffect, useState } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { StepDots } from "../components/StepDots";
import { AVOIDANCE_GROUPS, state } from "../lib/state";
import { useTrack } from "../lib/track";

/**
 * Step 4 — the watch list.
 *
 * These feed scoring on every scan afterwards, not just the one in
 * onboarding. Each row carries its examples because the category names alone
 * mean little to a lay owner: "ultra-processed" needs "hydrolyzed protein"
 * next to it to land.
 *
 * Nothing is required. Picking none is a legitimate answer and the app scores
 * fine without any, so this page has no validation and no error state.
 */
export default function WatchList() {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();
  const track = useTrack();

  const [picked, setPicked] = useState<string[]>(state.groups);

  useEffect(() => {
    track("step", { step: "watch_list" });
  }, [track]);

  const toggle = (id: string) => {
    haptics.selection();
    const next = picked.includes(id) ? picked.filter((g) => g !== id) : [...picked, id];
    setPicked(next);
    state.groups = next;
  };

  return (
    <div className="page">
      <div className="page__body">
        <div className="page__head">
          <h1 className="page__title">{t("watchList.title")}</h1>
          <p className="page__sub">{t("watchList.body")}</p>
        </div>

        <div className="scroller scroller--gap">
          {AVOIDANCE_GROUPS.map((group) => {
            const on = picked.includes(group.id);
            return (
              <button
                key={group.id}
                type="button"
                className={`avoid${on ? " avoid--on" : ""}`}
                aria-pressed={on}
                onClick={() => toggle(group.id)}
              >
                <span className="avoid__text">
                  <span className="avoid__name">{group.name}</span>
                  <span className="avoid__examples">{group.examples}</span>
                </span>
                <span className={`avoid__box${on ? " avoid__box--on" : ""}`} aria-hidden="true">
                  {on ? "✓" : ""}
                </span>
              </button>
            );
          })}
        </div>

        <div className="actions">
          <StepDots index={1} />
          <button
            type="button"
            className="btn btn--primary pressable"
            onClick={() => {
              haptics.medium();
              track("step_done", { step: "watch_list", count: picked.length });
              router.push("personalised");
            }}
          >
            {t("common.continue")}
          </button>
        </div>
      </div>
    </div>
  );
}
