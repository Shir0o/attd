# Changelog

## [1.17.0](https://github.com/Shir0o/attd/compare/v1.16.1...v1.17.0) (2026-10-24)


### Features

* **design:** bundle fonts locally & disable CDN fetching (closes [#197](https://github.com/Shir0o/attd/issues/197)) ([#280](https://github.com/Shir0o/attd/issues/280)) ([8c6664f](https://github.com/Shir0o/attd/commit/8c6664ffc26551526d2a7ccb35d008276140467e))
* **onboarding:** add coordinator age affirmation (closes [#277](https://github.com/Shir0o/attd/issues/277)) ([#281](https://github.com/Shir0o/attd/issues/281)) ([c5a01a3](https://github.com/Shir0o/attd/commit/c5a01a3e8498b2179f6b1b22a0aca55e12ed8234))


### Performance

* cache lowercase member names in sort comparators ([#273](https://github.com/Shir0o/attd/issues/273)) ([bd5c48e](https://github.com/Shir0o/attd/commit/bd5c48e768aa12b49929ca1011a6d0e6c617b86b))

## [1.16.1](https://github.com/Shir0o/attd/compare/v1.16.0...v1.16.1) (2026-10-24)


### Bug Fixes

* **design:** style snackbars with convocation tokens (closes [#251](https://github.com/Shir0o/attd/issues/251)) ([#274](https://github.com/Shir0o/attd/issues/274)) ([d33528a](https://github.com/Shir0o/attd/commit/d33528a1da2d4692577bda4fc1b704af98c12193))

## [1.16.0](https://github.com/Shir0o/attd/compare/v1.15.0...v1.16.0) (2026-10-23)


### Features

* **backup:** show snapshot item changes and thin history ([#272](https://github.com/Shir0o/attd/issues/272)) ([cd51e99](https://github.com/Shir0o/attd/commit/cd51e990addf99e237da32072854fc4a62482cf3))


### Bug Fixes

* **events:** sync session history to renamed events and keep settings on edit ([#270](https://github.com/Shir0o/attd/issues/270)) ([56ee343](https://github.com/Shir0o/attd/commit/56ee34340e10b1c9196354ad0ba95fb837aa8609))

## [1.15.0](https://github.com/Shir0o/attd/compare/v1.14.0...v1.15.0) (2026-10-23)


### Features

* **design:** unify search bar and remove focus border ([#269](https://github.com/Shir0o/attd/issues/269)) ([2229ac1](https://github.com/Shir0o/attd/commit/2229ac1e46854c77b17e4acf9a83eb666e21259c))


### Performance

* optimize ActiveRosterIndex query lowercasing and cached name matching ([#262](https://github.com/Shir0o/attd/issues/262)) ([21eba09](https://github.com/Shir0o/attd/commit/21eba091568acfefa1d61cd3e93f6ec89d1d2722))
* optimize soft deleted pruning in LocalJsonAttendanceRepository ([#268](https://github.com/Shir0o/attd/issues/268)) ([6076489](https://github.com/Shir0o/attd/commit/6076489af96270ee52da4a9854fb70eda94a9fad))

## [1.14.0](https://github.com/Shir0o/attd/compare/v1.13.0...v1.14.0) (2026-10-22)


### Features

* **settings:** repair historical event session titles ([#264](https://github.com/Shir0o/attd/issues/264)) ([85af76a](https://github.com/Shir0o/attd/commit/85af76a9797b54a7a0831a202fdc7fe7220e6c86))

## [1.13.0](https://github.com/Shir0o/attd/compare/v1.12.3...v1.13.0) (2026-10-22)


### Features

* **settings:** add id-safe duplicate member cleanup ([#263](https://github.com/Shir0o/attd/issues/263)) ([2e9c516](https://github.com/Shir0o/attd/commit/2e9c51657ab3b71d7f1afac516455f13100d7af7))


### Bug Fixes

* **attendance:** fast marking search shows each person once, including session guests ([#260](https://github.com/Shir0o/attd/issues/260)) ([63311c7](https://github.com/Shir0o/attd/commit/63311c7750cab5ff84573296debaf769d082804e))
