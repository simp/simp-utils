##  Introduction

This directory contains transition scripts to help in the SIMP 6.6.0 upgrade.

It should contain the following files"

openldap2ds389.rb  - ruby script that converts slapcat output to ldif for import into
                     389 directory server
net-ldap.gem       - rubygem required by openldap2ds389.rb
import2ds389.sh    - script used to import the ldif file created by openldap2ds389.rb


## Instructions for 389ds data import

The following are instructions for importing users and groups from
a SIMP install openldap directory server to a 389ds server installed
using the simp_ds389::instances::accounts manifest.

The basedn on the openldap  and the 389ds servers must be the same.

### Export Data from Openldap

Log on to your openldap server and export the data from the server using slapcat:

sudo slapcat > /tmp/simp_openldap.ldif

### Install scripts

Install the scripts on the ds389 server.

sudo yum install simp-utils

then install the net-ldap gem

cd /usr/share/simp/transition_scripts/6.6.0
sudo /opt/puppetlabs/puppet/bin/gem install ./net-ldap-0.17-0.gem

### Create LDIF file and import it

Copy the slapcat output from the openldap server into /usr/share/simp/transition_scripts/6.6.0/data/simp_openldap.ldif
on the ds389 server.

On the ds389 server run the script replacing <your basedn> with your basedn.

cd /usr/share/simp/transition_scripts/6.6.0/
sudo ./openldap2ds389.rb -b <your basedn>
sudo ./import2ds389.sh  <your basedn>

### Clean up

sudo /opt/puppetlabs/puppet/bin/gem  remove ./net-ldap
sudo rm -rf /usr/share/simp/transition_scripts/6.6.0/data
