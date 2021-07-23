#!/opt/puppetlabs/puppet/bin/ruby
#
#  This script is used to convert data from a SIMP openldap server into a
#  an ldif that can be imported into a SIMP ds389 server that has the same base dn.
#
#    This is a list of what it changes on the LDIF entries:
#
#    - Moves entries from ou=Group,<basedn> to ou=Groups,<basedn>
#      dsidm, a tool used to maintain entries in ds389, is opinionated at
#      this time on where groups and users should be.  It expects them
#      to be in  ou=Groups and ou=People.
#    - Removes attributes that are not compatible with ds389 (see
#      @delete_keys for a full list)
#    - Converts SSH  attributes to the format used by ds389.
#    - Adds objectClass attributes needed by dsidm.
#    - Converts lockout settings.
#
require 'fileutils'
require 'net-ldap'
require 'optparse'

def convert_group(dn,attr)
  newattr =  {}
  newdn = dn.gsub(@oldgroupdn,@newgroupdn)
  attr.each do |a,v|
    case a
    when :objectclass
      newv = [ 'groupOfNames', 'nsMemberOf', 'posixGroup']
      v.each do |nv|
        newv << nv
      end
      newattr[:objectclass] = newv.uniq
    else
      newattr[a] = v unless @delete_keys.member?(a)
    end
  end
  @ldifs_389[newdn] = newattr
end

def convert_user(dn,attr)
  newattr = {}
  attr.each do |a,v|
    case a
    when :cn
      newattr[a] = v
    when :sshpublickey
      nv = []
      v.each do |k|
        nv << k unless k.strip.empty?
      end
      nv = [ '<no ssh key>'] if nv.empty?
      newattr[:nssshpublickey] = nv
    when :objectclass
      newv = ['nsAccount']
      v.each do |nv|
        case nv
        when 'ldapPublicKey'
          # no op drop this class
        else
          newv << nv
        end
      end
      newattr[:objectclass] = newv.uniq
    when :pwdaccountlockedtime
      newattr[:nsaccountlock] = 'true'
    else
      newattr[a] = v unless @delete_keys.include?(a)
    end
  end
  @ldifs_389[dn] = newattr
end

@slapcat_file = './data/simp_openldap.ldif'
@output_ldif_file = './data/simp_ds389.ldif'
@basedn = ''

optparse = OptionParser.new do |opts|
  opts.banner = 'Usage:  openldap2ds389 -f <inputfile> -o <outputfile> -b <base dn>'
  opts.separator <<~HELP_MSG

  This script is used to convert data from a SIMP openldap server into a
  an ldif that can be imported into a SIMP ds389 server that has the same base dn.

  On the openldap server run slapcat > <inputfile>.
  Transfer the input file to the ds389 server and run this script on the ds389 server
  using the slapcat output as the <inputfile>.
  This script will create an ldif file in <outputfile> that contains all the users and
  groups in the People and Groups organiztional units from the old openldap server.

  The <outputfile> can be used by the import2ds389.sh script (or ldapadd) to import
  the entries into an 'accounts' instance of the ds389 server.

  OPTIONS:

  HELP_MSG

  opts.on('-b', '--basedn BASEDN', 'REQUIRED: base dn of the ldap server') do |b|
    @basedn = b.strip
  end
  opts.on('-f', '--file FILE', 'File that containslapcat data from openldap server', 'Default ./data/simp_openldap.ldif') do |f|
    @slapcat_file = f.strip
  end
  opts.on('-o', '--output FILE', 'file to output the ldifs to import into ds389 server','Default: ./data/simp_ds389.ldif') do |f|
    @output_ldif_file = f.strip
  end
  opts.on('-h', '--help', 'Help') do
    puts opts
    exit
  end
  opts.separator <<~HELP_MSG

  EXAMPLES:
    # To use the default locations for input and output files;
    openldap2ds389 -b 'dc=example,dc=com'

   # or to specify the location of the input and output files"
    openldap2ds389 -b 'dc=my,dc=domain' -f /tmp/ds389/myslapcat_file -o /tmp/ds389/myds389.ldif

  HELP_MSG

end

optparse.parse!

unless File.exists?(@slapcat_file)
  puts "File:  #{@slapcat_file} does not exist"
  exit
end

if @basedn.empty?
  puts "basedn is empty.  You must provide -b option when running openldap2ds389"
  exit
end

puts "Input File:  #{@slapcat_file}"
puts "Output File: #{@output_ldif_file}"
puts "Base DN:     #{@basedn}"

@delete_keys = [:entryuuid, :entrycsn, :pwdchangedtime, :pwdfailuretime]
@ldifs_389 = {}
@oldgroupdn = "ou=Group,#{@basedn}"
@olduserdn = "ou=People,#{@basedn}"
@newgroupdn ="ou=Groups,#{@basedn}"

# Read in the slapcat file
text = File.open(@slapcat_file, "r")
ldifs = Net::LDAP::Dataset.read_ldif(text)
text.close

ldifs.each do |dn, attr|
  # Only convert users and groups
  unless attr[:objectclass].member?('organizationalUnit')
    if dn.end_with?(@oldgroupdn)
      convert_group(dn,attr)
    elsif  dn.end_with?(@olduserdn)
      convert_user(dn,attr)
    end
  end
end

newtext = File.open(@output_ldif_file, 'w')

@ldifs_389.each do |k,v|
  newtext.write "dn: #{k}\n"
  v.each do |x,y|
    if y.kind_of?(Array)
      y.each do | p |
        newtext.write "#{x}: #{p}\n"
      end
    else
      newtext.write "#{x}: #{y}\n"
    end
  end
  newtext.write "\n"
end
newtext.close

puts "FINISHED output is in #{@output_ldif_file}"

