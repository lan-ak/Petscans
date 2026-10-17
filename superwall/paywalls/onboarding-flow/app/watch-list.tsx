import { useState } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { GroupIcon } from "../components/GroupIcon";
import { StepDots } from "../components/StepDots";
import { AVOIDANCE_GROUPS, state } from "../lib/state";
import { useStep } from "../lib/track";

/**
 * Step 4 — `OnboardingAvoidanceGroupsPage` → `AvoidanceGroupPicker`.
 *
 * Each row is `AvoidanceGroupRow`: the group's icon, its name and examples,
 * and a square check. A picked row fills with the brand green and its text
 * turns white, as natively. Nothing is required.
 */
export default function WatchList() {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();
  useStep("watch_list");

  const [picked, setPicked] = useState<string[]>(state.groups);

  const toggle = (id: string) => {
    haptics.selection();
    const next = picked.includes(id) ? picked.filter((g) => g !== id) : [...picked, id];
    setPicked(next);
    state.groups = next;
  };

  return (
    <div className="page">
      <div className="page__body">
        <div className="scroller scroller--groups">
          <div className="page__head page__head--groups">
            <h1 className="page__title">{t("watchList.title")}</h1>
            <p className="page__sub page__sub--lg">{t("watchList.body")}</p>
          </div>

          <div className="groups">
            {AVOIDANCE_GROUPS.map((group) => {
              const on = picked.includes(group.id);
              return (
                <button
                  key={group.id}
                  type="button"
                  className={`group${on ? " group--on" : ""}`}
                  aria-pressed={on}
                  onClick={() => toggle(group.id)}
                >
                  <span className="group__icon">
                    <GroupIcon id={group.id} />
                  </span>
                  <span className="group__text">
                    <span className="group__name">{group.name}</span>
                    <span className="group__examples">{group.examples}</span>
                  </span>
                  <span className={`group__box${on ? " group__box--on" : ""}`} aria-hidden="true">
                    {on ? (
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                        <path d="M5 12.5l4.5 4.5L19 7.5" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                    ) : null}
                  </span>
                </button>
              );
            })}
          </div>
        </div>

        <div className="actions">
          <StepDots index={1} />
          <button
            type="button"
            className="btn btn--primary pressable"
            onClick={() => {
              haptics.medium();
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
