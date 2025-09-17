$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'tests'))
require 'spec_helper'
require 'uri'
require 'pry'
require 'puppetlast'
require 'net/http'

# puppetlast, as a ruby script with a puppet-provided vendor ruby as a shebang
#   was difficult or impossible to test, so there was as symlink created in the
#   tests/ directory to rename the file to a proper '.rb'.
describe 'PuppetLast' do
  let(:pl) { PuppetLast.new }

  let(:all_hosts) do
    {
      json_doc: File.read(File.expand_path('spec/files/all_hosts.json')),
      json_obj: JSON.parse(File.read(File.expand_path('spec/files/all_hosts.json')), symbolize_names: true),
    }
  end

  let(:client6) do # rubocop:disable RSpec/IndexedLet
    {
      json_doc: File.read(File.expand_path('spec/files/client6.json')),
      json_obj: JSON.parse(File.read(File.expand_path('spec/files/client6.json')), symbolize_names: true),
    }
  end

  let(:client7) do # rubocop:disable RSpec/IndexedLet
    {
      json_doc: File.read(File.expand_path('spec/files/client7.json')),
      json_obj: JSON.parse(File.read(File.expand_path('spec/files/client7.json')), symbolize_names: true),
    }
  end

  let(:client9) do # rubocop:disable RSpec/IndexedLet
    {
      json_doc: File.read(File.expand_path('spec/files/client9.json')),
      json_obj: JSON.parse(File.read(File.expand_path('spec/files/client9.json')), symbolize_names: true),
    }
  end

  let(:puppet) do
    {
      json_doc: File.read(File.expand_path('spec/files/puppet.json')),
      json_obj: JSON.parse(File.read(File.expand_path('spec/files/puppet.json')), symbolize_names: true),
    }
  end

  describe 'parse_options' do
    skip('this is just an optparse implementation')
  end

  before :each do
    pl.setup_logger

    pl.stubs(:get_report_dir).returns(File.expand_path('spec/files'))
  end

  describe 'query_pdb_host' do
    context 'with PuppetDB running' do
      before :each do
        Net::HTTP.stubs(:get).with(URI('http://localhost:8138/pdb/query/v4/nodes/client6.test.net')).returns(client6[:json_doc])
      end

      it 'lists data about a specific host from PuppetDB' do
        expect(pl.query_pdb_host('client6.test.net', 8138)).to eq(client6[:json_obj])
      end
    end

    context 'without PuppetDB running' do
      it 'tells the user it cannot reach PuppetDB' do
        expect do
          err_msg = <<~EOM
            ERROR: Connection refused - connect(2) for "localhost" port 8138'
              Please make sure PuppetDB is running, this script is being run from
              the PuppetDB host, and the port is correct
          EOM
          pl.query_pdb_host('client6.test.net', 8138).to
          raise_error(RuntimeError, err_msg)
        end
      end
    end
  end

  describe 'query_pdb_hosts' do
    context 'with PuppetDB running' do
      before :each do
        Net::HTTP.stubs(:get).with(URI('http://localhost:8138/pdb/query/v4/nodes')).returns(all_hosts[:json_doc])
      end
      it 'lists data for all hosts from PuppetDB' do
        expect(pl.query_pdb_hosts(8138)).to eq(all_hosts[:json_obj])
      end
    end

    context 'without PuppetDB running' do
      it 'tells the user it cannot reach PuppetDB' do
        err_msg = <<~EOM
          ERROR: Connection refused - connect(2) for "localhost" port 8138'
            Please make sure PuppetDB is running, this script is being run from
            the PuppetDB host, and the port is correct
        EOM
        expect do
          pl.query_pdb_hosts(8138).to
          raise_error(RuntimeError, err_msg)
        end
      end
    end
  end

  #   describe 'transform_hosts' do
  #
  #   end

  describe 'main' do
    context 'success cases' do
      before :each do
        Net::HTTP.stubs(:get).with(URI('http://localhost:8138/pdb/query/v4/nodes/client6.test.net')).returns(client6[:json_doc])
        Net::HTTP.stubs(:get).with(URI('http://localhost:8138/pdb/query/v4/nodes/client7.test.net')).returns(client7[:json_doc])
        Net::HTTP.stubs(:get).with(URI('http://localhost:8138/pdb/query/v4/nodes/client9.test.net')).returns(client9[:json_doc])
        Net::HTTP.stubs(:get).with(URI('http://localhost:8138/pdb/query/v4/nodes/puppet.test.net')).returns(puppet[:json_doc])
        Net::HTTP.stubs(:get).with(URI('http://localhost:8138/pdb/query/v4/nodes')).returns(all_hosts[:json_doc])
        Time.stubs(:now).returns(Time.parse('2016-10-24T17:57:36.320Z')) # 1 hour beyond latest timestamp
      end

      context 'help' do
        it 'prints help' do
          # expected has name puppetlast.rb, not puppet, because we are testing with
          # a puppetlast.rb link.  We need this link in order to gather test code
          # coverage with SimpleCov.
          expected = <<~EOF
            Usage: puppetlast.rb [options]

              -d, --detailed             Show environment and last run status information
              -e, --expiration NUM       Don't show systems that have not checked in for more than NUM days.
              -S, --status a,b,c         Return only nodes with statuses: 'failed', 'changed', or 'unchanged'
              -H, --hosts a,b,c          List of hosts (short or long) that you wish to get data on
              -E, --environments a,b,c   List of environments you want to get data from
              -s, --sort-by SORT_OPTION  Sort by a given attribute: 'nil' => unsorted, 'certname' => default, 'time' => last checkin, 'status' => last run status, 'environments' => node environment
              -t, --timeformat TF        Select output time format (seconds, minutes, hours, days)
              -p, --pretty               Format the output more attractively.
              -P, --port                 The port that PuppetDB is listening on
              -f, --files-only           Only use the local files, not PuppetDB
              -l, --log-level level      Set the log level (fatal, error, warn, info, debug)
              -h, --help                 Help Message
          EOF
          expect { pl.main(['-h']) }.to output(expected).to_stdout
          expect(pl.main(['-h'])).to eq(0)
        end
      end

      context 'no parameters' do
        it 'prints the last time puppet was ran in hours for all in certname order' do
          expected = <<~EOF
            client3.test.net has no reported check in
            client6.test.net checked in 4286.38 minutes ago
            client7.test.net checked in 1586.38 minutes ago
            client8.test.net checked in 1526.38 minutes ago
            client9.test.net checked in 1466.38 minutes ago
            filehost.test.net checked in 60.01 minutes ago
            puppet.test.net checked in 60.00 minutes ago
          EOF
          expect { pl.main([]) }.to output(expected).to_stdout
          expect(pl.main([])).to eq(0)
        end
      end

      context 'with days instead of minutes' do
        it 'prints the last time puppet was ran in days' do
          out = <<~EOF
            client3.test.net has no reported check in
            client6.test.net checked in 2.98 days ago
            client7.test.net checked in 1.10 days ago
            client8.test.net checked in 1.06 days ago
            client9.test.net checked in 1.02 days ago
            filehost.test.net checked in 0.04 days ago
            puppet.test.net checked in 0.04 days ago
          EOF
          expect { pl.main(['-t', 'days']) }.to output(out).to_stdout
          expect(pl.main(['-t', 'days'])).to eq(0)
        end
      end

      context 'with pretty print' do
        it 'pretties print the last time puppet was ran' do
          out = <<~EOF
            client3.test.net  has no reported check in
            client6.test.net  checked in 4286.38 minutes ago
            client7.test.net  checked in 1586.38 minutes ago
            client8.test.net  checked in 1526.38 minutes ago
            client9.test.net  checked in 1466.38 minutes ago
            filehost.test.net checked in   60.01 minutes ago
            puppet.test.net   checked in   60.00 minutes ago
          EOF
          expect { pl.main(['-p']) }.to output(out).to_stdout
          expect(pl.main(['-p'])).to eq(0)
        end
      end
      context 'with detailed print' do
        it 'prints the last time puppet was ran and environment and status' do
          out = <<~EOF
            client3.test.net from environment test has no reported check in
            client6.test.net from environment production checked in 4286.38 minutes ago with status N/A
            client7.test.net from environment production checked in 1586.38 minutes ago with status N/A
            client8.test.net from environment test checked in 1526.38 minutes ago with status changed
            client9.test.net from environment test checked in 1466.38 minutes ago with status failed
            filehost.test.net from environment production checked in 60.01 minutes ago with status changed
            puppet.test.net from environment production checked in 60.00 minutes ago with status changed
          EOF

          expect { pl.main(['-d']) }.to output(out).to_stdout
          expect(pl.main(['-d'])).to eq(0)
        end
      end

      context 'certname sorted option' do
        it 'prints in certname order' do
          expected = <<~EOF
            client3.test.net has no reported check in
            client6.test.net checked in 4286.38 minutes ago
            client7.test.net checked in 1586.38 minutes ago
            client8.test.net checked in 1526.38 minutes ago
            client9.test.net checked in 1466.38 minutes ago
            filehost.test.net checked in 60.01 minutes ago
            puppet.test.net checked in 60.00 minutes ago
          EOF
          expect { pl.main(['-s', 'certname']) }.to output(expected).to_stdout
          expect(pl.main(['-s', 'certname'])).to eq(0)
        end
      end

      context 'with pretty print and unsorted option' do
        it 'aligns columns and print in db order' do
          expected = <<~EOF
            puppet.test.net   checked in   60.00 minutes ago
            client6.test.net  checked in 4286.38 minutes ago
            client7.test.net  checked in 1586.38 minutes ago
            client8.test.net  checked in 1526.38 minutes ago
            client9.test.net  checked in 1466.38 minutes ago
            client3.test.net  has no reported check in
            filehost.test.net checked in   60.01 minutes ago
          EOF
          expect { pl.main(['-p', '-s', 'nil']) }.to output(expected).to_stdout
          expect(pl.main(['-p', '-s', 'nil'])).to eq(0)
        end
      end

      context 'with pretty print, detailed print and time-sorted option' do
        it 'aligns columns, print details and sort based on checked in time' do
          expected = <<~EOF
            puppet.test.net   from environment production checked in   60.00 minutes ago with status changed
            filehost.test.net from environment production checked in   60.01 minutes ago with status changed
            client9.test.net  from environment test       checked in 1466.38 minutes ago with status failed#{' '}
            client8.test.net  from environment test       checked in 1526.38 minutes ago with status changed
            client7.test.net  from environment production checked in 1586.38 minutes ago with status N/A#{'    '}
            client6.test.net  from environment production checked in 4286.38 minutes ago with status N/A#{'    '}
            client3.test.net  from environment test       has no reported check in
          EOF
          expect { pl.main(['-p', '-d', '-s', 'time']) }.to output(expected).to_stdout
          expect(pl.main(['-p', '-d', '-s', 'time'])).to eq(0)
        end
      end

      context 'with detailed print and status sorted option' do
        # The sort order when 2 items have the same sort value differs
        # with different versions of Ruby. So for definitive results,
        # this test specifies only one node of each status type.
        it 'prints details and sort based on status' do
          expected = <<~EOF
            puppet.test.net from environment production checked in 60.00 minutes ago with status changed
            client9.test.net from environment test checked in 1466.38 minutes ago with status failed
            client7.test.net from environment production checked in 1586.38 minutes ago with status N/A
          EOF
          args = [ '-d', '-s', 'status', '--hosts',
                   'puppet.test.net,client7.test.net,client9.test.net' ]

          expect { pl.main(args) }.to output(expected).to_stdout
          expect(pl.main(args)).to eq(0)
        end
      end

      context 'with detailed print and environment sorted option' do
        # The sort order when 2 items have the same sort value differs
        # with different versions of Ruby. So for definitive results,
        # this test specifies only one node of each status type.
        it 'prints details and sort based on environment' do
          expected = <<~EOF
            puppet.test.net from environment production checked in 60.00 minutes ago with status changed
            client9.test.net from environment test checked in 1466.38 minutes ago with status failed
          EOF
          args = [ '-d', '-s', 'environment', '--hosts',
                   'puppet.test.net,client9.test.net' ]

          expect { pl.main(args) }.to output(expected).to_stdout
          expect(pl.main(args)).to eq(0)
        end
      end

      context 'for a specific host' do
        it 'prints the last time puppet was ran' do
          expected = <<~EOF
            client7.test.net checked in 1586.38 minutes ago
          EOF
          expect { pl.main(['--hosts', 'client7.test.net']) }.to output(expected).to_stdout
          expect(pl.main(['--hosts', 'client7.test.net'])).to eq(0)
        end
      end
      context 'for multiple hosts' do
        it 'prints the last time puppet was ran' do
          expected = <<~EOF
            client6.test.net checked in 4286.38 minutes ago
            client7.test.net checked in 1586.38 minutes ago
          EOF
          expect { pl.main(['--hosts', 'client6.test.net,client7.test.net']) }.to output(expected).to_stdout
          expect(pl.main(['--hosts', 'client6.test.net,client7.test.net'])).to eq(0)
        end
      end

      context 'time skew early all' do
        # time before oldest timestamp
        before :each do
          Time.stubs(:now).returns(Time.parse('2016-09-24T15:57:36.320Z'))
        end
        it 'tells the user their time in the future' do
          expected = <<~EOF
            client3.test.net has no reported check in
            client6.test.net time issue: 39033.62 minutes in the future
            client7.test.net time issue: 41733.62 minutes in the future
            client8.test.net time issue: 41793.62 minutes in the future
            client9.test.net time issue: 41853.62 minutes in the future
            filehost.test.net time issue: 43259.99 minutes in the future
            puppet.test.net time issue: 43260.00 minutes in the future
          EOF
          expect { pl.main([]) }.to output(expected).to_stdout
          expect(pl.main([])).to eq(0)
        end
      end

      context 'for only one environment' do
        it 'prints hosts from the specified environment' do
          expected = <<~EOF
            client6.test.net checked in 4286.38 minutes ago
            client7.test.net checked in 1586.38 minutes ago
            filehost.test.net checked in 60.01 minutes ago
            puppet.test.net checked in 60.00 minutes ago
          EOF
          expect { pl.main(['-E', 'production']) }.to output(expected).to_stdout
          expect(pl.main(['-E', 'production'])).to eq(0)
        end
      end
      context 'for many environments' do
        it 'prints hosts from the specified environments' do
          expected = <<~EOF
            client3.test.net has no reported check in
            client6.test.net checked in 4286.38 minutes ago
            client7.test.net checked in 1586.38 minutes ago
            client8.test.net checked in 1526.38 minutes ago
            client9.test.net checked in 1466.38 minutes ago
            filehost.test.net checked in 60.01 minutes ago
            puppet.test.net checked in 60.00 minutes ago
          EOF
          expect { pl.main(['-E', 'production,test']) }.to output(expected).to_stdout
          expect(pl.main(['-E', 'production,test'])).to eq(0)
        end
      end

      context 'with only one status' do
        it 'prints hosts from the specified environment' do
          expected = <<~EOF
            client8.test.net checked in 1526.38 minutes ago
            filehost.test.net checked in 60.01 minutes ago
            puppet.test.net checked in 60.00 minutes ago
          EOF
          expect { pl.main(['-S', 'changed']) }.to output(expected).to_stdout
          expect(pl.main(['-S', 'changed'])).to eq(0)
        end
      end
    end
  end
end
