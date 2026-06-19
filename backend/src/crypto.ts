/// Small WebCrypto helpers shared by auth (HMAC tokens) and cache (SHA-256 keys).

const encoder = new TextEncoder();

function base64UrlEncode(bytes: ArrayBuffer): string {
  const bin = String.fromCharCode(...new Uint8Array(bytes));
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function base64UrlEncodeString(s: string): string {
  return base64UrlEncode(encoder.encode(s).buffer as ArrayBuffer);
}

export function base64UrlDecodeString(s: string): string {
  const padded = s.replace(/-/g, "+").replace(/_/g, "/");
  return atob(padded);
}

async function importHmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

/// HMAC-SHA256 a message, returning a base64url signature.
export async function hmacSign(secret: string, message: string): Promise<string> {
  const key = await importHmacKey(secret);
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(message));
  return base64UrlEncode(sig);
}

/// Constant-time-ish verify (WebCrypto verify avoids early-exit comparison).
export async function hmacVerify(
  secret: string,
  message: string,
  signatureB64Url: string,
): Promise<boolean> {
  const key = await importHmacKey(secret);
  const padded = signatureB64Url.replace(/-/g, "+").replace(/_/g, "/");
  let bin: string;
  try {
    bin = atob(padded);
  } catch {
    return false;
  }
  const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
  return crypto.subtle.verify("HMAC", key, bytes, encoder.encode(message));
}

/// SHA-256 hex digest — used to build stable cache keys from request payloads.
export async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(input));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
