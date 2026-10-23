# Bolt Journal - Performance Learnings

## 2025-02-23 - `ActiveRosterIndex` String Lowercasing Overhead
**Learning:** `calculateMatchRank` and `calculateSearchRank` in `ActiveRosterIndex` were repeatedly calling `.toLowerCase()` and `.trim()` on query and target strings inside high-frequency search loops and sort comparators. By querying pre-lowercased properties (`Member.displayNameLowercase`, `Family.displayNameLowercase`) and trimming/lowercasing queries once, search performance is significantly improved.
**Action:** Always pre-lowercase query parameters once per search entry point and pass lowercased fields to inner rank calculations and sort comparators.
