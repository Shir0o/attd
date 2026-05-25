# Attendance Tracker — Screen Inventory (2026-05)

Captured on Pixel 6 Pro, dark theme, against commit `347cb6e` (PR #75 — "Polish large-event attendance: mark-all undo, smart family edits, history-aware defaults") on `main`.

Demo data seeded via the UI: 5 single-member families (Alice Smith, Bob Smith, Carol Jones, Dan Solo, Eve Lonely) and one event "Sunday Service" with a mixed-attendance session (3 present / 2 absent).

> **Caveat:** Onboarding (01-05) and a few hub/members/event screens (10, 12, 14, 15, 20, 21, 23, 30, 40, 41, 60, 64, 71) were captured under PR #74 (`9d0f34b`) before the worktree was fast-forwarded. Those screens' code didn't change visually in PR #75, so they're kept as-is. Everything in the **Attendance** group and `50-start-mode-picker.png` were re-shot under PR #75.

## Onboarding
| File | Screen | Description |
|---|---|---|
| `01-onboarding-1-quick-marking.png` | Onboarding 1 of 5 | "Quick Marking" — swipe demo with John Doe / Jane Smith mock cards |
| `02-onboarding-2.png` | Onboarding 2 of 5 | "Session History" — list of dated sessions with present/absent counts |
| `03-onboarding-3.png` | Onboarding 3 of 5 | "Manage Members" — search + list affordance preview |
| `04-onboarding-4.png` | Onboarding 4 of 5 | (verify on file — copy not captured during walkthrough) |
| `05-onboarding-5.png` | Onboarding 5 of 5 | "Data & Export" — Manage Members / Manage Backup / Backup to Local with "Get Started" CTA |

## Hub
| File | Screen | Description |
|---|---|---|
| `10-hub-empty.png` | Hub (empty) | First launch after onboarding — "No events scheduled" with FAB |
| `12-hub-with-event.png` | Hub with event | "Sunday Service" card showing TODAY + START button |
| `14-hub-event-taken.png` | Hub with taken event | Same card after session saved — TAKEN badge |
| `15-event-menu-sheet.png` | Event overflow sheet | Bottom sheet from 3-dot: Manage Members / View History / Edit Event / Delete Event |

## Members
| File | Screen | Description |
|---|---|---|
| `20-members-empty.png` | Manage Members (empty) | Search + add field, "Regular Members 0" |
| `21-members-populated.png` | Manage Members (5 members) | Alice Smith, Bob Smith, Carol Jones, Dan Solo, Eve Lonely as singletons, count chip "5" |
| `23-event-members-assigned.png` | Manage Event Members | All 5 toggled assigned, count "5 / 5" |

## Event Creation
| File | Screen | Description |
|---|---|---|
| `30-add-event.png` | New Event form | Empty form with Event Name field, Event Time picker, Frequency dropdown, day chips, Create Event button |

## Settings
| File | Screen | Description |
|---|---|---|
| `40-settings-top.png` | Settings (Appearance / Privacy / Cloud / Sheets) | Top of settings page — Theme Mode, App Lock, Google Drive Sync, Google Sheets Integration |
| `41-settings-data.png` | Settings (Data Management / Information) | Manage Members, Manage Backup Data, Backup to Local Storage, Advanced Reporting, Export Report, Feedback, Privacy Policy |

## Attendance (PR #75 — re-shot)
| File | Screen | Description |
|---|---|---|
| `50-start-mode-picker.png` | Start mode picker | Bottom sheet with three modes: "Start with all absent" (selected), "Start with all present", **"Smart defaults (from past 8 sessions)"** with new explanatory copy |
| `60-deck-card.png` | Deck mode — card | Flashcard view with Alice Smith, Deck/List toggle, undo/cross/check action row |
| `61-deck-list.png` | List mode — singletons flat | New flat "MEMBERS" section (no family headers since every family is a singleton); By family / By status toggle; **3-dot Mark everyone menu** in the top-right of the toggle row |
| `65a-mark-everyone-menu.png` | Mark-everyone popup | Popup from the 3-dot menu — "Mark everyone present" / "Mark everyone absent" |
| `65-mark-all-confirm.png` | Mark-all confirmation dialog | **NEW** — "Mark everyone present? This will set 5 members to present and overwrite any current statuses. You can undo from the snackbar." Cancel / Mark present |
| `66-mark-all-undo.png` | Mark-all undo snackbar | **NEW** — "Marked 5 members present." with Undo action; all 5 members now show purple checkmarks |
| `63-deck-list-mixed.png` | List mode — mixed | Alice/Bob/Dan marked present, Carol/Eve absent; snackbar still visible |
| `64-deck-list-bystatus.png` | List mode — by status | Members grouped under MARKED PRESENT / MARKED ABSENT *(captured under PR #74; layout for flat-singleton case unchanged)* |
| `70-session-summary.png` | Session summary — by status | Sunday Service summary, PRESENT 3 / ABSENT 2, Attendance Roster with marked-present and marked-absent groups, snackbar still showing |
| `71-session-summary-family.png` | Session summary — by family | Same summary in "By family" grouping *(captured under PR #74; logic mostly unchanged)* |

## Screens not captured (and why)

- **Family list page** (`FamilyListPage`) — defined in `lib/features/families/presentation/family_list_page.dart` but **no `Navigator.push` callsite exists outside its own file**, even after PR #75. Unreachable from the shipping navigation.
- **Family details page** (`FamilyDetailsPage`) — same. PR #75 added a "Suggested" section (`_suggestedMembers()`), but there's no UI entry point into the page in the shipping nav. Reachable only from `FamilyListPage`, which is itself unreachable.
- **Add family page** (`AddFamilyPage`) — only reachable from `FamilyListPage`, ditto.
- **Event history page** (`EventHistoryPage`) — reachable from the event overflow sheet (`15-event-menu-sheet.png` → "View History"), but during capture the tap missed and was not re-attempted to conserve the token budget. Worth a follow-up if needed.
- **Edit event page** — reused `AddEventPage` widget with the event prefilled. Visually near-identical to `30-add-event.png`. Skipped.

## Upload
PNGs live in `docs/screenshots/2026-05/`. Drag-drop the directory contents into Canva as a new project "Attendance Tracker — Screen Inventory 2026-05". This manifest provides the file→screen mapping for naming each Canva asset.
