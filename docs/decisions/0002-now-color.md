# 2. Amber marks "now" only; the accent color stays the system's

- Status: Accepted
- Date: 2026-10-17

## Context

The app icon is a neutral graphite arc with one amber point: the task being
recorded now. The question was whether the app's `AccentColor` should become
that amber so the UI matches the icon.

`Color.accentColor` is used for two different things in the app:

- **Selection and controls**: the selected Quick Panel row, the selected and
  current day in the sidebar calendar, the checkmarks in the Facet and Project
  Group pickers.
- **Recording state**: the play icon and "Tracking" label of the active task,
  the elapsed time in the menu bar panel, the active Quick Start card.

Making the accent amber would paint both groups amber, so amber would no longer
say "this is being recorded". It also fails contrast: white text on the
selected calendar day is about 2.6:1 on #E58A12 in light mode and about 1.8:1
on #FFB340 in dark mode. On macOS the app's accent only applies when the user's
system accent is Multicolor, so the match would be partial anyway.

## Decision

1. `AccentColor` stays unset, so selection and controls follow the system accent.
2. A separate `Now` color (`Color.now`) carries the icon's amber and is used
   only for recording state.
3. `Now` is #A65F00 in light mode (darkened from the icon's #E58A12 so text
   reaches 4.5:1) and #FFB340 in dark mode (the icon's own dark amber).
4. `scripts/gen_avow_icon.py` generates `Now.colorset` from the same design
   values as the icon, so the two cannot drift.

## Consequences

- Amber in the UI has one meaning, the same as in the icon, in line with
  [ADR 0001](0001-no-color-coding.md)'s rule that color must carry meaning.
- New UI that shows the active entry uses `Color.now`; UI that shows selection
  uses `Color.accentColor`.
- Stop buttons stay red: they are an action, not the recording state.
