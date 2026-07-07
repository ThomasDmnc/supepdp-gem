# Contributing

Thanks for your interest — contributions are welcome.

This is an **unofficial**, community-maintained client for the SUPER PDP API
(see the disclaimer in the [README](README.md)). It is not affiliated with or
endorsed by SUPER PDP.

## Getting started

```
git clone https://github.com/ThomasDmnc/supepdp-gem
cd supepdp-gem
bundle install
bundle exec rake        # runs the tests + rubocop
```

Requires Ruby >= 3.0. The gem is intentionally dependency-free at runtime
(stdlib `net/http` + `json` only) — please keep it that way; a change that adds
a runtime dependency needs a strong reason.

## Making a change

1. Open an issue first for anything non-trivial (new endpoints, behavior
   changes) so we can agree on the approach.
2. Fork, branch, and make your change.
3. Add or update tests. Tests run against a real stdlib `TCPServer` in
   `test/test_super_pdp.rb` — no external calls, no WebMock. Follow the existing
   pattern: add a route to `response_for` and assert against the recorded
   `@requests`.
4. Make sure `bundle exec rake` passes (tests + rubocop, both clean).
5. Update `CHANGELOG.md` under `[Unreleased]`.
6. Open a pull request describing the change and linking the issue.

## Scope

New endpoint helpers should stay thin wrappers over the raw verbs (`get`,
`post`, `patch`, `delete`), mirroring the existing ones in `client.rb`. Anything
the helpers don't cover is already reachable via the raw verbs, so we only add a
helper when it clearly improves ergonomics.

## Reporting bugs / security

Open a GitHub issue for bugs. For anything sensitive (e.g. a credential-handling
issue), email the maintainer at thomas.demoncy@gmail.com rather than filing a
public issue.

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT license](LICENSE.txt).
