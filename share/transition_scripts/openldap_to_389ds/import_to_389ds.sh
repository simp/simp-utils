#!/bin/bash

# This script must be run as root on the 389-DS server.
#
# USAGE:
#   import_to_389ds <inputfile>
#
#      inputfile = the file created by the openldap_to_389ds.rb script

basedn=''
file='simp_389ds.ldif'

if [ ! -z "$2" ]; then
  $file = $2
fi

if [ ! -f ${file} ]; then
  echo "Error: File '${file}' does not exist"
  exit 1
fi

# Determine the Base DN
basedn=$(
  grep -m1 "ou=\(People\|Groups\)" "${file}" | \
    awk '{gsub(/ou=(People|Groups),/, " "); print $3; }'
  )

if [ -z "${basedn}" ]; then
  echo "Error: Could not find any People or Groups in '${file}'"
  exit 1
fi

admin_group="cn=administrators,ou=Groups,${basedn}"
user_group="cn=users,ou=Groups,${basedn}"

if ! hash -t dsidm >&/dev/null; then
  echo 'Error: Could not find the "dsidm" command'
  exit 1
fi

for gid in users administrators; do
  if $( dsidm accounts -b "${basedn}" group get users | grep "member\(Uid\)\?:"); then
    echo "Error: Found existing entries in the '${gid}' group, refusing to continue"
    echo 'Please manually remove the groups if you wish to continue'
    exit 1
  fi
done

# Remove the users and administrators groups because they will be imported from the
# ldif file.

/usr/bin/ldapdelete -Y EXTERNAL -H ldapi://%2fvar%2frun%2fslapd-accounts.socket ${admin_group}
/usr/bin/ldapdelete -Y EXTERNAL -H ldapi://%2fvar%2frun%2fslapd-accounts.socket ${user_group}

/usr/bin/ldapadd -Y EXTERNAL -H ldapi://%2fvar%2frun%2fslapd-accounts.socket -f ${file}
