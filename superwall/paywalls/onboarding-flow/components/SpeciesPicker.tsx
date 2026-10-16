import { useTranslation } from "superwall/hooks";
import catArt from "../assets/companion-cat@3x.png";
import dogArt from "../assets/companion-dog@3x.png";
import type { Species } from "../lib/callbacks";

/**
 * The species control, as the two animals themselves — a port of
 * `CompanionSpeciesPicker`.
 *
 * It replaced a segmented picker that defaulted to `.dog`, which nobody
 * experienced as a decision: a dog owner never noticed it and a cat owner
 * corrected it, so the species the whole demo scored against was an
 * assumption. Nothing is preselected here, and "has not chosen" stays a real
 * state.
 *
 * The unchosen animal dims **in place and stays tappable**, so a mis-tap is
 * recoverable inside the same gesture — it is the screen transition that
 * takes the choice away, not the tap. That escape hatch matters, because the
 * choice drives scoring for every scan afterwards.
 */
export function SpeciesPicker({
  value,
  onPick,
}: {
  value: Species | null;
  onPick: (species: Species) => void;
}) {
  const { t } = useTranslation();

  return (
    <div className="species">
      {(["dog", "cat"] as const).map((species) => {
        const chosen = value === species;
        const dimmed = value !== null && !chosen;
        return (
          <button
            key={species}
            type="button"
            className={`species__card${chosen ? " species__card--on" : ""}${
              dimmed ? " species__card--dim" : ""
            }`}
            aria-pressed={chosen}
            aria-label={t(`index.${species}`)}
            onClick={() => onPick(species)}
          >
            <img
              className="species__rig"
              src={species === "cat" ? catArt : dogArt}
              alt=""
              aria-hidden="true"
            />
            <span className="species__label">{t(`index.${species}`)}</span>
          </button>
        );
      })}
    </div>
  );
}
