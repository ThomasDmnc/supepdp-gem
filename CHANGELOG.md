# Changelog

## [Unreleased]

### Fixed
- Token refresh is now thread-safe (a shared client no longer double-fetches
  the OAuth2 token under concurrent requests).

### Added
- `User-Agent` header on every request (`super_pdp/<version> (Ruby <version>)`)
  so the server can identify the client and version.
- Automatic retries with backoff for transient failures (HTTP 429/502/503/504 and
  connection errors) on idempotent verbs (`GET`/`DELETE`). Honors `Retry-After`;
  configurable via `max_retries` and `retry_base`. POST/PATCH are never retried.
- `LICENSE.txt`, gemspec metadata, `Rakefile`, `Gemfile`, rubocop config, and CI.
- Wider test coverage: token expiry/refresh, raw byte downloads, JSON request
  bodies, and the non-JSON response fallback.

## [0.1.0]
- Initial release: thin OAuth2 client for the SUPER PDP API.
