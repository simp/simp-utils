require 'spec_helper_acceptance'
describe 'OpenLDAP to 389DS convert and import scripts' do

  ldap_server = only_host_with_role(hosts, 'ldap_server')
  ldap_server_fqdn = fact_on(ldap_server, 'fqdn')

  let(:files_dir) { File.join(File.dirname(__FILE__), 'files', 'openldap_to_389ds') }
  let(:scripts_src) { 'share/transition_scripts/openldap_to_389ds' }
  let(:converter) { '/root/openldap_to_389ds.rb' }
  let(:importer) { '/root/import_to_389ds.sh' }
  let(:ldif_dir) { '/root/upgrade_ldifs' }
  let(:openldap_ldif) { "#{ldif_dir}/simp_openldap.ldif" }
  let(:malformed_openldap_ldif) { "#{ldif_dir}/malformed_simp_openldap.ldif" }
  let(:missing_domain_openldap_ldif) { "#{ldif_dir}/missing_domain_simp_openldap.ldif" }
  let(:ds389_ldif) { "#{ldif_dir}/simp_389ds.ldif" }

  let(:base_dn) { 'dc=test,dc=org' }


  # Notes:
  # - We tell the users to install simp-utils and rubygem-net-ldap packages
  #   on the EL8 server hosting 389DS, but they may try to run the converter
  #   script on the EL7 server hosting the OpenLDAP server. So, make sure it
  #   runs successfully on both.
  # - Have to explicitly run the converter with system Ruby
  #   - beaker ensures Puppet directories are in first in the path when
  #     executing commands on SUTs
  #   - rubygem-net-ldap installs into the Gem path for system Ruby
  #
  hosts.each do |host|
    context "Executing converter script on #{host}" do
      it 'should install net-ldap Ruby gem RPM from EPEL' do
        # This will install into system ruby
        host.install_package('rubygem-net-ldap')
      end

      it 'should install the converter script' do
        scp_to(host, "#{scripts_src}/#{File.basename(converter)}", converter)
        on(host, "chmod +x #{converter}")
      end

      it 'should install input data' do
        on(host, "mkdir -p #{ldif_dir}")
        scp_to(host, "#{files_dir}/#{File.basename(openldap_ldif)}", openldap_ldif)
        scp_to(host, "#{files_dir}/#{File.basename(malformed_openldap_ldif)}", malformed_openldap_ldif)
        scp_to(host, "#{files_dir}/#{File.basename(missing_domain_openldap_ldif)}", missing_domain_openldap_ldif)
      end

      it 'should print help' do
        on(host, 'echo $PATH')
        on(host, "/usr/bin/ruby #{converter} -h")
      end

      it 'should convert a valid input file using default options' do
        on(host, "cd #{ldif_dir}; /usr/bin/ruby #{converter}")
        output = on(host, "cat #{ds389_ldif}").stdout
        expect(output).to eq File.read(File.join(files_dir, 'simp_389ds.ldif'))
      end

      it 'should convert a valid input file using specified options' do
        infile = "#{ldif_dir}/myinput.ldif"
        outfile = "#{ldif_dir}/myoutput.ldif"
        on(host, "cp #{openldap_ldif} #{infile}")
        cmd = [
          '/usr/bin/ruby',
          converter,
          "-i #{infile}",
          "-o #{outfile}",
          "-b #{base_dn}"
        ].join(' ')
        on(host, cmd)
        output = on(host, "cat #{outfile}").stdout
        expect(output).to eq File.read(File.join(files_dir, 'simp_389ds.ldif'))
      end

      it 'should fail when the input file does not exist' do
        cmd = [
          '/usr/bin/ruby',
          converter,
          '-i /oops/simp_openldap.ldif',
          '-o oops_simp_389ds.ldif',
          "-b #{base_dn}"
        ].join(' ')
        on(host, cmd, :acceptable_exit_codes => [1])
      end

      it 'should fail when the input file does not contain valid LDIF data' do
        cmd = [
          '/usr/bin/ruby',
          converter,
          "-i #{malformed_openldap_ldif}",
          '-o malformed_389ds.ldif',
          "-b #{base_dn}"
        ].join(' ')
        on(host, cmd, :acceptable_exit_codes => [1])
      end

      it 'should fail when base DN is not specified and cannot be determined from input LDIF' do
        cmd = [
          '/usr/bin/ruby',
          converter,
          "-i #{missing_domain_openldap_ldif}",
          '-o missing_domain_389ds.ldif'
        ].join(' ')
        on(host, cmd, :acceptable_exit_codes => [1])
      end

      it 'should fail when the output file cannot be created' do
        cmd = [
          '/usr/bin/ruby',
          converter,
          "-i #{openldap_ldif}",
          '-o /does/not/exist/dir/simp_d389ds.ldif',
        ].join(' ')
        on(host, cmd, :acceptable_exit_codes => [1])
      end

      it 'should fail when the input file has no users or groups for base DN' do
        cmd = [
          '/usr/bin/ruby',
          converter,
          "-i #{openldap_ldif}",
          # specify a domain that does not match what is in the input file
          '-b dc=some,dc=other,dc=org'
        ].join(' ')
        on(host, cmd, :acceptable_exit_codes => [1])
      end
    end
  end

  context "Executing importer script on #{ldap_server}" do
    let(:ds_root_name) { 'accounts' }
    let(:hieradata) { {
      'simp_options::firewall'                   => false,
      'simp_options::trusted_nets'               => ['any'],
      'simp_options::pki'                        => true,
      'simp_options::pki::source'                => '/etc/pki/simp-testing/pki',
      'pki::private_key_source'                  => '/etc/pki/simp-testing/pki/private/%{facts.fqdn}.pem',
      'pki::public_key_source'                   => '/etc/pki/simp-testing/pki/public/%{facts.fqdn}.pub',
      'pki::cacerts_sources'                     => [ '/etc/pki/simp-testing/pki/cacerts'],
      'simp_options::ldap'                       => true,
      'simp_options::ldap::uri'                  => [ "ldaps://#{ldap_server_fqdn}" ],
      'simp_options::ldap::base_dn'              =>  base_dn,
      'simp_options::ldap::bind_dn'              =>  "cn=hostAuth,ou=Hosts,#{base_dn}",
      'simp_options::ldap::bind_pw'              => 'foobarbaz',
      'simp_options::ldap::bind_hash'            => '{SSHA}BNPDR0qqE6HyLTSlg13T0e/+yZnSgYQz',
      'simp_options::ldap::master'               =>  "ldaps://#{ldap_server_fqdn}",
      'simp_options::ldap::root_dn'              => "cn=LDAPAdmin,ou=People,#{base_dn}",
      'simp_ds389::instances::accounts::root_pw' => 'suP3rP@ssw0r!'
    } }

    let(:remove_ldap_server_manifest)  {
      "ds389::instance { 'accounts': ensure => 'absent' }"
    }

    let(:install_ldap_server_manifest) {
      "include 'simp_ds389::instances::accounts'"
    }

    shared_examples_for 'an accounts 389DS instance installer' do
      it 'should ensure hieradata is appropriately set' do
        set_hieradata_on(ldap_server, hieradata)
      end

      it 'should ensure any existing accounts instance is removed' do
        apply_manifest_on(ldap_server, remove_ldap_server_manifest, catch_failures: true)
      end

      it 'should apply simp_ds389::accounts::instance with no errors' do
        apply_manifest_on(ldap_server, install_ldap_server_manifest, catch_failures: true)
        apply_manifest_on(ldap_server, install_ldap_server_manifest, catch_changes: true)
      end
    end

    shared_examples_for 'a LDAP import validator' do
      it 'should create a searchable LDAP tree' do
        # Just verifying a standard ldapsearch from the top of the tree doesn't
        # fail. This output is also helpful for debug.
        on(ldap_server, 'ldapsearch -Y EXTERNAL -H ldapi://%2fvar%2frun%2fslapd-accounts.socket')
      end

      it 'should import groups' do
        group_list = on(ldap_server, "dsidm accounts -b #{base_dn} posixgroup list").stdout
        [
          'NotAllowed',
          'admin1',
          'admin2',
          'administrators',
          'auditor1',
          'baduser',
          'security',
          'testgroup',
          'user1',
          'user2',
          'users',
        ].each do |group|
          expect(group_list).to include(group)
        end
      end

      it 'should import users' do
        user_list = on(ldap_server, "dsidm accounts -b #{base_dn} user list").stdout
        [
          'admin1',   # in admin1, administrators, and users groups
          'admin2',   # in admin2, administrators, and users groups
          'auditor1', # in auditor1, security group
          'baduser',  # in baduser, NotAllowed group
          'user1',    # in user1, testuser and users group
          'user2',    # in user1, testuser and users group
        ].each do |user|
          expect(user_list).to include(user)
        end
      end

      it 'should add members to groups' do
        {
          'NotAllowed' => [
            "member: uid=baduser,ou=Groups,#{base_dn}"
          ],
          'administrators' => [
            "member: uid=admin1,ou=Groups,#{base_dn}",
            "member: uid=admin2,ou=Groups,#{base_dn}"
          ],
          'security' => [
            "member: uid=auditor1,ou=Groups,#{base_dn}"
          ],
          'testgroup' => [
            "member: uid=user1,ou=Groups,#{base_dn}",
            "member: uid=user2,ou=Groups,#{base_dn}"
          ],
          'users' => [
            "member: uid=admin1,ou=Groups,#{base_dn}",
            "member: uid=admin2,ou=Groups,#{base_dn}",
            "member: uid=user1,ou=Groups,#{base_dn}",
            "member: uid=user2,ou=Groups,#{base_dn}"
          ]
        }.each do |group,member_attrs|
          group_ldif = on(ldap_server, "dsidm accounts -b #{base_dn} posixgroup get #{group}").stdout
          member_attrs.each do |member_attr|
            expect(group_ldif).to match(%r{^#{member_attr}$})
          end
        end
      end
    end

    context 'import script install' do
      it 'should install import script' do
        scp_to(ldap_server, "#{scripts_src}/#{File.basename(importer)}", importer)
        on(ldap_server, "chmod +x #{importer}")
      end
    end

    # usecase that matches the README.md
    context 'import into a base accounts instance using specified input file' do
      include_examples 'an accounts 389DS instance installer'

      it 'should execute without error using specified LDIF file' do
        on(ldap_server, "#{importer} #{ds389_ldif}")
      end

      include_examples 'a LDAP import validator'
    end

    context 'import into a base accounts instance using default input file' do
      include_examples 'an accounts 389DS instance installer'

      it 'should execute without error using default LDIF file' do
        on(ldap_server, "cd #{ldif_dir}; #{importer}")
      end

      include_examples 'a LDAP import validator'
    end

    context 'import failures' do
      it 'should fail if the input file does not exist' do
        missing_ldif = '/does/not/exist/simp_ds389.ldif'
        result = on(ldap_server, "#{importer} #{missing_ldif}", :acceptable_exit_codes => [1])
        expect(result.stdout).to match(%r{File '#{missing_ldif}' does not exist})
      end

      it 'should fail if there are no People or Groups in the LDIF to import' do
        empty_ldif = "#{ldif_dir}/empty_simp_ds389.ldif"
        on(ldap_server, "touch #{empty_ldif}")
        result = on(ldap_server, "#{importer} #{empty_ldif}", :acceptable_exit_codes => [1])
        expect(result.stdout).to match('Could not find any People or Groups')
      end

      it 'should fail to import into an accounts instance with non-empty users or administrators groups' do
        # this test **assumes** the account instance is up and had populated the
        # users and/or administrators groups via a previous, successful import
        on(ldap_server, "#{importer} #{ds389_ldif}", :acceptable_exit_codes => [1])
      end

      it 'should fail if the accounts 389ds instance does not exist' do
        apply_manifest_on(ldap_server, remove_ldap_server_manifest, catch_failures: true)
        result = on(ldap_server, "#{importer} #{ds389_ldif}", :acceptable_exit_codes => [1])
      end

      it 'should fail if it cannot find the dsidm command' do
        # dsidm is in /usr/sbin
        result = on(ldap_server, "PATH=/usr/bin #{importer} #{ds389_ldif}", :acceptable_exit_codes => [1])
      end
    end
  end
end
