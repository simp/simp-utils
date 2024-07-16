%{lua:
--
-- When building the RPM, declare macro 'pup_module_info_dir' with the path to
-- the top-level project directory.  This directory should contain the
-- following items:
--   * 'build' directory
--   * 'README.md' file
--
package_release = '1'
local potential_src_dirs = {
  rpm.expand('%{pup_module_info_dir}'),
  rpm.expand('%{_sourcedir}'),
  posix.getcwd(),
}
local src_dir = "\0"

for _k,dir in pairs(potential_src_dirs) do
  if (posix.stat(dir .. '/build', 'type') == 'directory') and (posix.stat(dir .. '/README.md', 'type') == 'regular') then
    src_dir = dir
    break
  end
end

if src_dir == "\0" then
  error(
    "FATAL: Cannot determine RPM project's src_dir!\n" ..
    "\t* Paths tried: '" .. table.concat(potential_src_dirs, "', '") .."\n" ..
    "\t* PROTIP: Declare macro %pup_module_info_dir\n"
  )
end

-- Snag the RPM-specific items out of the 'build/rpm_metadata' directory
rel_file = (io.open(src_dir .. "/build/rpm_metadata/release", "r") or io.open(src_dir .. "/release", "r"))
if rel_file then
  for line in rel_file:lines() do
    if not (line:match("^%s*#") or line:match("^%s*$")) then
      package_release = line
      break
    end
  end
end
}

Summary: SIMP Utils
Name: simp-utils
Version: 6.8.0
Release: %{lua: print(package_release)}%{?dist}
License: Apache License, Version 2.0
Group: Applications/System
Source: %{name}-%{version}-%{release}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
%if 0%{?rhel} > 7
Recommends: puppet-agent >= 6
Recommends: genisoimage
Recommends: rpm
Recommends: yum
Recommends: yum-utils
%else
Requires: puppet-agent >= 6
Requires: genisoimage
Requires: rpm
Requires: yum
Requires: yum-utils
%endif
Provides: simp_utils
Obsoletes: simp_utils
BuildArch: noarch

%description
Useful scripts for dealing with a Puppet environment.

%prep
%setup -q

%build

%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

# Make your directories here.
mkdir -p %{buildroot}/usr/share/simp/ldifs
mkdir -p %{buildroot}/usr/share/simp/ks
mkdir -p %{buildroot}/usr/local/bin
mkdir -p %{buildroot}/usr/local/sbin

# Now install the files.
cp -r share/* %{buildroot}/usr/share/simp
cp -r scripts/* %{buildroot}/usr/local

chmod -R u=rwx,g=rx,o=rx %{buildroot}/usr/local/*bin

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(-,root,root)
/usr/local/bin/set_environment
/usr/local/bin/unpack_dvd
/usr/local/sbin/gen-ldap-update
/usr/local/sbin/puppetlast
/usr/local/sbin/simpenv
/usr/local/sbin/updaterepos
/usr/share/simp
%attr(0755,-,-) /usr/share/simp/ks/CentOS/repodetect.sh
%attr(0755,-,-) /usr/share/simp/ks/CentOS/7/diskdetect.sh
%attr(0755,-,-) /usr/share/simp/ks/CentOS/8/diskdetect.sh
%attr(0750,-,-) /usr/share/simp/transition_scripts/openldap_to_389ds/openldap_to_389ds.rb
%attr(0750,-,-) /usr/share/simp/transition_scripts/openldap_to_389ds/import_to_389ds.sh
%post
# Post installation stuff

%postun
# Post uninstall stuff

%changelog
* Tue Jul 16 2024 Steven Pritchard <steve@sicura.us> - 6.8.0-1
- Updates for Puppet 8
    - Various fixes for Ruby 3 compatibility
    - Fix use of legacy facts
    - Use Ruby 2.7 (Puppet 7) for GHA tests by default
    - Add Ruby 3.2/Puppet 8 to GHA test matrix

* Thu Oct 28 2021 Liz Nemsick <lnemsick.simp@gmail.com> - 6.7.2-1
-  EL8 client kickstart config fixes:
   - Removed krb5-workstation and subversion from the list of required packages
   - Added the following lines to enable modular repos required by the kickstart
     module --name=python36 --stream-3.6
     module --name=perl --stream=5.26
     module --name=perl-IO-Socket-SSL --stream=2.066
     module --name=perl-libwww-perl --stream=6.34

* Fri Oct 22 2021 Liz Nemsick <lnemsick.simp@gmail.com> - 6.7.1-1
- Fixed a bug in unpack_dvd error handling that prevented the correct
  error message from being emitted, when unpack_dvd detected the old
  SIMP yum layout.
- Adjusted the puppet-agent requirement to >= 6.
- Updated kickstart files in the share directory.

* Wed Sep 29 2021 Trevor Vaughan <tvaughan@onyxpoint.com> - 6.7.0-1
- Fixed dependencies for EL8 systems
- Updated unpack_dvd to handle the new SIMP ISO layout and not break the
  exported repos
- Fixed a bug where a symlink would be created in a versioned ISO directory if
  it was present as a directory instead of a symlink to be replaced
- Updated the kickstart files in the share directory

* Wed Sep 01 2021 Trevor Vaughan <tvaughan@onyxpoint.com> - 6.6.1-1
- Fixed the puppetlast script and enabled it to read from filesystem reports.

* Fri Jul 23 2021 Jeanne Greulich <jeanne.greulichr@onyxpoint.com> - 6.6.0-1
- Added transition scripts useful for upgrading from SIMP 6.5.0 to SIMP 6.6.0.

* Thu Apr 29 2021 Jeanne Greulich <jeanne.greulichr@onyxpoint.com> - 6.6.0-1
- Update unpack DVD to extract the SIMP repo into
  <destination dir>/SIMP/<os family>/<os version>/ and create the link
  to the major version if it is requested.

* Mon Mar 01 2021 Liz Nemsick <lnemsick.simp@gmail.com> - 6.6.0-1
- Changed shebang in convert_to_inetorg.rb to use Puppet's Ruby instead
  of system Ruby.
- Removed upgrade_simp_6.0.0_to_6.1.0 script
- Added a comment to the sample EL8 kickstart file to describe changes
  needed if booting in UEFI mode.
- Increased the minimum puppet-agent version required to 6.22.1.

* Mon Nov 23 2020 Jeanne Greulich <jeanne.greulichr@onyxpoint.com> - 6.5.0-0
- Added sample kickstart files to /usr/share/simp to allow users to have access
  all versions of the kickstart files.

* Wed Oct 21 2020 Chris Tessmer <chris.tessmer@onyxpoint.com> - 6.4.0-0
- Added check for dangerously unspecific OS versions in `unpack_dvd`
  (e.g., '7' instead of '7.0.2003').  This is common when autodetecting the OS
  version from the ISO's .treeinfo on some OSes (particularly CentOS).
  - When detected, script will exit with an informative message + instructions.
  - In this case, users should provide a more specific version with `-v`.
  - Users can explicitly specify an unspecific version with `-v`.

* Tue Oct 13 2020 Chris Tessmer <chris.tessmer@onyxpoint.com> - 6.3.0-0
- Added (optional) `--unpack-pxe [DIR]` option to the `unpack_dvd` script
  - Added (optional) `--environment ENV` to set the PXE rsync environment
  - Added a new `--[no-]unpack-yum` (enabled by default), to permit users to
    disable the RPM unpack
  - To enable unpacking PXE tftpboot files, run with `--unpack-pxe`
  - To disable unpacking RPMs/yum repos, run with `--no-unpack-yum`
  - See `unpack_dvd --help` for details
- Overhauled `unpack_dvd --help`; output now fits on 80-character PTY consoles

* Thu Jul 23 2020 Trevor Vaughan <tvaughan@onyxpoint.com> - 6.2.3-0
- Add spec tests for unpack_dvd
- Fix minor bugs identified unpack_dvd during testing

* Wed Jun 12 2019 Jeanne Greulich <jeanne.greulich@onyxpoint.com> - 6.2.2-0
- Update updaterepo script to change permissions on the repo
   files as well as repodata.
- Update unpack_dvd script
  - Make sure permissions on all directories containing RPMs for the
    repo are correct.
  - Only attempt to change ownership of files if run as root.
  - Put `noarch` rpms under the `noarch` directory for the SIMP repo.
  - Allow the user to specify the version directory for the OS, because
    the CentOS `.treeinfo` file only contains the major OS version number.
  - Added an option to allow user to not link the extracted files to the
    major version.
  - Added an option to change what group is used to own the files.
  - Used puppet ruby instead of system ruby and removed Ruby 1.9 logic
    and changed puppet-agent dependency to > 5.0
- Updated the README

* Mon Jun 03 2019 Liz Nemsick <lnemsick.simp@gmail.com> - 6.2.2-0
- Update the path of SIMP's Puppet skeleton to
  /usr/share/simp/environment-skeleton/puppet. This is the correct
  path for simp-environment-skeleton >= 7.1.0.

* Thu May 16 2019 Jeanne Greulich <jeanne.greulich@onyxpoint.com> - 6.2.1-0
- Fixed error so simpenv script  would work on EL6 also.

* Thu May 02 2019 Jeanne Greulich <jeanne.greulich@onyxpoint.com> - 6.2.0-0
- Added simpenv script which creates SIMP environments for SIMP 6.4
  or later.

* Thu Sep 20 2018 Liz Nemsick <lnemsick.simp@gmail.com> - 6.1.2-0
- Fixed bug in which updaterepos would fail when executed with Ruby 1.8.x
  (e.g on CentOS 6 servers)
- Fixed bug in which gen-ldap-update generated malformed ldif
  output when executed with Ruby 2.x (e.g on CentOS 7 servers)

* Mon Nov 27 2017 Nick Markowski <nicholas.markowski@onyxpoint.com> - 6.1.1-0
- Sample LDIFS recommend UID/GID above 1000

* Wed Oct 18 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 6.1.0-0
- Added script to upgrade SIMP 6.0.0 to SIMP 6.1.0
- Removed obsolete scripts
  - hiera_config
  - hiera_upgrade
  - migrate_to_simplib

* Wed Oct 04 2017 Trevor Vaughan <tvaughan@onyxpoint.com> - 6.0.4-0
- Fixed an incorrect dependency on /bin/ruby as opposed to /usr/bin/ruby
- Changed all instances of #!/usr/bin/env ruby to #!/usr/bin/ruby per the
  Fedora packaging guidelines

* Tue Oct 03 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 6.0.3-0
- Fixed bug in which puppetlast sort options were not working.

* Tue Oct 03 2017 Jeanne Greulich <jeanne.greulich@onyxpoint.com> - 6.0.2-0
- added example ldifs to be copied to /usr/share/simp
- changed rake and gemfiles so pkg:rpm would work

* Tue Sep 19 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 6.0.2-0
- Add set_environment node classifier.  Can be used as a simple,
  YAML-based ENC.

* Tue Nov 08 2016 Nick Miller <nick.miller@onyxpoint.com> - 6.0.1-0
- Simp-utils is now its own module
- Added travis file to run tests

* Tue Nov 08 2016 Nick Miller <nick.miller@onyxpoint.com> - 6.0.0-0
- puppetlast:
  - Now uses the new PuppetDB nodes endpoint over http
  - Gathers new information about the nodes, which can be now be sorted and
    isolated by status and environment
  - Expired nodes will no longer show up in the query
  - Errors and exit scenarios will now be handled more gracefully
  - Removed man page in favor of `puppetlast -h`

* Wed Oct 26 2016 Nick Miller <nick.miller@onyxpoint.com> - 5.0.1-2
- Removed the pssh dependency.
- Updated the Puppet dependency to require Puppet 4.

* Thu Aug 25 2016 Liz Nemsick <lnemsick.simp@gmail.com> - 5.0.1-1
- Removed man pages for simp utility, as simp command line provides
  up-to-date usage.

* Thu Nov 05 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-8
- Added a 'hiera_upgrade' script that moves away from the SIMP patched one to
  the use of the 'alias' function.

* Tue Apr 28 2015 Nick Markowski <nmarkowski@keywcorp.com> - 5.0.0-7
- Removed old simp config from site_ruby.

* Wed Apr 01 2015 Nick Markowski <nmarkowski@keywcorp.com> - 5.0.0-6
- Simp bootstrap ensures the puppetserver service is running before
  running puppet.

* Tue Feb 17 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-5
- Updated the simp 'config' and 'bootstrap' commands to properly ahndle the new
  Puppet server and environments.
- Removed the requirement on puppet-server
- Added script 'upgrade_to_puppetserver' to assist in upgrading from a
  pre-puppetserver system to the new Clojure-based puppet server.
- Added script 'migrate_to_environments' to assist in migrating a legacy system
  to an environment-based one.

* Thu Dec 04 2014 Kendall Moore <kmoore@keywcorp.com> - 5.0.0-4
- Updated simp config to ask user if they want to encrypt logs.
- Updated simp config to re-word the DHCP prompt to be more clear.

* Wed Dec 03 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-4
- Updated puppetlast to properly handle expired entries and unknown
  nodes.
- Unfortunate, since in Puppet 4.0, the server API is going away :-(.

* Wed Nov 26 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-3
- Added a requirement on yum-utils for the CentOS builds.

* Tue Nov 25 2014 Chris Tessmer <chris.tessmer@onyxpoint.com> - 5.0.0-3
- Fixed recommendation/current value logic in simp config

* Sun Nov 23 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-3
- Updated updaterepos and unpack_dvd to use the new default repo
  location in /var/www/yum/SIMP.

* Sun Nov 02 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-2
- Fixed several annoyances around using DHCP
- Added some additional checks around additional puppet runs during boostrap
- Fixed logic errors around setting up fileserver.conf

* Mon Aug 25 2014 Kendall Moore <kmoore@keywcorp.com> - 5.0.0-1
- Simp config does not allow you to keep 'current' sync and bind passwords on firstrun

* Tue Aug 19 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-1
- Added warning if puppetlast returns insane dates.

* Mon Aug 11 2014 Kendall Moore <kmoore@keywcorp.com> - 5.0.0-1
- Updated configuration_item initializer to use value from YAML file
  instead of loading it from the system

* Mon Jul 21 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0-0
- Updated to use /var instead of /srv for most data.

* Tue Jun 24 2014 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.1.0-5
- Fixed several bugs in the simp config command
- Updated the grub command to generate the password hash via Ruby and
  to be FIPS compliant
- Allow the RPM to install properly on both RHEL 6 and 7+

* Tue Nov 19 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.1.0-4
- Fixed a bug in 'simp runpuppet' that was incorrectly preserving the
  double quotes around the hostname output from puppet cert list.

* Tue Nov 12 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.1.0-3
- Re-wrote and added extdata2hiera and updated hirea_config to use it.
- This outputs valid YAML and valid JSON.  Hiera_config uses the YAML
  version to preserve comments.

* Tue Oct 29 2013 Raymond Page <raymond.page@icat.us> - 4.0.1-12
- Convert the GRUB password to SHA512 instead of MD5.

* Sun Oct 06 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.1.0-2
- Ensure that the 'hosts' and 'domains' directories get converted by 'simp
  config'.

* Wed Oct 02 2013 Kendall Moore <kmoore@keywcorp.com> - 4.1.0-1
- Updated puppetlast to correctly handle a nil entry for the domain field.

* Wed Sep 25 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.1.0-0
- Updated simp commands to work properly with Puppet 3.3.

* Tue Sep 24 2013 Kendall Moore <kmoore@keywcorp.com> - 4.0.1-10
- Updated dependencies for puppet 3.X and puppet-server 3.X due to
  an upgrade from extdata to hiera.
- Added a hiera_config script to consistently setup the hiera
  architecture inside of SIMP.

* Tue Sep 24 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.1-10
- Updated 'simp bootstrap' to use the new Passenger temp directory in
  /var/run/passenger.

* Thu Sep 12 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.1-9
- Fixed the security_relevant_logs entries in simp utils to pick up
  sudosh.

* Tue Jul 09 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.1-8
- Fixed a typo where security_relevant_logs was written as
  security_relevent_logs.

* Tue Jun 11 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.1-7
- Discovered a bug in the Ruby PTY library that affected CentOS 5.9
  and have modified 'simp config' to use IO::popen instead. Also, now
  returns the actual error message from cracklib-check instead of just
  telling you that your password is bad.

* Fri May 17 2013 Trevor Vaughan <tvaughan@onyxpoint.com> 4.0.1-6
- Updated the password generation script in simp to not include
  non-shell safe special characters. This was causing issues in some
  cases. The default is still 32 characters.
- Added support for enabling SELinux
- Updated the /etc/hosts code to preserve existing content
- Added support for specifying the LDAP Sync user to enable connecting
  to legacy systems.
- Added support for enabling SELinux.
- Updated the /etc/hosts code to preserve existing content.

* Fri Jan 18 2013 Maintenance
4.0.1-5
- Ensure that 'simp bootstrap' does not rely on the passenger-status command
  since it is removed by the EPEL version of rubygem-passenger

* Tue Nov 20 2012 Maintenance
4.0.1-4
- Updated the simp check -l command to handle the new placement of the
  /etc/pam_ldap.conf script in CentOS 6.

* Fri Sep 28 2012 Maintenance
4.0.1-3
- Updated the puppetlast script to have options for pretty printing
  and sorting by fqdn or time.

* Tue Sep 25 2012 Maintenance
4.0.1-2
- Changed the terms 'blob/glob' to 'domain wildcards' to make the
  inbuilt documentation less confusing.

* Wed May 16 2012 Maintenance
4.0.1-1
- Changed the following in runpuppet:
  - Fixed a typo
  - Changed Facter.id to Facter.value('id') to avoid a Ruby class conflict
  - Fixed error when creating a new file in a non-existant directory by
    creating the directory first

* Wed Mar 07 2012 Maintenance
4.0.1-0
- Added 'puppeteval' utility for getting metrics on Puppet runs.
- Renamed to simp-utils for consistency.

* Mon Jan 30 2012 Maintenance
2.0.0-8
- Initial rewrite of the 'simp' utility.

* Thu Jan 12 2012 Maintenance
2.0.0-7
- Added an 'unpack_dvd' script for creating the YUM repositories from the
  vendor DVDs or ISO images.

* Wed Dec 14 2011 Maintenance
4.0.0-6
- Updated to ensure that puppetrun can handle the new puppetca format as well
  as changing the directory to '/' when sshing to a host since this doesn't
  appear to play nicely with NFS home directories in all cases.

* Sun Dec 04 2011 Maintenance
4.0.0-5
- Now ensure that puppetlast can detect and report backward clock skew.

* Sun Nov 20 2011 Maintenance
4.0.0-4
- Added a check for facts.expiration being nil to account for legacy upgrades.

* Mon Nov 14 2011 Maintenance
4.0.0-3
- Fixed a bug where the default gateway from simp config was getting eclipsed
  by interface values.

* Tue Oct 11 2011 Maintenance
4.0.0-2
- Updated to work with the 2.7.6 version of Puppet and to ensure that
  :_timestamp can be handled as either a String or a Time value.

* Fri Sep 30 2011 Maintenance
4.0.0-1
- Updated to ensure that grub sections don't execute if there's no grub.conf.

* Wed Aug 24 2011 Maintenance
4.0.0-0
- Updated puppetlast to work with the 2.7 series of puppet.
- Initial version of 4.0 compatible config script.

* Thu Aug 04 2011 Maintenance
2.0.0-3
- Added additional tags to the puppet runs.
- Fixed a bug where specifying 'n' when asked about the grub password would
  ignore your selection.

* Wed Jun 1 2011 Maintenance
2.0.0-2
- Print out the autogenerated LDAP root password in 'simp config'.
- Moved puppetlast and gen-ldap-update to /usr/local/sbin since they didn't
  really fit in bin.
- Added /usr/local/sbin/updaterepos that will automatically properly symlink
  and update your Local repo or whatever other repo you point it at.
- Moved 'simp' to /usr/local/bin since it didn't really belong where it was.
- Ensure that autogenerated passwords are single quoted.


* Thu May 12 2011 Maintenance - 2.0.0-1
- Updated the 'simp config' script such that it will:
  - Properly report errors
  - Autogenerate passwords
  - Downcase hostnames
- Ensure that simp config doesn't die if there are problems with the Updates
  repo.
- Added --pluginsync to each puppet agent run to ensure that sync happens
  during bootstrap.
- Remove yumrepo from the initial puppet run as it was unnecessary.
- Added gen-ldap-update command for helping users update their LDAP with
  necessary bug fixes.
- Fixed typo
- Updated simp check to work with 2.0.0
- Added new puppetlast command. Note: 'puppetlast -h' is currently broken!

* Tue Jan 11 2011 Maintenance
2.0.0-0
- Refactored for SIMP-2.0.0-alpha release
- Added options to 'simp check' to check for unscoped function calls and
global resource defaults

* Sat Nov 20 2010 Maintenance - 1.0-3
- The 'simp config' utility now configures the keydist directory for the server.
- The 'simp bootstrap' utility has been added to be run after 'simp config'.
- The 'simp config' command now fully configures the Apache YUM repository.
- The simp_utils RPM now requires PSSH
- The following simp commands were added:
  - cleancerts
  - runpuppet

* Wed Oct 06 2010 Maintenance
1.0-2
- The simp command now suports:
  - doc
  - deftest
  - passgen
  - check
  - version
  - config
- Updated man pages.

* Tue Aug 3 2010 Maintenance
1.0-1
- Replaced simpdoc with simp doc

* Thu Jun 24 2010 Maintenance
1.0-0
- Addition of the simpdoc utility which is simply a script to make it easy to spawn the documentation
- Slight restructuring of internals to account for items in both bin and sbin.
- Stub to account for new simp rollup

* Fri Apr 23 2010 Maintenance
0.1-1
- Updated spec file to match new build process

* Wed Nov 04 2009 Maintenance
0.1-0
- Added the puppetlast script and associated man page to the bundle.
