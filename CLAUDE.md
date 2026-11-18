# Podz

SwiftUI app for finding and reserving mountain shelters/refuges ("pods"), backed by Supabase.

## File size

Keep files reasonably small — a file holding one screen or one clear
component is easier to review, diff, and split into a focused PR than one
that's grown into several unrelated things.

- **~400-500 lines is the point to start splitting.** Past that, a file
  usually holds more than one real concern (e.g. a screen plus two or
  three private subviews that don't need to live next to it).
- **When adding a new feature, check the file you're about to extend
  first.** If it's already past the guideline above, don't keep piling
  onto it — create a new file for the feature's own view(s)/store/model,
  even if the natural instinct is "there's already a `PostCard`, I'll just
  add my thing there." A new, focused file beats a monolith every time.
- Split along real seams: a private subview used by only one screen can
  move to its own file once the parent gets big; a store's queries for a
  new feature (e.g. reservations) get their own `XStore.swift`, not a
  bolt-on method on an unrelated store.
- This is a guideline, not a hard gate — a 550-line file that's genuinely
  one cohesive thing doesn't need to be chopped up for its own sake. Judge
  by whether a reviewer could understand the file's *purpose* in one read,
  not by the line count alone.

## Committing

- Commit and push proactively as work lands — don't let a branch grow
  into an unreviewable pile covering five unrelated features. One
  branch/PR per feature, not stacked.
- Never merge `main` without being asked to.

## Design

- **Follow `design.md`** for any UI change — its colors, button styles,
  type, spacing and patterns come from the Paper frames. Check it before
  every commit/push, and update it in the same change if you add a token,
  a button style or a pattern.
- Never hard-code a color: use the tokens in `design.md`.

## The team

Four bots live in `.claude/agents/` (the same names as on the portfolio). Call them by name (`@root`, `@holly`, `@foaly`, `@butler`, or "ask Root to…").

| Bot | Role | Edits files? |
|---|---|---|
| **Root** | Product lead: flows, what to cut, edge cases, onboarding, Lenny search, empty/error states, the booking path | No |
| **Holly** | Visual designer: screens against `design.md` (tokens, pills, control stack, type, light and dark, Paper frames) | Only when asked |
| **Foaly** | SwiftUI engineer: views, components, motion (Reduce Motion), gestures, accessibility | Yes |
| **Butler** | Software engineer: build and Xcode project, Supabase and `SQL/`, stores, performance, tools, tests, TestFlight | Yes |

Bots can't call each other, so the main session runs the chain:

1. Pick the bots the chore needs, in this order unless the request says otherwise: **Root → Holly → Foaly → Butler** (think, then look, then build, then ship).
2. Run the first bot. Each bot ends its report with a **Hand-off** section (Next, Task, Done when) or "Hand-off: none".
3. Pass each hand-off to the bot it names, with the previous reports' relevant findings, until a bot writes "Hand-off: none".
4. Skip bots that have nothing to do. A single-bot request ("ask Holly to check the Likes folder") runs only that bot.
5. Butler commits and pushes only if the request asked to ship; otherwise stop before committing and say what's ready.
6. Report to Maxence in one summary: what each bot found or changed, what was checked, and what still needs his decision.
