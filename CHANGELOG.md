# Changelog

## [Unreleased]

### Fixed
- Token refresh is now thread-safe (a shared client no longer double-fetches
  the OAuth2 token under concurrent requests).

### Added
- `LICENSE.txt`, gemspec metadata, `Rakefile`, `Gemfile`, rubocop config, and CI.
- Wider test coverage: token expiry/refresh, raw byte downloads, JSON request
  bodies, and the non-JSON response fallback.

## [0.1.0]
- Initial release: thin OAuth2 client for the SUPER PDP API.
