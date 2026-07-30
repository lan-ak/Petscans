import Foundation

/// Matches raw ingredient text to ingredients in the database.
///
/// Takes its `IngredientData` as a parameter rather than reading
/// `IngredientDatabase.shared`, so the same matcher runs in the app, in tests
/// against a small fixture, and in the `matchkit` offline harness against the
/// full catalog. The coverage numbers that harness reports are only meaningful
/// because it is literally this code, not a reimplementation of it.
struct IngredientMatcher {
    // Pre-compiled regex patterns (compiled once, reused for all matching)
    private static let parentheticalRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "\\(.*?\\)", options: [])
    }()

    private static let percentageRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "\\b\\d+%?\\b", options: [])
    }()

    private static let byproductRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "\\s*by-?products?\\s*", options: [])
    }()

    // Pre-compiled descriptor patterns
    private static let descriptorPatterns: [NSRegularExpression] = {
        let descriptors = [
            "dried", "dry", "powder", "powdered", "extract", "natural", "artificial",
            "fresh", "deboned", "meal", "concentrate", "concentrated", "organic",
            "raw", "cooked", "ground", "whole", "minced", "shredded", "flaked",
            "dehydrated", "freeze-dried", "frozen", "canned", "prepared",
            "hydrolyzed", "isolated", "pure", "refined", "enriched", "fortified"
        ]
        return descriptors.compactMap { try? NSRegularExpression(pattern: "\\b\($0)\\b", options: []) }
    }()

    init() {}

    /// Match raw ingredient text against a given database. Synchronous and pure —
    /// this is the entry point tests and `matchkit` use.
    func match(rawIngredients: String, data: IngredientData) -> [MatchedIngredient] {
        let ingredients = data.ingredients

        let tokens = Self.tokenize(rawIngredients, data: data)
        return tokens.enumerated().map { index, labelName in
            let normalized = Self.normalizeToken(labelName)
            let resolution = resolve(normalized, data: data)

            // Look up processing level from ingredient database
            let processingLevel: ProcessingLevel?
            if let id = resolution.id, let ingredient = ingredients[id] {
                processingLevel = ingredient.processingLevel
            } else {
                processingLevel = nil
            }

            return MatchedIngredient(
                ingredientId: resolution.id,
                labelName: labelName,
                rank: index + 1,
                processingLevel: processingLevel,
                matchConfidence: resolution.confidence
            )
        }
    }

    /// Resolve one normalized token, recording *how* it resolved.
    ///
    /// The stages run strongest-first and stop at the first hit, so the recorded
    /// confidence is the best available explanation for the match rather than the
    /// last one tried.
    func resolve(_ normalized: String, data: IngredientData) -> (id: String?, confidence: MatchConfidence) {
        if let id = data.synonyms[normalized] {
            return (id, .exact)
        }
        if let id = matchWithoutDescriptors(normalized, synonyms: data.synonyms) {
            return (id, .descriptor)
        }
        if let id = fuzzyMatch(normalized, data: data) {
            return (id, .fuzzy)
        }
        return (nil, .none)
    }

    /// Turn a raw label into the tokens that become ingredient rows.
    ///
    /// Two steps, in order: split on the separators that are outside any bracket,
    /// then expand `Header (a, b, c)` groups into their members. Both steps need to
    /// happen here rather than at the call sites — every ingredient list in the app
    /// arrives through `match`, and the offline harness measures this same function.
    static func tokenize(_ raw: String, data: IngredientData) -> [String] {
        splitTopLevel(raw).flatMap { expandGroup($0, data: data, depth: 0) }
    }

    /// Split on commas and semicolons, but only those outside every bracket.
    ///
    /// Labels routinely group sub-ingredients in parentheses — e.g.
    /// "Vitamins (Vitamin E Supplement, Thiamine Mononitrate, Vitamin D3 Supplement)".
    /// A naive split on every comma shatters that group into "Vitamins (Vitamin E Supplement",
    /// "Thiamine Mononitrate", "Vitamin D3 Supplement)" — dangling-paren tokens that fail
    /// synonym matching and read as broken in the UI. Keeping the group whole here lets
    /// `expandGroup` take it apart properly, or leave it alone if it isn't a list.
    ///
    /// Bracket tracking is a stack of the *open* delimiters rather than a depth counter,
    /// because real labels contain unbalanced brackets and the two failure modes need
    /// opposite handling:
    ///
    /// - **An orphan closer inside a group that does close later.** OCR drops the "(" from
    ///   "Riboflavin Supplement (Vitamin B-2)" inside a `[...]` vitamin pack. A depth
    ///   counter lets that ")" close the pack; everything after it splits as if it were
    ///   top-level and the pack's real "]" ends up glued to whatever token happened to be
    ///   last. That orphan must be ignored.
    /// - **An orphan closer standing in for the group's real closer.** A pack opened with
    ///   "[" and closed with ")" — the "]" never arrives. Ignoring that ")" swallows the
    ///   entire rest of the label into one token, which measured far worse than the bug it
    ///   was fixing. That orphan must be honoured.
    ///
    /// What separates them is whether the open group's own closer still lies ahead, so
    /// that is what `closesInnermost` looks for. Nothing here can be decided from the
    /// current character alone.
    private static func splitTopLevel(_ raw: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var open: [Character] = []
        let chars = Array(raw)

        for (i, ch) in chars.enumerated() {
            switch ch {
            case "(", "[", "{":
                open.append(ch)
                current.append(ch)
            case ")", "]", "}":
                if let matching = opener(for: ch), let position = open.lastIndex(of: matching) {
                    // Its own opener is open — close it, discarding any groups left
                    // dangling inside it.
                    open.removeSubrange(position...)
                } else if closesInnermost(ch, at: i, in: chars, open: open) {
                    open.removeLast()
                }
                current.append(ch)
            case ",", ";":
                if open.isEmpty {
                    tokens.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
            case ".":
                if open.isEmpty && isSentenceBreak(at: i, in: chars) {
                    tokens.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
            case ":":
                // Everything before a top-level colon is a heading, not an ingredient:
                // "Ingredients:", "Prime Filets with Ocean Whitefish & Tuna:". Dropping
                // it is the point — kept, it merges with the first real ingredient and
                // matches on whatever word of the recipe name happens to be an
                // ingredient, which is how "…Ocean Whitefish & Tuna: Water" becomes a
                // whitefish row.
                if open.isEmpty {
                    current = ""
                } else {
                    current.append(ch)
                }
            default:
                current.append(ch)
            }
        }
        tokens.append(current)
        return tokens
            .map { trimmingOrphanBrackets($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty && !isLotCode($0) }
    }

    /// Drop a leading or trailing bracket that nothing in the token pairs with.
    ///
    /// Keeping the group together means the orphan ")" in "Riboflavin Supplement Vitamin
    /// B-2)" survives to become a row of its own, and `labelName` is what the ingredient
    /// list displays. Matching already ignores brackets; this is so the row doesn't read
    /// as damaged text to someone checking a label against their pet's food.
    private static func trimmingOrphanBrackets(_ token: String) -> String {
        var result = Substring(token)
        func occurrences(_ ch: Character) -> Int { result.reduce(0) { $1 == ch ? $0 + 1 : $0 } }

        while let last = result.last, let open = opener(for: last), occurrences(open) < occurrences(last) {
            result = result.dropLast()
            while let last = result.last, last.isWhitespace { result = result.dropLast() }
        }
        while let first = result.first, let close = closer(for: first), occurrences(close) < occurrences(first) {
            result = result.dropFirst(1).drop(while: \.isWhitespace)
        }
        return String(result)
    }

    /// Manufacturing codes printed after the ingredient list — "J453018C", "H611423".
    /// They used to hide inside a neighbouring token ("Potassium Chloride. J453018C");
    /// splitting sentences promotes them to rows of their own, and a row that says
    /// "B615523 — unknown ingredient" is worse than no row at all.
    private static func isLotCode(_ token: String) -> Bool {
        token.count <= 12
            && token.contains(where: \.isNumber)
            && token.allSatisfy { $0.isNumber || ($0.isLetter && $0.isUppercase) }
    }

    /// Whether an orphan closer — one whose own opener was never seen — should be taken
    /// as ending the innermost open group. It should, unless that group's own closer is
    /// still to come, in which case the orphan is stray punctuation inside it.
    ///
    /// "Still to come" has to mean *before the next group of the same kind opens*. A
    /// variety pack repeats "Minerals [...], Vitamins [...]" once per recipe, so there is
    /// always another "]" somewhere ahead; accepting any of them as this group's closer
    /// keeps a malformed "Vitamins [... )" open across every remaining recipe on the
    /// label and collapses hundreds of ingredients into one token.
    private static func closesInnermost(
        _ ch: Character, at index: Int, in chars: [Character], open: [Character]
    ) -> Bool {
        guard let innermost = open.last, let proper = closer(for: innermost) else { return false }
        for next in chars[(index + 1)...] {
            if next == proper { return false }
            if next == innermost { break }
        }
        return true
    }

    private static func opener(for closer: Character) -> Character? {
        switch closer {
        case ")": return "("
        case "]": return "["
        case "}": return "{"
        default: return nil
        }
    }

    /// Whether a period ends a run of ingredients rather than sitting inside one.
    ///
    /// Variety packs put each recipe in its own sentence — "…Vitamin D-3 Supplement].
    /// Flaked Ocean Whitefish Dinner: Water, …" — and a label that ends mid-thought is
    /// routinely followed by a lot code ("Potassium Chloride. J453018C"). Without this,
    /// everything from the last comma of one recipe to the first comma of the next is a
    /// single row, and any group at that boundary can never be expanded because it no
    /// longer ends at its own bracket.
    ///
    /// Two things are deliberately not sentence breaks: a decimal point, which has no
    /// space after it, and the periods in an initialism like "B.H.A.", whose last period
    /// does. Requiring the preceding word to be longer than one character separates them.
    private static func isSentenceBreak(at index: Int, in chars: [Character]) -> Bool {
        let next = index + 1
        guard next >= chars.count || chars[next].isWhitespace else { return false }

        var wordLength = 0
        var i = index - 1
        while i >= 0, chars[i].isLetter || chars[i].isNumber {
            wordLength += 1
            i -= 1
        }
        // A bracket or another period immediately before is a real end of a list
        // ("…Supplement]."), so only an actual one-letter word disqualifies the break.
        return wordLength != 1
    }

    private static func closer(for opener: Character) -> Character? {
        switch opener {
        case "(": return ")"
        case "[": return "]"
        case "{": return "}"
        default: return nil
        }
    }

    private static func isOpener(_ ch: Character) -> Bool { ch == "(" || ch == "[" || ch == "{" }
    private static func isCloser(_ ch: Character) -> Bool { opener(for: ch) != nil }

    /// Expand `Header (a, b, c)` into `a`, `b`, `c` when the header is a category
    /// rather than an ingredient.
    ///
    /// A bracketed list on a label means one of two things, and they need opposite
    /// treatment:
    ///
    /// - **The header names a category.** "Minerals [Zinc Sulphate, Ferrous Sulphate, …]",
    ///   "Vitamins [Vitamin E Supplement, Niacin (Vitamin B-3), …]". The members are the
    ///   ingredients; the header is a heading. Held together as one token it becomes a
    ///   single row that fuzzy-matches to whichever member has the longest synonym key —
    ///   six minerals collapsing into "sodium selenite" — so the other members are invisible
    ///   to rules, allergens and avoidance groups, and the row carries one badge that
    ///   describes one twelfth of what it contains.
    /// - **The header names the ingredient.** "Fish Oil (source of DHA, EPA)". Expanding
    ///   that would delete the fish oil and leave two fragments that mean nothing alone.
    ///
    /// The discriminator is the header itself: a category word ("vitamins", "minerals",
    /// "preservatives") is not in the ingredient database, an ingredient is. Requiring at
    /// least one member to resolve as well keeps freeform notes that happen to contain a
    /// comma from being torn into pieces.
    ///
    /// Only `.exact`/`.descriptor` count as resolving. Fuzzy containment is a guess, and a
    /// guess on the header is precisely the failure this exists to remove.
    private static func expandGroup(_ token: String, data: IngredientData, depth: Int) -> [String] {
        guard depth < maxGroupDepth,
              let group = groupParts(token) else { return [token] }

        let members = splitTopLevel(group.inner)
        guard members.count >= 2,
              !resolvesCertainly(group.header, data: data),
              members.contains(where: { resolvesCertainly($0, data: data) }) else { return [token] }

        return members.flatMap { expandGroup($0, data: data, depth: depth + 1) }
    }

    /// Nested packs do occur ("Minerals [… , Vitamins (…)]"), runaway nesting does not.
    private static let maxGroupDepth = 3

    /// Split `Vitamins [A, B, C]` into header and inner text. `nil` when the token isn't
    /// a header followed by a bracketed span running to its end — "(Vitamin B-12)" has no
    /// header at all, and "Chicken Fat (preserved with mixed tocopherols)" qualifies here
    /// and is rejected by `expandGroup` for having only one member.
    ///
    /// The span is taken from the *first* opener to a final closer, without matching them
    /// off against each other. Bracket counting is what fails on these tokens: the group
    /// that most needs expanding is precisely the one holding an OCR-orphaned ")", and
    /// counting brackets in a group like that never balances, so it would be handed back
    /// whole — the one outcome this must not produce.
    ///
    /// The opener and closer need not even be the same kind. "Vitamins [A, B, C)" is a
    /// printing error, not an ambiguity.
    private static func groupParts(_ token: String) -> (header: String, inner: String)? {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        guard let last = trimmed.last, isCloser(last),
              let openIndex = trimmed.firstIndex(where: isOpener) else { return nil }

        let header = trimmed[..<openIndex].trimmingCharacters(in: .whitespaces)
        guard !header.isEmpty else { return nil }
        let inner = String(trimmed[trimmed.index(after: openIndex)..<trimmed.index(before: trimmed.endIndex)])
        return (header, inner)
    }

    /// Whether a fragment resolves without falling back to a fuzzy guess. Shares
    /// `normalizeToken` and the descriptor strip with `resolve`, so a member that
    /// expansion counts as known is one matching will actually find.
    private static func resolvesCertainly(_ text: String, data: IngredientData) -> Bool {
        let normalized = normalizeToken(text)
        guard !normalized.isEmpty else { return false }
        if data.synonyms[normalized] != nil { return true }
        return data.synonyms[strippingDescriptors(normalized)] != nil
    }

    // Cached character set for filtering (avoid recreating on every call)
    private static let allowedChars: CharacterSet = {
        CharacterSet.alphanumerics
            .union(CharacterSet.whitespaces)
            .union(CharacterSet(charactersIn: "'-/"))
    }()

    /// Normalize ingredient token for matching.
    ///
    /// `static` and internal because `IngredientData` needs the *identical*
    /// normalization to derive lookup keys from ingredient names. If the two ever
    /// diverged, a derived key would be unreachable by the very tokens it exists
    /// to catch — the failure would be silent and would look like missing data.
    static func normalizeToken(_ s: String) -> String {
        var result = s.lowercased()

        // Normalize smart quotes
        result = result.replacingOccurrences(of: "'", with: "'")

        // Remove parentheticals (using pre-compiled regex)
        if let regex = Self.parentheticalRegex {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "
            )
        }

        // Remove special characters except apostrophe, hyphen, slash
        result = String(result.unicodeScalars.filter { Self.allowedChars.contains($0) })

        // Collapse whitespace
        result = result.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Try matching without common descriptors like "dried", "powder", etc.
    ///
    /// Exact-only: the containment fallback that used to live at the end of this
    /// function is now `fuzzyMatch`, so the two can be told apart in
    /// `MatchConfidence`. They are very different claims about how well we know
    /// what an ingredient is.
    private func matchWithoutDescriptors(_ normalized: String, synonyms: [String: String]) -> String? {
        synonyms[Self.strippingDescriptors(normalized)]
    }

    /// Last-resort containment match: the token *contains* a known synonym key.
    ///
    /// Two things changed here, both because this path was producing wrong
    /// ingredients in production, and a wrong id feeds risk level, processing
    /// level, rules and allergen matching — so it moves the score, not just the
    /// label.
    ///
    /// **Deterministic order.** It used to iterate the synonyms dictionary and
    /// take the first hit. Swift `Dictionary` order depends on a per-process hash
    /// seed, so the same token could resolve to a different ingredient on
    /// different launches of the same build — and the answer was persisted into
    /// the scan. Measured over the shipped catalog, 32.6% of the occurrences
    /// reaching this path had two or more candidate keys, so that was ~44,000
    /// coin flips. Longest-key-first is deterministic and also more specific:
    /// "pearled barley" resolves to barley rather than to pear.
    ///
    /// **One direction only.** The old code also accepted the reverse — a synonym
    /// key containing the token — which is a much weaker claim and produced the
    /// worst errors: "preserved with mixed tocopherols" matched the *key*
    /// "chicken fat preserved with mixed tocopherols" and came back as chicken
    /// fat, 895 times. Dropping it costs 1.9 points of raw match rate and removes
    /// that entire class.
    ///
    /// This is still a guess. It is recorded as `.fuzzy` so the UI can show it as
    /// one.
    private func fuzzyMatch(_ normalized: String, data: IngredientData) -> String? {
        let stripped = Self.strippingDescriptors(normalized)
        guard stripped.count > 3 else { return nil }

        for entry in data.synonymsByLengthDescending where entry.key.count > 3 {
            if stripped.contains(entry.key) { return entry.id }
        }
        return nil
    }

    /// Strip descriptors, percentages and by-product suffixes from a normalized token.
    ///
    /// `static` for the same reason as `normalizeToken`: group expansion runs before
    /// any matcher instance is involved and has to decide "is this a known ingredient"
    /// the same way `resolve` will.
    private static func strippingDescriptors(_ normalized: String) -> String {
        var stripped = normalized

        // Remove all descriptors using pre-compiled patterns
        for pattern in Self.descriptorPatterns {
            stripped = pattern.stringByReplacingMatches(
                in: stripped,
                range: NSRange(stripped.startIndex..., in: stripped),
                withTemplate: ""
            )
        }

        // Remove common weight/percentage indicators (using pre-compiled regex)
        if let regex = Self.percentageRegex {
            stripped = regex.stringByReplacingMatches(
                in: stripped,
                range: NSRange(stripped.startIndex..., in: stripped),
                withTemplate: ""
            )
        }

        // Remove "by-product", "by product", "byproduct" as a suffix (using pre-compiled regex)
        if let regex = Self.byproductRegex {
            stripped = regex.stringByReplacingMatches(
                in: stripped,
                range: NSRange(stripped.startIndex..., in: stripped),
                withTemplate: ""
            )
        }

        // Collapse whitespace
        return stripped.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
