# frozen_string_literal: true

require "bundler/gem_tasks" # build / install / release tasks
require "rake/testtask"
require "rubocop/rake_task"

Rake::TestTask.new(:test) do |t|
  t.libs = %w[lib test]
  t.pattern = "test/**/test_*.rb"
  t.warning = false
end

RuboCop::RakeTask.new

task default: %i[test rubocop]
