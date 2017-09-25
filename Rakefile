#!/usr/bin/rake -T

require 'rspec/core/rake_task'
require 'rake/clean'

RSpec::Core::RakeTask.new(:spec)


# coverage/ contains SimpleCov results
CLEAN.include 'coverage'


# 'scripts' is not one of the standard directories specified by
# the :spec_standlone task in puppetlabs_spec_helper/rake_tasks.rb.
# Since we can't override Rake task, need to remove that task and
# then create a new one with the same name.
Rake.application.instance_variable_get('@tasks').delete('spec_standalone')
desc "Run spec tests"
RSpec::Core::RakeTask.new(:spec_standalone) do |t|
  t.rspec_opts = ['--color']
  t.pattern = 'spec/scripts/**/*_spec.rb'
end


