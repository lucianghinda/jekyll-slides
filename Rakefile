# frozen_string_literal: true

require "rake"
require "rubocop/rake_task"
require "tmpdir"

ROOT = File.expand_path(__dir__)
RUBY = RbConfig.ruby
RUBY_TESTS = Dir[File.join(ROOT, "test/**/*_test.rb")]
UNIT_TESTS = RUBY_TESTS - [
  File.join(ROOT, "test/package_test.rb"),
  File.join(ROOT, "test/example_presentation_test.rb"),
  File.join(ROOT, "test/presentation_css_test.rb")
]

def run_ruby_tests(files)
  sh RUBY, "-Itest", "-e", "ARGV.each { |file| require File.expand_path(file) }", *files
end

desc "Run Ruby unit and integration tests"
task :test do
  run_ruby_tests(UNIT_TESTS)
end

desc "Run JavaScript runtime tests"
task :js do
  sh "npm", "run", "test:javascript"
end

namespace :css do
  desc "Build the committed Tailwind stylesheet"
  task :build do
    sh "npm", "run", "build:css"
  end

  desc "Run stylesheet contract tests"
  task :test do
    run_ruby_tests([File.join(ROOT, "test/presentation_css_test.rb")])
  end
end

namespace :gem do
  desc "Run package tests, including a temporary gem build and archive check"
  task :verify do
    run_ruby_tests([File.join(ROOT, "test/package_test.rb")])
  end
end

desc "Run the isolated installed-gem example build test"
task :example do
  run_ruby_tests([File.join(ROOT, "test/example_presentation_test.rb")])
end

RuboCop::RakeTask.new(:rubocop)

desc "Run all Ruby, JavaScript, CSS, package, and installed-gem verification once"
task default: ["rubocop", "test", "js", "css:test", "gem:verify", "example"]
