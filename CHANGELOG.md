# Changelog

## [1.4.0](https://github.com/Shir0o/attd/compare/v1.3.9...v1.4.0) (2026-09-07)


### Features

* **attendance:** add present-but-late flag on session summary ([#180](https://github.com/Shir0o/attd/issues/180)) ([7c06fff](https://github.com/Shir0o/attd/commit/7c06fffb2e2c4fe431f6ac6084e7719d48370b7f))
* **attendance:** stabilize likely grid, direct guest addition, and event menu mode picker ([#175](https://github.com/Shir0o/attd/issues/175)) ([bec17cb](https://github.com/Shir0o/attd/commit/bec17cbdac357ff4ea7b05bdf180e7b894b05b10))
* **ci:** prefill Play Store release notes from changelog and standardize pipeline ([887123d](https://github.com/Shir0o/attd/commit/887123dac043b42758b966aefdb11c8bddd0b075))
* implement tiered error handling and privacy-first crash reporting ([#178](https://github.com/Shir0o/attd/issues/178)) ([a839f8c](https://github.com/Shir0o/attd/commit/a839f8cd904c506cacb8d4dcd720bc7be2a694e2))


### Bug Fixes

* **sync:** initialize dotenv and GoogleSignIn in background sync isolate ([#176](https://github.com/Shir0o/attd/issues/176)) ([dd7a775](https://github.com/Shir0o/attd/commit/dd7a77546d61fb9e64c377ef296f14dd63fca8b0))

## [1.3.9](https://github.com/Shir0o/attd/compare/v1.3.8...v1.3.9) (2026-09-03)


### Bug Fixes

* **icons:** bundle Material Icons font with uses-material-design
* **auth:** bundle ENV_SECRETS for Google Sign-In and Firebase config

## [1.3.8](https://github.com/Shir0o/attd/compare/v1.3.7...v1.3.8) (2026-09-03)


### Bug Fixes

* **release:** keep Material Icons font in release APKs ([#172](https://github.com/Shir0o/attd/issues/172)) ([343e3f0](https://github.com/Shir0o/attd/commit/343e3f081bd7628aea722723ead09418b2ea035d))

## [1.3.7](https://github.com/Shir0o/attd/compare/v1.3.6...v1.3.7) (2026-09-03)


### Bug Fixes

* fall back to native Firebase app on duplicate-app ([e2cb938](https://github.com/Shir0o/attd/commit/e2cb938d36c752823c03af98ecd8bcf86c8e50e0))
* fall back to native Firebase app on duplicate-app ([7ae1257](https://github.com/Shir0o/attd/commit/7ae125743d210914eb4c09537966ee4b3b54eb71))
* fall back to native Firebase app on duplicate-app ([#170](https://github.com/Shir0o/attd/issues/170)) ([e2cb938](https://github.com/Shir0o/attd/commit/e2cb938d36c752823c03af98ecd8bcf86c8e50e0))

## [1.3.6](https://github.com/Shir0o/attd/compare/v1.3.5...v1.3.6) (2026-09-03)


### Bug Fixes

* **deck:** optimize swipe dismiss animation for snappy responsive marking ([#165](https://github.com/Shir0o/attd/issues/165)) ([0fca42e](https://github.com/Shir0o/attd/commit/0fca42ed0afd3ae6b759b6c4781e1bff464fefe9))
* **release:** run explicit bundle install and relax fastlane gem constraint ([e8b109d](https://github.com/Shir0o/attd/commit/e8b109ddcc2cb9d00bf2b3fd43daadebcd46908b))
* **sheets:** preserve columns for hyphenated event names in google sheets sync ([#166](https://github.com/Shir0o/attd/issues/166)) ([582e96a](https://github.com/Shir0o/attd/commit/582e96a00a6b3be3ecdcd528319c63f650bb4248))
* skip Firebase re-init when native app already exists ([da0fa50](https://github.com/Shir0o/attd/commit/da0fa50612146eb59a49d192ed66637a8066649e))
* skip Firebase re-init when native app already exists ([bd9e8a0](https://github.com/Shir0o/attd/commit/bd9e8a015c395649f3a24fcdd8d9a5dd51e0eee8))
* skip Firebase re-init when native app already exists ([#169](https://github.com/Shir0o/attd/issues/169)) ([da0fa50](https://github.com/Shir0o/attd/commit/da0fa50612146eb59a49d192ed66637a8066649e))
