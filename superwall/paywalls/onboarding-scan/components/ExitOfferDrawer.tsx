import { useHaptics, useProducts, usePurchase, useTranslation } from "superwall/hooks";
import { has, offerKind, s } from "../lib/offer";

type Props = {
  /** Tapping the plan card just puts the drawer away — the offer is spent. */
  onDismissOffer: () => void;
  /** "No thanks, close" dismisses the drawer and the paywall with it. */
  onClosePaywall: () => void;
};

/**
 * The one-shot drawer shown when a user tries to leave the plans page.
 *
 * It sells the **tertiary** slot, and tertiary exists for nothing else. That is
 * `annual_39.99`: $39.99/year behind a 30-day $0.99 intro — cheaper than the
 * $59.99 primary on the page *and* with a longer, nearly-free runway. 245894
 * does exactly this, which is why its drawer can honestly say "here's a special
 * offer": the intro offer is never one of the two rows, so there is a real
 * concession left to make at the door.
 *
 * It used to sell `secondary` — the monthly plan — framed as a lighter
 * commitment rather than a discount, because month-to-month costs more over a
 * year and claiming a saving would have been false. With tertiary carrying the
 * intro, the saving is real and the copy can say so.
 */
export const ExitOfferDrawer = ({ onDismissOffer, onClosePaywall }: Props) => {
  const { getProduct } = useProducts();
  const { purchase } = usePurchase();
  const haptics = useHaptics();
  const { t } = useTranslation();

  const offer = getProduct("tertiary");
  const { price, period, periodly, trialPeriodDays, trialPeriodPrice } = offer?.variables ?? {};
  const kind = offerKind(offer);

  // Every string forks on the offer, and every variable can still be missing.
  const priced = has(price, period);

  const description =
    kind === "paid" && has(trialPeriodDays, trialPeriodPrice) && priced
      ? t("exitOffer.descPaid", {
          days: s(trialPeriodDays),
          trialPrice: s(trialPeriodPrice),
          price: s(price),
          period: s(period),
        })
      : kind === "free" && has(trialPeriodDays) && priced
        ? t("exitOffer.descFree", { days: s(trialPeriodDays), price: s(price), period: s(period) })
        : priced
          ? t("exitOffer.descNone", { price: s(price), period: s(period) })
          : t("exitOffer.descBare");

  const planTitle =
    kind === "paid" && has(trialPeriodDays, trialPeriodPrice)
      ? t("exitOffer.planPaid", {
          periodly: s(periodly),
          days: s(trialPeriodDays),
          trialPrice: s(trialPeriodPrice),
        })
      : kind === "free" && has(trialPeriodDays)
        ? t("exitOffer.planFree", { periodly: s(periodly), days: s(trialPeriodDays) })
        : has(price)
          ? t("exitOffer.planNone", { periodly: s(periodly), price: s(price) })
          : t("exitOffer.planBare", { periodly: s(periodly) });

  const planDetail = priced
    ? t("exitOffer.planDetail", { price: s(price), period: s(period) })
    : t("exitOffer.planDetailBare");

  const ctaLabel =
    kind === "paid" && has(trialPeriodDays, trialPeriodPrice)
      ? t("exitOffer.ctaPaid", { days: s(trialPeriodDays), trialPrice: s(trialPeriodPrice) })
      : kind === "free" && has(trialPeriodDays)
        ? t("exitOffer.ctaFree", { days: s(trialPeriodDays) })
        : priced
          ? t("exitOffer.ctaNone", { price: s(price), period: s(period) })
          : t("exitOffer.ctaBare");

  return (
    <div className="drawer" role="dialog" aria-label={t("exitOffer.title")}>
      {/* Tapping outside is the same gesture as tapping the plan card. */}
      <button
        type="button"
        className="drawer__scrim"
        aria-label={t("exitOffer.dismissAria")}
        onClick={onDismissOffer}
      />
      <div className="drawer__sheet">
        <div className="drawer__head">
          <h2 className="drawer__title">{t("exitOffer.title")}</h2>
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
          {t("exitOffer.dismiss")}
        </button>
      </div>
    </div>
  );
};
