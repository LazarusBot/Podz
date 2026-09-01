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
