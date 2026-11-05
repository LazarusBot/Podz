# Overnight review — 5 Nov 2026

Three PRs plus this report. **Nothing is merged, main is untouched, nothing was
run on Supabase, the edge function was not deployed, nothing was installed on
the phone.** Each branch builds (`generic/platform=iOS`), and the three
together merge cleanly and build.

| PR | Branch | What |
|---|---|---|
| [#111](https://github.com/LazarusBot/Podz/pull/111) Security hardening | `security/overnight-hardening` | Swift fixes + `SQL/security_hardening.sql` + edge function edits |
| [#112](https://github.com/LazarusBot/Podz/pull/112) Remove unused code | `cleanup/dead-code` | Unused fonts, images, code, French keys; files renamed |
| [#113](https://github.com/LazarusBot/Podz/pull/113) Design gaps | `design/overnight-gaps` | French, a11y labels, margins, dark mode, closed huts in See all |

Suggested order: #112 → #113 → #111 (any order works), then run the SQL and
redeploy the function (steps below).

---

## 1. Vulnerabilities, most severe first

| # | Severity | Issue | Fixed where | You need to |
|---|---|---|---|---|
| 1 | **High** | Anyone could rewrite their reservation after booking: guests, dates, pod (even a listed hut), `source`, or re-confirm a cancelled row. The capacity / listed checks only ran on INSERT. | SQL part 2 (BEFORE UPDATE trigger + update policy) | Run the SQL |
| 2 | **High** (to confirm) | Any user may be able to become a "host" and publish pods every traveler sees (with any phone, e-mail or website). `pods` has `Hosts can insert/update/delete their own pods`, gated only by `profiles.is_host`; if your profiles update policy lets a user update their own row (it must, the app edits profiles) and doesn't restrict columns, `is_host` is writable. | SQL section C (commented out) | Check profiles' policy (query in section C), then uncomment section C |
| 3 | **Medium** | `get_email_for_username` (SECURITY DEFINER, executable by anon): any username → its e-mail. App no longer calls it. | SQL part 1 drops it | Run the SQL |
| 4 | **Medium** | Overbooking under concurrency: two bookings of the last beds at the same time could both pass. | SQL part 3 (advisory lock per pod) | Run the SQL |
| 5 | **Medium** | Trip pass for a cancelled or "booked with the hut" stay: the edge function only checked ownership. Also `reservationId` went unchecked into the query. | `supabase/functions/generate-trip-pass/index.ts` | Redeploy |
| 6 | **Medium** | Shared phone: trip passes were one file for every account and survived sign-out; reservations stayed in memory. | Swift (#111): cleared on sign-out / delete | Test on phone |
| 7 | **Medium** | Hut contact links built from raw OSM data: `website` accepted any scheme starting with "http" (e.g. `httpx:`), `mailto:` could carry `?cc=…&body=…`, `tel:` any characters. | Swift (#111) | — |
| 8 | **Low** | `app_events` / `app_diagnostics`: unbounded inserts from anon (size). | SQL part 5 (size caps) | Run the SQL; rate limit is an option |
| 9 | **Low** | External stays lowered "N free now" for everyone (`beds_available_now` counted them) and could be inserted without bounds. | SQL part 4 | Run the SQL |
| 10 | **Low** | Avatar: full-size photos uploaded (could be 10+ MB), no type/size check; bucket limits unknown. | Swift (#111) + SQL part 6 (bucket 2 MB, JPEG) | Run the SQL |
| 11 | **Low** | Image loading: http allowed in code (ATS blocked it anyway), no size/pixel cap (decompression bomb from a bad URL in the DB). | Swift (#111) | — |
| 12 | **Low** | Deep links: `podz://pod/anything/<uuid>` accepted; `podz-legal://` handler opened Terms for any link. | Swift (#111) | — |
| 13 | **Low** | French templates: a very long or nested user name ("Shared with Shared with…") made the matcher recurse; could stall the UI. | Swift (#111): length/depth cap | — |
| 14 | Info | `reject_reservation_on_listed_pod` had no fixed `search_path`. | SQL part 3 | Run the SQL |

Also fixed: the Wallet pass never showed the altitude (`pod.altitudeM` instead
of `altitude_m` in the edge function).

**Checked and fine:** the anon key in `SupabaseClient.swift` (public by
design); `T()` is `Text(String)`, never markdown, so a name like `[x](y)` can't
become a link; the Lenny parsers (`LennyRequest`, `LennyText`,
`LennyItineraryParser`): no force-unwrap or index that can fail (ranges are
guarded, input capped at 2,000 chars, emoji / RTL only affect matching, not
indexing); analytics props are ids, counts and modes only, no e-mail, name,
free text or coordinates; avatar path is `<user id>/avatar.jpg`;
`beds_available_now` returns one number, never rows.

### Exact steps for you

1. **Run the SQL** — Supabase dashboard → SQL editor → paste
   `SQL/security_hardening.sql` → Run. It's one transaction, safe to re-run.
   Then the checks written under each part (e.g. as a user in the app: cancel
   a reservation → works; "Did you book it?" → Add to my list → works).
2. **Section C** — run the `pg_policy` query in it. If the profiles update
   policy doesn't restrict `is_host`, uncomment and run section C (it only drops
   write policies the app no longer uses).
3. **Redeploy the edge function** from the repo root:
   `supabase functions deploy generate-trip-pass`
   then in the app: Reservations → an upcoming stay → Add to Apple Wallet.
4. If anything misbehaves: every part says what it replaced; the old
   definitions are in the original SQL files.

---

## 2. What could not be verified (SQL not in the repo)

Check these in **Dashboard → Authentication → Policies** (or
`select * from pg_policies where tablename in (...)`):

| Table / object | What to look for |
|---|---|
| `profiles` | RLS on. SELECT: who can read which columns (the add-friend search reads `select *` of every profile, so **age and location are readable by every user** unless the policy or a view limits them). UPDATE: `using (id = auth.uid()) with check (id = auth.uid())`, and `is_host` not writable (see #2 above). No INSERT for other ids. |
| `friendships` | INSERT: `requester_id = auth.uid()`. UPDATE (accept/decline): **only the addressee** (`addressee_id = auth.uid()`), status only, otherwise a requester can accept their own request and see friends-only data. DELETE: either side. |
| `pod_likes` | All four commands scoped to `user_id = auth.uid()`; SELECT also for friends a folder is shared with, if that's how shared folders read pods. |
| `like_folders` | Owner-only writes; SELECT for the owner and for users in `like_folder_shares`. |
| `like_folder_shares` | INSERT/DELETE only by the folder's owner, and only to an accepted friend; SELECT by owner and recipient. |
| `pods` | SELECT `using (true)` is fine (public data). Writes: none for travelers (see #2). |
| `pod_photos`, `pod_rooms` | SELECT true is fine; writes: drop host ones (section C). |
| `delete_own_account()` | SECURITY DEFINER with `set search_path`, deletes only `auth.uid()`'s rows, not executable by anon. |
| Storage `avatars` | INSERT/UPDATE/DELETE only where `(storage.foldername(name))[1] = auth.uid()::text`. |
| Storage `post-photos`, `pod-models`, `pod-photos` | Upload policies no longer needed by the app: drop or restrict. |

**Legacy tables / policies to consider dropping** (host side and Posts are
gone from the app; their SQL files stay as the record of the live schema):
`posts`, `post_photos`, `post_likes`, `post_comments` and the `post-photos`
bucket (`SQL/posts_feed.sql`); the host policies in `SQL/host_accounts.sql`,
`host_guests.sql`, `host_pod_management.sql`, `pod_3d_models.sql`; columns
`profiles.is_host`, `profiles.header_photo_url`, `pods.host_id`,
`pods.model_url`; `messages` if it still exists. Section C has the policy
drops, commented.

---

## 3. Dead code removed (#112)

- **Fonts**: 7 DarkerGrotesque files + `UIAppFonts` entries (only `AppFont.pillLabel` used them; nothing called it). `mediumLabel` too.
- **Images** (~14 MB): `Pod`, `podz`, `profile`, `Hutte`, `likes`, `pods`.
- **Code**: `CloseButton.Style.classic`, `AppRadius` r4/r5/r18/r21/r26, `Analytics.trackError` + `.error` event, `ReservationsStore.profilesById`, `Pod.hostId`/`modelURL`, `Profile.isHost`/`headerPhotoURL`, `updateProfile(headerPhotoURL:)`.
- **French**: 16 dead pairs + 2 duplicate keys.
- **Renamed**: `PodCard.swift` → `PodPhoto.swift`, `HomeHeader.swift` → `AvatarView.swift`, `TripPassTicketComponents.swift` → `BarcodeView.swift` + `AddToWalletButton.swift`.
- **Comments / design.md** about the host shell, Posts, messages, skeleton, old view names.

Kept on purpose: `AppBadgeRed` (it's the generated `Color.appBadgeRed`),
`AccentColor`/`AppIcon` (build settings), French keys built at runtime.
After #113 lands, two more keys become dead: "Friends you turn on can view
this folder, read-only." and "Add some friends first — nobody to share with
yet." (left in so the PRs don't touch the same lines).

---

## 4. Design gaps

**Fixed (#113):** card subtitles and bed counts translated; tab / region /
close / photo / typing accessibility labels translated; Likes "Done" in Inter;
sheets on the 24 margin; `AppearanceState` removed (it forced light for the
Profile tab's first frame: a white flash in dark mode); See all ends a closed
hut's line with "Closed until June" in `alertInk`; the empty share-folder
sheet uses `LennyEmptyState` and its subtitle no longer mentions a switch.

**Audited, already right:** every 30 title is semiBold with −0.6 tracking; the
only system controls left are the graphical `DatePicker` (tinted `homeText`,
as design.md describes) and the three documented exceptions (Delete account
alert, trust explanation, Book through the hut dialog); `.system(size:)` is
only used to size SF Symbol glyphs; no raw colors outside the token files.

**Needs your decision:**
1. **Closed mark on Home cards and Likes tiles.** Options: (a) the See all
   treatment (red text in the caption line) on the hero cards' caption too,
   quietest; (b) a small `alertFill` capsule "Closed until June" on the photo,
   bottom-left; (c) nothing on photos, Lenny says it on the detail. I'd
   suggest (a) for hero cards and nothing on Likes tiles.
2. **Lenny caption tap targets** ("Details ›", "Not yet ›", "Another tip ›",
   "Find huts ›"…): ~30 pt tall, under 44. They could get an invisible
   taller hit area (`padding` + `contentShape` + negative padding) without
   moving anything, but they sit ~20 above the pills, so the extra area must
   not overlap them. Worth testing on the phone first. The caption is also
   copy-pasted in 12 files: a shared `LennyCaption` view would make that one
   change.
3. **Small action pills at 38** (Add a friend, Accept, the See all sort chips,
   the share pill 84 x 38): design.md says 38–40, below the 44 guideline.
   Keep, or grow the hit area only.
4. **Onboarding errors** are red text under the field, while design.md says
   errors are Lenny's note. Onboarding has its own style; your call.
5. **Dynamic Type**: fonts are fixed sizes (`AppFont`), so the app ignores
   the user's text size. Supporting it is a bigger, design-wide change.
6. Merge the `home*` / `onb*` token sets (already noted in design.md).

---

## 5. Next suggestions

- Run the SQL and redeploy (above), then delete the commented section C once confirmed.
- Put the dashboard-only schema (profiles, friendships, likes, folders, shares, storage policies, `delete_own_account`) into `SQL/` so the next review can check it.
- Rate-limit `app_events` per install (trigger or edge function) if junk shows up.
- Add a few unit tests for `hutWebURL` / `hutPhoneURL` / `hutMailURL`, `DeepLinkRouter.handle`, `OpeningStatus.evaluate` and `LennyRequestParser` (pure functions, easy wins).
- Consider a privacy view for profiles (id, username, full_name, avatar_url) for the friend search, so age / location aren't readable by everyone.
