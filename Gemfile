gem_sources = ENV.fetch('GEM_SERVERS','https://rubygems.org').split(/[, ]+/)

gem_sources.each { |gem_source| source gem_source }

group :syntax do
  gem 'metadata-json-lint'
  gem 'puppet-lint-trailing_comma-check', require: false
  gem 'rubocop', '~> 1.84.0'
  gem 'rubocop-performance', '~> 1.26.0'
  gem 'rubocop-rake', '~> 0.7.1'
  gem 'rubocop-rspec', '~> 3.7.0'
end

group :test do
  gem 'rake'
  # renovate: datasource=rubygems versioning=ruby
  gem 'puppet', ENV.fetch('PUPPET_VERSION', ['>= 7', '< 9'])
  gem 'rspec'
  gem 'simplecov'
  gem 'mocha'
  # renovate: datasource=rubygems versioning=ruby
  gem 'simp-rake-helpers', ENV.fetch('SIMP_RAKE_HELPERS_VERSION', '~> 5.24.0')
end

group :development do
  gem 'pry'
  gem 'pry-byebug'
  gem 'pry-doc'
end

group :system_tests do
  gem 'bcrypt_pbkdf'
  gem 'beaker'
  gem 'beaker-rspec'
  # renovate: datasource=rubygems versioning=ruby
  gem 'simp-beaker-helpers', ENV.fetch('SIMP_BEAKER_HELPERS_VERSION', '~> 2.0.0')
end

# Evaluate extra gemfiles if they exist
extra_gemfiles = [
  ENV.fetch('EXTRA_GEMFILE', ''),
  "#{__FILE__}.project",
  "#{__FILE__}.local",
  File.join(Dir.home, '.gemfile'),
]
extra_gemfiles.each do |gemfile|
  if File.file?(gemfile) && File.readable?(gemfile)
    eval(File.read(gemfile), binding) # rubocop:disable Security/Eval
  end
end
