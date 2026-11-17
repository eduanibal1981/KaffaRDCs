# Directorate dashboard concepts

Three mobile design options for Kafaa's Directorate overview, using the supplied Safari screenshot for the screen title and tab labels. The four centre names are used with fictional H2 2026 audit data. Review progress counts checklist items and each row shows the submission stage.

- [01 Approval queue first](01-approval-queue.png) puts auditor submissions at the top and shows the comment and approval controls separately in the review detail.
- [02 Auditor progress first](02-auditor-progress.png) gives each centre a progress bar, completion count and stage.
- [03 Overview and shortcuts](03-overview-and-shortcuts.png) opens with two shortcuts for Centres and Audit Structures, followed by approvals and progress.

Each image shows **View centres** when the registry has entries, **+ Add centre** when the count is zero, and a pre-approval comment in the selected audit's detail. The option numbers and titles identify the concepts. The review panels illustrate the comment interaction.

Created with the built-in image generation tool. These are English mockups. Arabic, right-to-left and large-text layouts have not been evaluated.

## Generation prompts

Each generation used the following shared prompt and one option-specific direction.

```text
Create one polished landscape PNG product design board for the Kafaa renal dialysis quality app on mobile. The supplied screenshot is a reference for role, labels, and bottom tabs. Redesign it as a fresh professional directorate dashboard in the established Kafaa palette of deep navy, cool white, soft blue-gray, muted teal and sparing amber, with modern readable sans serif typography, subtle 1px borders, crisp icons and ample spacing. Flat, front-on, high resolution UI presentation, no physical phone bezels, no external logos, no illustration, no browser chrome, no testing banner. Aim at ~3:2 canvas. Put a prominent, tall, readable populated mobile dashboard on the left (~43% of canvas width), with a slim bottom nav labeled “Overview”, “Centres”, “Audits”, “Actions”, “More”. To the right, show a large complementary “Review audit” detail panel for “Bousher” with status “Awaiting approval”. The detail shows “Pre-approval comment”, “To the auditor”, the example comment “Please attach the signed equipment checklist.” and a button “Send to auditor”. Keep the comment form visually separate from any approval action. At bottom right, show a true empty-state example of just the same Centres card used on the dashboard, under a small external caption “Empty state”. The empty-state card has the label “Centres”, large numeral “0”, and a real button “+ Add centre”. Use the extra space to keep type large and legible.
Exact shared dashboard content: header “Directorate overview”; a “Centres” card with numeral “4” and a “View centres” button; an “Audit Structures” card with “View structures”; an “Awaiting approval” section with count “2” and two audit submissions “Bousher” and “Seeb”, each with an “Open review” action; an “Auditor review progress” section for “H2 2026” with four readable full rows “Bousher” / “30/30” / “Submitted”, “Seeb” / “30/30” / “Submitted”, “Quriyat” / “18/30” / “In progress”, and “Al Amerat” / “0/30” / “Not started”. Each review number is a checklist completion count, do not use it as an official audit score. Use no extraneous sample rows, no lorem ipsum. All specified strings must be typeset correctly, with natural case, three balanced columns at most within progress rows, no text smaller than necessary, strong colour contrast, and meaningful alignment. Retain everything within the frame.
```

### 01-approval-queue

```text
External board heading “01 / Approval queue first”. Prioritize the two new submissions by placing a strong, substantial approval inbox right below the deep navy dashboard header, with a count pill and two clean, roomy rows. Use restrained amber for the awaiting status, teal-blue for Open review, and row separators. Place compact auditor review progress underneath as a plain list. Put the Centres and Audit Structures as two equal utility cards below the progress and before the tab bar. Carry the amber waiting status and navy action into the right-hand pre-approval review. Make the approval queue visually dominant and the first thing the eye sees within the dashboard.
```

### 02-auditor-progress

```text
External board heading “02 / Auditor progress first”. Put the H2 2026 auditor review progress card right beneath the dashboard header as the largest single block. Use four thin horizontal progress bars with a clearly different treatment for 30/30, 18/30, and a neutral empty bar for 0/30. Place the plain-text statuses right with their counts, so colour never has to communicate status alone. Use a quiet navy header, bright white surface, and teal progress accent with cool gray tracks. Below the progress, use a compact two-row Awaiting approval list followed by aligned Centres and Audit Structures cards before the nav. Put the corresponding comment form in the right panel. This design should read as a calm operational dashboard.
```

### 03-overview-and-shortcuts

```text
External board heading “03 / Overview and shortcuts”. Lead with a low navy header and a striking pair of equal-width cards right under it as the graphic signature. On the left, the Centres card shows its large 4 and a strong View centres button. On the right, the Audit Structures card shows a clean outline stacked-document icon and a clear View structures button. Then place an Awaiting approval compact white card with two rows and visible Open review buttons. Follow with a tidy auditor review progress status table, with a clearly aligned stage for each centre and no bars. Use powder blue surface accents and navy/teal typography with an amber approvals label. Use the same visual system in the right-hand review panel and the zero-centres example.
```
