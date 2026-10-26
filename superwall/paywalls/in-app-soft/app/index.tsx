import { useState } from "react";
import {
  useActions,
  useDevice,
  useHaptics,
  useIntroductoryOffer,
  useProducts,
  usePurchase,
  useTranslation,
} from "superwall/hooks";
import laurelLeft from "../assets/laurel-left.png";
import laurelRight from "../assets/laurel-right.png";
import { BellRing, Check, Crown, Star, UnlockKeyhole } from "../components/Icons";
import { has, num, offerKind, s, type OfferKind } from "../lib/offer";

const SELECTABLE = ["primary", "secondary"] as const;
type Reference = (typeof SELECTABLE)[number];

/**
 * The one page: a trial timeline while the selected plan carries an intro
 * offer the store will honour, and social proof when it doesn't.
 *
 * Eligibility is the store's answer (`useIntroductoryOffer`), the original's
 * `hasIntroductoryOffer`. On top of that the page checks the *selected*
 * product, because the weekly carries no intro. Without that check, an
 * eligible user who taps weekly would see "In -2 Days - Reminder" and
 * "Redeem 0 days", which is what the dashboard original rendered.
 */
export default function Index() {
  const { getProduct } = useProducts();
  const { purchase } = usePurchase();
  const { openUrl, restore } = useActions();
  const { eligible } = useIntroductoryOffer();
  const { hostPlatform } = useDevice();
  const haptics = useHaptics();
  const { t } = useTranslation();

  const [selectedIndex, setSelectedIndex] = useState(0);
  const [restoreFailed, setRestoreFailed] = useState(false);

  const selected = getProduct(SELECTABLE[selectedIndex]);
  const kind: OfferKind = eligible === true ? offerKind(selected) : "none";
  const offer = kind !== "none";

  const { trialPeriodDays: days, trialPeriodPrice: trialPrice, trialPeriodEndDate: trialEnd, price, period } =
    selected?.variables ?? {};

  const reminderDay = num(days) === undefined ? undefined : Number(days) - 2;

  const select = (index: number) => {
    haptics.selection();
    setSelectedIndex(index);
  };

  const buy = async (reference: Reference) => {
    haptics.medium();
    const result = await purchase(reference);
    if (result.status === "completed") haptics.success();
  };

  const onRestore = async () => {
    haptics.light();
    setRestoreFailed(false);
    const result = await restore();
    if (result?.status === "failed") setRestoreFailed(true);
  };

  const chargeTitle = has(days)
    ? kind === "paid"
      ? t("timelineChargeTitlePaid", { days: s(days) })
      : t("timelineChargeTitleFree", { days: s(days) })
    : t("timelineChargeTitleBare");

  const chargeDetail = has(trialEnd, price)
    ? t("timelineChargeDated", { price: s(price), date: s(trialEnd) })
    : has(trialEnd)
      ? t("timelineChargeDatedBare", { date: s(trialEnd) })
      : t("timelineChargeBare");

  const cta =
    kind === "paid" && has(days, trialPrice)
      ? t("ctaPaid", { days: s(days), price: s(trialPrice) })
      : kind === "free" && has(days)
        ? t("ctaFree", { days: s(days) })
        : t("ctaNone");

  const magic =
    kind === "paid" && has(trialPrice)
      ? t("magicPaid", { price: s(trialPrice) })
      : kind === "free"
        ? t("magicFree")
        : t("magicNone");

  const pricing = !has(price, period)
    ? undefined
    : kind === "paid" && has(days, trialPrice)
      ? t("pricingPaid", { days: s(days), trialPrice: s(trialPrice), price: s(price), period: s(period) })
      : kind === "free" && has(days)
        ? t("pricingFree", { days: s(days), price: s(price), period: s(period) })
        : t("pricingNone", { price: s(price), period: s(period) });

  /** Restore is a store concept; show neither variant until the host is known. */
  const native = hostPlatform === "ios" || hostPlatform === "android";

  return (
    <main className="page">
      <h1 className="headline">{offer ? t("headlineOffer") : t("headlineNoOffer")}</h1>

      {offer ? (
        <ol className="timeline">
          <li className="timeline__item">
            <span className="timeline__marker timeline__marker--filled">
              <UnlockKeyhole />
            </span>
            <div className="timeline__copy">
              <span className="timeline__title">{t("timelineTodayTitle")}</span>
              <p className="timeline__detail">{t("timelineTodayDetail")}</p>
            </div>
          </li>
          {reminderDay !== undefined && reminderDay >= 1 ? (
            <li className="timeline__item">
              <span className="timeline__marker">
                <BellRing />
              </span>
              <div className="timeline__copy">
                <span className="timeline__title">{t("timelineReminderTitle", { days: reminderDay })}</span>
                <p className="timeline__detail">
                  {kind === "paid" ? t("timelineReminderPaid") : t("timelineReminderFree")}
                </p>
              </div>
            </li>
          ) : null}
          <li className="timeline__item">
            <span className="timeline__marker">
              <Crown />
            </span>
            <div className="timeline__copy">
              <span className="timeline__title">{chargeTitle}</span>
              <p className="timeline__detail">{chargeDetail}</p>
            </div>
          </li>
        </ol>
      ) : (
        <div className="bento">
          <div className="accolades">
            <Accolade text={t("accoladeSources")} />
            <Accolade text={t("accoladeIngredients")} />
          </div>
          <div className="review">
            <div className="review__top">
              <div className="review__left">
                <span className="review__title">{t("reviewTitle")}</span>
                <span className="review__stars">
                  {[0, 1, 2, 3, 4].map((index) => (
                    <Star key={index} />
                  ))}
                </span>
              </div>
              <div className="review__right">
                <span>{t("reviewDate")}</span>
                <span>{t("reviewAuthor")}</span>
              </div>
            </div>
            <p className="review__body">{t("reviewBody")}</p>
          </div>
        </div>
      )}

      <div className="footer">
        <div className="plans">
          {SELECTABLE.map((reference, index) => (
            <PlanRow
              key={reference}
              reference={reference}
              selected={selectedIndex === index}
              eligible={eligible === true}
              onSelect={() => select(index)}
            />
          ))}
        </div>

        <div className="magic">
          <Check size={24} />
          <span>{magic}</span>
        </div>

        <button type="button" className="cta pressable" onClick={() => buy(SELECTABLE[selectedIndex])}>
          {cta}
        </button>

        {pricing ? <p className="pricing">{pricing}</p> : null}
        {restoreFailed ? <p className="pricing" role="status">{t("restoreFailed")}</p> : null}

        <div className="links">
          <button
            type="button"
            onClick={() => {
              haptics.light();
              openUrl("https://petscans.app/privacy");
            }}
          >
            {t("privacy")}
          </button>
          {native ? (
            <button type="button" onClick={onRestore}>
              {t("restore")}
            </button>
          ) : null}
          <button
            type="button"
            onClick={() => {
              haptics.light();
              openUrl("https://petscans.app/terms");
            }}
          >
            {t("terms")}
          </button>
        </div>
      </div>
    </main>
  );
}

function Accolade({ text }: { text: string }) {
  return (
    <div className="accolade">
      <img className="accolade__laurel" src={laurelLeft} alt="" />
      <span className="accolade__text">{text}</span>
      <img className="accolade__laurel" src={laurelRight} alt="" />
    </div>
  );
}

type PlanRowProps = {
  reference: Reference;
  selected: boolean;
  eligible: boolean;
  onSelect: () => void;
};

/**
 * One plan. With an intro the label is the offer and the caption the renewal;
 * without one the label is the price, and the annual adds its weekly
 * equivalent and the "Most popular" tab, as the original's no-trial rows did.
 */
function PlanRow({ reference, selected, eligible, onSelect }: PlanRowProps) {
  const { getProduct } = useProducts();
  const { t } = useTranslation();
  const product = getProduct(reference);
  const { price, period, periodly, weeklyPrice, trialPeriodDays: days, trialPeriodPrice: trialPrice } =
    product?.variables ?? {};
  const kind: OfferKind = eligible ? offerKind(product) : "none";

  const label =
    kind === "paid" && has(days, trialPrice)
      ? t("planTrialPaid", { days: s(days), trialPrice: s(trialPrice) })
      : kind === "free" && has(days)
        ? t("planTrialFree", { days: s(days) })
        : reference === "primary"
          ? (periodly ?? "")
          : has(price, period)
            ? t("planPrice", { price: s(price), period: s(period) })
            : (periodly ?? "");

  const caption =
    kind !== "none" && has(price, period)
      ? t("planThen", { price: s(price), period: s(period) })
      : reference === "primary" && has(price, period)
        ? t("planBilled", { price: s(price), period: s(period) })
        : undefined;

  const popular = kind === "none" && reference === "primary";

  return (
    <button
      type="button"
      className={`plan pressable${selected ? " plan--selected" : ""}${popular ? " plan--tab" : ""}`}
      aria-pressed={selected}
      onClick={onSelect}
    >
      {popular ? <span className="plan__tab">{t("planPopular")}</span> : null}
      <span className="plan__left">
        <span className="plan__label">{label}</span>
        {caption ? <span className="plan__caption">{caption}</span> : null}
      </span>
      {popular && has(weeklyPrice) ? (
        <span className="plan__weekly">{t("planWeekly", { price: s(weeklyPrice) })}</span>
      ) : null}
      <span className="plan__radio">{selected ? <Check size={24} /> : null}</span>
    </button>
  );
}
