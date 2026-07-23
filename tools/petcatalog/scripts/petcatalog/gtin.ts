/**
 * GTIN canonicalisation and validation.
 *
 * This is the build-side twin of PetScans/Services/BarcodeNormalizer.swift. The two MUST
 * agree: a barcode the app canonicalises to some GTIN-14 has to match the key this tool
 * wrote, or the lookup silently misses. The `catalogIntegrity` test asserts every shipped
 * row survives the Swift side.
 *
 * The tool does not handle UPC-E — vendor data never contains it. The app does, because a
 * camera can read one.
 */

/** Canonical GTIN-14: digits only, left-zero-padded. Null if it isn't a plausible GTIN. */
export function canonical(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const digits = String(raw).replace(/\D/g, '');
  if (![8, 12, 13, 14].includes(digits.length)) return null;
  return digits.padStart(14, '0');
}

/**
 * Mod-10 check digit. Weights are assigned right-to-left, which makes the result
 * invariant to left zero-padding — so a GTIN-14 and the UPC-A inside it agree.
 */
export function hasValidCheckDigit(gtin14: string): boolean {
  if (!/^\d{14}$/.test(gtin14)) return false;
  const d = [...gtin14].map(Number);
  const check = d[d.length - 1];
  const body = d.slice(0, -1).reverse();
  const sum = body.reduce((acc, v, i) => acc + v * (i % 2 === 0 ? 3 : 1), 0);
  return (10 - (sum % 10)) % 10 === check;
}

/**
 * Retail-issued, or a code that only exists inside one retailer's four walls?
 *
 * This matters more than it looks. 28% of the purchased Walmart rows carried UPC
 * number-system 4 ("retailer in-store use") — 88% of them named "(N pack)" — because
 * marketplace sellers mint a number for a bundle that has no manufacturer barcode. No
 * such barcode is printed on any physical product, so no scan can ever produce one.
 * Storing them would be dead weight; accepting them on a scan would be a false lookup.
 */
export function isRetailIssued(gtin14: string): boolean {
  if (!/^\d{14}$/.test(gtin14)) return false;

  // "00" + 12 digits => a UPC-A. Its first digit is the number system.
  if (gtin14.startsWith('00')) {
    const ns = gtin14[2];
    // 2 = variable weight/in-store, 4 = retailer in-store, 5 = coupon.
    return ns !== '2' && ns !== '4' && ns !== '5';
  }

  // "0" + 13 digits => an EAN-13. GS1 reserves 020-029/040-049 and 200-299 for
  // restricted circulation, and 977/978/979 for periodicals and books.
  if (gtin14.startsWith('0')) {
    const ean = gtin14.slice(1);
    const p2 = ean.slice(0, 2);
    const p3 = ean.slice(0, 3);
    if (p2 === '02' || p2 === '04') return false;
    if (ean.startsWith('2')) return false;
    if (['977', '978', '979', '981', '982'].includes(p3)) return false;
    return true;
  }

  // A leading indicator digit 1-8 marks a case/carton code (ITF-14). Those are printed
  // on shipping cases, never on the consumer unit a person points a phone at.
  return false;
}

/** Everything a shippable catalog key has to satisfy. */
export function isShippable(gtin14: string): boolean {
  return hasValidCheckDigit(gtin14) && isRetailIssued(gtin14);
}
