##  Introduction

This directory contains transition scripts to help in the migration of users and
groups from OpenLDAP (EL7) to 389-DS (EL8).

It should contain the following files"

openldap_to_389ds.rb - ruby script that converts slapcat output to ldif for import into
                       389 directory server
import_to_389ds.sh   - script used to import the LDIF file created by openldap_to_389ds.rb

## Instructions for 389-DS data import

The following are instructions for importing users and groups from
a SIMP install OpenLDAP directory server to a 389-DS server installed
using the `simp_ds389::instances::accounts` manifest.

The Base DN on the OpenLDAP  and the 389-DS servers must be the same.

### Export Data from OpenLDAP

Log on to your OpenLDAP server and export the data from the server using `slapcat`:

```
sudo slapcat > /tmp/simp_openldap.ldif
```

### Install scripts

Install the scripts and necessary dependencies on the 389-DS server.

```
sudo yum install -y simp-utils rubygem-net-ldap
```

### Clean and Import the LDIF File

On the 389-DS Server:

  * Copy the `simp_openldap.ldif` file to a secure location
    * Protect this file! It has a great deal of sensitive information
  * Remove the file from the OpenLDAP server
  * Run the following replacing <your basedn> with your actual Base DN
    * Check your Hiera data if you are not sure what your Base DN is

```
export PATH=$PATH:/usr/share/simp/transition_scripts/openldap_to_389ds
openldap_to_389ds.rb -i simp_openldap.ldif -o simp_389ds.ldif
sudo import_to_389ds.sh simp_389ds.ldif
```

### Validation

If all was successful, you can now remove the LDIF files.

A quick way to check is to run `sudo dsidm accounts user list` and make sure
that your accounts show up as expected.
