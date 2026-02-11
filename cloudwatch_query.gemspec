# frozen_string_literal: true

require_relative "lib/cloudwatch_query/version"

Gem::Specification.new do |spec|
  spec.name = "cloudwatch_query"
  spec.version = CloudwatchQuery::VERSION
  spec.authors = ["Igor Irianto"]

  spec.summary = "A Ruby gem for querying AWS CloudWatch Logs with a simple, chainable interface"
  spec.description = "Query AWS CloudWatch Logs using a fluent, ActiveRecord-style interface. " \
                     "Supports chainable queries, automatic Insights query generation, and enumerable results."
  spec.homepage = "https://github.com/iggredible/cloudwatch_query"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*", "LICENSE.txt", "README.md", "Rakefile", "cloudwatch_query.gemspec"]
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk-cloudwatchlogs", "~> 1.0"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
