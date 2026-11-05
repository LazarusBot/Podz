# Design improvements: a senior designer's review

5 Nov 2026, overnight. Read from the code and `design.md` only: I can't see the
rendered screens (no Simulator, no Paper), so anything about how a screen
*looks* is inferred from layout values and may be wrong on the phone. Every
claim below points at code you can check. No usage data exists, so none is quoted.

Four small prototypes came with this review, each a draft PR you can
close in one click:

| PR | What |
|---|---|
| #115 | Booking recap says the total and "paid at the hut"; after booking, where the pass is |
| #116 | Home cards carry "45 € / night · Open now"; card lines in French |
| #117 | Reduce Motion: no wiggle, no spin, no pop |
| #118 | Profile: "In 5 days" beside Reservations |

---

## (a) The 5 things that most hold the app back

1. **Reserve is taken blind.** The last question ("2 nights for 2 guests,
   from Sat 7 Nov. Shall I book it?", `BookingFlow.replyMessage`) gives no
   total and says nothing about payment, deposit or cancelling. The code
   knows the answer (`Reservation.swift`: no payment is collected, it's
   settled at the shelter) but the traveler doesn't. For a booking app this
   is the single biggest trust gap. → **#115**.
2. **Every launch is a gate.** A signed-in user waits at least 1.5 s
   (`LennyBeat`) and then *must* tap "Go to Home" (`LennyWaiting`,
   `OnboardingView`), on every cold launch. With no signal (in the
   mountains, where the offline pass matters most) the pods fetch can hold
   the screen up to 8 s first. Charming the first time; a toll from the
   fifth. See bet 1.
3. **The trip you booked is hard to find.** Three tabs: Home, Likes,
   Profile. Reservations and the trip pass live at Profile > Reservations,
   with no sign on the way that anything is booked. The core job ends with
   "go there", and "there" is two taps deep. → **#118** (small), bet 2 (big).
4. **Price shows up late.** Home's big cards say region and beds; price
   appears first on the pod detail (or in See all). "How much" is the first
   filter for most travelers. → **#116**.
5. **The words drift.** The same thing is a *pod* (Home, Lenny's search:
   "3 pods found"), a *hut* (Likes empty state, the detail), a *shelter*
   (welcome: "Book a shelter."), a *refuge* (French everywhere) and a
   *cabin* (onboarding). Lenny is *him* in onboarding ("Tell him where and
   when") and *it* in Reservations ("It finds the pods"). Some English reads
   unfinished ("Only this needed", "Tap your email"). See (f).

---

## (b) Improvements

Effort S = under an hour, M = a day, L = several days. Impact and risk are my judgement.

| # | Screen | Observation (from the code) | Proposal | Effort | Impact | Risk |
|---|---|---|---|---|---|---|
| 1 | Booking review | No total, no payment line before Reserve | "About 180 €, paid at the hut." / "You pay at the hut." in Lenny's recap. FR: "Environ 180 €, à payer au refuge." **(#115)** | S | high | low (needs the "paid at the hut" fact confirmed) |
| 2 | After booking | "Booked! … all set." ends the moment with nothing about what's next | "Booked! 2 nights for 2 guests. Your pass is in Reservations, even offline." and save the passes right then **(#115)** | S | high | low |
| 3 | Home cards | No price on cards; See all already has the line | Reuse See all's 12pt line: "45 € / night · Open now" **(#116)** | S | high | low (density) |
| 4 | Home cards, French | `Text(subtitle)` isn't translated: "24 beds · Listed" in English on a French phone | Translate each " · " piece **(#116)** | S | med | none |
| 5 | Reduce Motion | Folder wiggles (`repeatForever`), search-pill 360° roll, new-stay pop ignore Reduce Motion | Drop them under Reduce Motion, keep the state changes **(#117)** | S | med | none |
| 6 | Profile | Reservations row has no hint a trip is booked | Caption "In 5 days" / "Tomorrow" / "Today" / "Under way" **(#118)** | S | med | none |
| 7 | Launch | Mandatory tap + ≥1.5 s every launch | First launch of the day keeps Lenny; otherwise skip straight to Home once ready (no "Go to Home"), or auto-leave 0.6 s after "All good". Never wait on the network when the pods are cached. | M | high | med (it's a signature moment) |
| 8 | "Available tonight" | Lists every partner hut (`isBookable`), not huts with beds free tonight | Either filter on free beds (the detail already fetches `bedsAvailableNow`) or rename "Partner huts" / FR "Réservables dans l'app". The word "tonight" promises something unchecked. | S (rename) / M (filter) | med | low |
| 9 | Trust badge | Chip says **Verified**, alert title "Verified by Podz", but the message says the data comes "from the hut itself" | Say what it is: chip **Partner**, alert "Booked through Podz". Keep **Unverified** for listed huts. FR: "Partenaire". | S | med | low |
| 10 | Cancelling | "Cancel this reservation? You'll need to reserve again…" says nothing about money or the hut | "Cancel this stay? The hut gets your bed back. Nothing was paid in the app." FR: "Annuler ce séjour ? Le refuge récupère ton lit. Rien n'a été payé dans l'app." | S | med | low (confirm the policy) |
| 11 | Search pill | Placeholder "Search a region" but it also matches names and countries (`updateSearch`) | "Search a hut or a region" / "Cherche un refuge ou une région" | S | low | none |
| 12 | Caption buttons | "Ask Lenny to find it", "Details", "Another tip", "Go to Home" are 13pt text with 8pt vertical padding (4pt on the detail's "Details"): about 24–32pt tall, under the 44pt minimum. "Details" is the only way into the sections besides tapping the blank area | Keep the look, grow the hit area: `.padding(.vertical, 12)` + `.contentShape(Rectangle())`, or a `.frame(minHeight: 44)` | S | med | none |
| 13 | "See all" | 13pt text button with no padding (`MinimalHomeView.sectionHeader`) | Same fix: 44pt tall hit area, the text unchanged | S | low | none |
| 14 | Dynamic Type | `AppFont` builds a fixed-size `UIFont`; nothing scales | See (d) bet 3: scale body and captions only, capped at 130%, titles and pills fixed | M | high (a11y) | med (layouts sized to fit) |
| 15 | Onboarding copy | "Only this needed" / "No stress, no multiple fields, just your mail." / "Tap your email" | See (f) | S | med | low |
| 16 | Onboarding intro | "Discover unique, architectural stays and cozy cabins hidden deep within nature's most stunning landscapes." is the one marketing sentence in a quiet app | "Huts high in the mountains, a bed for the night." / "Des refuges en altitude, un lit pour la nuit." | S | low | low |
| 17 | Terminology | pod / hut / shelter / refuge / cabin (see a.5) | Pick one word for the UI. My vote: **hut** in English (what hikers say; "pod" stays the brand), **refuge** in French (already the case). "3 pods found" → "3 huts found". | M (many strings) | med | low |
| 18 | Lenny's pronoun | "him" (onboarding), "it" (Reservations empty state) | One. design.md already says "his line", onboarding "him": use **he** everywhere, or "it" everywhere, Max's call. | S | low | none |
| 19 | Errors (onboarding) | "Security: wait 30s", "Too many emails, try later" are system-ish while the rest of the app has Lenny's voice | "Wait 30 seconds, then try again." / "Too many codes sent. Try again in a few minutes." FR: "Attends 30 secondes, puis réessaie." / "Trop de codes envoyés. Réessaie dans quelques minutes." | S | low | none |
| 20 | Trip pass | The pass opens with the code and the barcode; what a hut warden needs at the door is the name on the booking | Add the traveler's name under the code (13 `homeSubtitle`). Check with a hut what they look at. | S | med | low |
| 21 | Pod detail | Five things compete under the photo (name + altitude, status row, facts, chips, Lenny + Details) above three pills | Fine on paper, but check on a 13 mini: if it's tight, drop the chip row from the stack (the sections have them) before anything else | S | low | low |
| 22 | Likes foam | Delightful, but a first-time user doesn't know pinch does anything | One Lenny tip the first time there are 3+ folders: "Pinch to bring them together." Shown once. | S | low | low |
| 23 | Reservations tips | "Another tip ›" is good; tips repeat? (can't tell without data) | Once the tips are exhausted the caption goes, rather than looping | S | low | none |
| 24 | Dark/light | design.md: some screens still force light | List them in design.md with a date; each restyle removes one (no code change now) | S | low | none |

---

## (c) Quick wins (an evening, all S)

- Merge or cherry-pick **#115, #116, #117, #118** after testing them on the phone.
- 44pt hit areas on the caption buttons and "See all" (rows 12–13).
- Search placeholder (row 11), onboarding copy (row 15, 19), Lenny's pronoun (row 18).
- Rename the trust chip (row 9) and the cancel question (row 10), once the
  payment/cancel policy is confirmed.
- "Available tonight": rename it today (row 8), filter it later.

---

## (d) Bigger bets

**1. A launch that gets out of the way (M).** Lenny's launch is a real
signature, but a gate on every launch taxes exactly the returning traveler a
booking app lives on. Proposal: keep it whole on the **first launch of the
day** (and first after sign-in); otherwise, when the pods are already cached,
show Lenny's line for one beat and dissolve into Home by itself (same 0.8 s
dissolve, no "Go to Home"). Offline, never wait on the network: open Home from
the cache at once. Risk: it is Max's moment; the first-of-the-day rule keeps it.

**2. "Your next trip" on Home (M).** The core job ends with *go there*. When a
stay is within 14 days, one quiet line under the title, above the search pill:
`Tre Cime · in 5 days ›` (13 `homeSubtitle`, underlined like the other
captions), opening the trip pass. Nothing when no trip is near. It's the most
useful thing Home could say to a returning traveler, but it touches the
densest spot (the memory note says to ask first), so it's a proposal only.
#118 is the safe half.

**3. Dynamic Type, minimal impact (M).** Today nothing scales: `AppFont`
returns a fixed-size `UIFont`. The safe path:
- In `AppFont.interVariable`, scale only sizes ≤ 16 (body, captions,
  subtitles) with `UIFontMetrics(forTextStyle: .body).scaledValue(for:)`,
  capped at 1.3×. Titles (20, 30) and pill labels (14 inside 83pt pills) stay fixed.
- Cap the whole app at `.dynamicTypeSize(...(.xxxLarge))` on the root so the
  scaled sizes stay within what the fixed layouts can take.
- Read `@Environment(\.dynamicTypeSize)` on the root view so a change in
  Settings redraws.
- Then test the three tight places: the pod detail stack, Lenny's bubble
  above the pills, the booking chips. This gets most of the benefit (body
  copy, captions, Lenny's words) without touching the frames.

---

## (e) Things NOT to change

- **Lenny as the one voice** for errors, waits, confirmations and empty
  states (`LennyNote`, `LennyEmptyState`). It's consistent, kind and unlike
  any other booking app. Keep the three system exceptions.
- **One highlighted pill per screen.** Book, Reserve, Directions, View
  selected pods: the inverted pill always tells you the next step.
- **The control stack rule** (74 from the bottom, one hit-target rule, no
  view swaps). It's what makes every screen feel like the same app.
- **Red only for what can cancel a trip** (a closed hut) and for errors.
- **Booking as questions in the stack**, not a form. It's the app's most
  original flow; the prototypes only add words to it.
- **Facilities rank, never filter** in Lenny's search: right for incomplete data.
- **Listed vs partner, said plainly** ("Book through the hut", "Unverified",
  the OSM credit). Honest by default.
- **The offline pack and the trip pass.** The strongest reason to install
  Podz before a trip.
- **The foam.** Odd, tactile, memorable. Leave it be.

---

## (f) Copy rewrites (EN + FR, tu)

| Where | Now | EN proposal | FR proposal |
|---|---|---|---|
| Onboarding email, title | Only this needed | Just your email | Juste ton e-mail |
| Onboarding email, subtitle | No stress, no multiple fields, just your mail. | No password. We send you a code. | Pas de mot de passe. On t'envoie un code. |
| Email placeholder | Tap your email | Your email | Ton e-mail |
| Intro subtitle | Discover unique, architectural stays… | Huts high in the mountains, a bed for the night. | Des refuges en altitude, un lit pour la nuit. |
| Meet Lenny | Tell him where and when. He finds you a bed in a mountain pod. | Tell him where and when. He finds you a bed. | Dis-lui où et quand. Il te trouve un lit. |
| Reservations empty | Tell Lenny where you'd like to go, and for how long. It finds the pods and plans the stays for you. | Tell Lenny where and for how long. He finds the huts and plans the nights. | Dis à Lenny où et combien de temps. Il trouve les refuges et prévoit les nuits. |
| Booking review | …Shall I book it? | …About 180 €, paid at the hut. Shall I book it? **(#115)** | …Environ 180 €, à payer au refuge. Je réserve ? |
| Booked | Booked! … all set. | Booked! 2 nights for 2 guests. Your pass is in Reservations, even offline. **(#115)** | Réservé ! 2 nuits pour 2 personnes. Ton billet est dans Réservations, même hors ligne. |
| Cancel question | Cancel this reservation? You'll need to reserve again if you change your mind. | Cancel this stay? The hut gets your bed back. | Annuler ce séjour ? Le refuge récupère ton lit. |
| Trust chip | Verified | Partner | Partenaire |
| Trust alert title | Verified by Podz | Booked through Podz | Réservé via Podz |
| Search placeholder | Search a region | Search a hut or a region | Cherche un refuge ou une région |
| Section | Available tonight | Book in the app (or keep "tonight" and filter on free beds) | Réservables dans l'app |
| Lenny search title | 3 pods found | 3 huts found | 3 refuges trouvés (already) |
| Rate limit | Security: wait 30s | Wait 30 seconds, then try again. | Attends 30 secondes, puis réessaie. |
| Too many emails | Too many emails, try later | Too many codes sent. Try again in a few minutes. | Trop de codes envoyés. Réessaie dans quelques minutes. |

---

## (g) Open questions for Max

1. **Is "paid at the hut" true for every partner hut?** Any deposits, any
   cancellation fee? #115 and rows 9–10 depend on it. If unsure, the neutral
   line is "Nothing is paid in the app."
2. Is `price_per_night` really **per person**? The model comment says so; #115's total assumes it.
3. **Launch gate**: is "Go to Home" on every launch deliberate (a ritual), or only meant for the first one?
4. **One word**: hut or pod in the English UI? And is Lenny he or it?
5. "Available tonight": rename it, or filter it on free beds tonight?
6. Would you take a "Your next trip" line on Home (bet 2), or keep Home untouched?
7. What do hut wardens actually check at the door: the code, the barcode, or the name? (row 20)

---

Worktree used for all this: `/Users/0xmaxou/Documents/42 /Programmation/SwiftUI/Podz-design-improvements` (left in place).
