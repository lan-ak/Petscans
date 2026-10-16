import { useHaptics, useTranslation, useVariables } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { Companion } from "../components/Companion";
import { Check } from "../components/Icons";
import { petName, petSpecies } from "../lib/variables";

/**
 * What a scan returns — the manufactured aha.
 *
 * The user reaching this page has scored nothing, so there is no result to
 * reflect. What the app does know is their pet: `pet_species` is set for 265
 * of these 272 users, and `pet_name` for 126. So the page opens on their own
 * animal, then shows the three verdicts a scan can come back with.
 *
 * Both reads are guarded. The species falls back to the dog rig (81% of this
 * audience) and the name falls back to "your pet", which is the majority path
 * here, not an edge case.
 */
export default function Index() {
  const { user } = useVariables();
  const { t } = useTranslation();
  const haptics = useHaptics();
  const router = useRouter();

  const pet = petName(user);
  const species = petSpecies(user);

  /** One example per verdict band, in the species the user actually owns. */
  const samples =
    species === "cat"
      ? [
          { band: "excellent", score: 94, name: t("intro.catExcellent"), verdict: t("intro.verdictExcellent") },
          { band: "moderate", score: 61, name: t("intro.catModerate"), verdict: t("intro.verdictModerate") },
          { band: "poor", score: 23, name: t("intro.catPoor"), verdict: t("intro.verdictPoor") },
        ]
      : [
          { band: "excellent", score: 94, name: t("intro.dogExcellent"), verdict: t("intro.verdictExcellent") },
          { band: "moderate", score: 61, name: t("intro.dogModerate"), verdict: t("intro.verdictModerate") },
          { band: "poor", score: 23, name: t("intro.dogPoor"), verdict: t("intro.verdictPoor") },
        ];

  return (
    <main className="page">
      <div className="hero">
        <div className="eyebrow">
          <Check size={14} />
          {t("intro.eyebrow")}
        </div>

        <Companion
          species={species}
          alt={species === "cat" ? t("intro.companionCat") : t("intro.companionDog")}
        />

        <h1 className="hero__headline">{t("intro.headline", { pet })}</h1>
        <p className="hero__sub">{t("intro.sub")}</p>

        <div className="sample-list">
          {samples.map((sample) => (
            <div className="result-card" key={sample.band}>
              <div className="result-card__top">
                <span
                  className={`score-ring score-ring--${sample.band}`}
                  style={{ ["--score" as string]: String(sample.score) }}
                  aria-hidden="true"
                >
                  <span className="score-ring__value">{sample.score}</span>
                </span>
                <div className="result-card__food">
                  <span className="result-card__name">{sample.name}</span>
                  <span className="result-card__verdict result-card__verdict--inline">
                    <span className={`score-dot score-dot--${sample.band}`} />
                    <span>{sample.verdict}</span>
                  </span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Sticky, so the three sample cards scroll under it on a short phone. */}
      <div className="footer">
        <button
          type="button"
          className="cta pressable"
          onClick={() => {
            haptics.medium();
            router.push("plans");
          }}
        >
          {t("intro.cta")}
        </button>
      </div>
    </main>
  );
}
