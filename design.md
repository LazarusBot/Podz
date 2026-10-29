# Podz design

The source of truth is the Paper file **Podz** (frames: Onboarding 1-6, Home,
Home2, DetailView, each in dark and white). This file records what those
frames use so the app can follow them without opening Paper.

**Every UI change must follow this file, and must update it when it adds a
color, a button style or a pattern.** Check it before every commit/push.

## Principles

- Pure black / white grounds. **No accent color**: the photos carry all the color.
- Flat. No shadows, no gradients except a fade into the ground. The one frosted
  material is the like-folder picker (see Patterns).
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
`Podz/Onboarding/OnboardingTheme.swift` (PR #50). They are the same palette:
merge them into one set when both are on `main`.

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

- Content margin 24. Button rows sit 40 from the screen edges (56 on onboarding).
- Pill buttons: capsule, **83 tall**, 13 apart. Search pill: 60 tall. Tab bar: 220 x 64.
- Pod cards: 296 x 340, radius 36 continuous, caption 12 below. A peek of the next card (card width = screen - 97).
- Photos that bleed from the top: rounded only along the bottom, radius 75. Onboarding card photo: radius 53, inset 21.
- Lenny mark: 40 round in the search pill; 56 round badge (3pt ground-colored border) on the detail. Photo dots: 10 round, fanned on a 42 radius arc above the badge.
- Safe areas: bottom buttons sit 40 above the safe area.

## Buttons

All buttons are flat capsules in `homePill` (95% opacity) with a 1pt ground-colored border, and use `TapScaleButtonStyle` for the press.

- **Text pill** ("Book", "Continue", "Touch to start"): 14 regular label in `homeText`.
- **Highlighted pill** (last onboarding step): ground and text swap, `onbHighlight` fill, 14 semiBold label.
- **Back**: 83 x 83 pill, chevron 8 x 12, 1.5 stroke, round caps, `homeText` at 45%.
- **Close** (`CloseButton(style: .pill, size: 44)`): round pill, same fill and 1pt border as back, thin 12pt "x" (1.5 stroke, round caps) in `homeText` at 45%. Only the Likes folder sheet uses it so far; other sheets still use the classic gray circle until they are restyled.
- **Like**: 83 x 83 pill, the tab bar's heart (22, 1.6 stroke): outline at 45% when not liked, filled at full strength when liked, with a quick bounce. Tapping when liked removes the like; otherwise it opens the folder picker.
- **Search pill**: capsule in `homePill`, 14 regular text, placeholder in `homeSubtitle`, Lenny mark at the trailing end.
- **Tab bar**: floating capsule, three line icons (home, heart, person), 22 / 1.6 stroke. Active icon at full strength, others at 45%.
- **Field pill** (onboarding): same capsule, 14 regular, caret in `homeText`.
- Placing a new button: reuse one of these. Do not add glass or shadows.

## Patterns

- **Search bar, two modes.** Tapping the bar is a plain search (nothing moves). Tapping the Lenny mark enters Lenny mode: the bar inverts (`homeText` fill), the mark rolls one full turn to the leading end and its disc melts into the bar so only the eyes and mouth show, the placeholder becomes "Chamonix to Zermatt in 5 days". Leaving the field rolls it back. Tap outside a field to dismiss the keyboard.
- **Pod detail.** *Stack*: photo 524/852 of the screen height, name + altitude, two-line teaser, back / like / Book. *Extended* (swipe up on the photo or title, or tap the title): photo shrinks to 250/852, full description and facts appear; swipe down or tap to return. The only way out is the back button: swipe-to-dismiss is off because it fights the photo paging.
- **Likes.** The folder picker sheet keeps its frosted folders and the photo-drops-into-a-folder animation. The sheet is always light. Its header: the pill close button, then the 20 title.
- **Welcome.** Photos drift behind the text, bent toward you near the screen edges; Reduce Motion freezes the drift.

## Motion

`AppMotion`: quick 0.15, snappy 0.2, standard 0.25. Larger moves use `.smooth`: 0.4 for the search roll, 0.45 for the detail stack / extended. Respect Reduce Motion for anything continuous.

## Appearance

Onboarding, Home and the pod detail follow the system appearance. Everything else (Likes, Profile, the host shell, sheets such as Book and the folder picker) has no dark palette yet and forces light with `.preferredColorScheme(.light)`.

## Before you push UI

1. Colors come from a token above. No new hex; add a token here first.
2. Buttons are one of the styles above.
3. Looks right in light and dark (or is deliberately forced light).
4. Sizes and radii match this file; this file is updated if you changed any.
