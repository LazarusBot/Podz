# Podz design

The source of truth is the Paper file **Podz** (frames: Onboarding 1-6, Home,
Home2, DetailView, each in dark and white). This file records what those
frames use so the app can follow them without opening Paper.

**Every UI change must follow this file, and must update it when it adds a
color, a button style or a pattern.** Check it before every commit/push.

## Principles

- **UX comes first.** Ease of use beats visual polish and beats adding
  features. Before building, check how many gestures and controls share one
  screen: horizontal paging, vertical swipes, edge swipes, taps on the same
  area and system gestures (swipe-to-dismiss, keyboard dismiss) all compete.
  If a screen is getting crowded or two interactions could fight (the pod
  detail's photo paging vs. swipe-to-dismiss is the example), **tell the
  user before building** and propose the simpler option; remove the
  interaction that is hardest to get right.
- Pure black / white grounds. **No accent color**: the photos carry all the color.
- Flat. No shadows, no gradients except a fade into the ground and the soft black scrim under a name on a photo tile (white text on photos is the one place text isn't a token). Nothing is glass:
  the Likes folders are flat bubbles (see Patterns).
- Dark and light are both designed. Never hard-code a color: use a token below,
  built with `Color(light:dark:)`.
- Quiet copy: short, lower-key sentences ("Tell him where and when.").

## Colors

| Role | Token | Light | Dark |
|---|---|---|---|
| Ground (screen background) | `homeBackground` / `onbBackground` | #FFFFFF | #000000 |
| Text, glyphs, icon strokes | `homeText` / `onbText` | #000000 | #FFFFFF |
| Pill (buttons, fields, tab bar, search bar) | `homePill` / `onbPill` | #F1F1F1 | #323232 |
| Subtitle, "See all", placeholder | `homeSubtitle` | #989898 | #A0A0A0 |
| Subtitle on the onboarding | `onbSubtitle` | #989898 | white 88% |
| Body copy under a title | `homeBodyText` | #989898 | white 88% |
| Placeholder on the inverted (Lenny) search bar | `homeSubtitleOnInverse` | #A0A0A0 | #A0A0A0 |
| Highlighted button ("Get started") | `onbHighlight` / `onbHighlightText` | #000000 / #FFFFFF | #FFFFFF / #000000 |
| Pill border | `homeBackground` (the ground, so it reads as a gap) | | |
| Welcome collage outline | `onbCollageOutline` | clear | white 25% |
| Error text | `appBadgeRed` | | |

`home*` tokens live in `Podz/Home/HomeTheme.swift`, `onb*` in
`Podz/Onboarding/OnboardingTheme.swift`. They are the same palette: merge them
into one set (a cleanup for later).

## Type

Inter, through `AppFont`. Sizes in points.

| Use | Font |
|---|---|
| Home title and the Likes tab title (other tabs to follow) | semiBold 30, tracking -0.02em, left-aligned at the 24 margin, 25 below the safe area |
| Screen / detail / sheet title ("Save to folder") | semiBold 20 (the altitude beside it: semiBold 14) |
| Section header | semiBold 16 |
| Body copy | regular 16, line spacing 5 |
| Subtitle, card caption, button label | regular 14 |
| Caption, "See all" | regular 13 |
| Highlighted button label | semiBold 14 |

## Shape and spacing

- Content margin 24. Button rows sit 40 from the screen edges on the pod detail, 24 (the grid's edge) on the Likes folder, 56 on onboarding.
- Pill buttons: capsule, **83 tall**, 13 apart. Search pill: 60 tall. Tab bar: 220 x 64.
- Pod cards: 296 x 340, radius 36 continuous, caption 12 below. A peek of the next card (card width = screen - 97).
- Photos that bleed from the top: rounded only along the bottom, radius 75. Onboarding card photo: radius 53, inset 21.
- Lenny mark: 40 round in the search pill; 56 round badge (3pt ground-colored border) on the detail. Photo dots: 10 round, fanned on a 42 radius arc above the badge.
- Safe areas: bottom buttons sit 40 above the safe area.

## Buttons

All buttons are flat capsules in `homePill` (95% opacity) with a 1pt ground-colored border, and use `TapScaleButtonStyle` for the press.

- **Text pill** ("Book", "Open", "Continue", "Touch to start"): 14 regular label in `homeText`.
- **Highlighted pill** (last onboarding step): ground and text swap, `onbHighlight` fill, 14 semiBold label.
- **Back**: 83 x 83 pill, chevron 8 x 12, 1.5 stroke, round caps, `homeText` at 35%.
- **Close** (`CloseButton(style: .pill, size: 44)`): round pill, same fill and 1pt border as back, thin 12pt "x" (1.5 stroke, round caps) in `homeText` at 45%. Only the Likes folder sheet uses it so far; other sheets still use the classic gray circle until they are restyled.
- **Share** (Likes folder): round 83 pill like Back, the app's SF Symbol `link` (16 semibold) in `homeText` at 35%. Not the vector from the Paper example, which wasn't right.
- **Like**: 83 x 83 pill, the tab bar's heart (22, 1.6 stroke): outline at 45% when not liked, filled at full strength when liked, with a quick bounce. Tapping when liked removes the like; otherwise it opens the folder picker.
- **Search pill**: capsule in `homePill`, 14 regular text, placeholder in `homeSubtitle`, Lenny mark at the trailing end.
- **Tab bar**: floating capsule, three line icons (home, heart, person), 22 / 1.6 stroke. Active icon at full strength, others at 45%.
- **Field pill** (onboarding): same capsule, 14 regular, caret in `homeText`.
- Placing a new button: reuse one of these. Do not add glass or shadows.

## Patterns

- **Search bar, two modes.** Tapping the bar is a plain search (nothing moves). Tapping the Lenny mark enters Lenny mode: the bar inverts (`homeText` fill), the mark rolls one full turn to the leading end and its disc melts into the bar so only the eyes and mouth show, the placeholder becomes "Chamonix to Zermatt in 5 days". Leaving the field rolls it back. Tap outside a field to dismiss the keyboard.
- **Pod detail.** *Stack*: photo 524/852 of the screen height, name + altitude, two-line teaser, back / like / Book. *Extended* (tap anywhere between the photo and the buttons): photo shrinks to 250/852, full description and facts appear; tap the same area to return. The only swipe on this screen is paging through the photos, and the only way out is the back button (swipe-to-dismiss is off).
- **Likes folder** (a folder opened from the Likes tab; Paper `LikesFolderView`). A two-column grid of the folder's pods: tiles 166 x 216 (radius 36, 13 apart, 12 between rows, 24 margins), the pod's name (15 semiBold, white) bottom-left on a soft black scrim. One tile is selected: full strength with a white check circle top-right (26, black 1.6 check); the others sit at 55%. Tap a tile to select it (the first one until you pick). The grid fades into the ground over its lower half, with the pills on top: back, share link (own folders only), **Open** (opens the selected pod). No title, no tab bar. The same tile is the onboarding's region picker tile.
- **Lenny search** (Paper `LennySearch` dark + white; opened by the Search key in the Home pill's Lenny mode, `LennySearchScreen`). A 30 semiBold "Lenny is searching…" title, then the route in the inverted pill (60 high, `homeText` fill, `homeBackground` text 14, Lenny's mark at the leading end with its disc melted into the bar), then the steps (`LennyTimeline`): an 18 dot (`homeText` 12% ring, solid dot at full strength when done, 30% while running) on a dotted line, name 13 semiBold (`homeSubtitle` while running), caption 11 `homeSubtitle`. Bottom: the back pill and **View selected pods** (dimmed until every stop is looked up; the last step stays pending until then). No navigation bar, follows the system appearance.
- **Lenny plan** (Paper `LennyPlan` dark + white; `LennyPlanView`). "Check your plan" (30 semiBold) with a 13 `homeSubtitle` line under it ("Lake Braies · 2 of 3"), then the stop's pods in the Likes-folder grid (`FolderPodTile`: picked one full strength with a check, the rest at 55%; tap to pick, tap the picked one again to open it). Bottom: the back pill (previous stop, or back to the search) and a text pill "Next stop: <name>", "See summary" on the last stop.
- **Lenny summary** (`LennySummaryView`, no Paper frame yet: built from the Profile pages recipe). "Your plan" (30 semiBold), then one flat row per stop in route order (72 photo radius 22, the pod's name 16 semiBold, the stop 13 `homeSubtitle`, hairline); tap a row to open the pod. Bottom: the back pill (to the last stop) and "Done" (closes Lenny). Fade into the ground under the pills. Fade into the ground under the pills, same as the folder view.
- **Folder bubbles = a foam** (Paper `LikesFolderSheet`, dark + white; used on the Likes tab and in the save-to-folder sheet; the word stays "folder"). A folder is a flat shape in `homePill`, 300 across when it's the only one, with its name (15 semiBold, `homeText`) in the middle and up to two of its pods' photos tucked inside its edge (119 x 141 at full size, radius 30, at 55%, cut off by the bubble's edge, mirrored on alternate bubbles). Bubbles are **packed tight, like soap foam**, not spread out: each sinks a little into its neighbors and the two **flatten against each other** along a straight edge with a 6pt gap and softly rounded corners (`FoamLayout` / `FoamCellView`). The cluster sits in the middle column and may be cropped a little by the screen edges. **They shrink as folders are added** (base radius 100% for one folder, 88% for two, 76% for three, 63% from four) and **each bubble's size follows the number of pods inside it**: its area is proportional to the count compared with the average, so a folder with four times the pods is twice as wide, equal folders are equal, an empty one is small (never below 55% of the base) and none is wider than the screen allows (the biggest is capped at 160% of the base). **Pinch out to unpack, pinch in to pack**: the bubbles follow the fingers, drift apart into plain circles (no two touching) and are packed again by pinching in; on release it settles with a soft spring to whichever side you passed halfway (never snapping back), and the flat edges grow and fade smoothly along the way. It's a two-finger gesture, so it doesn't compete with scrolling, taps or long-press. On the Likes tab a tap opens the folder; long-press switches to delete mode (wiggle, a minus on the rim); folders shared with you follow your own, with "by X" under the name; the friends a folder is shared with show as small avatars under the name. In the save-to-folder sheet (title 30 semiBold, centered), a tap saves: the pod's photo falls onto the bubble and shrinks into its middle; the bottom row is the **back** pill (closes the sheet) and the **New folder** text pill, with the bubbles scrolling behind; a new folder is a bubble with its name field in the middle and New folder is hidden while it's being named. No close X, no drag indicator. The share-folder sheet has the pill close button (44), then a 20 semiBold title, on the `homeBackground` ground.
- **Welcome.** Photos drift behind the text, bent toward you near the screen edges; Reduce Motion freezes the drift.

## Motion

`AppMotion`: quick 0.15, snappy 0.2, standard 0.25. Larger moves use `.smooth`: 0.4 for the search roll, 0.45 for the detail stack / extended. Respect Reduce Motion for anything continuous.

## Appearance

Onboarding, Home, the Likes tab (overview and folder view) and the pod detail follow the system appearance. The folder picker and share-folder sheets follow it too. Everything else (Profile, the host shell, the Book sheet) has no dark palette yet and forces light with `.preferredColorScheme(.light)`.

## Before you push UI

1. Colors come from a token above. No new hex; add a token here first.
2. Buttons are one of the styles above.
3. Looks right in light and dark (or is deliberately forced light).
4. Sizes and radii match this file; this file is updated if you changed any.
