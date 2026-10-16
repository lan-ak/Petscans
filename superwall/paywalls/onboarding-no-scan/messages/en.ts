/**
 * Every user-facing string on the no-scan paywall.
 *
 * Nothing here carries a price: prices arrive from the store already localised
 * and are interpolated at the call site, always guarded on the value existing.
 *
 * The sample foods are deliberately **unbranded**. The three cards exist to
 * show what a verdict looks like, and putting an invented score beside a real
 * manufacturer's name would be a public claim about that product. If PetScans
 * wants to stand behind specific branded examples, swap these for real scores
 * out of the catalogue — that is a product decision, not a copy one.
 */
export default {
  chrome: {
    back: "Back",
    close: "Close",
  },

  /* ------------------------------------------- page 1: what a scan returns */
  intro: {
    eyebrow: "WHAT YOU'LL SEE",

    // Forks on pet_name, which 146 of 272 of these users have never set.
    headline: "Every food {pet} eats gets a score.",
    // Sells confidence at the shelf rather than describing the mechanism: the
    // job to be done is the next purchase, standing in an aisle, deciding.
    sub: "Scan any bag in the aisle and know what's in it before you buy — all 30+ ingredients, in seconds.",

    // Unbranded on purpose — see the note at the top of this file.
    dogExcellent: "Grass-fed dry food",
    dogModerate: "Everyday chicken kibble",
    dogPoor: "Bacon-flavour strips",
    catExcellent: "Wild-caught dry food",
    catModerate: "Everyday tuna pâté",
    catPoor: "Seafood treat mix",

    verdictExcellent: "Excellent · nothing to avoid",
    verdictModerate: "Caution · 4 to avoid",
    verdictPoor: "Avoid · 9 to avoid",

    companionDog: "Your dog",
    companionCat: "Your cat",

    // Plain "Continue", matching every onboarding step before this page.
    // The offer is on the next page; this button only moves there.
    cta: "Continue",
  },

  /* ---------------------------------------------------- page 2: the offer */
  plans: {
    headlinePaid: "Protect every bowl {pet} eats — {days} days for {price}",
    headlineFree: "Protect every bowl {pet} eats — free for {days} days",
    headlineBare: "Protect every bowl {pet} eats.",
    // Shown when the selected plan has no introductory offer at all —
    // the monthly row, and any user who has already spent their trial.
    headlineNoOffer: "Never guess what's in {pet}'s bowl again.",

    timelineTodayTitle: "Today - Instant access",
    timelineTodayDetail: "Unlock every scan, safety score and allergen alert for {pet}.",
    timelineReminderTitle: "In {days} days - Reminder",
    timelineReminderPaid: "We'll send you a reminder before your intro price ends.",
    timelineReminderFree: "We'll send you a reminder that your trial is ending soon.",
    timelineChargeTitlePaid: "In {days} Days - Full Price Starts",
    timelineChargeTitleFree: "In {days} Days - Billing Starts",
    timelineChargeTitleBarePaid: "Full Price Starts",
    timelineChargeTitleBareFree: "Billing Starts",
    timelineChargeDated: "You'll be charged {price} on {date} unless you cancel anytime before.",
    timelineChargeDatedBare: "You'll be charged on {date} unless you cancel anytime before.",
    timelineChargePriced: "You'll be charged {price} unless you cancel anytime before.",
    timelineChargeBare: "You'll be charged unless you cancel anytime before.",

    // Only rendered when there is no introductory offer to explain. With a
    // trial on the table the timeline answers the live question ("when am I
    // charged"); proof answers a question nobody is asking yet.
    accoladeSources: "5",
    accoladeSourcesLabel: "verified\nsources",
    accoladeIngredients: "3,000",
    accoladeIngredientsLabel: "ingredients\nscored",
    reviewTitle: "Caught what the label hid",
    reviewMeta: "Jessica R.",
    reviewDate: "Mar 15",
    reviewBody:
      'I scanned my dog\'s "premium" treats and three came back AVOID for BHA and artificial dyes. PetScans caught what the label buried — I switched brands the same day.',

    magicNone: "No commitment, cancel anytime",
    magicPaid: "Just {price} due today",
    magicFree: "No payment due now",

    ctaPaid: "Try {days} days for {price}",
    ctaFree: "Start my {trial} free trial",
    ctaNone: "Unlock PetScans",

    pricingPaid: "{days} days for {trialPrice}, then {price} per {period}. Cancel anytime.",
    pricingFree: "{days} days free, then {price} per {period}. Cancel anytime.",
    pricingNone: "{price} per {period}. Cancel anytime.",

    planSaving: "Save {percent}%",
    planBilled: "{price} per {period}",

    /*
     * Each row states the full terms — what is free, for how long, and what
     * renews at what price. App Review rejects a subscription paywall that
     * shows a trial without the price and period it converts to, so these
     * three strings always carry the renewal, never just the offer.
     */
    planTrialFree: "{days} days free, then {price} per {period}",
    planTrialPaid: "{days} days for {trialPrice}, then {price} per {period}",

    terms: "Terms",
    privacy: "Privacy",
    restore: "Restore",
  },

  /* ---------------------------------------------------- the exit offer */
  exitOffer: {
    title: "Wait — here's a special offer",
    // The tertiary slot is the intro offer and nothing else, so this really is
    // a concession: cheaper per year than the plan on the page, behind a
    // 30-day near-free runway. The copy may say "offer" because it is one.
    descFree: "We'd hate to see you go. Try PetScans free for {days} days, then {price}/{period}.",
    descPaid:
      "We'd hate to see you go. Try PetScans for {days} days for just {trialPrice}, then {price}/{period}.",
    descNone: "We'd hate to see you go. Get PetScans for {price}/{period}.",
    descBare: "We'd hate to see you go. Here's our best offer instead.",
    planFree: "Your {periodly} plan — {days} days free",
    planPaid: "Your {periodly} plan — {days} days for {trialPrice}",
    planNone: "Your {periodly} plan — {price}",
    planBare: "Your {periodly} plan",
    planDetail: "Then {price}/{period}. Cancel anytime.",
    planDetailBare: "Cancel anytime.",
    ctaFree: "Claim offer — {days} days free",
    ctaPaid: "Claim offer — {days} days for {trialPrice}",
    ctaNone: "Claim offer — {price}/{period}",
    ctaBare: "Claim offer",
    dismiss: "No thanks, close",
    dismissAria: "Dismiss offer",
  },
} as const;
