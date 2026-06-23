# 1. No color coding for Projects and Facets

- Status: Accepted
- Date: 2026-06-23

## Context

Avow is a tool whose primary purpose is to **record and aggregate the time
spent on work**. Its data model is intentionally organized around three
orthogonal axes:

- `Project` — what the task belongs to
- `Facet` — a cross-cutting "kind of work" label
- `TimeEntry` — the actual recorded time

Many comparable tools introduce **color** as a way to make lists, boards, and
charts easier to scan. A natural question is whether Avow should assign colors
to Projects (or Facets), especially in the aggregation-heavy screens
(`OverviewView`, `CalendarView`) where multiple items are shown side by side.

We evaluated this and concluded that color, done naively, is a trap. The
reasoning is recorded here so the decision is not relitigated without new
information.

### Two kinds of color

Color serves two distinct functions, and they must not be conflated:

1. **Decorative color** — "looks nicer / richer." This is pure noise relative
   to Avow's value (recording accuracy and clean aggregation). Excluding it is
   unambiguously correct.
2. **Data-encoding color** — lets the eye tell apart which segment of a chart
   belongs to which Project/Facet. This has real utility, but only under
   constraints described below.

### The impossibility triangle

For data-encoding color, three desirable properties **cannot all hold at once**:

| Property          | Meaning                                          |
| ----------------- | ------------------------------------------------ |
| **Stability**     | The same Project/Facet always has the same color |
| **Scalability**   | Works even as the number of items grows          |
| **Distinguishability** | Colors are tellable apart at a glance       |

You can only pick two:

- **Stable + Distinguishable** → not Scalable. Humans reliably distinguish only
  ~6–8 categorical colors at a glance, so the colored set must be capped; the
  rest fall back to grey.
- **Stable + Scalable** → not Distinguishable. Deriving color from an ID hash is
  stable and unbounded, but produces near-duplicate/colliding colors that the
  eye cannot separate — defeating the purpose.
- **Scalable + Distinguishable** → not Stable. Assigning colors per-view (e.g.
  "top N items in this screen get colors") avoids the ceiling, but the same
  Project would change color between views/days. Unstable color is worse than
  no color, because color's only value is *learn once, recognize thereafter*.

The only viable corner is **Stable + Distinguishable (cap scalability)**. In
practice that means color cannot be an automatic system-assigned attribute; it
must be a **scarce, user-assigned resource**: the user manually pins a color to
a handful (≈5–6) of important Projects, everything else stays grey, and a pinned
color never changes.

That, in turn, means a "real" color feature is not a small visual touch — it
drags in a color-management UI and pushes ongoing curation work onto the user.

## Decision

1. Avow does **not** ship automatic color coding for Projects or Facets. This is
   a deliberate **non-goal**, not an unfinished feature.
2. Decorative color is rejected permanently.
3. Data-encoding color is **deferred**, not forbidden. If it is ever added, it
   must take the only viable form: **user-assigned, stable, capped at a few
   items, rest grey** — never auto-assigned across all items, and never
   per-view dynamic.
4. The "hard to read aggregations" problem is addressed first by means that are
   *stable and scalable*: sorting (by descending time), folding small items into
   an "Other" bucket, and label ordering — not by color.

## Consequences

- The aggregation screens (`OverviewView`, `CalendarView`) rely on labels,
  ordering, and folding rather than color. This keeps the UI free of color-
  management surface area and avoids the instability/ceiling problems above.
- We avoid the cascading cost of palette pickers, collision avoidance, and
  per-Project color state in the MVP.
- **Re-evaluation trigger:** revisit data-encoding color only when real usage
  shows roughly **more than 5–7 Projects/Facets appearing simultaneously in a
  single screen**. Below that, labels suffice. The decision should be driven by
  observed data, not assumption.
- If revisited, the first spec must be "user pins color to a few items; the rest
  are grey," explicitly *not* "assign a color to every Project."
