#!/bin/bash

#  This script must be run as root on the ds389 server.
#  USAGE:
#  ./import2ds389.sh <basedn> [inputfile]
#
#       basedn = the basedn used in LDAP
#
#       inputfile = the file created by the openldap2ds389.rb script.
#                   DEFAULT = ./data/simp_ds389.ldif
#

basedn="$1"

if [ $# == 2 ]; then
  file="$2"
else
  file="./data/simp_ds389.ldif"
fi

if [ ! -f ${file}]; then
  echo "File ${file} does not exist"
  exit
fi

admin_group="cn=administrators,ou=Groups,${basedn}"
user_group="cn=users,ou=Groups,${basedn}"

# Remove the users and administrators groups because they will be imported from the
# ldif file.

/usr/bin/ldapdelete -Y EXTERNAL  -H ldapi://%2fvar%2frun%2fslapd-accounts.socket ${admin_group}
/usr/bin/ldapdelete -Y EXTERNAL  -H ldapi://%2fvar%2frun%2fslapd-accounts.socket ${user_group}

/usr/bin/ldapadd -Y EXTERNAL  -H ldapi://%2fvar%2frun%2fslapd-accounts.socket  -f ${file}


