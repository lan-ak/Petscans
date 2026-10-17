/**
 * Every user-facing string in the surface, so a second locale is one new file
 * and no code change. The app itself is English-only in-product today (only
 * the store metadata is translated), so this is the first place PetScans copy
 * has been reviewable in one piece.
 *
 * Wording follows the native screens it replaces where they already had a
 * line that worked — `ProductCatalogSearchView` had spent several passes on
 * its empty state, and that reasoning is in its comments.
 */
export default {
  chrome: {
    back: "Back",
    close: "Close",
    done: "Done",
    stepOf: "Step {n} of {total}",
  },

  common: {
    continue: "Continue",
  },

  promise: {
    // The headline the Meta concept test won on (6.26% CTR, best of five), so
    // the app opens on the same promise the ad made rather than a greeting.
    title: "Find out what's really in your pet's food",
    body: "Most bags hide something. Scan any food and see what your pet should be avoiding — in seconds.",
  },

  petSetup: {
    // `PetFormView` / `AllergenSelectionView`, word for word.
    title: "Let's meet your pet",
    namePlaceholder: "Pet Name",
    species: "Species",
    searchMore: "Search for more...",
    nameError: "Please enter your pet's name",
    allergenLabel: "What ingredients are you avoiding?",
    allergenOptional: "(optional)",
    footnote: "You can always update this later in Settings",
  },

  watchList: {
    title: "What should we watch out for?",
    body: "We'll warn you whenever a food contains these — pick as many or as few as you like.",
  },

  // `OnboardingPersonalizedResultView`, word for word.
  personalised: {
    title: "Now scored for {pet}",
    titleBare: "Now scored for your pet",
    inGeneral: "In general: {verdict}",
    forPet: "For {pet}",
    bannerTitle: "Contains Ingredients {pet} Should Avoid",
    watchTitle: "On your watch list",
    planTitle: "From now on, every scan checks",
    planUnsafe: "Ingredients that are unsafe for {pet}",
    planGroupsOne: "1 thing on your watch list",
    planGroups: "{count} things on your watch list",
    planToxic: "Toxic ingredients and species warnings",
  },

  // 1.4.8 native step 1, `OnboardingFoodCheckPage`, word for word.
  index: {
    title: "Let's see what's really in pet food",
    subtitle: "Pick a popular one. We'll score it out of 100, the same way we'll score yours.",
    species: "Who are we checking for?",
    dog: "Dog",
    cat: "Cat",
    pick: "Pick a food",
    footnote: "You'll scan your own bag right after setup.",
  },

  result: {
    safety: "Safety",
    processing: "Processing",
    // `OnboardingFoodResultView`, word for word.
    clearTitle: "Nothing here is a general concern.",
    clearBody: "That's the general picture. Tell us who's eating it and we'll check it against their own allergies.",
    inside: "What's inside",
    insideHint: "Tap an ingredient to see what it is",
    impact: {
      positive: "Good",
      negative: "Concern",
      neutral: "Neutral",
    },
    suitability: "Suitability",
    none: "none",
    found: "{count} found",
  },

  // `IngredientDetailSheet`, word for word. `{animal}` is "dogs" or "cats".
  ingredient: {
    navTitle: "Ingredient Details",
    details: "Details",
    origin: "Origin",
    processing: "Processing",
    allergenRisk: "Allergen Risk",
    suitableFor: "Suitable For",
    sources: "Sources",
    dogs: "dogs",
    cats: "cats",
    watch: "What to watch for",
    safety: "Safety Information",
    perSpecies: "Species-specific risk:",
    symptoms: "Possible Symptoms",
    dose: "Toxic Dose",
    notes: "Notes",
    research: "What the research says",
    risk: {
      toxic: "This ingredient is not recommended for {animal}. It may cause adverse health effects. Please review the information below for details.",
      caution: "This ingredient may not be suitable for all {animal}. Some animals may have sensitivities or there may be concerns with certain formulations. Check the notes below for specific information.",
      moderation: "This ingredient is generally fine for {animal} in normal amounts. A few animals are sensitive to it — the notes below cover what to watch for.",
      mostlySafe: "This ingredient is generally fine for {animal} in normal amounts. A few animals are sensitive to it — the notes below cover what to watch for.",
      safe: "This ingredient is generally considered safe for {animal} when used appropriately.",
    },
    evidence: {
      strong: "Strong evidence",
      moderate: "Moderate evidence",
      limited: "Limited evidence",
      debated: "Debated",
    },
  },

  // `IngredientSearchSheet`, word for word.
  search: {
    navTitle: "Search Ingredients",
    placeholder: "Search {count} ingredients",
    clear: "Clear",
    selectedOne: "1 ingredient selected",
    selected: "{count} ingredients selected",
    doneCount: "Done ({count} selected)",
  },

  a11y: {
    scoreRing: "Score {score} out of 100",
    flagClear: "No issues",
    flagFound: "Issue found",
  },

  // `onboarding-scan` (276012), word for word, so the paywall reads the same
  // whether it is this flow's last step or the native flow's paywall.
  plans: {
    headlinePaid: "Protect every bowl {pet} eats — {days} days for {price}",
    headlineFree: "Protect every bowl {pet} eats — free for {days} days",
    headlineBare: "Protect every bowl {pet} eats.",
    headlineNoOffer: "Never guess what's in {pet}'s bowl again.",

    timelineTodayTitle: "Today - Instant access",
    timelineTodayDetail: "Unlock every scan, safety score and allergen alert for {pet}.",
    timelineReminderTitle: "In {days} days - Reminder",
    // A 3-day trial reminds on day 1; 276012 says "In 1 days".
    timelineReminderTitleOne: "In 1 day - Reminder",
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
    // Each row carries the renewal terms, never just the offer — App Review.
    planTrialFree: "{days} days free, then {price} per {period}",
    planTrialPaid: "{days} days for {trialPrice}, then {price} per {period}",

    terms: "Terms",
    privacy: "Privacy",
    restore: "Restore",
  },

  exitOffer: {
    title: "Wait — here's a special offer",
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
