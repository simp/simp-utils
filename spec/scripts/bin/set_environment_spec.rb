$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'tests'))
require 'spec_helper'
require 'set_environment'

# The tests/set_environment.rb symlink is a test-only artifact needed so
# "require 'set_environment'" works properly. (Missing suffix is the
# problem...)
describe 'Simp::YamlNodeClassifier' do
  let(:classifier) { Simp::YamlNodeClassifier.new }

  describe '#run' do
    let(:config) { File.join(File.dirname(__FILE__), 'files', 'valid_config.yaml') }
    let(:latest_and_greatest_yaml) { "---\nenvironment: latest_and_greatest\n" }
    let(:production_yaml) { "---\nenvironment: production\n" }

    context 'valid configuration' do
      it 'outputs environment for matching, specific hostname rule' do
        expect {
          classifier.run(['worker1.test.local'], config)
        }.to output(latest_and_greatest_yaml).to_stdout
      end

      it 'outputs environment for matching, hostname regex rule' do
        expect {
          classifier.run(['worker10.test.local'], config)
        }.to output(production_yaml).to_stdout
      end

      it 'outputs environment for first matching rule found' do
        expect {
          classifier.run(['logserver1.test.local'], config)
        }.to output(production_yaml).to_stdout
      end

      it 'outputs default environment when no matching rule is found' do
        expect {
          classifier.run(['es1.test.local'], config)
        }.to output(production_yaml).to_stdout
      end
    end

    context 'no configuration' do
      it "outputs 'production' environment for any node" do
        expect {
          classifier.run(['anything'], '/does/not/exist.yaml')
        }.to output(production_yaml).to_stdout
      end
    end

    context 'invalid configuration' do
      it 'fails when the configuration YAML cannot be parsed' do
        invalid_config = File.join(File.dirname(__FILE__), 'files', 'invalid_config.yaml')
        expect {
          classifier.run(['logserver1.test.local'], invalid_config)
        }.to raise_error(RuntimeError)
      end

      it "'fails when a regex rule is missing the trailing '/'" do
        invalid_config = File.join(File.dirname(__FILE__), 'files', 'invalid_rule_config.yaml')
        err_msg = %r{is not a valid hostname or regex}
        expect {
          classifier.run(['logserver1.test.local'], invalid_config)
        }.to raise_error(RuntimeError, err_msg)
      end
    end

    context 'extra input' do
      it 'ignores extra inputs when more than 1 input is supplied' do
        expect {
          classifier.run(['worker1.test.local', 'extra.test.local'], config)
        }.to output(latest_and_greatest_yaml).to_stdout
      end
    end

    context 'invalid input' do
      it 'fails when a single input is not supplied' do
        err_msg = %r{You must pass the FQDN of the host as the first argument}
        expect {
          classifier.run([], config).to raise_error(RuntimeError, err_msg)
        }.to raise_error(RuntimeError, err_msg)
      end
    end
  end
end
