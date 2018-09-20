require 'beaker-rspec'
require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers

unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    # Install Facter for beaker helpers (which uses 'facter' as
    # part of the host setup) and some of the tests
    host.install_package('rubygems')
    on(host, 'gem install facter')
    on(host, 'echo export PATH=$PATH:/usr/local/bin > /root/.bashrc')
  end
end

RSpec.configure do |c|
  # Readable test descriptions
  c.formatter = :documentation
end
