#!/usr/bin/env ruby
#
# frozen_string_literal: true

#  This script is used to convert user and group data from a SIMP OpenLDAP
#  server into a LDIF that can be imported into a SIMP 389-DS server that has
#  the same base DN.
#
#    This is a list of what it changes on the LDIF entries:
#
#    - Moves entries from ou=Group,<basedn> to ou=Groups,<basedn>
#      dsidm, a tool used to maintain entries in 389-DS, is opinionated at
#      this time on where groups and users should be.  It expects them
#      to be in  ou=Groups and ou=People.
#    - Removes attributes that are not compatible with 389-DS (see
#      `DELETE_KEYS` for a full list)
#    - Converts SSH  attributes to the format used by 389-DS.
#    - Adds `objectClass` attributes needed by dsidm.
#    - Converts `lockout` settings.
#
require 'fileutils'
require 'net-ldap'
require 'optparse'

# Attributes that will cause issues in 389-DS
# - memberuid is copied into to member before deletion
# - sshpublickey is copied into nssshpublickey before deletion

DELETE_KEYS = %i[
  entrycsn
  entryuuid
  memberuid
  pwdaccountlockedtime
  pwdchangedtime
  pwdfailuretime
  sshpublickey
].freeze

def convert_group(attrs, groupdn)
  newattrs = {}
  attrs.each do |a, v|
    newattrs[a] = v.dup

    newattrs[a].delete_if { |x| x.nil? || x.strip.empty? }

    newattrs[a] += %w[groupOfNames nsMemberOf posixGroup] if a == :objectclass

    newattrs[a].uniq!
  end

  newattrs[:member] = newattrs[:memberuid].map { |u| "uid=#{u},#{groupdn}" } if newattrs[:memberuid]

  newattrs.delete_if { |a, _v| DELETE_KEYS.include?(a) }
  newattrs
end

def convert_user(attrs)
  newattrs = {}
  lastname = ""
  firstname = ""
  attrs.each do |a, v|
    newattrs[a] = v.dup

    newattrs[a].delete_if { |x| x.nil? || x.strip.empty? }

    if a == :objectclass
      newattrs[a] << 'nsAccount'
      if newattrs[a].member?('inetOrgPerson')
        newattrs[a] << 'nsPerson'
        newattrs[a] << 'nsOrgPerson'
      end
      newattrs[a].delete('ldapPublicKey')
    end

    if a == :sn
      lastname = newattrs[a].first
    end
    if a == :givenname
      firstname = newattrs[a].first
    end


    if a == :sshpublickey
      newattrs[a] = ['<no ssh key>'] if newattrs[a].empty?
      newattrs[:nssshpublickey] = newattrs[a]
    end

    newattrs[a].uniq!
  end

  if newattrs[:objectclass].member?('nsPerson')
    newattrs[:displayname] = [ "#{firstname} #{lastname}" ]
  end
  newattrs[:nsaccountlock] = ['true'] if newattrs[:pwdaccountlockedtime]

  newattrs.delete_if { |a, _v| DELETE_KEYS.include?(a) }
  newattrs
end

input_ldif = 'simp_openldap.ldif'
output_ldif = 'simp_389ds.ldif'
basedn = nil

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} -i INFILE -o OUTFILE [-b BASEDN]"
  # in case we are using system Ruby on EL7 (2.0.0), don't use
  # <<~
  opts.separator <<-HELP_MSG.gsub(/^    /,'')
      See the README.md for detailed instructions.

    OPTIONS:

  HELP_MSG

  opts.on('-b', '--basedn BASEDN',
    'Base DN of the LDAP server.  When absent,',
    'will attempt to determine it from the input',
    'file.'
  ) do |b|
    basedn = b.strip
  end

  opts.on('-i', '--input INFILE',
    'Input LDIF file containing the slapcat dump',
    'of the OpenLDAP server.',
    'Default: ./simp_openldap.ldif'
  ) do |f|
    input_ldif = f.strip
  end

  opts.on('-o', '--output OUTFILE',
    'Generated LDIF file for import into 389-DS.',
    'Default: ./simp_389ds.ldif'
  ) do |f|
    output_ldif = f.strip
  end

  opts.on('-h', '--help', 'Help') do
    puts opts
    exit
  end

  opts.separator <<-HELP_MSG.gsub(/^    /,'')

    EXAMPLES:
      # To use the default locations for input and output files
      #{$PROGRAM_NAME} -b 'dc=my,dc=domain'

      # To specify the location of the input and output files
      #{$PROGRAM_NAME} -b 'dc=my,dc=domain' -i /tmp/myslapcat_file.ldif -o /tmp/myds389.ldif

  HELP_MSG
end

optparse.parse!

unless File.exist?(input_ldif)
  warn "ERROR: input file '#{input_ldif}' does not exist"
  exit 1
end

# Read in the slapcat file
fh = File.open(input_ldif, 'r')
begin
  ldifs = Net::LDAP::Dataset.read_ldif(fh)
rescue Exception => e
  warn "ERROR: Malformed LDIF input:\n#{e}\n#{e.backtrace.join("\n")}"
  exit 1
ensure
  fh.close
end

basedn ||= ldifs.select { |_k, v| v[:structuralobjectclass].include?('domain') }.keys.first

unless basedn
  warn 'ERROR: Could not determine Base DN, please specify using -b'
  exit 1
end

puts "Input File:  #{input_ldif}"
puts "Output File: #{output_ldif}"
puts "Base DN:     #{basedn}"

oldgroupdn = "ou=Group,#{basedn}"
olduserdn = "ou=People,#{basedn}"
newgroupdn = "ou=Groups,#{basedn}"

ldifs389 = Net::LDAP::Dataset.new

ldifs.each do |dn, attr|
  # Only convert users and groups
  unless attr[:objectclass].member?('organizationalUnit')
    if dn.end_with?(oldgroupdn)
      new_dn = dn.gsub(oldgroupdn, newgroupdn)
      ldifs389[new_dn] = convert_group(attr, newgroupdn)
    elsif dn.end_with?(olduserdn)
      ldifs389[dn] = convert_user(attr)
    end
  end
end

if ldifs389.empty?
  warn "ERROR: No user or group records found, is base DN '#{basedn}' valid?"
  exit 1
end

begin
  File.open(output_ldif, 'w') do |ofh|
    ofh.puts(ldifs389.to_ldif.join("\n"))
  end
rescue Exception => e
  warn "ERROR: Output file could not be created:\n#{e}\n#{e.backtrace.join("\n")}"
  exit 1
end

puts "FINISHED output is in #{output_ldif}"
