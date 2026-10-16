import { useState } from "react";
import {
  useActions,
  useDevice,
  useHaptics,
  useProducts,
  usePurchase,
  useTranslation,
  useVariables,
} from "superwall/hooks";
import laurelLeft from "../assets/laurel-left.png";
import laurelRight from "../assets/laurel-right.png";
import { BellRing, Check, Crown, Star, UnlockKeyhole } from "../components/Icons";
import { has, num, offerKind, s } from "../lib/offer";
import { petName } from "../lib/variables";

const SELECTABLE = ["primary", "secondary"] as const;

/**
 * What the annual plan saves against paying monthly for the same year:
 *
 *     (monthly x 12 - annual) / (monthly x 12)
 *
 * That is the only comparison the badge may make, because it is the only one a
 * buyer can act on — twelve months either way, one price against the other.
 *
 * The earlier version compared the annual's *per-month* cost to the monthly
 * price and wrapped it in `Math.abs`, which reached the same number by a longer
 * route and would have reported a "saving" even if the annual were the dearer
 * of the two. Both inputs are store-owned, so the badge simply does not render
 * until they arrive — or if there is no saving to claim.
 */
const savingsPercent = (annualRaw?: number, monthlyRaw?: number) => {
  if (!annualRaw || !monthlyRaw) return undefined;
  const yearOfMonthly = monthlyRaw * 12;
  if (annualRaw >= yearOfMonthly) return undefined;
  return Math.round(((yearOfMonthly - annualRaw) / yearOfMonthly) * 100);
};

/** The plans page: what they get, when they're charged, and what it costs. */
export default function Plans() {
  const { user } = useVariables();
  const { getProduct } = useProducts();
  const { purchase } = usePurchase();
  const { openUrl, restore } = useActions();
  const { hostPlatform } = useDevice();
  const haptics = useHaptics();
  const { t } = useTranslation();

  const [selectedIndex, setSelectedIndex] = useState(0);

  const primary = getProduct("primary");
  const secondary = getProduct("secondary");
  const selected = getProduct(SELECTABLE[selectedIndex]);

  const pet = petName(user);

  const kind = offerKind(selected);

  const trialDays = selected?.variables.trialPeriodDays;
  const trialPrice = selected?.variables.trialPeriodPrice;
  const price = selected?.variables.price;
  const period = selected?.variables.period;
  const trialText = selected?.variables.trialPeriodText;

  /*
   * The timeline counts down the plan the user has tapped, so every step reads
   * `selected`, exactly as 245894's liquid does. Reading `primary` here would
   * count down to a charge they have not chosen.
   */
  const trialEnd = selected?.variables.trialPeriodEndDate;

  const reminderDay = num(trialDays) === undefined ? undefined : Number(trialDays) - 2;
  const showReminderStep = reminderDay !== undefined && reminderDay >= 1;

  /**
   * Timeline when the **selected** plan has a trial, reviews when it doesn't.
   *
   * This is 245894's behaviour, replicated. In the editor document the Timeline
   * and the Social Proof Bento both branch on `products.selected.trialPeriodText`,
   * as do the two headers — so tapping a row with no trial swaps the header, the
   * panel, the magic words, the CTA and the fine print together. The page is
   * describing the plan under the user's thumb, and the timeline is only honest
   * while that plan is the one being counted down.
   *
   * The rows themselves no longer fork on a layout: both carry a per-week price
   * whatever offer they hold, so nothing restyles as the user moves between them.
   */
  const showTimeline = kind !== "none";

  const savings = savingsPercent(
    num(primary?.variables.rawPrice),
    num(secondary?.variables.rawPrice),
  );


  /** Restore is a store concept; the Web SDK has no receipts to restore. */
  const native = hostPlatform === "ios" || hostPlatform === "android";

  const buy = async (reference: (typeof SELECTABLE)[number]) => {
    haptics.medium();
    const result = await purchase(reference);
    if (result.status === "completed") haptics.success();
  };

  const select = (index: number) => {
    haptics.selection();
    setSelectedIndex(index);
  };

  /*
   * The header pair, 245894's "No Trial Header" / "Trial Eligible Header".
   * Both branch on the selected plan, so the headline changes with the row.
   */
  const headline =
    kind === "none"
      ? t("plans.headlineNoOffer", { pet })
      : kind === "paid" && has(trialDays, trialPrice)
        ? t("plans.headlinePaid", { pet, days: s(trialDays), price: s(trialPrice) })
        : has(trialDays)
          ? t("plans.headlineFree", { pet, days: s(trialDays) })
          : t("plans.headlineBare", { pet });

  const chargeTitle = has(trialDays)
    ? kind === "paid"
      ? t("plans.timelineChargeTitlePaid", { days: s(trialDays) })
      : t("plans.timelineChargeTitleFree", { days: s(trialDays) })
    : kind === "paid"
      ? t("plans.timelineChargeTitleBarePaid")
      : t("plans.timelineChargeTitleBareFree");

  /*
   * Always name the amount when the store has given us one, free trial or not.
   * This used to withhold the price on the free-trial branch and show only a
   * date — the fine print carried the number, but the step that says "you will
   * be charged" is exactly where App Review expects to see it.
   */
  const chargeDetail =
    has(trialEnd, price)
      ? t("plans.timelineChargeDated", { price: s(price), date: s(trialEnd) })
      : has(trialEnd)
        ? t("plans.timelineChargeDatedBare", { date: s(trialEnd) })
        : has(price)
          ? t("plans.timelineChargePriced", { price: s(price) })
          : t("plans.timelineChargeBare");

  return (
    <main className="page page--plans">
      <h1 className="plans__headline">{headline}</h1>

      {showTimeline ? (
        <div className="timeline">
          <div className="timeline__item">
            <span className="timeline__rail" />
            <span className="timeline__marker">
              <UnlockKeyhole />
            </span>
            <div className="timeline__copy">
              <span className="timeline__title">{t("plans.timelineTodayTitle")}</span>
              <p className="timeline__detail">{t("plans.timelineTodayDetail", { pet })}</p>
            </div>
          </div>

          {showReminderStep ? (
            <div className="timeline__item">
              <span className="timeline__rail" />
              <span className="timeline__marker timeline__marker--outline">
                <BellRing />
              </span>
              <div className="timeline__copy">
                <span className="timeline__title">
                  {t("plans.timelineReminderTitle", { days: reminderDay })}
                </span>
                <p className="timeline__detail">
                  {kind === "paid"
                    ? t("plans.timelineReminderPaid")
                    : t("plans.timelineReminderFree")}
                </p>
              </div>
            </div>
          ) : null}

          <div className="timeline__item">
            <span className="timeline__rail" />
            <span className="timeline__marker timeline__marker--outline">
              <Crown />
            </span>
            <div className="timeline__copy">
              <span className="timeline__title">{chargeTitle}</span>
              <p className="timeline__detail">{chargeDetail}</p>
            </div>
          </div>
        </div>
      ) : (
        <div className="bento">
          <div className="accolades">
            <div className="accolade">
              <img className="accolade__laurel" src={laurelLeft} alt="" />
              <span className="accolade__stat">
                <span className="accolade__figure">{t("plans.accoladeSources")}</span>
                <span className="accolade__label">{t("plans.accoladeSourcesLabel")}</span>
              </span>
              <img className="accolade__laurel" src={laurelRight} alt="" />
            </div>
            <div className="accolade">
              <img className="accolade__laurel" src={laurelLeft} alt="" />
              <span className="accolade__stat">
                <span className="accolade__figure">{t("plans.accoladeIngredients")}</span>
                <span className="accolade__label">{t("plans.accoladeIngredientsLabel")}</span>
              </span>
              <img className="accolade__laurel" src={laurelRight} alt="" />
            </div>
          </div>

          <Review
            title={t("plans.reviewTitle")}
            meta={t("plans.reviewMeta")}
            date={t("plans.reviewDate")}
            body={t("plans.reviewBody")}
          />
        </div>
      )}

      <div className="footer">
        <div className="plan-list">
          <PlanRow
            reference="primary"
            index={0}
            selectedIndex={selectedIndex}
            onSelect={select}
            savings={savings}
          />
          <PlanRow
            reference="secondary"
            index={1}
            selectedIndex={selectedIndex}
            onSelect={select}
          />
        </div>

        <div className="magic-words">
          <Check size={24} />
          <span>
            {kind === "none"
              ? t("plans.magicNone")
              : kind === "paid" && has(trialPrice)
                ? t("plans.magicPaid", { price: s(trialPrice) })
                : t("plans.magicFree")}
          </span>
        </div>

        <button
          type="button"
          className="cta pressable"
          onClick={() => buy(SELECTABLE[selectedIndex])}
        >
          {kind === "paid" && has(trialDays, trialPrice)
            ? t("plans.ctaPaid", { days: s(trialDays), price: s(trialPrice) })
            : kind === "free" && has(trialText)
              ? t("plans.ctaFree", { trial: s(trialText) })
              : t("plans.ctaNone")}
        </button>

        {has(price, period) ? (
          <div className="pricing-copy">
            {kind === "paid" && has(trialDays, trialPrice)
              ? t("plans.pricingPaid", { days: s(trialDays), trialPrice: s(trialPrice), price: s(price), period: s(period) })
              : kind === "free" && has(trialDays)
                ? t("plans.pricingFree", { days: s(trialDays), price: s(price), period: s(period) })
                : t("plans.pricingNone", { price: s(price), period: s(period) })}
          </div>
        ) : null}

        <div className="legal">
          <button
            type="button"
            onClick={() => {
              haptics.light();
              openUrl("https://petscans.app/terms");
            }}
          >
            {t("plans.terms")}
          </button>
          <span>·</span>
          <button
            type="button"
            onClick={() => {
              haptics.light();
              openUrl("https://petscans.app/privacy");
            }}
          >
            {t("plans.privacy")}
          </button>
          {native ? (
            <>
              <span>·</span>
              <button
                type="button"
                onClick={() => {
                  haptics.light();
                  restore();
                }}
              >
                {t("plans.restore")}
              </button>
            </>
          ) : null}
        </div>
      </div>
    </main>
  );
}

function Review({
  title,
  meta,
  date,
  body,
}: {
  title: string;
  meta: string;
  date: string;
  body: string;
}) {
  return (
    <div className="review">
      <div className="review__top">
        <div className="review__left">
          <span className="review__title">{title}</span>
          <div className="review__stars">
            {[0, 1, 2, 3, 4].map((index) => (
              <Star key={index} />
            ))}
          </div>
        </div>
        <div className="review__right">
          <span className="review__meta">{date}</span>
          <span className="review__meta">{meta}</span>
        </div>
      </div>
      <p className="review__body">{body}</p>
    </div>
  );
}

type PlanRowProps = {
  reference: "primary" | "secondary";
  index: number;
  selectedIndex: number;
  onSelect: (index: number) => void;
  savings?: number;
};

const PlanRow = ({
  reference,
  index,
  selectedIndex,
  onSelect,
  savings,
}: PlanRowProps) => {
  const { getProduct } = useProducts();
  const { t } = useTranslation();
  const product = getProduct(reference);
  const {
    periodly,
    price,
    period,
    trialPeriodDays,
    trialPeriodPrice,
  } = product?.variables ?? {};
  const kind = offerKind(product);
  const isSelected = selectedIndex === index;

  const priced = has(price, period);
  /*
   * The caption is the whole offer in one line — what is free, for how long,
   * and what renews at what price. With the selector in the right column it is
   * the only place the terms appear on the row, so it never abbreviates them.
   */
  const caption =
    kind === "paid" && has(trialPeriodDays, trialPeriodPrice) && priced
      ? t("plans.planTrialPaid", {
          days: s(trialPeriodDays),
          trialPrice: s(trialPeriodPrice),
          price: s(price),
          period: s(period),
        })
      : kind === "free" && has(trialPeriodDays) && priced
        ? t("plans.planTrialFree", {
            days: s(trialPeriodDays),
            price: s(price),
            period: s(period),
          })
        : priced
          ? t("plans.planBilled", { price: s(price), period: s(period) })
          : undefined;

  /**
   * The annual row carries the savings callout in both layouts. Any intro
   * offer is already spelled out in the caption, so the banner is free to do
   * the one job the caption cannot: make annual-vs-monthly obvious at a glance.
   */
  const callout =
    reference === "primary" && savings !== undefined
      ? t("plans.planSaving", { percent: savings })
      : undefined;

  return (
    <button
      type="button"
      className={`plan${isSelected ? " plan--selected" : ""}${callout ? " plan--callout" : ""}`}
      aria-pressed={isSelected}
      onClick={() => onSelect(index)}
    >
      {callout ? <span className="plan__callout">{callout}</span> : null}
      <span className="plan__left">
        {/* `periodly` localises itself in 44 locales — never a catalog string. */}
        <span className="plan__label">{periodly ?? ""}</span>
        {caption ? <span className="plan__caption">{caption}</span> : null}
      </span>
      {/*
       * The right column is the selector, not a second price: the caption on
       * the left already states the full terms, so repeating a number here only
       * competed with it. A filled circle also reads as "chosen" at a glance in
       * a way a price never does.
       */}
      <span className="plan__radio">{isSelected ? <Check size={24} /> : null}</span>
    </button>
  );
};
