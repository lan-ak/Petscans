import { useHaptics, useProducts, usePurchase } from "superwall/hooks";
import { has, offerKind } from "../lib/offer";

type Props = {
  /** Tapping the plan card just puts the drawer away — the offer is spent. */
  onDismissOffer: () => void;
  /** "No thanks, close" dismisses the drawer and the paywall with it. */
  onClosePaywall: () => void;
};

/**
 * The one-shot drawer shown when a user tries to leave the plans page.
 *
 * It sells the secondary slot — the monthly plan — as a lighter commitment
 * rather than a discount. Month-to-month costs more over a year than the annual
 * plan does, so nothing here may claim to be a saving or a "special offer": the
 * only honest pitch is the shorter commitment, and that is the one we make.
 */
export const ExitOfferDrawer = ({ onDismissOffer, onClosePaywall }: Props) => {
  const { getProduct } = useProducts();
  const { purchase } = usePurchase();
  const haptics = useHaptics();

  const offer = getProduct("secondary");
  const { price, period, periodly, trialPeriodDays, trialPeriodPrice } = offer?.variables ?? {};
  const kind = offerKind(offer);

  // Every string forks on the offer, and every variable can still be missing.
  const priced = has(price, period);
  const description =
    kind === "paid" && has(trialPeriodDays, trialPeriodPrice) && priced
      ? `Not ready to commit to a year? Try PetScans for ${trialPeriodDays} days for just ${trialPeriodPrice}, then ${price}/${period}.`
      : kind === "free" && has(trialPeriodDays) && priced
        ? `Not ready to commit to a year? Try PetScans free for ${trialPeriodDays} days, then ${price}/${period}.`
        : priced
          ? `Not ready to commit to a year? Get PetScans for ${price}/${period} instead.`
          : "Not ready to commit to a year? Take PetScans month to month instead.";

  const planName = `Your ${periodly ?? ""} plan`.replace("  ", " ");
  const planTitle =
    kind === "paid" && has(trialPeriodDays, trialPeriodPrice)
      ? `${planName} — ${trialPeriodDays} days for ${trialPeriodPrice}`
      : kind === "free" && has(trialPeriodDays)
        ? `${planName} — ${trialPeriodDays} days free`
        : has(price)
          ? `${planName} — ${price}`
          : planName;

  const planDetail = priced
    ? `${kind === "none" ? "" : "Then "}${price}/${period}. Cancel anytime.`
    : "Cancel anytime.";

  const ctaLabel =
    kind === "paid" && has(trialPeriodDays, trialPeriodPrice)
      ? `Switch to ${periodly ?? "monthly"} — ${trialPeriodDays} days for ${trialPeriodPrice}`
      : kind === "free" && has(trialPeriodDays)
        ? `Switch to ${periodly ?? "monthly"} — ${trialPeriodDays} days free`
        : priced
          ? `Switch to ${periodly ?? "monthly"} — ${price}/${period}`
          : `Switch to ${periodly ?? "monthly"}`;

  return (
    <div className="drawer" role="dialog" aria-label="Month to month option">
      {/* Tapping outside is the same gesture as tapping the plan card. */}
      <button
        type="button"
        className="drawer__scrim"
        aria-label="Dismiss offer"
        onClick={onDismissOffer}
      />
      <div className="drawer__sheet">
        <div className="drawer__head">
          <h2 className="drawer__title">Wait — try it month to month</h2>
          <p className="drawer__sub">{description}</p>
        </div>

        <button
          type="button"
          className="drawer__plan"
          onClick={() => {
            haptics.light();
            onDismissOffer();
          }}
        >
          <span className="drawer__plan-title">{planTitle}</span>
          <span className="drawer__plan-detail">{planDetail}</span>
        </button>

        <button
          type="button"
          className="drawer__cta pressable"
          onClick={async () => {
            haptics.medium();
            const result = await purchase("secondary");
            if (result.status === "completed") haptics.success();
          }}
        >
          {ctaLabel}
        </button>

        <button
          type="button"
          className="drawer__dismiss"
          onClick={() => {
            haptics.light();
            onClosePaywall();
          }}
        >
          No thanks, close
        </button>
      </div>
    </div>
  );
};
