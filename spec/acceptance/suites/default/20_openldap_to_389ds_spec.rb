require 'spec_helper_acceptance'
describe 'OpenLDAP to 389ds scripts' do

  ldap_server = only_host_with_role(hosts, 'ldap_server')
  ldap_server_fqdn = fact_on(ldap_server, 'fqdn')

  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }
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

    context 'simp_ds389::accounts::instance set up' do
      it 'works with no errors' do
        set_hieradata_on(ldap_server, hieradata)
        apply_manifest_on(ldap_server, install_ldap_server_manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(ldap_server, install_ldap_server_manifest, catch_changes: true)
      end
    end

    context 'import into simp_ds389::accounts::instance' do
      it 'should install import script' do
        scp_to(ldap_server, "#{scripts_src}/#{File.basename(importer)}", importer)
        on(ldap_server, "chmod +x #{importer}")
      end

      it 'should import users and groups into an empty accounts instance using specified LDIF file' do
        on(ldap_server, "#{importer} #{ds389_ldif}")

        # list the whole tree for debug
        on(ldap_server, 'ldapsearch -Y EXTERNAL -H ldapi://%2fvar%2frun%2fslapd-accounts.socket')

        user_list = on(ldap_server, "dsidm accounts -b #{base_dn} user list").stdout
        group_list = on(ldap_server, "dsidm accounts -b #{base_dn} group list").stdout

        [
          'admin1',   # in admin1 group
          'admin2',   # in admin2 group
          'auditor1', # in security group
          'baduser',  # in NotAllowed group
          'user1',    # in testuser group
          'user2',    # in testuser group
        ].each do |user|
          expect(user_list).to include(user)
        end

        [
          'NotAllowed',
          'admin1',
          'admin2',
          'administrators',
          'security',
          'testgroup',
          'users',
        ].each do |group|
          expect(group_list).to include(group)
        end

        # TODO make sure users have correct groups set
      end

      it 'should import users and groups into an empty accounts instance using default LDIF file'
      it 'should fail if the input file does not exist'
      it 'should fail if there are no People or Groups in the LDIF to import'
      it 'should fail to import into an accounts instance with non-empty administrators group'
      it 'should fail to import into an accounts instance with non-empty users group'
      it 'should fail if the accounts 389ds instance does not exist'
      it 'should fail if it cannot find the dsidm command'
    end
  end
end
