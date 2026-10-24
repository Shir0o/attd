## 2025-05-18 - Optimized Member Sort Comparators Using Cached Lowercase Names
**Learning:** Calling `displayName.toLowerCase()` within $O(N \log N)$ sorting comparators causes repeated string allocations and CPU overhead on every element comparison in Flutter/Dart.
**Action:** Use `Member.displayNameLowercase` in sort comparators across all roster, likelihood, and insights sorting logic to leverage cached lowercased display names.
