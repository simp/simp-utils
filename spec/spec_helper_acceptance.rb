require 'beaker-rspec'
require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers

unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    # Install system ruby, as some of simp-utils scripts
    # use system ruby
    host.install_package('ruby')

    # Install Puppet
    # Acceptance tests need puppet in order to turn FIPS mode on
    if host.is_pe?
      install_pe
    else
      install_puppet
    end
  end
end


RSpec.configure do |c|
  # ensure that environment OS is ready on each host
  fix_errata_on hosts

  # Detect cases in which no examples are executed (e.g., nodeset does not
  # have hosts with required roles)
  c.fail_if_no_examples = true

  # Readable test descriptions
  c.formatter = :documentation
end
