##  Introduction

This directory contains transition scripts to help in the migration of LDAP
accounts data from a SIMP-managed OpenLDAP server (EL7) to a SIMP-managed
389 Directory Server instance (EL8).

It contains the following files:

* `openldap_to_389ds.rb`: Ruby script that converts `slapcat` output to an
  LDIF file for import into a 389 Directory Server instance.
* `import_to_389ds.sh`: Script used to import the LDIF file created by
  `openldap_to_389ds.rb` into a 389 Directory Server instance.

## Instructions for 389-DS data import

The following are instructions for importing users and groups from an OpenLDAP
directory server managed by SIMP via `simp_openldap::server` to a 389-DS instance
managed by SIMP via `simp_ds389::instances::accounts` .

The Base DN on the OpenLDAP and the 389-DS servers must be the same.

### Export Data from OpenLDAP

Log on to your OpenLDAP server and export the data from the server using `slapcat`:

```
sudo slapcat > /tmp/simp_openldap.ldif
```

### Install scripts

The install scripts are provided by the simp-utils RPM and require the net-ldap
Ruby gem to be installed for the Ruby instance used by `root` on the 389-DS
server.

Assuming `root` uses system Ruby on the 389-DS server, install the scripts and
the net-ldap Ruby gem as follows:

```
sudo yum install -y simp-utils rubygem-net-ldap
```

* The rubygem-net-ldap package is available from the EPEL repository.
* For other Ruby instances, you can install the net-ldap gem using
  the corresponding `gem` program.

### Clean and Import the LDIF File

On the 389-DS server:

  * Copy the `simp_openldap.ldif` file to a secure location
    * **Protect this file! It has a great deal of sensitive information**

  * Remove the file from the OpenLDAP server
  * Run the following

      ```
      export PATH=$PATH:/usr/share/simp/transition_scripts/openldap_to_389ds
      openldap_to_389ds.rb -i simp_openldap.ldif -o simp_389ds.ldif
      ```

  * Finally, run the following command as `root`

      ```
      import_to_389ds.sh simp_389ds.ldif
      ```

### Validation

If all was successful, you can now remove the LDIF files.

A quick way to spot check that the import was successful is to run
`sudo dsidm accounts -b <base DN> user list` and
`sudo dsidm accounts -b <base DN> posixgroups list`.
The user accounts and groups should be listed in that output.
