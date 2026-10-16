import { useEffect, useState } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { Companion } from "../components/Companions";
import { StepDots } from "../components/StepDots";
import { quickPickAllergens, state } from "../lib/state";
import { useTrack } from "../lib/track";

/**
 * Step 3 — the profile.
 *
 * The page that used to lose 48% of arrivals when it came *first*; it now sits
 * after the payoff that earns it. The companion is the only thing on it that
 * says who the form is about, which is why it stays.
 *
 * The name is the one required answer in the whole flow, and it gates leaving
 * this page rather than the final submit — by the time the watch list is done
 * the name is already valid.
 */
export default function PetSetup() {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();
  const track = useTrack();

  const [name, setName] = useState(state.petName);
  const [allergens, setAllergens] = useState<string[]>(state.allergens);
  // Blank until a submit has been attempted, so the field is not red before
  // the user has had a chance to type in it.
  const [showError, setShowError] = useState(false);

  useEffect(() => {
    track("step", { step: "pet_setup" });
  }, [track]);

  const picks = quickPickAllergens(state.species);

  const toggleAllergen = (id: string) => {
    haptics.selection();
    const next = allergens.includes(id)
      ? allergens.filter((a) => a !== id)
      : [...allergens, id];
    setAllergens(next);
    state.allergens = next;
  };

  const advance = () => {
    if (!name.trim()) {
      haptics.warning();
      setShowError(true);
      return;
    }
    haptics.medium();
    state.petName = name.trim();
    track("step_done", { step: "pet_setup", count: allergens.length });
    router.push("watch-list");
  };

  return (
    <div className="page">
      <div className="page__body">
        <div className="scroller">
          <div className="hero hero--inline">
            <Companion species={state.species ?? "dog"} />
          </div>

          <h1 className="page__title page__title--center">{t("petSetup.title")}</h1>

          <label className="field-label" htmlFor="pet-name">
            {t("petSetup.nameLabel")}
          </label>
          <div className={`field${showError && !name.trim() ? " field--error" : ""}`}>
            <input
              id="pet-name"
              className="field__input"
              value={name}
              onChange={(e) => {
                setName(e.target.value);
                setShowError(false);
              }}
              placeholder={t("petSetup.namePlaceholder")}
              autoComplete="off"
              autoCorrect="off"
              autoCapitalize="words"
              enterKeyHint="done"
              // Return dismisses the keyboard and leaves the user here. It
              // deliberately does not advance: the allergen chips sit below,
              // and moving on off a return press would skip past them.
              onKeyDown={(e) => {
                if (e.key === "Enter") e.currentTarget.blur();
              }}
            />
          </div>
          {showError && !name.trim() ? (
            <p className="field-error">{t("petSetup.nameError")}</p>
          ) : null}

          <div className="divider" />

          <div className="section-head">
            <p className="section-label">{t("petSetup.allergenLabel")}</p>
            <p className="section-note">{t("petSetup.allergenOptional")}</p>
          </div>
          <div className="chips">
            {picks.map((pick) => {
              const on = allergens.includes(pick.id);
              return (
                <button
                  key={pick.id}
                  type="button"
                  className={`chip${on ? " chip--on" : ""}`}
                  aria-pressed={on}
                  onClick={() => toggleAllergen(pick.id)}
                >
                  {pick.name}
                </button>
              );
            })}
          </div>

          <p className="footnote">{t("petSetup.footnote")}</p>
        </div>

        <div className="actions">
          <StepDots index={0} />
          <button type="button" className="btn btn--primary pressable" onClick={advance}>
            {t("common.continue")}
          </button>
        </div>
      </div>
    </div>
  );
}
