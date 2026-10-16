/**
 * Every user-facing string on the aha paywall.
 *
 * This surface predates the catalog convention — the copy used to be literals
 * in JSX. It is lifted here unchanged except where the two-page rework needed
 * new lines, so the German pass has one file to work from.
 *
 * Nothing here carries a price. Prices come from the store already localised
 * and are interpolated at the call site, always guarded on the value existing.
 *
 * No plural engine: anywhere a count can be 1, there are two keys rather than
 * one with an "(s)" in it.
 */
export default {
  chrome: {
    back: "Back",
    close: "Close",
  },

  /* ------------------------------------------------- page 1: their result */
  result: {
    eyebrow: "SCAN COMPLETE",

    // Forks on searched_food_flag_count. Every user in this audience has the
    // attribute (66 of 66), so there is no "unknown" branch — but the count
    // itself is 0 for 42% of them, and the clean copy must not imply otherwise.
    headlineOne: "You caught something in {pet}'s bowl.",
    headlineMany: "You caught {count} things in {pet}'s bowl.",
    headlineCleanBranded: "{brand} passed. Good pick.",
    headlineClean: "Nothing to avoid in that one.",

    // This audience is an OR: `placementsSinceInstall_aha_food_result >= 1`
    // admits a device whose `searched_food_*` attributes were never written or
    // have since been cleared. There is then no card to show and no flag count
    // to trust, so the page leads on the one thing still true of them.
    headlineNoResult: "{pet} eats more than you've scanned.",

    /*
     * All three subs sell confidence at the shelf, not anxiety about the bowl.
     * The old lines counted what the user hadn't scanned yet, which reads as a
     * scolding — and for the 42% holding a clean result it argues with the good
     * news in their hand. The job to be done is the next purchase: standing in
     * an aisle, deciding. The locked cards below say the same thing ("The next
     * bag"), so the page now makes one argument instead of two.
     */
    subFlagged: "Now you can catch it in the aisle — scan any bag before you buy it.",
    // Keeps 245894's "But that's just one meal." beat, then turns it forward.
    subClean: "But that's just one meal. Scan the next bag while you're still in the aisle.",

    companionDog: "Your dog",
    companionCat: "Your cat",
    subNoResult: "Scan any bag in the aisle and know what's in it before you buy.",

    nothingToAvoid: "nothing to avoid",
    toAvoid: "{count} to avoid",

    mysteryTreats: "Treats",
    mysteryNextBag: "The next bag",
    mysteryWetFood: "Wet food",

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
