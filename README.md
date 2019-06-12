[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![Build Status](https://travis-ci.org/simp/simp-utils.svg)](https://travis-ci.org/simp/simp-utils)

# simp-utils
Utilities for managing SIMP

LDIFS
-----

Example ldif files to help manage LDAP entries.


Scripts
-------

A general description of the scripts installed under
/usr/local is  given here.
See the script itself for more details.

/usr/local/sbin/updaterepos
^^^^^^^^^^^^^^^^^^^^^^^^^^^
usage:  updaterepos <repodir>

This will go into each directory under repodir not named noarch,
 - update links to files under ../noarch,
 - rebuild the repodata
 - update the repodata to ensure it is readable by root:apache


/usr/local/bin/unpack_dvd
^^^^^^^^^^^^^^^^^^^^^^^^^

usage:  unpack_dvd --help gives a complete usage statement.

This script unpacks either a SIMP ISO image or a distribution DVD to the specified
directory or /var/www/yum/ (default).

/usr/local/sbin/simpenv
^^^^^^^^^^^^^^^^^^^^^^^
usage:  simpenv -h gives a complete usage statement

This script can be used to create or list environments in SIMP 6.4 or later.

/usr/local/sbin/puppetlast
^^^^^^^^^^^^^^^^^^^^^^^^^^
usage:  puppetlast -h gives a complete usage statement

puppetlast queries PuppetDB and returns a list of nodes and the last time the
catalog was compiled

/usr/local/sbin/gen-ldap-update
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
This is run  on and LDAP server to generate an  ldif file that can be used
to updated attributes in LDAP.

/usr/local/bin/set_environment
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
This is a YAML-based node classifier which can be used as a Puppet
External Node Classifier (ENC).




