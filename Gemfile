source "https://rubygems.org"

# fastlane + google-api-client (for Play Store supply). Pin to known-good
# versions so a fresh Ruby install doesn't pull in a breaking release.
#
# google-api-client 0.53.0 is too old: fastlane 2.238 passes a
# `changes_not_sent_for_review` keyword to androidpublisher_v3's
# `commit_edit` that doesn't exist in that client version, producing:
#   ArgumentError: unknown keyword: :changes_not_sent_for_review
# Bumping google-api-client to ~> 0.55 picks up the newer androidpublisher
# service definition that knows the keyword.
gem "fastlane", "~> 2.220"
gem "google-api-client", "~> 0.55"
