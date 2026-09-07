# Roadmap — refuge reservation features

Original architecture doc (as given, 2026-09-01), kept verbatim below, plus
notes on how each item lands against the current codebase — what already
exists, what's genuinely new, and what depends on what.

## Partie 1 : Les 5 fonctionnalités clés du MVP

### 1. Moteur de recherche cartographique (Focus Itinéraire)
> Carte interactive affichant le tracé complet d'un GR / sentier pilote.
> Positionnement visuel des refuges partenaires tout le long du parcours.
> Permet de planifier des étapes logiques (Jour 1, Jour 2).

**Note:** this overlaps a lot with what "Lenny" already does
(`LennySearchViewModel`, `LennyJourneyProgress`, `LennyResultCard` —
"Chamonix to Zermatt in 5 days" already returns pods staged along a route).
Lenny solves the *matching* half of this today; what's actually missing is
the *map visualization* half — an interactive trail polyline with day
markers, versus Lenny's current list-of-results UI. Worth framing this as
"give Lenny's results a map view" rather than a new engine built from
scratch — cheaper, and keeps one mental model for route search instead of
two competing ones.

### 2. Tunnel de réservation spécialisé avec option "Demi-Pension"
> Formulaire de réservation par nombre de lits. Sélection
> obligatoire/facultative des repas (Dîner, Petit-déjeuner). Prise en
> compte des contraintes et régimes alimentaires (Végétarien, allergies).

**Note:** clean, well-scoped extension of what exists — `ReservationSheet`
today is just check-in/check-out/guests. Add meal fields to the
`Reservation` model + SQL table, extend the form. No architectural surprises,
no new infrastructure needed. Genuinely MVP-sized.

### 3. "Mode Billet" 100% hors-ligne (Offline Ticket)
> Téléchargement local automatique dès la validation du paiement. QR Code,
> détails, coordonnées GPS/radio du refuge. Accessible sans réseau.

**Note:** the right feature for this product (real high-altitude
no-signal use case) but its trigger — "dès la validation du paiement" —
doesn't exist yet: there is currently *no payment step at all*.
`ReservationSheet` explicitly tells users "No payment is taken now —
you'll settle up at the shelter." Either build this to trigger on
reservation *confirmation* instead (buildable today), or sequence it
after item 4.

### 4. Système de versement des arrhes (Sécurité Gardien)
> Prélèvement automatique d'un montant fixe ou de la totalité. Reversement
> garanti au gardien en cas de no-show.

**Note:** this is the heaviest item on the whole list, MVP or not — it
requires standing up real payment processing (Stripe/Apple Pay/etc.),
handling refunds/cancellations, PCI-adjacent compliance, and a payout path
to guardians, none of which exists today. It's also the one item here with
real legal/compliance surface (App Store payment rules if any of this
touches in-app purchase territory, KYC for payouts, etc.). Worth scoping
and budgeting this one separately from the rest of the MVP rather than
estimating it like a normal feature.

### 5. Tableau de bord "Cuisine & Lits" pour le Gardien
> Écran épuré pour tablette/smartphone. Récap fin de journée : clients,
> repas végétariens, pique-niques du lendemain.

**Note:** this isn't a screen, it's a second product surface. There is
currently **zero guardian-facing infrastructure** — no guardian auth, no
guardian role/permissions, and `PodDetailView`'s "host" section is
hardcoded placeholder text today ("The Podz Team" / generic blurb) since
there's no host/guardian data model yet. Budget this as standing up a
second (admin-facing) app experience, not a dashboard bolted onto the
existing hiker app.

## Partie 2 : Backlog des évolutions futures (post-MVP)

### 1. Portail Randonneur (Avancé)
Alpine club card verification + push safety alerts. Reasonable. No push
notification infrastructure exists yet (messaging today is Supabase
realtime, not APNs) — that's new plumbing, not just a new screen.

### 2. Portail Gardien (Avancé)
Offline-first async planning + dynamic bed allocation. Correctly
sequenced after item 5 above, since it depends on the guardian dashboard
existing first.

### 3. Moteur Backend & API
- **Anti-overbooking allocation algorithm** — already exists.
  `SQL/reservations.sql`'s `enforce_reservation_capacity()` trigger already
  enforces capacity server-side at insert time, including the concurrent-
  booking race case (whichever request lands second sees the first's
  committed row and fails cleanly). Worth knowing before scoping this as
  new work — the remaining gap is UX-level (surfacing real availability
  earlier), not the core allocation logic.
- **Multi-currency payment gateway** — depends on item 4 (MVP) existing
  first.
- **Weather/risk API aggregator** — genuinely standalone, no dependency on
  anything else here. Could be pulled forward if there's appetite, since
  it doesn't block on payment or guardian infrastructure the way most of
  the rest of this list does.

## Rough sequencing, given the above

1. Meal/dietary options on the existing reservation flow (#2) — cheapest,
   most self-contained win.
2. Map visualization on top of Lenny's existing route matching (#1).
3. Payment integration (#4) — the real gating dependency for offline
   tickets (#3) and multi-currency (Part 2).
4. Offline ticket (#3), once payment (or at least confirmation) exists.
5. Guardian portal MVP (#5) as its own effort, then its "Avancé" follow-on
   (Part 2 #2).
6. Weather/risk aggregator (Part 2 #3) can slot in anywhere — no
   dependencies.
