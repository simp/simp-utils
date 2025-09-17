require 'spec_helper_acceptance'

# This is a unit test that verifies the basic operation of
# gen-ldap-update with the system Ruby for each server in
# each node set.  The generated LDIF output was manually
# verified to work on a SIMP 6.2.0 system.
#
# TODO Would be best to integration test this with the simp_openldap
# module, as that module is responsible for configuring the LDAP server
# and generating the /etc/openldap/default.ldif file.
#
test_name 'gen-ldap-update unit test'

describe 'gen-ldap-update unit test' do
  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }

  let(:modify_ldif) { File.read(File.join(files_dir, 'modify.ldif')) }

  hosts.each do |host|
    context 'set up' do
      it 'sets up common test files' do
        scp_to(host, 'scripts/sbin/gen-ldap-update', '/root/gen-ldap-update')
        on(host, 'chmod +x /root/gen-ldap-update')

        on(host, 'mkdir -p /etc/openldap')
        scp_to(host, File.join(files_dir, 'default.ldif'), '/etc/openldap/default.ldif')
      end
    end

    context 'when /etc/openldap/ldap.conf is present' do
      it 'removes old ldap.conf files and install test /etc/openldap/ldap.conf' do
        on(host, 'rm -f /etc/ldap.conf /etc/openldap/ldap.conf')
        scp_to(host, File.join(files_dir, 'etc_openldap_ldap.conf'), '/etc/openldap/ldap.conf')
      end

      it 'generates ldap modify instructions for configured domain' do
        results = on(host, '/root/gen-ldap-update')
        expect(results.stdout).to eq modify_ldif
      end
    end

    context 'when /etc/ldap.conf is present' do
      it 'removes old ldap.conf files and install test /etc/ldap.conf' do
        on(host, 'rm -f /etc/ldap.conf /etc/openldap/ldap.conf')
        scp_to(host, File.join(files_dir, 'etc_ldap.conf'), '/etc/ldap.conf')
      end

      it 'generates ldap modify instructions for configured domain' do
        results = on(host, '/root/gen-ldap-update')
        expect(results.stdout).to eq modify_ldif
      end
    end

    context 'when host domain does not match default.ldif domain' do
      it 'removes old ldap.conf files and install /etc/openldap/ldap.conf with different domain' do
        on(host, 'rm -f /etc/ldap.conf /etc/openldap/ldap.conf')
        scp_to(host, File.join(files_dir, 'etc_openldap_ldap_other_domain.conf'), '/etc/openldap/ldap.conf')
      end

      it 'fails to generate ldap modify instructions' do
        on(host, '/root/gen-ldap-update', acceptable_exit_codes: [1])
      end
    end

    context 'when DNs of interest do not exist in default.ldif' do
      it 'restores test /etc/openldap/ldap.conf' do
        scp_to(host, File.join(files_dir, 'etc_openldap_ldap.conf'), '/etc/openldap/ldap.conf')
      end

      it 'installs test /etc/openldap/default.ldif missing DNs of interest' do
        scp_to(host, File.join(files_dir, 'incomplete_default.ldif'), '/etc/openldap/default.ldif')
      end

      it 'fails to generate ldap modify instructions' do
        on(host, '/root/gen-ldap-update', acceptable_exit_codes: [1])
      end
    end

    context 'when /etc/openldap/default.ldif is absent' do
      it 'removes default.ldif on hosts' do
        on(host, 'rm /etc/openldap/default.ldif')
      end

      it 'fails to generate ldap modify instructions' do
        on(host, '/root/gen-ldap-update', acceptable_exit_codes: [1])
      end
    end

    context 'when no ldap configuration is present' do
      let(:host_base_dn) do
        fact_on(host, 'networking.domain').split('.').map { |d| "dc=#{d}" }.join(',')
      end

      it 'removes old ldap.conf files' do
        on(host, 'rm -f /etc/ldap.conf /etc/openldap/ldap.conf')
      end

      it 'installs default.ldif with base_dn using host domain' do
        default_ldif_txt = File.read(File.join(files_dir, 'default.ldif'))
        default_ldif_txt.gsub!('dc=example,dc=com', host_base_dn)
        create_remote_file(host, '/etc/openldap/default.ldif', default_ldif_txt)
      end

      # FIXME: This is hack that wouldn't be necessary if gen-ldap-update used
      # the domain fact?
      it 'fixes hostname' do
        fqdn = fact_on(host, 'networking.fqdn').strip
        hostname = on(host, 'hostname').stdout.strip
        if fqdn != hostname
          on(host, "hostname #{fqdn}")
        end
      end

      it 'generates ldap modify instructions for host domain' do
        results = on(host, '/root/gen-ldap-update')
        expected = modify_ldif.gsub('dc=example,dc=com', host_base_dn)
        expect(results.stdout).to eq expected
      end
    end

    context 'restore for next test' do
      it 'removes mock system directories/files created for tests' do
        on(host, 'rm -rf /etc/ldap.conf /etc/openldap')
      end
    end
  end
end
