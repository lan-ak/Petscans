import SwiftUI

// MARK: - State

/// Mirrors the state-machine inputs one-for-one, so swapping this SwiftUI rig for a
/// Rive one later is a view swap behind an unchanged interface.
struct CompanionMood: Equatable {
    /// −1 settle · 0 neutral · +1 wince. One axis rather than three discrete states:
    /// a fourth score band then becomes a value rather than a new pose.
    var concern: Double = 0
    /// Search or scan in flight. Drives the attend pose, which replaces a spinner
    /// rather than accompanying one.
    var busy: Bool = false

    static let neutral = CompanionMood()
    static let attending = CompanionMood(concern: 0, busy: true)

    /// Swift owns the verdict → concern mapping rather than baking it into the rig:
    /// it is business logic that belongs where it can be tested.
    static func forVerdict(score: Int, hasFlag: Bool, allergenHit: Bool) -> CompanionMood {
        if allergenHit { return CompanionMood(concern: 1) }
        if hasFlag { return CompanionMood(concern: 0.7) }
        return CompanionMood(concern: score >= 75 ? -1 : 0)
    }
}

/// The sizes the companion is allowed to be.
///
/// It shipped at 156, 110, 104, 96 and 92 across five screens — five numbers, none of
/// them derived from anything, which is how a character stops reading as one character
/// and starts reading as five images of the same drawing. A named scale also makes the
/// 72pt floor enforceable rather than a note in a document: below that the rig is a
/// blinking icon and the motion system is being paid for nothing.
enum CompanionSize {
    /// The welcome hero. The only place the pair carries a screen on its own.
    case hero
    /// A payoff moment — the demo verdict and the personalised verdict.
    case prominent
    /// Alongside a control or a form: the species picker, the profile page.
    case standard

    var points: CGFloat {
        switch self {
        case .hero:      return 156
        case .prominent: return 108
        case .standard:  return 96
        }
    }

    /// Below this the rig is not worth running — see `CompanionView.height`.
    static let floor: CGFloat = 72
}

// MARK: - The rig

/// The companion. One dog, one cat, built from the same parts in the same order.
///
/// Three layers, each touching only what it owns:
///
/// - **life** — breathing, blinking, ear flicks, micro-turns, weight shifts. Runs
///   continuously and stops only for Reduce Motion. No mood pose may touch the eyes
///   or the chest, because the first draft did and the character froze solid during
///   the search — the longest continuous look a user gets at it.
/// - **mood** — head offset, ear angle, brows, mouth corners. Written as poses rather
///   than animations, which is what lets the verdict still read with motion off.
/// - **accent** — the perk. A one-shot sitting over both without displacing either.
struct CompanionView: View {
    let species: Species
    var mood: CompanionMood = .neutral
    /// Increment to fire the accent one-shot. A token rather than a binding so the
    /// caller cannot leave the rig stuck mid-gesture.
    var perkToken: Int = 0
    var height: CGFloat = CompanionSize.standard.points
    /// Staggers arrival when more than one is on screen. Two characters appearing on
    /// the same frame read as one image; 120ms apart they read as two animals.
    var entranceDelay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // life
    @State private var eyeScale: CGFloat = 1
    @State private var earLifeL: Double = 0
    @State private var earLifeR: Double = 0
    @State private var headLifeAngle: Double = 0
    @State private var headLifeDX: CGFloat = 0
    @State private var swayX: CGFloat = 0
    @State private var swayRoll: Double = 0
    @State private var jowlAngle: Double = 0
    @State private var breathing = false
    @State private var riding = false
    @State private var exhale: CGFloat = 1

    // accent
    @State private var perkAngle: Double = 0
    @State private var perkDX: CGFloat = 0
    @State private var perkEarNear: Double = 0
    @State private var perkEarFar: Double = 0
    @State private var appeared = false

    private var palette: CompanionPalette { .of(species) }

    /// Light from the upper left, as it is everywhere else in the app's shadows.
    private var furGradient: LinearGradient {
        LinearGradient(colors: [palette.furLight, palette.fur, palette.furDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private var chestGradient: LinearGradient {
        LinearGradient(colors: [palette.fur, palette.furDeep],
                       startPoint: .top, endPoint: .bottom)
    }
    private var creamGradient: LinearGradient {
        LinearGradient(colors: [palette.creamLight, palette.cream, palette.creamDeep],
                       startPoint: .top, endPoint: .bottom)
    }
    private var isCalm: Bool { reduceMotion }
    /// One design unit in points at the current render size.
    private var u: CGFloat { height / CompanionCanvas.height }
    private var width: CGFloat { height * CompanionCanvas.aspect }

    var body: some View {
        ZStack {
            // Stays put while the body sways above it — a contact shadow that slides
            // with the animal is a drop shadow, and drop shadows float.
            CompanionArt.contact
                .fill(ColorTokens.contactShadow)
                .blur(radius: 7 * u)
                .scaleEffect(x: concern <= -0.5 ? 1.04 : 1, y: 1, anchor: .center)
                .animation(moodAnimation, value: mood)

            ZStack {
                chestLayer
                headLayer
            }
            // weight shift lives on its own node so it never fights the breath
            .offset(x: swayX * u)
            .rotationEffect(.degrees(swayRoll), anchor: CompanionArt.Pivot.chest)
        }
        .frame(width: width, height: height)
        .scaleEffect(appeared ? 1 : 0.9, anchor: .bottom)
        .opacity(appeared ? 1 : 0)
        .accessibilityHidden(true)
        .onAppear {
            guard !isCalm else {
                appeared = true
                return
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.74).delay(entranceDelay)) {
                appeared = true
            }
            breathing = true
            riding = true
        }
        .onChange(of: perkToken) { _, _ in Task { await perk() } }
        .onChange(of: mood) { _, new in
            guard !isCalm, new.concern <= -0.5 else { return }
            Task { await settleExhale() }
        }
        .task(id: isCalm) { await runLife() }
    }

    // MARK: Layers

    private var chestLayer: some View {
        ZStack {
            CompanionArt.chest(species).fill(chestGradient)
            CompanionArt.chestPatch(species)
                .fill(creamGradient)
                .mask(CompanionArt.chest(species))
            // Occlusion under the chin. The head draws over most of it, so what is left
            // is the fringe — which is the part that reads as the head sitting *on* the
            // shoulders rather than in front of them.
            CompanionArt.neckShade
                .fill(palette.furDeep)
                .opacity(0.5)
                .blur(radius: 6 * u)
                .mask(CompanionArt.chest(species))
        }
        .scaleEffect(x: 1, y: (breathing ? 1.02 : 1.0) * exhale, anchor: CompanionArt.Pivot.chest)
        .animation(breathAnimation, value: breathing)
    }

    private var headLayer: some View {
        ZStack {
            earGroup(left: true)
            earGroup(left: false)
            faceGroup
        }
        // ---- life
        .rotationEffect(.degrees(headLifeAngle), anchor: CompanionArt.Pivot.neck)
        .offset(x: headLifeDX * u)
        // ---- accent
        .rotationEffect(.degrees(perkAngle), anchor: CompanionArt.Pivot.neck)
        .offset(x: perkDX * u)
        // ---- mood
        .rotationEffect(.degrees(moodHeadAngle), anchor: CompanionArt.Pivot.neck)
        .offset(y: moodHeadDY * u)
        .animation(moodAnimation, value: mood)
        // ---- rides the breath, 140ms behind it, and never scales with it
        .offset(y: riding ? -1.5 * u : 0)
        .animation(breathAnimation?.delay(0.14), value: riding)
    }

    private func earGroup(left: Bool) -> some View {
        let anchor = CompanionArt.Pivot.ear(species, left: left)
        return ZStack {
            CompanionArt.ear(species, left: left).fill(palette.shade)
            if species == .cat {
                CompanionArt.earInner(left: left).fill(palette.earInner).opacity(0.7)
            }
        }
        .rotationEffect(.degrees(left ? earLifeL : earLifeR), anchor: anchor)
        .rotationEffect(.degrees(left ? perkEarNear : perkEarFar), anchor: anchor)
        .rotationEffect(.degrees(moodEarAngle(left: left)), anchor: anchor)
        .scaleEffect(moodEarScale, anchor: anchor)
        .animation(moodAnimation, value: mood)
    }

    private var faceGroup: some View {
        ZStack {
            CompanionArt.skull(species).fill(furGradient)
            CompanionArt.skullShade(species).fill(palette.shade).opacity(species == .dog ? 0.26 : 0.24)

            if species == .cat {
                CompanionArt.whiskersInner
                    .stroke(palette.whisker, style: .init(lineWidth: 1.8 * u, lineCap: .round))
                    .opacity(0.75)
                    .rotationEffect(.degrees(jowlAngle), anchor: CompanionCanvas.anchor(110, 150))
                CompanionArt.whiskersOuter
                    .stroke(palette.shade, style: .init(lineWidth: 2.2 * u, lineCap: .round))
                    .rotationEffect(.degrees(jowlAngle), anchor: CompanionCanvas.anchor(110, 150))
            }

            CompanionArt.muzzle(species).fill(creamGradient)
            if species == .dog {
                CompanionArt.jowl.fill(creamGradient)
                    .rotationEffect(.degrees(jowlAngle), anchor: CompanionCanvas.anchor(110, 150))
            }

            browGroup(left: true)
            browGroup(left: false)
            eyeGroup(left: true)
            eyeGroup(left: false)

            CompanionArt.nose(species).fill(palette.nose)
            CompanionArt.mouthStem(species)
                .stroke(palette.dark, style: .init(lineWidth: (species == .dog ? 2.6 : 2.4) * u, lineCap: .round))
            mouthCorner(left: true)
            mouthCorner(left: false)
        }
    }

    private func browGroup(left: Bool) -> some View {
        CompanionArt.brow(species, left: left)
            .fill(palette.cream)
            .opacity(species == .dog ? 0.72 : 0.68)
            .rotationEffect(.degrees(moodBrowAngle(left: left)),
                            anchor: CompanionArt.Pivot.brow(species, left: left))
            .offset(x: moodBrowDX(left: left) * u, y: moodBrowDY * u)
            .animation(moodAnimation, value: mood)
    }

    private func eyeGroup(left: Bool) -> some View {
        ZStack {
            CompanionArt.eyeOuter(species, left: left).fill(palette.iris)
            if species == .cat {
                CompanionArt.eyePupil(left: left, dilation: pupilDilation).fill(palette.pupil)
                    .animation(moodAnimation, value: mood)
            }
            CompanionArt.eyeHighlight(species, left: left).fill(.white).opacity(0.87)
        }
        .scaleEffect(x: 1, y: eyeScale, anchor: CompanionArt.Pivot.eye(species, left: left))
    }

    private func mouthCorner(left: Bool) -> some View {
        CompanionArt.mouthCorner(species, left: left)
            .stroke(palette.dark, style: .init(lineWidth: (species == .dog ? 2.6 : 2.4) * u, lineCap: .round))
            .offset(x: (left ? 1.5 : -1.5) * moodMouthLift * u, y: -1.5 * moodMouthLift * u)
            .animation(moodAnimation, value: mood)
    }

    // MARK: Mood poses
    //
    // Alert *widens* the ear silhouette; aversion pins it back and *narrows* it.
    // Silhouette width is the only ear cue that survives at picker size, and because
    // the dog's ears hang and the cat's stand the sign is opposite between rigs.

    private var narrow: Double { species == .dog ? -18 : 18 }
    private var wide: Double { species == .dog ? 14 : -14 }

    private var concern: Double { max(-1, min(1, mood.concern)) }

    private var moodHeadAngle: Double {
        if mood.busy { return -4 }
        return concern > 0 ? -6 * concern : 0
    }

    private var moodHeadDY: CGFloat {
        if mood.busy { return -2 }
        return concern > 0 ? 5 * concern : -3 * concern   // settle drops, wince drops further
    }

    private func moodEarAngle(left: Bool) -> Double {
        let base: Double
        if mood.busy { base = wide }
        else if concern > 0 { base = narrow * concern }
        else { base = wide * 0.45 * -concern }
        return left ? base : -base
    }

    private var moodEarScale: CGFloat { concern > 0 ? 1 - 0.04 * concern : 1 }

    /// Pivoted at the inner end and knitting down-and-together. Inner-down is a
    /// squint; inner-up is a plea, and a plea is the register this product cannot use.
    private func moodBrowAngle(left: Bool) -> Double {
        guard concern > 0 else { return 0 }
        return (left ? 7 : -7) * concern
    }
    private func moodBrowDX(left: Bool) -> CGFloat { concern > 0 ? (left ? 2 : -2) * concern : 0 }
    private var moodBrowDY: CGFloat { concern > 0 ? 1.5 * concern : 0 }

    private var moodMouthLift: CGFloat { concern > 0 ? concern : 0 }

    private var pupilDilation: CGFloat {
        if mood.busy { return 0.78 }
        return concern > 0 ? 1 + 0.23 * concern : 1
    }

    // MARK: Timing

    private var breathPeriod: Double {
        if mood.busy { return 3.2 }
        if concern <= -0.5 { return 6.5 }
        if concern >= 0.5 { return 3.4 }
        return 4.0
    }

    private var breathAnimation: Animation? {
        isCalm ? nil : .easeInOut(duration: breathPeriod).repeatForever(autoreverses: true)
    }

    /// Reactions differ in entry, not in pose. Held poses a unit or two apart do not
    /// read at this size; entry velocities do.
    private var moodAnimation: Animation? {
        if isCalm { return nil }
        if concern >= 0.5 { return .easeOut(duration: 0.16) }   // wince: fast, no overshoot
        if concern <= -0.5 { return .easeOut(duration: 0.9) }   // settle: slow release
        return .easeOut(duration: 0.34)
    }

    // MARK: - Layer 1: the micro-event pool
    //
    // At picker size the breathing loop moves the shoulder line under a point over four
    // seconds — right at the threshold of perceptible motion. Aliveness cannot come from
    // loop amplitude at this scale, so it comes from short events with fast leading
    // edges: one every 1.6–2.2s, drawn without replacement so nothing repeats twice
    // running. Each rig draws independently, which is what keeps a pair from syncing.

    private enum LifeEvent: CaseIterable {
        case blink, doubleBlink, earFlick, twitch, microTurn, weightShift

        var weight: Int {
            switch self {
            case .blink: return 30
            case .doubleBlink: return 6
            case .earFlick: return 20
            case .twitch: return 10
            case .microTurn: return 22
            case .weightShift: return 12
            }
        }
    }

    /// Arousal raises event rate; relief lowers it.
    private var lifeRate: Double {
        if mood.busy { return 0.72 }
        if concern >= 0.5 { return 0.68 }
        if concern <= -0.5 { return 1.35 }
        return 1.0
    }

    private func runLife() async {
        guard !isCalm else { return }
        var last: LifeEvent?
        var lastEarWasLeft = false

        while !Task.isCancelled {
            let wait = (1600 + Double.random(in: 0...600)) * lifeRate
            try? await Task.sleep(for: .milliseconds(Int(wait)))
            if Task.isCancelled { return }

            let pool = LifeEvent.allCases.filter { $0 != last }
            let total = pool.reduce(0) { $0 + $1.weight }
            var roll = Int.random(in: 0..<max(total, 1))
            var chosen = pool[0]
            for event in pool {
                roll -= event.weight
                if roll < 0 { chosen = event; break }
            }
            last = chosen

            switch chosen {
            case .blink:
                await blink()
            case .doubleBlink:
                await blink()
                try? await Task.sleep(for: .milliseconds(340))
                await blink()
            case .earFlick:
                // alternate with a 60/40 bias, so the same ear never becomes a tic
                let goLeft = lastEarWasLeft ? Double.random(in: 0...1) < 0.4
                                            : Double.random(in: 0...1) < 0.6
                lastEarWasLeft = goLeft
                await earFlick(left: goLeft)
            case .twitch:
                await twitch()
            case .microTurn:
                await microTurn()
            case .weightShift:
                await weightShift()
            }
        }
    }

    private func blink() async {
        withAnimation(.easeInOut(duration: 0.065)) { eyeScale = 0.05 }
        try? await Task.sleep(for: .milliseconds(65))
        withAnimation(.easeInOut(duration: 0.065)) { eyeScale = 1 }
    }

    private func earFlick(left: Bool) async {
        let sign: Double = left ? 1 : -1
        withAnimation(.easeOut(duration: 0.06)) {
            if left { earLifeL = 9 * sign } else { earLifeR = 9 * sign }
        }
        try? await Task.sleep(for: .milliseconds(60))
        withAnimation(.easeInOut(duration: 0.045)) {
            if left { earLifeL = -4 * sign } else { earLifeR = -4 * sign }
        }
        try? await Task.sleep(for: .milliseconds(45))
        withAnimation(.easeOut(duration: 0.075)) {
            if left { earLifeL = 0 } else { earLifeR = 0 }
        }
    }

    private func twitch() async {
        withAnimation(.easeOut(duration: 0.07)) { jowlAngle = 3 }
        try? await Task.sleep(for: .milliseconds(70))
        withAnimation(.easeOut(duration: 0.07)) { jowlAngle = 0 }
    }

    private func microTurn() async {
        withAnimation(.easeInOut(duration: 0.42)) { headLifeAngle = 1.8; headLifeDX = 1.2 }
        try? await Task.sleep(for: .milliseconds(1320))
        withAnimation(.easeInOut(duration: 0.52)) { headLifeAngle = 0; headLifeDX = 0 }
    }

    private func weightShift() async {
        withAnimation(.easeInOut(duration: 0.45)) { swayX = 1.6; swayRoll = 0.7 }
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.easeInOut(duration: 0.45)) { swayX = 0; swayRoll = 0 }
    }

    /// The relief beat: one deep exhale on entry, then the slower loop. A slower loop
    /// on its own reads as deflation rather than release.
    private func settleExhale() async {
        withAnimation(.easeInOut(duration: 0.7)) { exhale = 1.035 }
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.easeInOut(duration: 1.1)) { exhale = 0.99 }
        try? await Task.sleep(for: .milliseconds(1100))
        withAnimation(.easeInOut(duration: 0.8)) { exhale = 1 }
    }

    // MARK: - Layer 3: the accent

    private func perk() async {
        guard !isCalm else {
            // Reduce Motion still needs confirmation the tap registered. An instant
            // pose held briefly, not a lost animation.
            perkAngle = -6
            try? await Task.sleep(for: .milliseconds(600))
            perkAngle = 0
            return
        }

        // One easing per segment. A single spring curve across four keyframes
        // overshoots at every one of them and reads as a jitter, not a head cock.
        withAnimation(.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.15)) {
            perkAngle = -8; perkDX = -2
        }
        withAnimation(.easeOut(duration: 0.17)) { perkEarNear = 5 }
        withAnimation(.easeOut(duration: 0.2)) { perkEarFar = -3 }

        try? await Task.sleep(for: .milliseconds(210))   // 150 travel + 60 hold
        withAnimation(.easeInOut(duration: 0.17)) { perkAngle = 2.5; perkDX = 0.6 }
        withAnimation(.easeInOut(duration: 0.22)) { perkEarNear = -2; perkEarFar = 0 }

        try? await Task.sleep(for: .milliseconds(170))
        withAnimation(.easeOut(duration: 0.13)) { perkAngle = 0; perkDX = 0 }
        // the near ear settles 90ms after the head, so the two are never rigid together
        try? await Task.sleep(for: .milliseconds(90))
        withAnimation(.easeOut(duration: 0.16)) { perkEarNear = 0 }
    }
}

// MARK: - Previews

#Preview("Pair") {
    HStack(spacing: 24) {
        CompanionView(species: .dog, height: 150)
        CompanionView(species: .cat, height: 150)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}

#Preview("Wince") {
    HStack(spacing: 24) {
        CompanionView(species: .dog, mood: CompanionMood(concern: 1), height: 150)
        CompanionView(species: .cat, mood: CompanionMood(concern: 1), height: 150)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}

#Preview("Settle / Attend") {
    HStack(spacing: 24) {
        CompanionView(species: .dog, mood: CompanionMood(concern: -1), height: 150)
        CompanionView(species: .cat, mood: .attending, height: 150)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}
