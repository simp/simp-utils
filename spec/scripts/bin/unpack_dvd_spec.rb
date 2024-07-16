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
    File.expand_path('../../../scripts/bin/unpack_dvd', __dir__)
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
    'rpmbuild',
    'createrepo',
  ]
  require 'facter'
  missing_apps = required_apps.select{|x| !Facter::Core::Execution.which(x)}


  Dir.glob(File.join(__dir__, 'files', 'unpack_dvd', 'ISO', '*')).each do |target|
    next unless File.directory?(target)
    target_name = File.basename(target)

    context "when unpacking an ISO for #{target_name}" do
      before(:each) {
        working_dir = File.join(@tmpdir, target_name)
        @output_dir = File.join(working_dir,'output')
        @tftpboot_dir = File.join(working_dir,'tftpboot')
        FileUtils.mkdir_p([@output_dir, @tftpboot_dir])
      }
      after(:each) do
        FileUtils.remove_entry_secure(@output_dir) if File.directory?(@output_dir)
        FileUtils.remove_entry_secure(@tftpboot_dir) if File.directory?(@tftpboot_dir)
      end

      let(:os) { target_name.split('_').first }
      let(:os_version) { target_name.split('_').last }
      let(:os_version_xyz) { (os_version.split('.').size > 1) ? os_version : "#{os_version}.x.y" }
      let(:iso_path) { File.join(@tmpdir, "#{target_name}.iso") }
      let(:output_dir) { @output_dir }
      let(:tftpboot_dir) { @tftpboot_dir }
      let(:cmd){ "ruby '#{unpack_dvd}' -d '#{output_dir}' '#{iso_path}'" }

      unless missing_apps.empty?
        it 'runs unpack_dvd' do
          skip("The following executable(s) must be available to build the fixture ISO: '#{missing_apps.join("', ")}'")
        end
        break
      end

      it "builds a mock ISO to test #{target_name}" do
        Dir.chdir(target) do
          %x[#{mkisofs} -o #{iso_path} .]
          expect($?.exitstatus).to eq 0
        end
      end

      context 'when running unpack_dvd'  do
        before(:each) do
          Dir.chdir(target) do
            %x{#{cmd}}
          end
        end
        let!(:exit_status) do
          $?.exitstatus
        end

        context 'without -v' do
          if target_name.split('_').first == 'CentOS'
            it('fails (because CentOS ISOs only provide major OS versions)'){ expect(exit_status).to eq 1 }
          else
            it("executes without failures"){ expect(exit_status).to eq 0 }
          end
        end

        context 'with -v x.y.z' do
          let(:cmd){ "#{super()} -v #{os_version_xyz}" }

          it('executes without failures'){ expect(exit_status).to eq 0 }
          it 'creates a populated Updates/repodata' do
            glob = File.join(output_dir, os, os_version_xyz, '**', 'Updates', 'repodata', '*')
            expect( Dir.glob(glob).grep(/repomd\.xml$/)).not_to be_empty
          end

          it "symlinks yum repo [os_version] to [os_version_xyz]" do
            src = File.join(output_dir, os, os_version_xyz)
            symlink = File.join(output_dir, os, os_version)
            expect( File.readlink(symlink) ).to eql File.basename(src)
          end

          context 'with --unpack-pxe' do
            let(:cmd){ "#{super()} --unpack-pxe #{tftpboot_dir} --no-unpack-yum" }

            it('executes without failures'){ expect(exit_status).to eq 0 }
            it 'has a populated tftpboot directory' do
              glob = File.join(tftpboot_dir, "#{os.downcase}-#{os_version_xyz}-x86_64", '*')
              expect( Dir.glob(glob).grep(%r[/dummy\.img$])).not_to be_empty
            end
            it "symlinks tftpboot/centos-[os_version]-x86_64 to tftpboot/centos-[os_version_xyz]-x86_64" do
              src = File.join(tftpboot_dir, "#{os.downcase}-#{os_version_xyz}-x86_64")
              symlink = File.join(tftpboot_dir, "#{os.downcase}-#{os_version}-x86_64")
              expect( File.readlink(symlink) ).to eql File.basename(src)
            end

          end
        end
      end
    end
  end
end
