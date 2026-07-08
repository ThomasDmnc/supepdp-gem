# Changelog

## [Unreleased]

## [1.1.0] - 2026-07-08

### Changed
- **Breaking:** `enroll_company` now takes keyword arguments and sends
  `multipart/form-data` (the API requires it). Call it as
  `enroll_company(enroll: {...}, formal_agreement: file, **documents)` where
  `enroll` is the company/KYC JSON document and files accept a path, an IO, or a
  `[io, filename, content_type]` triple. The previous `enroll_company(json_body)`
  form is removed.

### Added
- Multipart request support threaded through `request`/`build_request` via
  `Net::HTTP#set_form`, used by `enroll_company`.

## [1.0.0] - 2026-07-08

### Fixed
- Token refresh is now thread-safe (a shared client no longer double-fetches
  the OAuth2 token under concurrent requests).

### Added
- Community files: `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1), `SECURITY.md`,
  and GitHub issue/PR templates.
- `User-Agent` header on every request (`super_pdp/<version> (Ruby <version>)`)
  so the server can identify the client and version.
- Status-specific error subclasses of `APIError`: `UnauthorizedError` (401/403),
  `NotFoundError` (404), and `RateLimitError` (429, exposes `#retry_after`). Existing
  `rescue SuperPDP::APIError` still catches all of them.
- Automatic retries with backoff for transient failures (HTTP 429/502/503/504 and
  connection errors) on idempotent verbs (`GET`/`DELETE`). Honors `Retry-After`;
  configurable via `max_retries` and `retry_base`. POST/PATCH are never retried.
- `LICENSE.txt`, gemspec metadata, `Rakefile`, `Gemfile`, rubocop config, and CI.
- Wider test coverage: token expiry/refresh, raw byte downloads, JSON request
  bodies, and the non-JSON response fallback.

## [0.1.0]
- Initial release: thin OAuth2 client for the SUPER PDP API.
