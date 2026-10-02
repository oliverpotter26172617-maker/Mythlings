---
name: design-with-taste
description: "Plan, build, or review visual interfaces and creative assets through distinct art directions, user choice, and live visual iteration."
---

# Design With Taste

Use this skill before designing, building, or reviewing visual work when Oliver's design instructions apply.

## Gather the brief

Extract these four inputs from the request and supplied references:

- **Aesthetic:** the mood, visual character, and level of polish.
- **Reference:** the work whose feel should inform the result. Match qualities, never copy its distinctive expression or assets.
- **Intent:** what the audience must understand or do.
- **Guardrails:** explicit always and never lists, including brand, accessibility, regulatory, and technical constraints.

Ask only for missing inputs that would change the design. Keep questions concrete. Do not ask the user to make the direction vaguer.

## Coordinate the work

For substantial visual tasks, use [the specialist workflow](references/design-team.md). Keep one shared brief and use native Codex agents when available and permitted by the active instructions. Small visual fixes stay small: reuse the established direction and relevant checks.

## Explore before building

If the project's previous exploration, choices and assets are recorded, continue from those artefacts for small refinements. Do not restart an established direction or claim earlier stages were completed without evidence. New or unselected work follows the full sequence below.

1. Present **five distinct visual directions** as concise, genuinely different concepts. For each, state its palette, type character, layout rhythm, and why it suits the intent. Do not build five full implementations.
2. Select a direction only when the user chooses one or has already made the choice clear. Until then, use flat CSS stand-ins for imagery and keep implementation reversible.
3. After direction selection, create **three body/content variants** that test different hierarchy or composition within that direction. Show the differences and settle on one before polishing.
4. Create an original hero image or visual asset that fits the selected direction. Do not use generic stock imagery or imply an unapproved visual direction through a finished asset.

## Build and refine

- Reuse the existing stack and components. Prefer CSS and platform features; do not add dependencies without approval.
- Preserve accessibility basics, keyboard operation, readable contrast, responsive layouts, and clear focus states.
- Avoid by default: blue-purple gradients, gradient text, glossy 3D blobs, Inter/system-font-only design, rounded-everything, icon-grid feature rows, untextured stock photography, and lorem ipsum.
- Open the work in its running visual environment. Add or use a **live tweaks panel** for small, visible adjustments such as spacing, colour, type scale, density, or image treatment.
- Iterate against what is actually rendered. Do not choose visual values by terminal inspection alone. If a live preview or tweak mechanism is unavailable, explain the specific blocker and stop before claiming visual review.
- Keep refinements small and tied to the user's intent and guardrails. Do not expand the product or invent content to fill space.

## Review

For new work, check the selected direction and all three variants against the brief. For refinements, use the recorded selection and inspect the affected views. Inspect the chosen result at realistic desktop and mobile sizes. Report what was visually inspected and any unresolved limitation. A static build or code-only review is not visual iteration.

Judge the rendered result on hierarchy, typography, composition, distinctive character, content accuracy, accessibility and responsive behaviour. Tie each finding to a visible example. Fix the most consequential issues first, then re-inspect the affected views. Allow at most two correction passes; if the same fix fails twice, change approach and state the remaining blocker. Do not hide accessibility, content or functional failures behind an overall aesthetic score.
