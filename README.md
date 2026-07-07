# super_pdp

Thin, dependency-free Ruby client for the [SUPER PDP API](https://api.superpdp.tech) —
send and receive invoices under France's e-invoicing reform (Peppol network).

Stdlib only (`net/http` + `json`). No Faraday, no generated model classes.

> **Unofficial.** This is an independent, community-maintained client. It is
> **not** affiliated with, endorsed by, or supported by SUPER PDP. "SUPER PDP"
> and any related marks belong to their respective owners; they are used here
> only to describe what this gem talks to (nominative use). The gem calls the
> publicly documented HTTP API — no proprietary code is included — and is
> provided "as is" under the MIT license, with no warranty. The maintainer may
> update or **yank this gem from RubyGems at any time**; pin a version if you
> depend on it.

## Install

```ruby
gem "super_pdp"
```

## Auth

Two modes, both OAuth2:

```ruby
# Client credentials — acts on your own data (api-key-like). Token is fetched
# and refreshed automatically.
pdp = SuperPDP.new(client_id: "...", client_secret: "...")

# Bearer token — acts on a user's behalf. You obtain the token yourself via the
# authorization_code flow (/oauth2/authorize) and pass it in.
pdp = SuperPDP.new(access_token: "user-token")
```

## Use

```ruby
pdp.companies_me
pdp.create_invoice({ en_invoice: { ... } })   # body is a positional Hash
pdp.create_invoice({ en_invoice: { ... } }, expand: %w[events])  # + query params
pdp.invoice(42, expand: %w[en_invoice events])
pdp.download_invoice(42)              # raw bytes (PDF/XML), not JSON
pdp.create_invoice_event(invoice_id: 42, status: "fr:204")

# Cursor pagination handled for you:
pdp.each_item("/invoices", direction: "outgoing").each do |inv|
  puts inv["id"]
end
```

Named helpers exist for every endpoint (companies, invoices, invoice_events,
ereportings, b2c_transactions, b2c_payments, directory_entries,
french_directory, validation_reports, oauth2_sessions). For anything not
wrapped, drop to the raw verbs:

```ruby
pdp.get("/invoices", limit: 10)
pdp.post("/some/new/route", { key: "value" })
```

Responses are parsed JSON (`Hash`/`Array`). Non-2xx raises `SuperPDP::APIError`
(`#status`, `#body`).

## Test

```
bundle exec rake test     # or: bundle exec rake  (runs tests + rubocop)
```

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). In short:
open an issue to discuss anything non-trivial, then send a PR with `bundle exec
rake` (tests + rubocop) passing.

## Releasing (maintainers)

Bump `SuperPDP::VERSION`, update `CHANGELOG.md`, then:

```
bundle exec rake release   # tags the version and pushes the .gem to RubyGems
```

## License

MIT — see [LICENSE.txt](LICENSE.txt).
