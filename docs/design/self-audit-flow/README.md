# Self-audit navigation flow

These two pictures show four consecutive screens. They were made with the built-in ImageGen tool from the selected focused-scoring design and the supplied Audit Structure main-area cards. Scoring on the fourth screen is an example.

- [Main areas → Sections](01-main-areas-and-sections.png) opens the selected area's sections on a separate screen and shows how many criteria are answered.
- [Criteria → Focused scoring](02-criteria-and-scoring.png) shows the criteria in the selected section, the Unanswered filter, and the saved score for one criterion.

In the proposed flow, Previous and Next navigate within the section. Back returns to the list with its scroll position and filter. The Info icon opens the assessment summary, and saved responses refresh counts across the navigator.

## Generation prompts

### Picture 1

```text
Use case: ui-mockup. Create one high-resolution landscape PNG with exactly two separate full-height Kafaa mobile app screens side by side. These are two consecutive pages of one self-audit journey. Reference image 1 shows Kafaa's chosen focused scoring design and blue-white style. Reference image 2 shows the five actual Audit Structure v 1.00 main areas, their icons, colors and counts. Use a consistent flat, realistic Flutter Material-style UI: upright portrait 390×800-like screen proportions, dark navy text #122C50, white surfaces, pale cool gray page backgrounds, muted blue dividers and brand blue #0F5E9C for actions. Practical text sizes and readable wrapped titles. Put the screens in a pale blue quiet background with two slim external captions underneath, and a small right-pointing direction arrow in the gap only. Full screens with single-row app bars, neat alignment, realistic touch targets, no shiny hardware, emulator bar, overlays, bottom sheets, stickers, gradients, decorative images, or invented copy. Use the exact strings and numeric metadata below. The current assessment is the same fresh draft across the navigator. The only answer is made at the end of the flow. Keep the centre, structure and readiness score behind the outlined circled-i icon.
This board shows the first half. External captions "Main areas" and "Sections".
LEFT PHONE: White app bar with back arrow, "Self-audit" and circled-i and history icons. Underneath heading "Main areas" and a compact right-aligned "0/79 answered". Five evenly spaced rounded cards use the pastel outlines and colour icons seen in reference image 2. Each card has one trailing right chevron because it opens a page. The cards contain these exact names and sublines, in this order:
"Leadership, Governance, Documentation and Registration" / "7 sections · 24 criteria · 72 max points" / warm orange scales icon.
"Facility, Haemodialysis Equipment and Vascular Care" / "6 sections · 13 criteria · 39 max points" / soft pink medical kit icon.
"Medical Patient Care and Patient Satisfaction" / "7 sections · 29 criteria · 87 max points" / soft violet heart icon.
"Infection Prevention and Patient Management" / "2 sections · 8 criteria · 24 max points" / muted teal shield icon.
"Emergency Preparedness and Response" / "1 section · 5 criteria · 15 max points" / coral emergency icon.
Give the top card a very subtle warm tint to show the card chosen in this flow. Keep the metadata legible, each count paired with its exact label. Do not use accordion down arrows or expand sections inline.
RIGHT PHONE: Separate page with white back arrow app bar titled "Sections" and circled-i at right. Immediately below: the parent label "Leadership, Governance, Documentation and Registration", with the same orange scales icon in a small lightly tinted block, and a single subline "0/24 answered". Present exactly seven clean dense selectable white rows with slender separators or small gaps, each with its title, a short subline and a right chevron. Use these exact seven entries, no additions or duplicates:
"Leadership and Governance" / "0/16 answered · 48 max points";
"Governance and Documentation" / "0/3 answered · 9 max points";
"Initial Assessment Documentation" / "0/1 answered · 3 max points";
"Monthly Progress Notes" / "0/1 answered · 3 max points";
"Medication and Dialysis Orders" / "0/1 answered · 3 max points";
"Multidisciplinary Communication" / "0/1 answered · 3 max points";
"Complication and Transfer Reporting" / "0/1 answered · 3 max points".
Give the first section a very light blue row tint to indicate the next selection. All seven titles must fit and be readable. Use the space for the hierarchy, no extra filters on this page and no sticky action footer.
```

### Picture 2

```text
Use case: ui-mockup. Create one high-resolution landscape PNG with exactly two separate full-height Kafaa mobile app screens side by side. These are two consecutive pages of one self-audit journey. Reference image 1 shows Kafaa's chosen focused scoring design and blue-white style. Reference image 2 shows the five actual Audit Structure v 1.00 main areas, their icons, colors and counts. Use a consistent flat, realistic Flutter Material-style UI: upright portrait 390×800-like screen proportions, dark navy text #122C50, white surfaces, pale cool gray page backgrounds, muted blue dividers and brand blue #0F5E9C for actions. Practical text sizes and readable wrapped titles. Put the screens in a pale blue quiet background with two slim external captions underneath, and a small right-pointing direction arrow in the gap only. Full screens with single-row app bars, neat alignment, realistic touch targets, no shiny hardware, emulator bar, overlays, bottom sheets, stickers, gradients, decorative images, or invented copy. Use the exact strings and numeric metadata below. The current assessment is the same fresh draft across the navigator. The only answer is made at the end of the flow. Keep the centre, structure and readiness score behind the outlined circled-i icon.
This board shows the second half, from the Leadership and Governance section to the actual scoring workspace. Outside captions "Criteria" and "Focused scoring".
LEFT PHONE: Slim white app bar with back arrow, title "Criteria" and circled-i. Immediately underneath is the selected section title "Leadership and Governance" and compact "0/16 answered". Then a balanced two-option switch "All criteria" / "Unanswered", with only "All criteria" selected in blue. Show the top three visible choices from a scrollable criterion list. Use one rectangular white row per criterion, with code, legible wrapped wording and a muted "Unanswered" text label, then right chevron. Use these exact lines:
"T1-2.16" / "Aman incident reporting system managed with root cause analysis and action plans."
"T1-2.15" / "Risk register maintained, with all risks reviewed and reported every 3 months."
"T1-2.14" / "Community renal health awareness sessions conducted during the last 6 months."
Light blue tint on the first row indicates the criterion opened on the right. Do not show score fields in the list. Keep criterion codes and text intact.
RIGHT PHONE: Slim white back-arrow app bar "Self-audit", circled-i and history icons, closely matching the chosen left phone from reference image 1. Immediately under it one narrow context line "Leadership and Governance" with "1/16 answered" at right, after scoring. A single bordered white card starts with "T1-2.16" and full wording "Aman incident reporting system managed with root cause analysis and action plans." The three big horizontally aligned internal rows are stacked vertically. Each has a radio circle, clear label and right-aligned saved scale descriptor and points: "Met" / "90%" / "3 pts"; "Partially Met" / "80%" / "2 pts"; "Not Met" / "70%" / "1 pt". Select only the Met radio, with a calm pale blue row tint. Under the rows, separate icon-and-chevron actions "Add comment" and "Compliance proof (0)". A small check and "All changes saved" beneath the card. A slim bottom bar contains "Previous" and "Next criterion" with directional arrows. Make the score visually distinct from the percentage descriptor. No large fixed summary or submit controls. Keep visual weight on the criterion and its scoring options.
```
