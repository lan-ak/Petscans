import Foundation
import Compression

/// Inflate the `ingredients` column of `catalog.sqlite`.
///
/// The column is a raw-DEFLATE blob, which keeps the bundled catalog small (the
/// ingredient text is ~60% of the file). Raw DEFLATE decodes natively via Apple's
/// Compression framework — `COMPRESSION_ZLIB` is raw DEFLATE, matching the build
/// tool's `zlib.deflateRawSync` in `tools/petcatalog/scripts/petcatalog/pack.ts`.
/// `meta.ingredients_codec` records the format.
///
/// This lives on its own, rather than inside `LocalCatalogStore`, so the
/// `matchkit` offline harness can read the same catalog the app reads without
/// pulling in GRDB. The codec is the one detail that must not drift between the
/// app, the harness and the packer — so there is exactly one copy of it.
func inflateIngredientsBlob(_ data: Data) -> String {
    if data.isEmpty { return "" }
    // Ingredient lists are a few hundred bytes to ~2 KB decompressed; 64 KB is ample headroom.
    let capacity = 64 * 1024
    let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
    defer { dst.deallocate() }
    let written = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Int in
        guard let src = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
        return compression_decode_buffer(dst, capacity, src, data.count, nil, COMPRESSION_ZLIB)
    }
    guard written > 0 else { return "" }
    return String(bytes: UnsafeBufferPointer(start: dst, count: written), encoding: .utf8) ?? ""
}
