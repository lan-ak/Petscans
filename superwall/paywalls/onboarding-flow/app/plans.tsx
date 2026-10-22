import { useState } from "react";
import {
  useActions,
  useDevice,
  useHaptics,
  useProducts,
  usePurchase,
  useTranslation,
} from "superwall/hooks";
import laurelLeft from "../assets/laurel-left.png";
import laurelRight from "../assets/laurel-right.png";
import { BellRing, Check, Crown, Star, UnlockKeyhole } from "../components/PaywallIcons";
import { useLineup } from "../lib/lineup";
import { has, num, offerKind, s } from "../lib/offer";
import { petLabel } from "../lib/state";
import { useStep } from "../lib/track";

const SELECTABLE = ["primary", "secondary"] as const;

/**
 * Step 6 — the paywall, inside the flow.
 *
 * This is the plans page of `onboarding-scan` (276012), the paywall campaign
 * 64348 used to show on `onboarding_complete` once this surface had closed.
 * Same plans, same timeline, same exit offer, same copy — moved in here so
 * the step after the personalised verdict is the offer itself, with no
 * dismissal and second presentation in between.
 *
 * The profile has already been handed to the app (`onboardingDone`) before
 * this page is pushed, so however the surface closes — a purchase, a restore,
 * or "No thanks" — the app has everything it needs to persist the pet.
 *
 * The app still registers `onboarding_complete` when the surface closes; on
 * 1.4.8+ nothing answers it, since campaign 64348 is gated to older versions.
 *
 * The weekly price-test arms show this page too, with a weekly plan in the
 * primary slot. It has no trial, so it takes the no-offer branch (reviews,
 * not the timeline), and it gets no "Save X%" badge: see `savingsPercent`.
 */
export default function Plans() {
  const { getProduct } = useProducts();
  const { purchase } = usePurchase();
  const { openUrl, restore } = useActions();
  const { hostPlatform } = useDevice();
  const haptics = useHaptics();
  const { t } = useTranslation();
  const lineup = useLineup();
  useStep("plans");

  const [selectedIndex, setSelectedIndex] = useState(0);

  const primary = getProduct("primary");
  const secondary = getProduct("secondary");
  const selected = getProduct(SELECTABLE[selectedIndex]);

  const pet = petLabel();
  const kind = offerKind(selected);

  const trialDays = selected?.variables.trialPeriodDays;
  const trialPrice = selected?.variables.trialPeriodPrice;
  const price = selected?.variables.price;
  const period = selected?.variables.period;
  const trialText = selected?.variables.trialPeriodText;

  // The timeline counts down the plan under the user's thumb, never `primary`.
  const trialEnd = selected?.variables.trialPeriodEndDate;

  const reminderDay = num(trialDays) === undefined ? undefined : Number(trialDays) - 2;
  const showReminderStep = reminderDay !== undefined && reminderDay >= 1;

  /** Timeline when the selected plan has a trial, reviews when it doesn't — as 276012. */
  const showTimeline = kind !== "none";

  const savings =
    lineup === "yearly"
      ? savingsPercent(num(primary?.variables.rawPrice), num(secondary?.variables.rawPrice))
      : undefined;

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

  // Always name the amount when the store has given one — App Review looks here.
  const chargeDetail = has(trialEnd, price)
    ? t("plans.timelineChargeDated", { price: s(price), date: s(trialEnd) })
    : has(trialEnd)
      ? t("plans.timelineChargeDatedBare", { date: s(trialEnd) })
      : has(price)
        ? t("plans.timelineChargePriced", { price: s(price) })
        : t("plans.timelineChargeBare");

  return (
    <div className="page">
      <div className="page__body pw">
        <div className="scroller">
          <h1 className="pw-headline">{headline}</h1>

          {showTimeline ? (
            <div className="pw-timeline">
              <div className="pw-timeline__item">
                <span className="pw-timeline__rail" />
                <span className="pw-timeline__marker">
                  <UnlockKeyhole />
                </span>
                <div className="pw-timeline__copy">
                  <span className="pw-timeline__title">{t("plans.timelineTodayTitle")}</span>
                  <p className="pw-timeline__detail">{t("plans.timelineTodayDetail", { pet })}</p>
                </div>
              </div>

              {showReminderStep ? (
                <div className="pw-timeline__item">
                  <span className="pw-timeline__rail" />
                  <span className="pw-timeline__marker pw-timeline__marker--outline">
                    <BellRing />
                  </span>
                  <div className="pw-timeline__copy">
                    <span className="pw-timeline__title">
                      {reminderDay === 1
                        ? t("plans.timelineReminderTitleOne")
                        : t("plans.timelineReminderTitle", { days: reminderDay })}
                    </span>
                    <p className="pw-timeline__detail">
                      {kind === "paid" ? t("plans.timelineReminderPaid") : t("plans.timelineReminderFree")}
                    </p>
                  </div>
                </div>
              ) : null}

              <div className="pw-timeline__item">
                <span className="pw-timeline__rail" />
                <span className="pw-timeline__marker pw-timeline__marker--outline">
                  <Crown />
                </span>
                <div className="pw-timeline__copy">
                  <span className="pw-timeline__title">{chargeTitle}</span>
                  <p className="pw-timeline__detail">{chargeDetail}</p>
                </div>
              </div>
            </div>
          ) : (
            <div className="pw-bento">
              <div className="pw-accolades">
                <Accolade figure={t("plans.accoladeSources")} label={t("plans.accoladeSourcesLabel")} />
                <Accolade figure={t("plans.accoladeIngredients")} label={t("plans.accoladeIngredientsLabel")} />
              </div>
              <Review
                title={t("plans.reviewTitle")}
                meta={t("plans.reviewMeta")}
                date={t("plans.reviewDate")}
                body={t("plans.reviewBody")}
              />
            </div>
          )}
        </div>

        <div className="actions pw-actions">
          <div className="pw-plan-list">
            <PlanRow reference="primary" index={0} selectedIndex={selectedIndex} onSelect={select} savings={savings} />
            <PlanRow reference="secondary" index={1} selectedIndex={selectedIndex} onSelect={select} />
          </div>

          <div className="pw-magic">
            <Check size={22} />
            <span>
              {kind === "none"
                ? t("plans.magicNone")
                : kind === "paid" && has(trialPrice)
                  ? t("plans.magicPaid", { price: s(trialPrice) })
                  : t("plans.magicFree")}
            </span>
          </div>

          <button type="button" className="btn btn--primary pressable" onClick={() => buy(SELECTABLE[selectedIndex])}>
            {kind === "paid" && has(trialDays, trialPrice)
              ? t("plans.ctaPaid", { days: s(trialDays), price: s(trialPrice) })
              : kind === "free" && has(trialText)
                ? t("plans.ctaFree", { trial: s(trialText) })
                : t("plans.ctaNone")}
          </button>

          {has(price, period) ? (
            <div className="pw-pricing">
              {kind === "paid" && has(trialDays, trialPrice)
                ? t("plans.pricingPaid", { days: s(trialDays), trialPrice: s(trialPrice), price: s(price), period: s(period) })
                : kind === "free" && has(trialDays)
                  ? t("plans.pricingFree", { days: s(trialDays), price: s(price), period: s(period) })
                  : t("plans.pricingNone", { price: s(price), period: s(period) })}
            </div>
          ) : null}

          <div className="pw-legal">
            <button
              type="button"
              onClick={() => {
                haptics.light();
                openUrl("https://petscans.app/terms");
              }}
            >
              {t("plans.terms")}
            </button>
            <span aria-hidden="true">·</span>
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
                <span aria-hidden="true">·</span>
                <button
                  type="button"
                  onClick={async () => {
                    haptics.light();
                    const result = await restore();
                    if (result.status === "restored") haptics.success();
                  }}
                >
                  {t("plans.restore")}
                </button>
              </>
            ) : null}
          </div>
        </div>
      </div>
    </div>
  );
}

/**
 * What the annual plan saves against twelve months of the monthly — the only
 * comparison a buyer can act on. Renders nothing until both prices arrive, or
 * if there is no saving to claim.
 *
 * Yearly lineup only. The sum treats the primary as an annual price, so on a
 * weekly arm it would read $4.99 a week as a 95% saving on the monthly. Above
 * about $2.07 a week, a weekly plan costs more per month than the monthly, so
 * there is no honest saving to claim.
 */
function savingsPercent(annualRaw?: number, monthlyRaw?: number) {
  if (!annualRaw || !monthlyRaw) return undefined;
  const yearOfMonthly = monthlyRaw * 12;
  if (annualRaw >= yearOfMonthly) return undefined;
  return Math.round(((yearOfMonthly - annualRaw) / yearOfMonthly) * 100);
}

function Accolade({ figure, label }: { figure: string; label: string }) {
  return (
    <div className="pw-accolade">
      <img className="pw-accolade__laurel" src={laurelLeft} alt="" />
      <span className="pw-accolade__stat">
        <span className="pw-accolade__figure">{figure}</span>
        <span className="pw-accolade__label">{label}</span>
      </span>
      <img className="pw-accolade__laurel" src={laurelRight} alt="" />
    </div>
  );
}

function Review({ title, meta, date, body }: { title: string; meta: string; date: string; body: string }) {
  return (
    <div className="pw-review">
      <div className="pw-review__top">
        <div className="pw-review__left">
          <span className="pw-review__title">{title}</span>
          <div className="pw-review__stars">
            {[0, 1, 2, 3, 4].map((index) => (
              <Star key={index} />
            ))}
          </div>
        </div>
        <div className="pw-review__right">
          <span className="pw-review__meta">{date}</span>
          <span className="pw-review__meta">{meta}</span>
        </div>
      </div>
      <p className="pw-review__body">{body}</p>
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

function PlanRow({ reference, index, selectedIndex, onSelect, savings }: PlanRowProps) {
  const { getProduct } = useProducts();
  const { t } = useTranslation();
  const product = getProduct(reference);
  const { periodly, price, period, trialPeriodDays, trialPeriodPrice } = product?.variables ?? {};
  const kind = offerKind(product);
  const isSelected = selectedIndex === index;

  const priced = has(price, period);
  // The whole offer in one line; it never abbreviates the renewal terms.
  const caption =
    kind === "paid" && has(trialPeriodDays, trialPeriodPrice) && priced
      ? t("plans.planTrialPaid", { days: s(trialPeriodDays), trialPrice: s(trialPeriodPrice), price: s(price), period: s(period) })
      : kind === "free" && has(trialPeriodDays) && priced
        ? t("plans.planTrialFree", { days: s(trialPeriodDays), price: s(price), period: s(period) })
        : priced
          ? t("plans.planBilled", { price: s(price), period: s(period) })
          : undefined;

  const callout =
    reference === "primary" && savings !== undefined ? t("plans.planSaving", { percent: savings }) : undefined;

  return (
    <button
      type="button"
      className={`pw-plan${isSelected ? " pw-plan--selected" : ""}${callout ? " pw-plan--callout" : ""}`}
      aria-pressed={isSelected}
      onClick={() => onSelect(index)}
    >
      {callout ? <span className="pw-plan__callout">{callout}</span> : null}
      <span className="pw-plan__left">
        {/* `periodly` localises itself — never a catalog string. */}
        <span className="pw-plan__label">{periodly ?? ""}</span>
        {caption ? <span className="pw-plan__caption">{caption}</span> : null}
      </span>
      <span className="pw-plan__radio">{isSelected ? <Check size={22} /> : null}</span>
    </button>
  );
}
