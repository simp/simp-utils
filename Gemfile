# ------------------------------------------------------------------------------
# NOTE: SIMP Puppet rake tasks support ruby 2.1.9
# ------------------------------------------------------------------------------
gem_sources = ENV.fetch('GEM_SERVERS','https://rubygems.org').split(/[, ]+/)

gem_sources.each { |gem_source| source gem_source }

group :test do
  gem 'rake'
  gem 'rspec'
  gem 'mocha'
  gem 'puppet', ENV.fetch('PUPPET_VERSION', '~> 4.0')
  # Ruby code coverage
  gem 'simplecov'
  gem 'travis'
  gem 'travis-lint'
  gem 'travish'
  gem 'pry'
  gem 'pry-doc'
end
