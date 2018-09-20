require 'spec_helper_acceptance'

# Repository helper methods stolen from simp-core/spec/spec_helper_rpm.rb
def set_up_repo(host)
  reponame = ENV['BEAKER_repo']
  reponame ||= '6_X'
  if reponame[0] == '/'
    copy_repo(host,reponame)
  else
    internet_simprepo(host, reponame)
  end
end

# Install the packagecloud yum repos
# See https://packagecloud.io/simp-project/ for the reponame key
def internet_simprepo(host, reponame)
  on(host, "curl -s https://packagecloud.io/install/repositories/simp-project/#{reponame}/script.rpm.sh | bash")
  on(host, "curl -s https://packagecloud.io/install/repositories/simp-project/#{reponame}_Dependencies/script.rpm.sh | bash")
end

def copy_repo(host,reponame)
  if File.exists?(reponame)
    scp_to(hosts,reponame,'/etc/yum.repos.d/simp_manual.repo')
  else
    fail("File #{reponame} could not be found")
  end
end

def repo_dir(repo)
  "/var/www/yum/#{repo}"
end

def set_up_local_repo(host, repo_name)
   repo_spec = <<EOM
[#{repo_name}-local-x86_64]
name=#{repo_name} local repo
baseurl=file://#{repo_dir(repo_name)}/x86_64
enabled=1
gpgcheck=0
EOM
   repo_file = File.join('/', 'etc','yum.repos.d', "#{repo_name}_local.repo")
   create_remote_file(host, repo_file, repo_spec)
end

shared_examples_for 'a YUM repo updater' do |host, repo, command|
  context "#{repo_dir(repo)} does not exist" do
    it "updaterepos should fail to update the #{repo} YUM repo" do
      on(host, command, :acceptable_exit_codes => [1])
    end
  end

  context "#{repo_dir(repo)} does exist" do
    it 'should set up local repositories' do
      set_up_local_repo(host, repo)
    end

    it "should set up #{repo_dir(repo)}" do
      on(host, "mkdir -p #{repo_dir(repo)}/noarch #{repo_dir(repo)}/x86_64")
      on(host, "cp /root/staging/noarch/* #{repo_dir(repo)}/noarch")
      on(host, "cp /root/staging/x86_64/* #{repo_dir(repo)}/x86_64")
    end

    it "updaterepos should update the #{repo} YUM repo" do
      on(host, command, :pty => true )
      on(host, 'yum makecache')
      (noarch_rpms + x86_64_rpms).each do |pkg|
        result = on(host, "yum provides -C #{pkg}")
        expect(result.stdout).to match(/^Repo\s*:\s*#{repo}\-local\-x86_64/)
      end
    end

    it 'updaterepos should provide links of noarch RPMs' do
      noarch_rpms.each do |pkg|
        info = on(host, "ls -al #{repo_dir(repo)}/x86_64/#{pkg}*.rpm").stdout.strip
        expect(info).to match(/lrwxrwxrwx.*\s+\->\s+\.\.\/noarch\/#{Regexp.escape(pkg)}/)
      end
    end

    it 'updaterepos should allow apache group access to repodata' do
      info = on(host, "ls -ld #{repo_dir(repo)}/x86_64/repodata").stdout.strip
      expect(info).to match(/^drwxr\-[xs].*root\s+apache/)
      info = on(host, "ls -l #{repo_dir(repo)}/x86_64/repodata/").stdout.strip
      info.split("\n").each do |file_info|
        next if file_info.match(/^total/)
        expect(file_info).to match(/^.rw.r\-..*root\s+apache/)
      end
    end

    it 'updaterepos should be safely re-run' do
      on(host, command, :pty => true )
    end
  end
end


test_name 'updaterepos unit test'

describe 'updaterepos unit test' do

  hosts.each do |host|
    let(:noarch_rpms) { [
      'pupmod-puppetlabs-stdlib',
      'pupmod-simp-simplib',
      'simp-adapter'
    ] }

    let(:x86_64_rpms) { [
      'sudosh2',
      'chkrootkit'
    ] }

    context 'setup' do
      it 'should set up common test files' do
        scp_to(host, 'scripts/sbin/updaterepos', '/root/updaterepos')
        on(host, 'chmod +x /root/updaterepos')
      end

      it 'should set up remote repositories' do
        host.install_package('epel-release')
        host.install_package('createrepo')
        host.install_package('yum-utils')
        host.install_package('httpd')
        set_up_repo(host)
        on(host, 'yum makecache')
      end

      it 'should download but not install packages' do
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

    context 'updaterepos operation' do

      context 'with no arguments' do
        it_behaves_like('a YUM repo updater', host, 'SIMP', '/root/updaterepos')
      end

      context 'with a directory command line argument' do
        it_behaves_like('a YUM repo updater', host, 'OTHER', '/root/updaterepos /var/www/yum/OTHER')
      end
    end
  end
end
