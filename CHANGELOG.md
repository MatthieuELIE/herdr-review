# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `:help herdr-review`: the reference for setup, notes, colors, sending and the review log.
- Once you pick an agent, `send()` saves each modified buffer that holds a note, so the review quotes the file the agent reads. If a buffer cannot be saved, nothing is sent and the notes stay.
- The `HerdrReviewLine`, `HerdrReviewNumber` and `HerdrReviewText` highlight groups, derived from the `DiagnosticInfo` text color and the `Normal` background. A group you define stays, and `:colorscheme` recomputes the others.

### Changed

- A note tints the background of its lines, and its text shows after a `▎ ` bar on the same tint. With a transparent `Normal`, nothing is tinted.
- Notes sit under the signs and overlay of mini.diff.
- When herdr fails with a stderr that is not JSON, the decode error goes to a debug notification instead of `herdr-review.log`.

### Fixed

- `comment()` on a buffer with no file warns that it needs one and opens no window.
- Archived reviews are readable by you alone, and so is their folder.
- A review that cannot be written to its archive file shows an error.
- An excerpt holding backticks gets a fence one backtick longer than its longest run, so it no longer breaks the review's Markdown.

## [0.1.0] - 2026-11-07

### Added

- `comment()` opens a floating window for a note on the cursor line, or on the selected lines in visual mode. The note colors the numbers of its lines and shows as virtual lines under the last one. It follows its lines through edits, `:bd` and `:edit`, and is never written to the file.
- `comment()` on a line a note covers reopens that note to correct it. Emptying the window deletes it.
- `send()` lists the agents of your nvim's Herdr workspace by tab label and status, with `New agent` last. The chosen agent gets every note as `path:line` with the selected lines and your comment, focus moves to it and the notes are cleared. Cancelling the list or an error (agent blocked, `herdr` missing, nvim outside Herdr) keeps them.
- `setup({ agent = ... })` sets the agent that `New agent` starts, `claude` by default.
- Each sent review is saved under `stdpath('state')/herdr-review/<repo>/`.

[0.1.0]: https://github.com/MatthieuELIE/herdr-review/releases/tag/v0.1.0
