require 'spec_helper'

describe 'unpack_dvd script' do
  before(:all) do
    require 'tmpdir'

    @tmpdir = Dir.mktmpdir

    at_exit do
      FileUtils.remove_entry_secure(@tmpdir) if File.directory?(@tmpdir)
    end
  end

  let(:unpack_dvd) do
    File.expand_path(
      File.join(
        File.dirname(__FILE__), '..','..','..',
        'scripts',
        'bin',
        'unpack_dvd'
      )
    )
  end

  let(:mkisofs) do
    [
      'mkisofs',
      '-quiet',
      '-uid 0',
      '-gid 0',
      '-J',
      '-joliet-long',
      '-r',
      '-v',
      '-T',
      '-m TRANS.TBL'
    ].join(' ')
  end

  required_apps = [
    'mkisofs',
    'isoinfo',
    'rpmbuild'
  ]

  require 'facter'
  missing_apps = required_apps.select{|x| !Facter::Core::Execution.which(x)}

  Dir.glob(File.join(__dir__, 'files', 'unpack_dvd', 'ISO', '*')).each do |target|
    next unless File.directory?(target)

    target_name = File.basename(target)

    context target_name do
      let(:iso_path) do
        File.join(@tmpdir, "#{target_name}.iso")
      end

      let(:working_dir) do
        dir = File.join(@tmpdir, target_name)

        File.directory?(dir) ? dir : FileUtils.mkdir(dir).first
      end

      let(:os) do
        target_name.split('_').first
      end

      let(:os_version) do
        target_name.split('_').last
      end

      if missing_apps.empty?
        it 'builds a test ISO' do
          Dir.chdir(target) do
            %x{#{mkisofs} -o #{iso_path} .}
            expect($?.exitstatus).to eq 0
          end
        end

        it 'runs unpack_dvd' do
          Dir.chdir(working_dir) do
            FileUtils.mkdir('output')

            %x{ruby #{unpack_dvd} -d output #{iso_path}}
            expect($?.exitstatus).to eq 0
          end
        end

        it 'has a populated Updates/repodata' do
          Dir.chdir(working_dir) do
            expect(
              Dir.glob(
                File.join('output', os, os_version, '**', 'Updates', 'repodata', '*')
              ).grep(/repomd\.xml$/)
            ).not_to be_empty
          end
        end
      else
        it 'runs unpack_dvd' do
          skip(%{The following applications must be present: '#{missing_apps.join("', ")}'})
        end
      end
    end
  end
end
