import { useUser } from "superwall/hooks";
import { num } from "../lib/offer";

/**
 * The watch-list the app set at onboarding finish. Each group is its own
 * boolean attribute, so an absent one and an explicit false differ.
 */
const WATCH_LIST = [
  { attribute: "avoids_ultra_processed", label: "Ultra-processed" },
  { attribute: "avoids_artificial_colours", label: "Artificial colours" },
  { attribute: "avoids_meat_byproducts", label: "Meat by-products" },
  { attribute: "avoids_grain_fillers", label: "Grain fillers" },
  { attribute: "avoids_added_sugars", label: "Added sugars" },
  { attribute: "avoids_artificial_preservatives", label: "Preservatives" },
  { attribute: "avoids_common_allergens", label: "Common allergens" },
  { attribute: "avoids_gums_thickeners", label: "Gums & thickeners" },
] as const;

const isTrue = (value: unknown) => value === true || value === "true";

/** What a label can hide, framed against what this user asked us to catch. */
export default function Stakes() {
  const user = useUser();

  const petName = (user.pet_name as string | undefined) ?? "your pet";
  const species = (user.pet_species as string | undefined) ?? "pet";
  const groupCount = num(user.avoid_group_count as string | number | undefined) ?? 0;
  const hasGroups = groupCount >= 1;

  return (
    <main className="page page--stakes">
      <div className="stakes">
        <h1 className="stakes__headline">
          {hasGroups
            ? `Most ${species} food hide something you asked us to avoid.`
            : `Most ${species} food hide things you'd never feed.`}
        </h1>

        {hasGroups ? (
          <>
            <p className="stakes__lede">
              You told PetScans what to keep out of {petName}'s bowl:
            </p>
            <div className="chips">
              {WATCH_LIST.filter((group) => isTrue(user[group.attribute])).map((group) => (
                <span className="chip" key={group.attribute}>
                  <span className="chip__dot" />
                  {group.label}
                </span>
              ))}
            </div>
          </>
        ) : null}

        <div className="stat-card">
          <span className="stat-card__figure">30+</span>
          <p className="stat-card__caption">
            ingredients in the average bag. The ones that matter hide in the fine print — where you
            would never look.
          </p>
        </div>

        <p className="stakes__close">
          PetScans reads every ingredient in seconds — so nothing gets past you again.
        </p>
      </div>
    </main>
  );
}
