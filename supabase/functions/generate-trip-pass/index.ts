// generate-trip-pass
//
// Builds and signs a real .pkpass for one of the caller's own upcoming
// reservations. Signing has to happen server-side, never in the iOS
// app itself — a .pkpass is only valid Wallet content once it carries a
// PKCS#7 signature made with the Pass Type ID certificate's *private*
// key, and that key can never ship inside the app bundle (anyone could
// pull it back out and forge passes under this app's identity).
//
// Required secrets (`supabase secrets set NAME=value`) — see the repo's
// setup notes for exactly how to obtain each:
//   PASS_TYPE_IDENTIFIER   e.g. "pass.xGhost.Podz.trippass"
//   TEAM_IDENTIFIER        the 10-character Apple Developer Team ID
//   PASS_P12_BASE64        the Pass Type ID certificate, exported from
//                          Keychain Access as a .p12, base64-encoded
//   PASS_P12_PASSWORD      the password chosen while exporting that .p12
//   WWDR_PEM                Apple's own WWDR intermediate certificate,
//                          PEM-encoded (public — not secret, but kept as
//                          a secret here purely for convenience of
//                          storage/rotation)
//
// Deploy: `supabase functions deploy generate-trip-pass`

import { createClient } from "jsr:@supabase/supabase-js@2";
import forge from "npm:node-forge@1.3.1";
import JSZip from "npm:jszip@3.10.1";

const ICON_FILES = ["icon.png", "icon@2x.png", "icon@3x.png"] as const;

interface ReservationRow {
  id: string;
  pod_id: string;
  check_in: string;
  check_out: string;
  guests: number;
}

interface PodRow {
  name: string;
  address: string | null;
  region: string | null;
  country: string;
  latitude: number | null;
  longitude: number | null;
  altitude_m: number | null;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response("Missing Authorization header", { status: 401 });
  }

  let reservationId: string;
  try {
    const body = await req.json();
    reservationId = body.reservationId;
    if (!reservationId) throw new Error("missing reservationId");
  } catch {
    return new Response("Expected JSON body: { reservationId }", { status: 400 });
  }

  // Forwards the caller's own JWT rather than using a service-role key —
  // reservations.sql's own RLS policy (user_id = auth.uid()) is what
  // actually stops one user from generating a pass for someone else's
  // reservation, same as every other client read in this app.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: reservation, error: reservationError } = await supabase
    .from("reservations")
    .select("id, pod_id, check_in, check_out, guests")
    .eq("id", reservationId)
    .single<ReservationRow>();

  if (reservationError || !reservation) {
    return new Response("Reservation not found", { status: 404 });
  }

  const { data: pod, error: podError } = await supabase
    .from("pods")
    .select("name, address, region, country, latitude, longitude, altitude_m")
    .eq("id", reservation.pod_id)
    .single<PodRow>();

  if (podError || !pod) {
    return new Response("Pod not found", { status: 404 });
  }

  const passTypeIdentifier = requireEnv("PASS_TYPE_IDENTIFIER");
  const teamIdentifier = requireEnv("TEAM_IDENTIFIER");

  const confirmationCode = reservation.id.replace(/-/g, "").slice(0, 8).toUpperCase();
  const passJson = buildPassJson({
    passTypeIdentifier,
    teamIdentifier,
    serialNumber: reservation.id,
    confirmationCode,
    pod,
    reservation,
  });

  const assetsDir = new URL("./assets/", import.meta.url);
  const files = new Map<string, Uint8Array>();
  files.set("pass.json", new TextEncoder().encode(JSON.stringify(passJson)));
  for (const name of ICON_FILES) {
    files.set(name, await Deno.readFile(new URL(name, assetsDir)));
  }

  const manifest: Record<string, string> = {};
  for (const [name, bytes] of files) {
    manifest[name] = sha1Hex(bytes);
  }
  const manifestBytes = new TextEncoder().encode(JSON.stringify(manifest));
  files.set("manifest.json", manifestBytes);

  const signatureBytes = signManifest(manifestBytes);
  files.set("signature", signatureBytes);

  const zip = new JSZip();
  for (const [name, bytes] of files) {
    zip.file(name, bytes);
  }
  const pkpass = await zip.generateAsync({ type: "uint8array", compression: "STORE" });

  return new Response(pkpass, {
    headers: {
      "Content-Type": "application/vnd.apple.pkpass",
      "Content-Disposition": `attachment; filename="trip-pass.pkpass"`,
    },
  });
});

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing required secret: ${name}`);
  return value;
}

function buildPassJson(args: {
  passTypeIdentifier: string;
  teamIdentifier: string;
  serialNumber: string;
  confirmationCode: string;
  pod: PodRow;
  reservation: ReservationRow;
}): Record<string, unknown> {
  const { passTypeIdentifier, teamIdentifier, serialNumber, confirmationCode, pod, reservation } = args;
  const locationLine = [pod.region, pod.country].filter(Boolean).join(", ");

  // "generic" style, not "boardingPass"/"eventTicket" — this isn't a
  // timed departure with a gate, just a booking confirmation, and generic
  // is the style that doesn't force a strip image or a transit-specific
  // layout neither pod photos nor this data actually fit.
  return {
    formatVersion: 1,
    passTypeIdentifier,
    teamIdentifier,
    serialNumber,
    organizationName: "Podz",
    description: `${pod.name} — Podz trip pass`,
    logoText: "Podz",
    backgroundColor: "rgb(10, 10, 10)",
    foregroundColor: "rgb(255, 255, 255)",
    labelColor: "rgb(180, 180, 180)",
    generic: {
      primaryFields: [
        { key: "pod", label: "POD", value: pod.name },
      ],
      secondaryFields: [
        { key: "checkIn", label: "CHECK-IN", value: reservation.check_in, dateStyle: "PKDateStyleMedium" },
        { key: "checkOut", label: "CHECK-OUT", value: reservation.check_out, dateStyle: "PKDateStyleMedium" },
      ],
      auxiliaryFields: [
        { key: "guests", label: "GUESTS", value: `${reservation.guests}` },
        ...(pod.altitudeM != null ? [{ key: "altitude", label: "ALTITUDE", value: `${pod.altitudeM} m` }] : []),
      ],
      backFields: [
        { key: "confirmation", label: "Confirmation code", value: confirmationCode },
        ...(locationLine ? [{ key: "location", label: "Location", value: locationLine }] : []),
        ...(pod.address ? [{ key: "address", label: "Address", value: pod.address }] : []),
      ],
    },
    barcodes: [
      {
        // Code128, not QR — matches the barcode `TripPassView` itself
        // renders in-app so the pass looks the same whether it's still
        // being viewed in Podz or already added to Wallet.
        format: "PKBarcodeFormatCode128",
        message: `PODZ-${confirmationCode}`,
        messageEncoding: "iso-8859-1",
        altText: confirmationCode,
      },
    ],
    // Surfaces the pass on the lock screen once you're actually near the
    // refuge — the one bit of this pass that only matters offline, in
    // the exact spot signal is least likely to exist.
    ...(pod.latitude != null && pod.longitude != null
      ? { locations: [{ latitude: pod.latitude, longitude: pod.longitude }] }
      : {}),
  };
}

function sha1Hex(data: Uint8Array): string {
  const md = forge.md.sha1.create();
  md.update(forge.util.createBuffer(data).getBytes());
  return md.digest().toHex();
}

/// PKCS#7 detached signature over `manifest.json`'s raw bytes — the
/// exact shape Wallet expects the `signature` file inside a .pkpass to
/// be. Same forge-based approach the established Node pass-signing
/// libraries (passkit-generator, node-passbook) use, since Deno has no
/// native PKCS#7/CMS signer and no way to shell out to `openssl smime`.
function signManifest(manifestBytes: Uint8Array): Uint8Array {
  const p12Base64 = requireEnv("PASS_P12_BASE64");
  const p12Password = requireEnv("PASS_P12_PASSWORD");
  const wwdrPem = requireEnv("WWDR_PEM");

  const p12Der = forge.util.decode64(p12Base64);
  const p12Asn1 = forge.asn1.fromDer(p12Der);
  const p12 = forge.pkcs12.pkcs12FromAsn1(p12Asn1, p12Password);

  const certBags = p12.getBags({ bagType: forge.pki.oids.certBag })[forge.pki.oids.certBag]!;
  const keyBags = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag })[forge.pki.oids.pkcs8ShroudedKeyBag]!;
  const signerCert = certBags[0].cert!;
  const signerKey = keyBags[0].key!;
  const wwdrCert = forge.pki.certificateFromPem(wwdrPem);

  const p7 = forge.pkcs7.createSignedData();
  p7.content = forge.util.createBuffer(forge.util.createBuffer(manifestBytes).getBytes());
  p7.addCertificate(signerCert);
  p7.addCertificate(wwdrCert);
  p7.addSigner({
    key: signerKey,
    certificate: signerCert,
    digestAlgorithm: forge.pki.oids.sha256,
    authenticatedAttributes: [
      { type: forge.pki.oids.contentType, value: forge.pki.oids.data },
      { type: forge.pki.oids.messageDigest },
      { type: forge.pki.oids.signingTime, value: new Date() },
    ],
  });
  // detached: true — the signature file references manifest.json's
  // digest without embedding manifest.json's own bytes a second time
  // inside it, matching what a .pkpass's separate `signature` file is
  // meant to hold.
  p7.sign({ detached: true });

  const der = forge.asn1.toDer(p7.toAsn1()).getBytes();
  const bytes = new Uint8Array(der.length);
  for (let i = 0; i < der.length; i++) bytes[i] = der.charCodeAt(i);
  return bytes;
}
