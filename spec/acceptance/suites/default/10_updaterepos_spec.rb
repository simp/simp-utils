require 'spec_helper_acceptance'

# Repository helper methods stolen from simp-core/spec/acceptance/helpers/repo_helper.rb

# Install a yum repo
#
# +host+: Host object on which the yum repo will be installed
# +repo_filename+: Path of the repo file to be installed
#
# @fails if the specified repo file cannot be installed on host
def copy_repo(_host, repo_filename, repo_name = 'simp_manual.repo')
  raise("File #{repo_filename} could not be found") unless File.exist?(repo_filename)
  puts('=' * 72)
  puts("Using repos defined in #{repo_filename}")
  puts('=' * 72)
  scp_to(hosts, repo_filename, "/etc/yum.repos.d/#{repo_name}")
end

# Set up SIMP repos on the host
#
# By default, the latest SIMP repos available online will be configured.  This
# can be overidden with the BEAKER_repo environment variable, when BEAKER_repo
# is set to a fully qualified path of a repo file.
#
# +host+: Host object on which SIMP repo(s) will be installed
# +set_up_simp_main+:  Whether to set up the main SIMP repo
#                      (simp-community-simp)
# +set_up_simp_deps+:  Whether to set up the SIMP dependencies repos
#                      ( simp-community_epel, simp_community_puppet, and
#                      simp-community-postgresql)
#
# @fails if the specified repos cannot be installed on host
def set_up_simp_repos(host, set_up_simp_main = true, set_up_simp_deps = true)
  reponame = ENV['BEAKER_repo']
  if reponame && (reponame[0] == '/')
    copy_repo(host, reponame)
  else
    disable_list = []
    unless set_up_simp_main
      disable_list << 'simp-community-simp'
    end

    unless set_up_simp_deps
      disable_list << 'simp-community-epel'
      disable_list << 'simp-community-puppet'
      disable_list << 'simp-community-postgresql'
    end

    install_simp_repos(host, disable_list)
  end
end

def repo_dir(repo)
  "/var/www/yum/#{repo}"
end

def set_up_local_repo(host, repo_name)
  repo_spec = <<~EOM
    [#{repo_name}-local-x86_64]
    name=#{repo_name} local repo
    baseurl=file://#{repo_dir(repo_name)}/x86_64
    enabled=1
    gpgcheck=0
  EOM
  repo_file = File.join('/', 'etc', 'yum.repos.d', "#{repo_name}_local.repo")
  create_remote_file(host, repo_file, repo_spec)
end

shared_examples_for 'a YUM repo updater' do |host, repo, command|
  context "#{repo_dir(repo)} does not exist" do
    it "updaterepos should fail to update the #{repo} YUM repo" do
      on(host, command, acceptable_exit_codes: [1])
    end
  end

  context "#{repo_dir(repo)} does exist" do
    it 'sets up local repositories' do
      set_up_local_repo(host, repo)
    end

    it "sets up #{repo_dir(repo)}" do
      on(host, "mkdir -p #{repo_dir(repo)}/noarch #{repo_dir(repo)}/x86_64")
      on(host, "cp /root/staging/noarch/* #{repo_dir(repo)}/noarch")
      on(host, "cp /root/staging/x86_64/* #{repo_dir(repo)}/x86_64")
    end

    it "updaterepos should update the #{repo} YUM repo" do
      on(host, command, pty: true)
      on(host, 'yum makecache')
      (noarch_rpms + x86_64_rpms).each do |pkg|
        result = on(host, "yum provides -C #{pkg}")
        expect(result.stdout).to match(%r{^Repo\s*:\s*#{repo}\-local\-x86_64})
      end
    end

    it 'updaterepos should provide links of noarch RPMs' do
      noarch_rpms.each do |pkg|
        info = on(host, "ls -al #{repo_dir(repo)}/x86_64/#{pkg}*.rpm").stdout.strip
        expect(info).to match(%r{lrwxrwxrwx.*\s+\->\s+\.\./noarch/#{Regexp.escape(pkg)}})
      end
    end

    it 'updaterepos should allow apache group access to repodata' do
      info = on(host, "ls -ld #{repo_dir(repo)}/x86_64/repodata").stdout.strip
      expect(info).to match(%r{^drwxr\-[xs].*root\s+apache})
      info = on(host, "ls -l #{repo_dir(repo)}/x86_64/repodata/").stdout.strip
      info.split("\n").each do |file_info|
        next if file_info.match?(%r{^total})
        expect(file_info).to match(%r{^.rw.r\-..*root\s+apache})
      end
    end

    it 'updaterepos should allow apache group access to directories and files' do
      info = on(host, "ls -ld #{repo_dir(repo)}/x86_64").stdout.strip
      expect(info).to match(%r{^drwxr\-[xs].*root\s+apache})
      info = on(host, "ls -l #{repo_dir(repo)}/x86_64/").stdout.strip
      info.split("\n").each do |file_info|
        next if file_info.match?(%r{^total})
        expect(file_info).to match(%r{^.rw.r..*root\s+apache})
      end
    end

    it 'updaterepos should be safely re-run' do
      on(host, command, pty: true)
    end
  end
end

test_name 'updaterepos unit test'

describe 'updaterepos unit test' do
  hosts.each do |host|
    os_major = fact_on(host, 'os.release.major')
    if os_major == '8'
      puts 'SKIPPING test because SIMP repositories for EL8 are not set up: SIMP-9143'
      next
    end

    let(:noarch_rpms) do
      [
        'pupmod-puppetlabs-stdlib',
        'pupmod-simp-simplib',
        'simp-adapter',
      ]
    end

    let(:x86_64_rpms) do
      [
        'sudosh2',
        'chkrootkit',
      ]
    end

    context "setup on #{host}" do
      it 'sets up common test files' do
        scp_to(host, 'scripts/sbin/updaterepos', '/root/updaterepos')
        on(host, 'chmod +x /root/updaterepos')
      end

      it 'sets up remote repositories' do
        enable_epel_on(host)
        set_up_simp_repos(host)
        host.install_package('createrepo_c')
        host.install_package('yum-utils')
        host.install_package('httpd')
        on(host, 'yum makecache')
      end

      it 'downloads but not install packages' do
        on(host, 'mkdir -p /root/staging/noarch')
        noarch_rpms.each do |pkg|
          on(host, "cd /root/staging/noarch; yumdownloader #{pkg}")
        end

        on(host, 'mkdir -p /root/staging/x86_64')
        x86_64_rpms.each do |pkg|
          on(host, "cd /root/staging/x86_64; yumdownloader #{pkg}")
        end
      end
    end

    context "updaterepos operation on #{host}" do
      context 'with no arguments' do
        it_behaves_like('a YUM repo updater', host, 'SIMP', '/root/updaterepos')
      end

      context 'with a directory command line argument' do
        it_behaves_like('a YUM repo updater', host, 'OTHER', '/root/updaterepos /var/www/yum/OTHER')
      end
    end
  end
end
