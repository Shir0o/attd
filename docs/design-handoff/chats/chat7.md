# Comment UI

_Started 2026-05-25 16:35 UTC_

---

## User

Apply comment

## User

Apply comment

## User

Apply comment

## Assistant

_[tool: grep]_

_[tool: read_file]_

_[tool: grep]_

_[tool: grep]_

_[tool: grep]_

_[tool: read_file]_

_[tool: str_replace_edit]_

_[tool: show_html]_

_[tool: show_html]_

_[tool: eval_js]_

_[tool: eval_js]_

_[tool: eval_js]_

_[tool: eval_js]_

_[tool: save_screenshot]_

_[tool: grep]_

_[tool: read_file]_

_[tool: str_replace_edit]_

_[tool: done]_

Updated the HubMini in the day/night promo to mirror the real Hub screen — TODAY · 10:00 pill, "Lord's Table" headline, Expected stat + Start button, then an Upcoming section with two event rows. Earlier ListPreview already had the A–Z chip removed and the "All" mark-all pill added on the right.

## User

Apply comment

## Assistant

_[tool: eval_js]_

_[tool: save_screenshot]_

_[tool: view_image]_

_[tool: eval_js]_

_[tool: eval_js]_

_[tool: str_replace_edit]_

_[tool: done]_

Removed the gear icon from the HubMini header and scaled up the "Roll call" and "Lord's Table" display text (30px and 28px) so both read clearly at the mini-phone scale.

## User

Apply comment

## Assistant

_[tool: read_file]_

_[tool: str_replace_edit]_

_[tool: done]_

Fixed. The MarketingFrame sets `color: #fff` for dark-themed promos, which was bleeding into the light MiniPhone nested inside. Added `color: var(--ink)` on the MiniPhone's themed inner div so any unstyled text picks up the local theme's ink color instead.

