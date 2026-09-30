# Changelog

All notable changes to this project will be documented in this file.

Reconstructed from this repository's git history: each release lists the
feature and fix commits it carried. Version bumps, screenshot additions
and CI syncs are left out.

## [1.2.11] - 2026-09-30

### Fixed
- De-duplicate 36 questions filed under two categories at once, 10 of which
  gave two different answers ("3" and "Trois" for an octopus's hearts). With
  both categories selected the same question could come up twice in a game.
  Each is replaced by a new question in the same category at the same
  difficulty rather than deleted, so the bank stays 32 categories of exactly
  100.

### Added
- A spec over the whole 3,200-question bank: shape, no array holes, non-empty
  question and answer, each question's `category` matching its key, one
  difficulty vocabulary, and no repeats. The loader only type-checks the first
  entry it reads, so a malformed one further down used to load fine and fail
  when a player drew it.

## [1.2.10] - 2026-08-05

### Added
- Add ES and DE translations

### Changed
- Add issue/PR templates and CONTRIBUTING.md

## [1.2.9] - 2026-08-04

### Changed
- Symlink common/ to shared game-common

## [1.2.8] - 2026-07-29

### Fixed
- Drop deprecated name field from _meta.lua

## [1.2.5] - 2026-07-28

### Changed
- Add GPL-3.0 LICENSE

## [1.2.0] - 2026-07-15

### Added
- Bundle 3200-question FR bank with category picker

## [1.1.1] - 2026-07-15

### Added
- Adopt TitleBar header + vendor missing common/ dependency

### Changed
- Remove ../game-common/ fallback from package.path

## [1.1.0] - 2026-07-08

### Added
- I18n FR/EN translation + bump to 1.1.0

## [1.0.0] - 2026-06-24

### Added
- Initial release of quiz.koplugin v1.0.0

### Changed
- Add Rules section to README; style: minor formatting cleanup
