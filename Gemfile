source "https://rubygems.org"

# fastlane + google-api-client (for Play Store supply). Pin to known-good
# versions so a fresh Ruby install doesn't pull in a breaking release.
#
# fastlane 2.238+ calls `commit_edit(changes_not_sent_for_review: ...)`
# on the androidpublisher_v3 service, but google-api-client 0.53.0 (the
# latest available on rubygems.org) doesn't know that keyword, producing:
#   ArgumentError: unknown keyword: :changes_not_sent_for_review
# Pin fastlane to 2.220.x so the call site doesn't pass the unknown
# kwarg. google-api-client 0.53.0 stays the floor.
gem "fastlane", "= 2.220.0"
gem "google-api-client", "~> 0.53"
