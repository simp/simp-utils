require 'spec_helper_acceptance'

# Repository helper methods stolen from simp-core/spec/acceptance/helpers/repo_helper.rb

# Install a yum repo
#
# +host+: Host object on which the yum repo will be installed
# +repo_filename+: Path of the repo file to be installed
#
# @fails if the specified repo file cannot be installed on host
def copy_repo(host, repo_filename, repo_name = 'simp_manual.repo')
  if File.exists?(repo_filename)
    puts('='*72)
    puts("Using repos defined in #{repo_filename}")
    puts('='*72)
    scp_to(hosts, repo_filename, "/etc/yum.repos.d/#{repo_name}")
  else
    fail("File #{repo_filename} could not be found")
  end
end

# Install a SIMP packagecloud yum repo
#
# - Each repo is modeled after what appears in simp-doc
# - See https://packagecloud.io/simp-project/ for the reponame key
#
# +host+: Host object on which SIMP repo(s) will be installed
# +reponame+: The base name of the repo, e.g. '6_X'
# +type+: Which repo to install:
#   :main for the main repo containing SIMP puppet modules
#   :deps for the SIMP dependency repo containing OS or application
#         RPMs not available from standard CentOS repos
#
# @fails if the specified repo cannot be installed on host
def install_internet_simp_repo(host, reponame, type)
  case type
  when :main
    full_reponame = reponame
    # FIXME: Use a gpgkey list appropriate for more than 6_X
    repo = <<~EOM
      [simp-project_#{reponame}]
      name=simp-project_#{reponame}
      baseurl=https://packagecloud.io/simp-project/#{reponame}/el/$releasever/$basearch
      gpgcheck=1
      enabled=1
      gpgkey=https://raw.githubusercontent.com/NationalSecurityAgency/SIMP/master/GPGKEYS/RPM-GPG-KEY-SIMP
             https://download.simp-project.com/simp/GPGKEYS/RPM-GPG-KEY-SIMP-6
      sslverify=1
      sslcacert=/etc/pki/tls/certs/ca-bundle.crt
      metadata_expire=300
    EOM
  when :deps
    full_reponame = "#{reponame}_Dependencies"
    # FIXME: Use a gpgkey list appropriate for more than 6_X
    repo = <<~EOM
      [simp-project_#{reponame}_dependencies]
      name=simp-project_#{reponame}_dependencies
      baseurl=https://packagecloud.io/simp-project/#{reponame}_Dependencies/el/$releasever/$basearch
      gpgcheck=1
      enabled=1
      gpgkey=https://raw.githubusercontent.com/NationalSecurityAgency/SIMP/master/GPGKEYS/RPM-GPG-KEY-SIMP
             https://download.simp-project.com/simp/GPGKEYS/RPM-GPG-KEY-SIMP-6
             https://yum.puppet.com/RPM-GPG-KEY-puppetlabs
             https://yum.puppet.com/RPM-GPG-KEY-puppet
             https://apt.postgresql.org/pub/repos/yum/RPM-GPG-KEY-PGDG-96
             https://artifacts.elastic.co/GPG-KEY-elasticsearch
             https://grafanarel.s3.amazonaws.com/RPM-GPG-KEY-grafana
             https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-$releasever
      sslverify=1
      sslcacert=/etc/pki/tls/certs/ca-bundle.crt
      metadata_expire=300
    EOM
    full_reponame = "#{reponame}_Dependencies"
  else
    fail("install_internet_simp_repo() Unknown repo type specified '#{type.to_s}'")
  end
  puts('='*72)
  puts("Using SIMP #{full_reponame} Internet repo from packagecloud")
  puts('='*72)

  create_remote_file(host, "/etc/yum.repos.d/simp-project_#{full_reponame.downcase}.repo", repo)
end

# Set up SIMP repos on the host
#
# By default, the SIMP '6_X' repos available from packagecloud
# will be configured.  This can be overidden with the BEAKER_repo
# environment variable as follows:
# - When set to a fully qualified path of a repo file, the file will
#   be installed as a repo on the host.  In this case set_up_simp_main
#   and set_up_simp_deps are both ignored, as the repo file is assumed
#   to be configured appropriately.
# - Otherwise, BEAKER_repo is assumed to be the base name of the SIMP
#   internet repos (e.g., '6_X_Alpha')
#
# +host+: Host object on which SIMP repo(s) will be installed
# +set_up_simp_main+:  Whether to set up the main SIMP repo
# +set_up_simp_deps+:  Whether to set up the SIMP dependencies repo
#
# @fails if the specified repos cannot be installed on host
def set_up_simp_repos(host, set_up_simp_main = true, set_up_simp_deps = true )
  reponame = ENV['BEAKER_repo']
  reponame ||= '6_X'
  if reponame[0] == '/'
    copy_repo(host, reponame)
  else
    install_internet_simp_repo(host, reponame, :main) if set_up_simp_main
    install_internet_simp_repo(host, reponame, :deps) if set_up_simp_deps
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

    it 'updaterepos should allow apache group access to directories and files' do
      info = on(host, "ls -ld #{repo_dir(repo)}/x86_64").stdout.strip
      expect(info).to match(/^drwxr\-[xs].*root\s+apache/)
      info = on(host, "ls -l #{repo_dir(repo)}/x86_64/").stdout.strip
      info.split("\n").each do |file_info|
        next if file_info.match(/^total/)
        expect(file_info).to match(/^.rw.r..*root\s+apache/)
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
        set_up_simp_repos(host)
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
