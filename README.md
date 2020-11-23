[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![Build Status](https://travis-ci.org/simp/simp-utils.svg)](https://travis-ci.org/simp/simp-utils)

# simp-utils
Utilities for managing SIMP

## LDIFS

Example ldif files to help manage LDAP. These ldifs are installed in
`/usr/share/simp/ldifs`.

## Kickstart Scripts

Example kickstart scripts to help set up PXE booting are installed in
`/usr/share/simp/ks`.

## Scripts

This section contains a brief description of the scripts installed under
`/usr/local`.  See each script's help for more details.

### /usr/local/bin/set_environment

This is a YAML-based node classifier which can be used as a Puppet
External Node Classifier (ENC).

### /usr/local/bin/unpack_dvd

Usage:  ``unpack_dvd [options] /path/to/dvd/to/unpack``

This script unpacks either a SIMP ISO image or a distribution DVD to the specified
directory or `/var/www/yum/` (default).

The ``--help`` option gives a complete usage statement.

### /usr/local/sbin/gen-ldap-update

Usage:  ``gen-ldap-update``

This is run on an LDAP server to generate an ldif file that can be used
to update attributes in LDAP.

### /usr/local/sbin/puppetlast

Usage:  ``puppetlast [options]``

``puppetlast`` queries PuppetDB and returns a list of nodes and the last
time the catalog was compiled on each node.

The ``--help`` option gives a complete usage statement.

### /usr/local/sbin/simpenv

Usage:
  ``simpenv --list``
  or
  ``simpenv -n|-c|-l|-a [new|copy|link] [EXISTING_ENV] NEWENV``

This script can be used to create or list environments in SIMP 6.4 or later.

The ``--help`` option gives a complete usage statement.

### /usr/local/sbin/updaterepos

Usage:  ``updaterepos <repodir>``

This will go into each directory under ``repodir`` that is not named
``noarch`` and do the following:

 - Update links to files under ``../noarch``
 - Rebuild the ``repodata``
 - Update the ``repodata`` to ensure it is readable by ``root:apache``
