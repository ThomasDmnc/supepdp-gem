# frozen_string_literal: true

require_relative "super_pdp/version"
require_relative "super_pdp/error"
require_relative "super_pdp/client"

module SuperPDP
  def self.new(...) = Client.new(...)
end
