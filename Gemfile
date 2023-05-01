gem_sources = ENV.fetch('GEM_SERVERS','https://rubygems.org').split(/[, ]+/)

gem_sources.each { |gem_source| source gem_source }

group :test do
  gem 'rake'
  gem 'puppet', ENV.fetch('PUPPET_VERSION', '~> 7')
  gem 'rspec'
  gem 'simplecov'
  gem 'mocha'
  gem 'simp-rake-helpers', ENV['SIMP_RAKE_HELPERS_VERSION'] || ['>= 5.12.1', '< 6']
  gem 'pathspec', '~> 0.2' if Gem::Requirement.create('< 2.6').satisfied_by?(Gem::Version.new(RUBY_VERSION.dup))


  gem 'pry'
  gem 'pry-byebug'
  gem 'pry-doc'
end

group :system_tests do
  gem 'beaker'
  gem 'beaker-rspec'
  gem 'simp-beaker-helpers', ENV.fetch('SIMP_BEAKER_HELPERS_VERSION', ['>= 1.28.0', '< 2.0.0'])
end

# Evaluate extra gemfiles if they exist
extra_gemfiles = [
  ENV['EXTRA_GEMFILE'] || '',
  "#{__FILE__}.project",
  "#{__FILE__}.local",
  File.join(Dir.home, '.gemfile'),
]
extra_gemfiles.each do |gemfile|
  if File.file?(gemfile) && File.readable?(gemfile)
    eval(File.read(gemfile), binding)
  end
end
