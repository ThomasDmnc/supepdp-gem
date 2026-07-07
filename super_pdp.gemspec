# frozen_string_literal: true

require_relative "lib/super_pdp/version"

Gem::Specification.new do |spec|
  spec.name = "super_pdp"
  spec.version = SuperPDP::VERSION
  spec.authors = ["Thomas Demoncy"]
  spec.email = ["thomas.demoncy@gmail.com"]

  spec.summary = "Ruby client for the SUPER PDP e-invoicing API"
  spec.description = "Thin, dependency-free Ruby client for the SUPER PDP API " \
                     "(France electronic invoicing reform / Peppol)."
  spec.homepage = "https://api.superpdp.tech"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/ThomasDmnc/supepdp-gem",
    "changelog_uri" => "https://github.com/ThomasDmnc/supepdp-gem/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "rubocop-minitest", "~> 0.35"
  spec.add_development_dependency "rubocop-rake", "~> 0.6"
end
