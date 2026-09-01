import { useState } from "react";
import { useHaptics, useProducts, usePurchase, useUser } from "superwall/hooks";
import { useActions } from "superwall/hooks";
import laurelLeft from "../assets/laurel-left.png";
import laurelRight from "../assets/laurel-right.png";
import { BellRing, Check, Crown, Star, UnlockKeyhole } from "../components/Icons";
import { has, num, offerKind } from "../lib/offer";

const SELECTABLE = ["primary", "secondary"] as const;

/**
 * How much cheaper the annual plan works out per month, against the monthly
 * one — the dashboard paywall's liquid maths, in TypeScript.
 */
const savingsPercent = (primaryRaw?: number, secondaryRaw?: number) => {
  if (!primaryRaw || !secondaryRaw) return undefined;
  return Math.round(Math.abs(((primaryRaw / 12 - secondaryRaw) / secondaryRaw) * 100));
};

/** The plans page: what they get, when they're charged, and what it costs. */
export default function Plans() {
  const user = useUser();
  const { getProduct } = useProducts();
  const { purchase } = usePurchase();
  const { openUrl, restore } = useActions();
  const haptics = useHaptics();

  const [selectedIndex, setSelectedIndex] = useState(0);

  const primary = getProduct("primary");
  const secondary = getProduct("secondary");
  const selected = getProduct(SELECTABLE[selectedIndex]);

  const petName = (user.pet_name as string | undefined) ?? "your pet";

  const kind = offerKind(selected);
  const listKind = offerKind(primary);
  const trialDays = selected?.variables.trialPeriodDays;
  const trialPrice = selected?.variables.trialPeriodPrice;
  const trialEnd = selected?.variables.trialPeriodEndDate;
  const price = selected?.variables.price;
  const period = selected?.variables.period;
  const weekly = selected?.variables.weeklyPrice;
  const trialText = selected?.variables.trialPeriodText;

  const reminderDay = num(trialDays) === undefined ? undefined : Number(trialDays) - 2;
  const showReminderStep = reminderDay !== undefined && reminderDay >= 1;

  const savings = savingsPercent(num(primary?.variables.rawPrice), num(secondary?.variables.rawPrice));

  const buy = async (reference: (typeof SELECTABLE)[number]) => {
    haptics.medium();
    const result = await purchase(reference);
    if (result.status === "completed") haptics.success();
  };

  const select = (index: number) => {
    haptics.selection();
    setSelectedIndex(index);
  };

  return (
    <main className="page page--plans">
      {kind === "none" ? (
        <h1 className="plans__headline">Never guess what's in {petName}'s bowl again.</h1>
      ) : (
        <h1 className="plans__headline">
          {kind === "paid" && has(trialDays, trialPrice)
            ? `Protect every bowl ${petName} eats — ${trialDays} days for ${trialPrice}`
            : has(trialDays)
              ? `Protect every bowl ${petName} eats — free for ${trialDays} days`
              : `Protect every bowl ${petName} eats.`}
        </h1>
      )}

      {kind === "none" ? null : (
        <div className="timeline">
          <div className="timeline__item">
            <span className="timeline__rail" />
            <span className="timeline__marker">
              <UnlockKeyhole />
            </span>
            <div className="timeline__copy">
              <span className="timeline__title">Today - Instant access</span>
              <p className="timeline__detail">
                Unlock every scan, safety score and allergen alert for {petName}.
              </p>
            </div>
          </div>

          {showReminderStep ? (
            <div className="timeline__item">
              <span className="timeline__rail" />
              <span className="timeline__marker timeline__marker--outline">
                <BellRing />
              </span>
              <div className="timeline__copy">
                <span className="timeline__title">In {reminderDay} days - Reminder</span>
                <p className="timeline__detail">
                  {kind === "paid"
                    ? "We'll send you a reminder before your intro price ends."
                    : "We'll send you a reminder that your trial is ending soon."}
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
              <span className="timeline__title">
                {has(trialDays) ? `In ${trialDays} Days - ` : ""}
                {kind === "paid" ? "Full Price Starts" : "Billing Starts"}
              </span>
              <p className="timeline__detail">
                {has(trialEnd)
                  ? kind === "paid" && has(price)
                    ? `You'll be charged ${price} on ${trialEnd} unless you cancel anytime before.`
                    : `You'll be charged on ${trialEnd} unless you cancel anytime before.`
                  : has(price)
                    ? `You'll be charged ${price} unless you cancel anytime before.`
                    : "You'll be charged unless you cancel anytime before."}
              </p>
            </div>
          </div>
        </div>
      )}

      {kind === "none" ? (
        <div className="bento">
          <div className="accolades">
            <div className="accolade">
              <img className="accolade__laurel" src={laurelLeft} alt="" />
              <span className="accolade__label">{"Backed by\nvet science"}</span>
              <img className="accolade__laurel" src={laurelRight} alt="" />
            </div>
            <div className="accolade">
              <img className="accolade__laurel" src={laurelLeft} alt="" />
              <span className="accolade__label">{"Trusted by\npet parents"}</span>
              <img className="accolade__laurel" src={laurelRight} alt="" />
            </div>
          </div>

          <div className="review">
            <div className="review__top">
              <div className="review__left">
                <span className="review__title">Caught what the label hid</span>
                <div className="review__stars">
                  {[0, 1, 2, 3, 4].map((index) => (
                    <Star key={index} />
                  ))}
                </div>
              </div>
              <div className="review__right">
                <span className="review__meta">Mar 15</span>
                <span className="review__meta">Jessica R.</span>
              </div>
            </div>
            <p className="review__body">
              I scanned my dog's "premium" treats and three came back AVOID for BHA and artificial
              dyes. PetScans caught what the label buried — I switched brands the same day.
            </p>
          </div>
        </div>
      ) : null}

      <div className="footer">
        <div className="plan-list">
          <PlanRow
            reference="primary"
            index={0}
            selectedIndex={selectedIndex}
            onSelect={select}
            listKind={listKind}
            savings={savings}
          />
          <PlanRow
            reference="secondary"
            index={1}
            selectedIndex={selectedIndex}
            onSelect={select}
            listKind={listKind}
          />
        </div>

        <div className="magic-words">
          <Check size={24} />
          <span>
            {kind === "none"
              ? "No commitment, cancel anytime"
              : kind === "paid" && has(trialPrice)
                ? `Just ${trialPrice} due today`
                : "No payment due now"}
          </span>
        </div>

        <button type="button" className="cta pressable" onClick={() => buy(SELECTABLE[selectedIndex])}>
          {kind === "paid" && has(trialDays, trialPrice)
            ? `Try ${trialDays} days for ${trialPrice}`
            : kind === "free" && has(trialText)
              ? `Start my ${trialText} free trial`
              : "Unlock PetScans"}
        </button>

        {has(price, period) ? (
          <div className="pricing-copy">
            {kind === "paid" && has(trialDays, trialPrice)
              ? `${trialDays} days for ${trialPrice}, then ${price} per ${period}. Cancel anytime.`
              : kind === "free" && has(trialText, weekly)
                ? `${trialText} free, then ${price} per ${period} (${weekly}/wk). Cancel anytime.`
                : `${price} per ${period}. Cancel anytime.`}
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
            Terms
          </button>
          <span>·</span>
          <button
            type="button"
            onClick={() => {
              haptics.light();
              openUrl("https://petscans.app/privacy");
            }}
          >
            Privacy
          </button>
          <span>·</span>
          <button
            type="button"
            onClick={() => {
              haptics.light();
              restore();
            }}
          >
            Restore
          </button>
        </div>
      </div>
    </main>
  );
}

type PlanRowProps = {
  reference: "primary" | "secondary";
  index: number;
  selectedIndex: number;
  onSelect: (index: number) => void;
  /** The primary slot decides which of the two selector layouts renders. */
  listKind: ReturnType<typeof offerKind>;
  savings?: number;
};

const PlanRow = ({ reference, index, selectedIndex, onSelect, listKind, savings }: PlanRowProps) => {
  const { getProduct } = useProducts();
  const product = getProduct(reference);
  const { periodly, price, period, weeklyPrice, trialPeriodDays, trialPeriodPrice, trialPeriodText } =
    product?.variables ?? {};
  const kind = offerKind(product);
  const isSelected = selectedIndex === index;

  const priced = has(price, period);
  const caption =
    kind === "paid" && has(trialPeriodDays, trialPeriodPrice) && priced
      ? `${trialPeriodDays} days for ${trialPeriodPrice}, then ${price}/${period}`
      : kind === "free" && has(trialPeriodText) && priced
        ? `${trialPeriodText} free trial, then ${price}/${period}`
        : priced
          ? `Billed ${price} / ${period}`
          : undefined;

  // Only the annual row in the no-trial layout carries the savings callout.
  const callout =
    listKind === "none" && reference === "primary"
      ? kind === "paid" && has(trialPeriodDays, trialPeriodPrice)
        ? `${trialPeriodDays} days for ${trialPeriodPrice}`
        : kind === "free" && has(trialPeriodText)
          ? `${trialPeriodText} free trial`
          : savings === undefined
            ? undefined
            : `Save ${savings}%`
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
        <span className="plan__label">{periodly ?? "Plan"}</span>
        {caption ? <span className="plan__caption">{caption}</span> : null}
      </span>
      {listKind === "none" ? (
        <span className="plan__price">
          {reference === "primary"
            ? has(weeklyPrice)
              ? `${weeklyPrice}/week`
              : null
            : priced
              ? `${price}/${period}`
              : null}
        </span>
      ) : (
        <span className="plan__radio">{isSelected ? <Check size={24} /> : null}</span>
      )}
    </button>
  );
};
