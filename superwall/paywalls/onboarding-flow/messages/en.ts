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
    cta: "Get Started",
  },

  petSetup: {
    title: "Now, about your pet",
    nameLabel: "Their name",
    namePlaceholder: "e.g. Max",
    nameError: "Please enter your pet's name",
    allergenLabel: "What ingredients are you avoiding?",
    allergenOptional: "(optional)",
    footnote: "You can always update this later in Settings",
  },

  watchList: {
    title: "What should we watch out for?",
    body: "We'll warn you whenever a food contains these — pick as many or as few as you like.",
  },

  personalised: {
    title: "Here's that food, scored for {pet}",
    titleBare: "All set for {pet}",
    rescoring: "Re-scoring against their profile…",
    was: "Was {verdict}",
    now: "{verdict} for {pet}",
    // When the profile didn't move the verdict, say so plainly rather than
    // inventing a change — the screen's credibility is the whole point.
    steadyNudge: "Same verdict for {pet} — nothing in their profile changes this one. Every scan from here is checked against it.",
    exampleNudge: "That was an example. Scan your own bag any time and we'll score it against this profile.",
    noFood: "We'll score every food you scan against {pet}'s profile from here.",
    cta: "See what {pet} can eat",
  },

  index: {
    title: "Let's check what you're feeding",
    subtitle: "We read the ingredients panel and score it out of 100. Takes about five seconds.",
    species: "Who are we checking for?",
    dog: "Dog",
    cat: "Cat",
    scan: "Scan the bag",
    search: "Search by name instead",
    // The zero-input path. Named for the situation, not the mechanism —
    // "see an example" tested as a feature, "haven't got it on you" as an out.
    example: "Don't have it on you? See an example",
    opening: "Opening camera",
  },

  search: {
    title: "Which food?",
    placeholder: "Search any food or brand",
    clear: "Clear",
    popular: "Popular brands",
    searching: "Searching",
    scanInstead: "Scan the bag instead",
    // Carried over from `ProductCatalogSearchView.emptyState`, which already
    // learned that naming the shape of a good query beats "no results".
    emptyTitle: 'No matches for "{term}"',
    emptyBody: 'Try just the brand and protein, e.g. "purina chicken".',
    emptyBrowse: "Browse popular brands",
    emptyExample: "None of these — see an example",
    variants: "{count} sizes",
    failedTitle: "Search didn't run",
    failedBody: "Something went wrong reading the catalogue. You can try again, or look at an example.",
    retry: "Try again",
  },

  result: {
    exampleBadge: "Example · not your food",
    outOf: "of 100",
    safety: "Safety",
    processing: "Processing",
    suitability: "Suitability",
    continue: "Continue",
    checkOwn: "Check my own food now",
    // The screen most users actually see: the median real score is 93 and 39
    // of 64 land in the 90s. A clean label that only says "great" answers the
    // question and ends the funnel, so this has to reopen it.
    cleanNudge:
      "Most foods we check land in the 90s. What changes the answer is which flags matter for your pet — allergens for some, fillers for others. That's next.",
    flagNudge: "Here's what we'd watch in your next bag.",
    none: "none",
    found: "{count} found",
  },

  noCamera: {
    title: "No camera, no problem",
    body: "You can turn it on later in Settings. For now, two other ways in.",
    example: "See an example food",
    search: "Search by name",
  },

  notFound: {
    title: "We don't have this one yet",
    barcodeKey: "Barcode read",
    body: "We've logged it and we'll add it. Meanwhile:",
    similar: "See a similar food",
    search: "Search by name",
  },

  a11y: {
    scoreRing: "Score {score} out of 100",
    flagClear: "No issues",
    flagFound: "Issue found",
  },
} as const;
