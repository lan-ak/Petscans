import { useEffect, useState } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { Companion } from "../components/Companions";
import { StepDots } from "../components/StepDots";
import type { Species } from "../lib/callbacks";
import { quickPickAllergens, state } from "../lib/state";
import { useStep } from "../lib/track";

/**
 * Step 3 — `OnboardingPetSetupPage` → `PetFormView` → `AllergenSelectionView`.
 *
 * Native order: the companion, "Let's meet your pet", the name field, the
 * Dog/Cat segmented control, a divider, the allergen question with its quick
 * picks and "Search for more...", the footnote. The name is the one required
 * answer, and it gates leaving this page.
 *
 * Allergens picked in search that aren't quick picks show as extra selected
 * chips, which is how native shows them too; tapping one removes it.
 */
export default function PetSetup() {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();
  useStep("pet_setup");

  const [name, setName] = useState(state.petName);
  const [species, setSpecies] = useState<Species>(state.species ?? "dog");
  const [allergens, setAllergens] = useState<string[]>(state.allergens);
  // Blank until a submit has been attempted, so the field isn't red first.
  const [showError, setShowError] = useState(false);

  // This page stays mounted under the search sheet, so pick up what was
  // chosen there when it comes back to the top.
  useEffect(() => {
    if (router.name === "pet-setup") setAllergens(state.allergens);
  }, [router.name]);

  const picks = quickPickAllergens(species);
  const pickIds = new Set(picks.map((p) => p.id));
  const extras = allergens.filter((a) => !pickIds.has(a)).sort();

  const setAll = (next: string[]) => {
    setAllergens(next);
    state.allergens = next;
  };

  const toggle = (id: string) => {
    haptics.selection();
    setAll(allergens.includes(id) ? allergens.filter((a) => a !== id) : [...allergens, id]);
  };

  const chooseSpecies = (next: Species) => {
    if (next === species) return;
    haptics.selection();
    setSpecies(next);
    state.species = next;
  };

  const advance = () => {
    if (!name.trim()) {
      haptics.warning();
      setShowError(true);
      return;
    }
    haptics.medium();
    state.petName = name.trim();
    router.push("watch-list");
  };

  const error = showError && !name.trim();

  return (
    <div className="page">
      <div className="page__body">
        <div className="scroller form">
          <div className="form__hero">
            <Companion species={species} />
          </div>

          <h1 className="page__title page__title--center">{t("petSetup.title")}</h1>

          <div className="form__fields">
            <div className="form__name">
              <input
                id="pet-name"
                className={`input${error ? " input--error" : ""}`}
                value={name}
                aria-label={t("petSetup.namePlaceholder")}
                placeholder={t("petSetup.namePlaceholder")}
                onChange={(e) => {
                  setName(e.target.value);
                  setShowError(false);
                }}
                autoComplete="off"
                autoCorrect="off"
                autoCapitalize="words"
                enterKeyHint="done"
                // Return dismisses the keyboard and stays here: the allergen
                // chips sit below, and advancing would skip past them.
                onKeyDown={(e) => {
                  if (e.key === "Enter") e.currentTarget.blur();
                }}
              />
              {error ? <p className="field-error">{t("petSetup.nameError")}</p> : null}
            </div>

            <div className="segmented" role="radiogroup" aria-label={t("petSetup.species")}>
              {(["dog", "cat"] as const).map((s) => (
                <button
                  key={s}
                  type="button"
                  role="radio"
                  aria-checked={species === s}
                  className={`segmented__item${species === s ? " segmented__item--on" : ""}`}
                  onClick={() => chooseSpecies(s)}
                >
                  {t(`index.${s}`)}
                </button>
              ))}
            </div>
          </div>

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
                  onClick={() => toggle(pick.id)}
                >
                  {pick.name}
                </button>
              );
            })}
            {extras.map((id) => (
              <button
                key={id}
                type="button"
                className="chip chip--on"
                aria-pressed="true"
                onClick={() => toggle(id)}
              >
                {capitalise(id)}
              </button>
            ))}
          </div>

          <button
            type="button"
            className="btn btn--soft"
            onClick={() => {
              haptics.light();
              router.push("allergen-search");
            }}
          >
            <SearchGlyph />
            <span className="btn--soft__label">{t("petSetup.searchMore")}</span>
          </button>

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

/** Swift's `.capitalized`, which is how native prints a searched allergen. */
export function capitalise(id: string): string {
  return id.replace(/\b\p{L}/gu, (c) => c.toUpperCase());
}

/** `magnifyingglass` */
export function SearchGlyph({ size = 20 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="10.5" cy="10.5" r="6.5" stroke="currentColor" strokeWidth="2.4" />
      <path d="m15.5 15.5 5 5" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
    </svg>
  );
}
