#!/bin/bash

# This script must be run as root on the 389-DS server.
#
# USAGE:
#   import_to_389ds <inputfile>
#
#      inputfile = the file created by the openldap_to_389ds.rb script

basedn=''
file='simp_389ds.ldif'

if [ ! -z "$1" ]; then
  file="$1"
fi

if [ ! -f ${file} ]; then
  echo "ERROR: File '${file}' does not exist"
  exit 1
fi

# Determine the Base DN
basedn=$(
  grep -m1 "ou=\(People\|Groups\)" "${file}" | \
    awk '{gsub(/ou=(People|Groups),/, " "); print $3; }'
  )

if [ -z "${basedn}" ]; then
  echo "ERROR: Could not find any People or Groups in '${file}'"
  exit 1
fi

admin_group="cn=administrators,ou=Groups,${basedn}"
user_group="cn=users,ou=Groups,${basedn}"

if ! command -v dsidm >&/dev/null; then
  echo 'ERROR: Could not find the "dsidm" command'
  exit 1
fi

for gid in users administrators; do
  if dsidm accounts -b "${basedn}" group get $gid | grep "member\(Uid\)\?:"; then
    echo "ERROR: Found existing members for the '${gid}' group, refusing to continue"
    echo 'Please manually remove the groups if you wish to continue'
    exit 1
  fi
done

# Remove the users and administrators groups because they will be imported from the
# ldif file.

echo "Removing empty 'administrators' group prior to import"
/usr/bin/ldapdelete -Y EXTERNAL -H ldapi://%2fvar%2frun%2fslapd-accounts.socket "${admin_group}"

echo
echo "Removing empty 'users' group prior to import"
/usr/bin/ldapdelete -Y EXTERNAL -H ldapi://%2fvar%2frun%2fslapd-accounts.socket "${user_group}"

echo
echo "Applying ${file}"
/usr/bin/ldapadd -Y EXTERNAL -H ldapi://%2fvar%2frun%2fslapd-accounts.socket -f "${file}"
