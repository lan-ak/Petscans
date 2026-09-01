import { useHaptics, useProducts, usePurchase } from "superwall/hooks";
import { has, offerKind } from "../lib/offer";

type Props = {
  /** Tapping the plan card just puts the drawer away — the offer is spent. */
  onDismissOffer: () => void;
  /** "No thanks, close" dismisses the drawer and the paywall with it. */
  onClosePaywall: () => void;
};

/**
 * The one-shot fallback offer shown when a user tries to leave the plans page,
 * selling the tertiary slot rather than whichever plan is selected.
 */
export const ExitOfferDrawer = ({ onDismissOffer, onClosePaywall }: Props) => {
  const { getProduct } = useProducts();
  const { purchase } = usePurchase();
  const haptics = useHaptics();

  const offer = getProduct("tertiary");
  const { price, period, periodly, trialPeriodDays, trialPeriodPrice } = offer?.variables ?? {};
  const kind = offerKind(offer);

  // Every string forks on the offer, and every variable can still be missing.
  const priced = has(price, period);
  const description =
    kind === "paid" && has(trialPeriodDays, trialPeriodPrice) && priced
      ? `We'd hate to see you go. Try PetScans for ${trialPeriodDays} days for just ${trialPeriodPrice}, then ${price}/${period}.`
      : kind === "free" && has(trialPeriodDays) && priced
        ? `We'd hate to see you go. Try PetScans free for ${trialPeriodDays} days, then ${price}/${period}.`
        : priced
          ? `We'd hate to see you go. Get PetScans for ${price}/${period}.`
          : "We'd hate to see you go. Here's PetScans at our lowest price.";

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
      ? `Claim offer — ${trialPeriodDays} days for ${trialPeriodPrice}`
      : kind === "free" && has(trialPeriodDays)
        ? `Claim offer — ${trialPeriodDays} days free`
        : priced
          ? `Claim offer — ${price}/${period}`
          : "Claim offer";

  return (
    <div className="drawer" role="dialog" aria-label="Special offer">
      {/* Tapping outside is the same gesture as tapping the plan card. */}
      <button
        type="button"
        className="drawer__scrim"
        aria-label="Dismiss offer"
        onClick={onDismissOffer}
      />
      <div className="drawer__sheet">
        <div className="drawer__head">
          <h2 className="drawer__title">Wait — here's a special offer</h2>
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
            const result = await purchase("tertiary");
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
