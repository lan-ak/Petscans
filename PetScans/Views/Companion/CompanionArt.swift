import SwiftUI

/// The design space every companion coordinate is authored in. Parts are drawn into
/// this space and scaled to the view at draw time, which is what lets pivots stay
/// absolute points rather than percentages of a part's own bounding box.
///
/// Percentages were the original bug: one shared `88% 12%` landed on the dog's ear
/// join and, on the cat's triangular ear, at a point outside the shape entirely — so
/// the cat's ear slid instead of hinging. Absolute coordinates cannot do that, and
/// they transfer to Rive directly as bone positions.
enum CompanionCanvas {
    static let width: CGFloat = 220
    static let height: CGFloat = 258
    static let aspect: CGFloat = width / height

    /// An absolute design-space point expressed as a rotation anchor.
    static func anchor(_ x: CGFloat, _ y: CGFloat) -> UnitPoint {
        UnitPoint(x: x / width, y: y / height)
    }
}

// MARK: - Palette

/// Every value sits mid-range on purpose: nothing near-white, nothing near-black.
/// That is what lets one set of artwork sit on both `#F0F9F4` and `#1A1F1C` without
/// a second colourway, and it is why the rig needs no theme input.
struct CompanionPalette {
    let fur: Color
    /// Where the light lands. Flat fills are what made the first pass read as clip art:
    /// a shape with one colour has no form, and no amount of motion rescues it.
    let furLight: Color
    /// Where it falls away — the underside of the chest, the far side of the skull.
    let furDeep: Color
    let shade: Color
    let cream: Color
    let creamLight: Color
    let creamDeep: Color
    let dark: Color
    let eye: Color
    let iris: Color
    let pupil: Color
    let nose: Color
    let earInner: Color
    let whisker: Color

    static let dog = CompanionPalette(
        fur:      Color(red: 0xC0/255, green: 0x8E/255, blue: 0x5C/255),
        furLight: Color(red: 0xD5/255, green: 0xAA/255, blue: 0x7B/255),
        furDeep:  Color(red: 0xA5/255, green: 0x6E/255, blue: 0x42/255),
        shade:    Color(red: 0xA8/255, green: 0x78/255, blue: 0x48/255),
        cream:    Color(red: 0xEB/255, green: 0xDC/255, blue: 0xC4/255),
        creamLight: Color(red: 0xF7/255, green: 0xED/255, blue: 0xDD/255),
        creamDeep:  Color(red: 0xD9/255, green: 0xC3/255, blue: 0xA3/255),
        dark:     Color(red: 0x5A/255, green: 0x46/255, blue: 0x38/255),
        eye:      Color(red: 0x3B/255, green: 0x2D/255, blue: 0x24/255),
        iris:     Color(red: 0x3B/255, green: 0x2D/255, blue: 0x24/255),
        pupil:    Color(red: 0x3B/255, green: 0x2D/255, blue: 0x24/255),
        nose:     Color(red: 0x5A/255, green: 0x46/255, blue: 0x38/255),
        earInner: Color(red: 0xA8/255, green: 0x78/255, blue: 0x48/255),
        whisker:  Color(red: 0x6B/255, green: 0x61/255, blue: 0x52/255)
    )

    static let cat = CompanionPalette(
        fur:      Color(red: 0x94/255, green: 0x8A/255, blue: 0x7D/255),
        furLight: Color(red: 0xAB/255, green: 0xA1/255, blue: 0x93/255),
        furDeep:  Color(red: 0x79/255, green: 0x70/255, blue: 0x63/255),
        shade:    Color(red: 0x7C/255, green: 0x72/255, blue: 0x64/255),
        cream:    Color(red: 0xE4/255, green: 0xDB/255, blue: 0xCC/255),
        creamLight: Color(red: 0xF2/255, green: 0xEB/255, blue: 0xDF/255),
        creamDeep:  Color(red: 0xD0/255, green: 0xC4/255, blue: 0xB1/255),
        dark:     Color(red: 0x5A/255, green: 0x46/255, blue: 0x38/255),
        eye:      Color(red: 0x26/255, green: 0x22/255, blue: 0x1C/255),
        iris:     Color(red: 0x9F/255, green: 0xAF/255, blue: 0x6E/255),
        pupil:    Color(red: 0x26/255, green: 0x22/255, blue: 0x1C/255),
        nose:     Color(red: 0xC6/255, green: 0x8F/255, blue: 0x86/255),
        earInner: Color(red: 0xC9/255, green: 0x9B/255, blue: 0x92/255),
        whisker:  Color(red: 0x6B/255, green: 0x61/255, blue: 0x52/255)
    )

    static func of(_ species: Species) -> CompanionPalette {
        species == .dog ? .dog : .cat
    }
}

// MARK: - Path building

/// A tiny builder so the artwork reads as the path data it is, rather than as
/// forty lines of CGPoint arithmetic. Commands map one-to-one onto SVG's.
struct CompanionPen {
    var path = Path()
    let sx: CGFloat
    let sy: CGFloat

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }

    mutating func m(_ x: CGFloat, _ y: CGFloat) { path.move(to: p(x, y)) }
    mutating func l(_ x: CGFloat, _ y: CGFloat) { path.addLine(to: p(x, y)) }
    mutating func c(_ x1: CGFloat, _ y1: CGFloat,
                    _ x2: CGFloat, _ y2: CGFloat,
                    _ x: CGFloat, _ y: CGFloat) {
        path.addCurve(to: p(x, y), control1: p(x1, y1), control2: p(x2, y2))
    }
    mutating func close() { path.closeSubpath() }

    mutating func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
        path.addEllipse(in: CGRect(x: (cx - rx) * sx, y: (cy - ry) * sy,
                                   width: rx * 2 * sx, height: ry * 2 * sy))
    }

    mutating func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
        path.move(to: p(x1, y1))
        path.addLine(to: p(x2, y2))
    }
}

/// A shape drawn in companion design space and scaled into whatever rect it is given.
struct CompanionShape: Shape {
    let build: (inout CompanionPen) -> Void

    func path(in rect: CGRect) -> Path {
        var pen = CompanionPen(sx: rect.width / CompanionCanvas.width,
                               sy: rect.height / CompanionCanvas.height)
        build(&pen)
        return pen.path
    }
}

// MARK: - The artwork

/// Both animals are built from the same parts in the same order so one motion system
/// drives either. The differences are deliberately narrow: head proportion, ear shape,
/// eye size, muzzle, whiskers.
///
/// Neither is a breed. The dog is a mid-size, semi-drop-eared, mid-tan generic and the
/// cat a warm-grey shorthair — a recognisable golden retriever wins one owner and
/// quietly excludes every other.
enum CompanionArt {

    // MARK: Body

    /// The shoulder line runs up *behind* the skull rather than stopping below it.
    ///
    /// Tucking it under matters more than it sounds: the head is the part that moves,
    /// and a chest that stops at the chin leaves a strip of background showing at the
    /// neck — the head reads as floating above the body, and every head turn opens the
    /// gap further. The overlap is hidden because the head draws over it.
    static func chest(_ s: Species) -> CompanionShape {
        CompanionShape { p in
            if s == .dog {
                p.m(110, 158)
                p.c(147, 158, 173, 198, 173, 230)
                p.c(173, 243, 163, 249, 148, 249)
                p.l(72, 249)
                p.c(57, 249, 47, 243, 47, 230)
                p.c(47, 198, 73, 158, 110, 158)
                p.close()
            } else {
                p.m(110, 162)
                p.c(143, 162, 167, 200, 167, 230)
                p.c(167, 243, 157, 249, 143, 249)
                p.l(77, 249)
                p.c(63, 249, 53, 243, 53, 230)
                p.c(53, 200, 77, 162, 110, 162)
                p.close()
            }
        }
    }

    /// Drawn long and clipped to the body, so the patch inherits the base curve rather
    /// than being hand-matched to it.
    static func chestPatch(_ s: Species) -> CompanionShape {
        CompanionShape { p in
            if s == .dog {
                p.m(84, 258); p.c(84, 220, 95, 194, 110, 194)
                p.c(125, 194, 136, 220, 136, 258); p.close()
            } else {
                p.m(88, 258); p.c(88, 222, 97, 198, 110, 198)
                p.c(123, 198, 132, 222, 132, 258); p.close()
            }
        }
    }

    // MARK: Ears
    // The right ear is drawn three units lower than the left on both rigs. An animal
    // at rest is never square, and drawn asymmetry costs nothing to animate.

    static func ear(_ s: Species, left: Bool) -> CompanionShape {
        CompanionShape { p in
            if s == .dog {
                if left {
                    p.m(66, 76); p.c(48, 70, 32, 86, 31, 110)
                    p.c(30, 134, 44, 152, 60, 147)
                    p.c(70, 144, 70, 114, 66, 76); p.close()
                } else {
                    p.m(154, 79); p.c(172, 73, 188, 89, 189, 113)
                    p.c(190, 137, 176, 155, 160, 150)
                    p.c(150, 147, 150, 117, 154, 79); p.close()
                }
            } else {
                if left {
                    p.m(74, 94); p.l(62, 38); p.c(61, 34, 65, 31, 69, 34)
                    p.l(108, 74); p.close()
                } else {
                    p.m(146, 97); p.l(158, 41); p.c(159, 37, 155, 34, 151, 37)
                    p.l(112, 77); p.close()
                }
            }
        }
    }

    /// Cats only — the pink inner triangle.
    static func earInner(left: Bool) -> CompanionShape {
        CompanionShape { p in
            if left { p.m(78, 88); p.l(70, 52); p.l(96, 76); p.close() }
            else    { p.m(142, 91); p.l(150, 55); p.l(124, 79); p.close() }
        }
    }

    // MARK: Skull
    // Dog: 104 wide × 110 tall, tapering to the cheek, with the muzzle pushed 17 units
    // through the outline. Cat: 116 × 104, wider than tall. In the first draft both
    // heads were the same circle and the dog's muzzle sat entirely inside its own
    // outline — strip the ears and there was no species left.

    static func skull(_ s: Species) -> CompanionShape {
        CompanionShape { p in
            if s == .dog {
                p.m(110, 58)
                p.c(138, 58, 162, 78, 162, 108)
                p.c(162, 130, 156, 148, 140, 158)
                p.c(130, 165, 121, 168, 110, 168)
                p.c(99, 168, 90, 165, 80, 158)
                p.c(64, 148, 58, 130, 58, 108)
                p.c(58, 78, 82, 58, 110, 58)
                p.close()
            } else {
                p.m(110, 70)
                p.c(142, 70, 168, 92, 168, 118)
                p.c(168, 146, 142, 174, 110, 174)
                p.c(78, 174, 52, 146, 52, 118)
                p.c(52, 92, 78, 70, 110, 70)
                p.close()
            }
        }
    }

    static func skullShade(_ s: Species) -> CompanionShape {
        CompanionShape { p in
            if s == .dog {
                p.m(110, 58)
                p.c(138, 58, 162, 78, 162, 108)
                p.c(162, 114, 161, 120, 160, 125)
                p.c(146, 110, 130, 103, 110, 103)
                p.c(90, 103, 74, 110, 60, 125)
                p.c(59, 120, 58, 114, 58, 108)
                p.c(58, 78, 82, 58, 110, 58)
                p.close()
            } else {
                p.m(110, 70)
                p.c(142, 70, 168, 92, 168, 118)
                p.c(168, 124, 167, 129, 166, 134)
                p.c(150, 118, 132, 110, 110, 110)
                p.c(88, 110, 70, 118, 54, 134)
                p.c(53, 129, 52, 124, 52, 118)
                p.c(52, 92, 78, 70, 110, 70)
                p.close()
            }
        }
    }

    // MARK: Muzzle

    static func muzzle(_ s: Species) -> CompanionShape {
        CompanionShape { p in
            if s == .dog {
                p.ellipse(110, 158, 34, 27)
            } else {
                p.ellipse(97, 150, 16, 12)
                p.ellipse(123, 150, 16, 12)
            }
        }
    }

    /// Dog only — the lower jowl mass, which is what the whisker-twitch equivalent moves.
    static let jowl = CompanionShape { p in p.ellipse(110, 163, 26, 19) }

    // MARK: Face

    static func brow(_ s: Species, left: Bool) -> CompanionShape {
        CompanionShape { p in
            if s == .dog { p.ellipse(left ? 79 : 141, 96, 9.5, 4) }
            else         { p.ellipse(left ? 77 : 143, 100, 9.5, 3.6) }
        }
    }

    static func eyeOuter(_ s: Species, left: Bool) -> CompanionShape {
        CompanionShape { p in
            if s == .dog { p.ellipse(left ? 80 : 140, 112, 8, 9.5) }
            else         { p.ellipse(left ? 78 : 142, 118, 11, 12.5) }
        }
    }

    /// Cats only. A fully constricted slit reads wary, and on a screen that asks the
    /// user to *choose* this animal that costs cat owners — so it rests rounder and
    /// earns a free state channel by dilating on a bad verdict.
    static func eyePupil(left: Bool, dilation: CGFloat) -> CompanionShape {
        CompanionShape { p in
            p.ellipse(left ? 78 : 142, 118, 6.5 * dilation, 10)
        }
    }

    static func eyeHighlight(_ s: Species, left: Bool) -> CompanionShape {
        CompanionShape { p in
            if s == .dog { p.ellipse(left ? 83 : 143, 108, 2.6, 2.6) }
            else         { p.ellipse(left ? 82 : 146, 112, 2.8, 2.8) }
        }
    }

    static func nose(_ s: Species) -> CompanionShape {
        CompanionShape { p in
            if s == .dog {
                p.m(110, 140)
                p.c(119, 140, 125, 145, 125, 150)
                p.c(125, 156, 118, 160, 110, 160)
                p.c(102, 160, 95, 156, 95, 150)
                p.c(95, 145, 101, 140, 110, 140)
                p.close()
            } else {
                p.m(110, 144); p.l(103, 137); p.l(117, 137); p.close()
            }
        }
    }

    static func mouthStem(_ s: Species) -> CompanionShape {
        CompanionShape { p in
            if s == .dog { p.line(110, 160, 110, 167) }
            else         { p.line(110, 144, 110, 149) }
        }
    }

    /// Split left/right so each corner can travel independently. The mouth is the
    /// highest-contrast readable feature at ship size, and up to 3 units of corner
    /// travel is what makes a wince legible where the brow cannot carry it alone.
    static func mouthCorner(_ s: Species, left: Bool) -> CompanionShape {
        CompanionShape { p in
            if s == .dog {
                p.m(110, 167)
                if left { p.c(104, 175, 95, 174, 92, 168) }
                else    { p.c(116, 175, 125, 174, 128, 168) }
            } else {
                p.m(110, 149)
                if left { p.c(106, 155, 100, 155, 97, 151) }
                else    { p.c(114, 155, 120, 155, 123, 151) }
            }
        }
    }

    // MARK: Whiskers (cat)
    // Two-tone. Cream at low opacity extending onto the page ground measured about
    // 1.15:1 against the app's mint — invisible on the theme that actually ships. The
    // outer run now uses the ear's own mid-grey, a value already proven on both grounds.

    static let whiskersInner = CompanionShape { p in
        p.line(86, 148, 58, 141); p.line(86, 153, 56, 154); p.line(86, 158, 58, 166)
        p.line(134, 148, 162, 141); p.line(134, 153, 164, 154); p.line(134, 158, 162, 166)
    }

    static let whiskersOuter = CompanionShape { p in
        p.line(58, 141, 44, 138); p.line(56, 154, 42, 155); p.line(58, 166, 45, 172)
        p.line(162, 141, 176, 138); p.line(164, 154, 178, 155); p.line(162, 166, 175, 172)
    }

    // MARK: Grounding

    /// The contact shadow. Without one the animal is a sticker sitting on top of the
    /// screen rather than something standing in the same space as the rest of the UI —
    /// the cheapest single thing separating an illustration from an asset.
    static let contact = CompanionShape { p in p.ellipse(110, 252, 50, 6.5) }

    /// Ambient occlusion where the head meets the shoulders. Drawn on the chest so the
    /// head passes over it and only the fringe shows, which is how a shadow under a
    /// chin actually behaves.
    static let neckShade = CompanionShape { p in p.ellipse(110, 170, 44, 16) }

    // MARK: - Pivots
    // These are the bone positions. They ship as absolute coordinates, never as a
    // percentage of a bounding box.

    enum Pivot {
        static let chest = CompanionCanvas.anchor(110, 258)
        /// Below the head's own extent. Rotating a head about its own chin makes the
        /// skull swing laterally like a lever; the first draft did exactly that.
        static let neck  = CompanionCanvas.anchor(110, 190)

        static func ear(_ s: Species, left: Bool) -> UnitPoint {
            switch (s, left) {
            case (.dog, true):  return CompanionCanvas.anchor(68, 86)
            case (.dog, false): return CompanionCanvas.anchor(152, 89)
            case (.cat, true):  return CompanionCanvas.anchor(91, 84)
            case (.cat, false): return CompanionCanvas.anchor(129, 87)
            }
        }

        static func eye(_ s: Species, left: Bool) -> UnitPoint {
            switch (s, left) {
            case (.dog, true):  return CompanionCanvas.anchor(80, 112)
            case (.dog, false): return CompanionCanvas.anchor(140, 112)
            case (.cat, true):  return CompanionCanvas.anchor(78, 118)
            case (.cat, false): return CompanionCanvas.anchor(142, 118)
            }
        }

        /// The inner end, so the brow knits rather than see-saws. Pivoting at the outer
        /// end lifts the inner end — the medial brow raise, which is the most reliable
        /// "sad at you" signal there is and exactly what this register forbids.
        static func brow(_ s: Species, left: Bool) -> UnitPoint {
            switch (s, left) {
            case (.dog, true):  return CompanionCanvas.anchor(89, 96)
            case (.dog, false): return CompanionCanvas.anchor(131, 96)
            case (.cat, true):  return CompanionCanvas.anchor(87, 100)
            case (.cat, false): return CompanionCanvas.anchor(133, 100)
            }
        }
    }
}
