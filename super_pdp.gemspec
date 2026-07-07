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

  spec.files = Dir["lib/**/*.rb", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
end
