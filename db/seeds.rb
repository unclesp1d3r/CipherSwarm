# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
unless User.exists?(name: "admin")
  user = User.new
  user.name = "admin"
  user.email = "admin@example.com"
  user.password = "password"
  user.password_confirmation = "password"
  user.save!
  user.add_role(:admin)
end

unless User.exists?(name: "user")
  user = User.new
  user.name = "user"
  user.email = "nobody@example.com"
  user.password = "password"
  user.password_confirmation = "password"
end

unless Project.exists?(name: "Default Project")
  project = Project.new
  project.name = "Default Project"
  project.description = "This is the default project."
  project.users.append(User.first)
  project.save!
end

OperatingSystem.create(name: "windows", cracker_command: "hashcat.exe") unless OperatingSystem.exists?(name: "windows")
OperatingSystem.create(name: "linux", cracker_command: "hashcat.bin") unless OperatingSystem.exists?(name: "linux")
OperatingSystem.create(name: "darwin", cracker_command: "hashcat.bin") unless OperatingSystem.exists?(name: "darwin")

if Rails.env.local? && !Agent.count.positive?
  agent = Agent.new
  agent.host_name = "Agent 1"
  agent.user = User.first
  agent.projects.append(Project.first)
  agent.advanced_configuration.use_native_hashcat = true
  agent.save!
end

# Add the built-in hash types
[
  {
    hashcat_mode: 0,
    name: "MD5",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 10,
    name: "md5($pass.$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 11,
    name: "Joomla < 2.5.18",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 12,
    name: "PostgreSQL",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 20,
    name: "md5($salt.$pass)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 21,
    name: "osCommerce, xt:Commerce",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 22,
    name: "Juniper NetScreen/SSG (ScreenOS)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 23,
    name: "Skype",
    category: :instant_messaging,
    enabled: true
  },
  {
    hashcat_mode: 24,
    name: "SolarWinds Serv-U",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 30,
    name: "md5(utf16le($pass).$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 40,
    name: "md5($salt.utf16le($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 50,
    name: "HMAC-MD5 (key = $pass)",
    category: :raw_hash_authenticated,
    enabled: true
  },
  {
    hashcat_mode: 60,
    name: "HMAC-MD5 (key = $salt)",
    category: :raw_hash_authenticated,
    enabled: true
  },
  {
    hashcat_mode: 70,
    name: "md5(utf16le($pass))",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 100,
    name: "SHA1",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 101,
    name: "nsldap, SHA-1(Base64), Netscape LDAP SHA",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 110,
    name: "sha1($pass.$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 111,
    name: "nsldaps, SSHA-1(Base64), Netscape LDAP SSHA",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 112,
    name: "Oracle S: Type (Oracle 11+)",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 120,
    name: "sha1($salt.$pass)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 121,
    name: "SMF (Simple Machines Forum) > v1.1",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 122,
    name: "macOS v10.4, macOS v10.5, macOS v10.6",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 124,
    name: "Django (SHA-1)",
    category: :framework,
    enabled: true
  },
  {
    hashcat_mode: 125,
    name: "ArubaOS",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 130,
    name: "sha1(utf16le($pass).$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 131,
    name: "MSSQL (2000)",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 132,
    name: "MSSQL (2005)",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 133,
    name: "PeopleSoft",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 140,
    name: "sha1($salt.utf16le($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 141,
    name: "Episerver 6.x < .NET 4",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 150,
    name: "HMAC-SHA1 (key = $pass)",
    category: :raw_hash_authenticated,
    enabled: true
  },
  {
    hashcat_mode: 160,
    name: "HMAC-SHA1 (key = $salt)",
    category: :raw_hash_authenticated,
    enabled: true
  },
  {
    hashcat_mode: 170,
    name: "sha1(utf16le($pass))",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 200,
    name: "MySQL323",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 300,
    name: "MySQL4.1/MySQL5",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 400,
    name: "phpass",
    category: :generic_kdf,
    enabled: true
  },
  {
    hashcat_mode: 500,
    name: "md5crypt, MD5 (Unix), Cisco-IOS $1$ (MD5)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 501,
    name: "Juniper IVE",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 600,
    name: "BLAKE2b-512",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 610,
    name: "BLAKE2b-512($pass.$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 620,
    name: "BLAKE2b-512($salt.$pass)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 900,
    name: "MD4",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 1000,
    name: "NTLM",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 1100,
    name: "Domain Cached Credentials (DCC), MS Cache",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 1300,
    name: "SHA2-224",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 1400,
    name: "SHA2-256",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 1410,
    name: "sha256($pass.$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 1411,
    name: "SSHA-256(Base64), LDAP {SSHA256}",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 1420,
    name: "sha256($salt.$pass)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 1421,
    name: "hMailServer",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 1430,
    name: "sha256(utf16le($pass).$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 1440,
    name: "sha256($salt.utf16le($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 1441,
    name: "Episerver 6.x >= .NET 4",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 1450,
    name: "HMAC-SHA256 (key = $pass)",
    category: :raw_hash_authenticated,
    enabled: true
  },
  {
    hashcat_mode: 1460,
    name: "HMAC-SHA256 (key = $salt)",
    category: :raw_hash_authenticated,
    enabled: true
  },
  {
    hashcat_mode: 1470,
    name: "sha256(utf16le($pass))",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 1500,
    name: "descrypt, DES (Unix), Traditional DES",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 1600,
    name: "Apache $apr1$ MD5, md5apr1, MD5 (APR)",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 1700,
    name: "SHA2-512",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 1710,
    name: "sha512($pass.$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 1711,
    name: "SSHA-512(Base64), LDAP {SSHA512}",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 1720,
    name: "sha512($salt.$pass)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 1722,
    name: "macOS v10.7",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 1730,
    name: "sha512(utf16le($pass).$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 1731,
    name: "MSSQL (2012, 2014)",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 1740,
    name: "sha512($salt.utf16le($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 1750,
    name: "HMAC-SHA512 (key = $pass)",
    category: :raw_hash_authenticated,
    enabled: true
  },
  {
    hashcat_mode: 1760,
    name: "HMAC-SHA512 (key = $salt)",
    category: :raw_hash_authenticated,
    enabled: true
  },
  {
    hashcat_mode: 1770,
    name: "sha512(utf16le($pass))",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 1800,
    name: "sha512crypt $6$, SHA512 (Unix)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 2000,
    name: "STDOUT",
    category: "plaintext",
    enabled: true
  },
  {
    hashcat_mode: 2100,
    name: "Domain Cached Credentials 2 (DCC2), MS Cache 2",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 2400,
    name: "Cisco-PIX MD5",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 2410,
    name: "Cisco-ASA MD5",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 2500,
    name: "WPA-EAPOL-PBKDF2",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 2501,
    name: "WPA-EAPOL-PMK",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 2600,
    name: "md5(md5($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 2611,
    name: "vBulletin < v3.8.5",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 2612,
    name: "PHPS",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 2711,
    name: "vBulletin >= v3.8.5",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 2811,
    name: "MyBB 1.2+, IPB2+ (Invision Power Board)",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 3000,
    name: "LM",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 3100,
    name: "Oracle H: Type (Oracle 7+)",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 3200,
    name: "bcrypt $2*$, Blowfish (Unix)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 3500,
    name: "md5(md5(md5($pass)))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 3710,
    name: "md5($salt.md5($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 3711,
    name: "MediaWiki B type",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 3800,
    name: "md5($salt.$pass.$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 3910,
    name: "md5(md5($pass).md5($salt))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 4010,
    name: "md5($salt.md5($salt.$pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 4110,
    name: "md5($salt.md5($pass.$salt))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 4300,
    name: "md5(strtoupper(md5($pass)))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 4400,
    name: "md5(sha1($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 4410,
    name: "md5(sha1($pass).$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 4500,
    name: "sha1(sha1($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 4510,
    name: "sha1(sha1($pass).$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 4520,
    name: "sha1($salt.sha1($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 4521,
    name: "Redmine",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 4522,
    name: "PunBB",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 4700,
    name: "sha1(md5($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 4710,
    name: "sha1(md5($pass).$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 4711,
    name: "Huawei sha1(md5($pass).$salt)",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 4800,
    name: "iSCSI CHAP authentication, MD5(CHAP)",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 4900,
    name: "sha1($salt.$pass.$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 5000,
    name: "sha1(sha1($salt.$pass.$salt))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 5100,
    name: "Half MD5",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 5200,
    name: "Password Safe v3",
    category: "password_manager",
    enabled: true
  },
  {
    hashcat_mode: 5300,
    name: "IKE-PSK MD5",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 5400,
    name: "IKE-PSK SHA1",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 5500,
    name: "NetNTLMv1 / NetNTLMv1+ESS",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 5600,
    name: "NetNTLMv2",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 5700,
    name: "Cisco-IOS type 4 (SHA256)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 5800,
    name: "Samsung Android Password/PIN",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 6000,
    name: "RIPEMD-160",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 6100,
    name: "Whirlpool",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 6211,
    name: "TrueCrypt RIPEMD160 + XTS 512 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 6212,
    name: "TrueCrypt RIPEMD160 + XTS 1024 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 6213,
    name: "TrueCrypt RIPEMD160 + XTS 1536 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 6221,
    name: "TrueCrypt SHA512 + XTS 512 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 6222,
    name: "TrueCrypt SHA512 + XTS 1024 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 6223,
    name: "TrueCrypt SHA512 + XTS 1536 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 6231,
    name: "TrueCrypt Whirlpool + XTS 512 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 6232,
    name: "TrueCrypt Whirlpool + XTS 1024 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 6233,
    name: "TrueCrypt Whirlpool + XTS 1536 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 6241,
    name: "TrueCrypt RIPEMD160 + XTS 512 bit + boot-mode (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 6242,
    name: "TrueCrypt RIPEMD160 + XTS 1024 bit + boot-mode (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 6243,
    name: "TrueCrypt RIPEMD160 + XTS 1536 bit + boot-mode (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 6300,
    name: "AIX {smd5}",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 6400,
    name: "AIX {ssha256}",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 6500,
    name: "AIX {ssha512}",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 6600,
    name: "1Password, agilekeychain",
    category: "password_manager",
    enabled: true
  },
  {
    hashcat_mode: 6700,
    name: "AIX {ssha1}",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 6800,
    name: "LastPass + LastPass sniffed",
    category: "password_manager",
    enabled: true
  },
  {
    hashcat_mode: 6900,
    name: "GOST R 34.11-94",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 7000,
    name: "FortiGate (FortiOS)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 7100,
    name: "macOS v10.8+ (PBKDF2-SHA512)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 7200,
    name: "GRUB 2",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 7300,
    name: "IPMI2 RAKP HMAC-SHA1",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 7400,
    name: "sha256crypt $5$, SHA256 (Unix)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 7401,
    name: "MySQL $A$ (sha256crypt)",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 7500,
    name: "Kerberos 5, etype 23, AS-REQ Pre-Auth",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 7700,
    name: "SAP CODVN B (BCODE)",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 7701,
    name: "SAP CODVN B (BCODE) from RFC_READ_TABLE",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 7800,
    name: "SAP CODVN F/G (PASSCODE)",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 7801,
    name: "SAP CODVN F/G (PASSCODE) from RFC_READ_TABLE",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 7900,
    name: "Drupal7",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 8000,
    name: "Sybase ASE",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 8100,
    name: "Citrix NetScaler (SHA1)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 8200,
    name: "1Password, cloudkeychain",
    category: "password_manager",
    enabled: true
  },
  {
    hashcat_mode: 8300,
    name: "DNSSEC (NSEC3)",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 8400,
    name: "WBB3 (Woltlab Burning Board)",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 8500,
    name: "RACF",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 8600,
    name: "Lotus Notes/Domino 5",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 8700,
    name: "Lotus Notes/Domino 6",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 8800,
    name: "Android FDE <= 4.3",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 8900,
    name: "scrypt",
    category: :generic_kdf,
    enabled: true
  },
  {
    hashcat_mode: 9000,
    name: "Password Safe v2",
    category: "password_manager",
    enabled: true
  },
  {
    hashcat_mode: 9100,
    name: "Lotus Notes/Domino 8",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 9200,
    name: "Cisco-IOS $8$ (PBKDF2-SHA256)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 9300,
    name: "Cisco-IOS $9$ (scrypt)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 9400,
    name: "MS Office 2007",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 9500,
    name: "MS Office 2010",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 9600,
    name: "MS Office 2013",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 9700,
    name: "MS Office <= 2003 $0/$1, MD5 + RC4",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 9710,
    name: "MS Office <= 2003 $0/$1, MD5 + RC4, collider #1",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 9720,
    name: "MS Office <= 2003 $0/$1, MD5 + RC4, collider #2",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 9800,
    name: "MS Office <= 2003 $3/$4, SHA1 + RC4",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 9810,
    name: "MS Office <= 2003 $3, SHA1 + RC4, collider #1",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 9820,
    name: "MS Office <= 2003 $3, SHA1 + RC4, collider #2",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 9900,
    name: "Radmin2",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 10000,
    name: "Django (PBKDF2-SHA256)",
    category: :framework,
    enabled: true
  },
  {
    hashcat_mode: 10100,
    name: "SipHash",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 10200,
    name: "CRAM-MD5",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 10300,
    name: "SAP CODVN H (PWDSALTEDHASH) iSSHA-1",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 10400,
    name: "PDF 1.1 - 1.3 (Acrobat 2 - 4)",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 10410,
    name: "PDF 1.1 - 1.3 (Acrobat 2 - 4), collider #1",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 10420,
    name: "PDF 1.1 - 1.3 (Acrobat 2 - 4), collider #2",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 10500,
    name: "PDF 1.4 - 1.6 (Acrobat 5 - 8)",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 10600,
    name: "PDF 1.7 Level 3 (Acrobat 9)",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 10700,
    name: "PDF 1.7 Level 8 (Acrobat 10 - 11)",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 10800,
    name: "SHA2-384",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 10810,
    name: "sha384($pass.$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 10820,
    name: "sha384($salt.$pass)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 10830,
    name: "sha384(utf16le($pass).$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 10840,
    name: "sha384($salt.utf16le($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 10870,
    name: "sha384(utf16le($pass))",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 10900,
    name: "PBKDF2-HMAC-SHA256",
    category: :generic_kdf,
    enabled: true
  },
  {
    hashcat_mode: 10901,
    name: "RedHat 389-DS LDAP (PBKDF2-HMAC-SHA256)",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 11000,
    name: "PrestaShop",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 11100,
    name: "PostgreSQL CRAM (MD5)",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 11200,
    name: "MySQL CRAM (SHA1)",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 11300,
    name: "Bitcoin/Litecoin wallet.dat",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 11400,
    name: "SIP digest authentication (MD5)",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 11500,
    name: "CRC32",
    category: "raw_checksum",
    enabled: true
  },
  {
    hashcat_mode: 11600,
    name: "7-Zip",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 11700,
    name: "GOST R 34.11-2012 (Streebog) 256-bit, big-endian",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 11750,
    name: "HMAC-Streebog-256 (key = $pass), big-endian",
    category: :raw_hash_authenticated,
    enabled: true
  },
  {
    hashcat_mode: 11760,
    name: "HMAC-Streebog-256 (key = $salt), big-endian",
    category: :raw_hash_authenticated,
    enabled: true
  },
  {
    hashcat_mode: 11800,
    name: "GOST R 34.11-2012 (Streebog) 512-bit, big-endian",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 11850,
    name: "HMAC-Streebog-512 (key = $pass), big-endian",
    category: :raw_hash_authenticated,
    enabled: true
  },
  {
    hashcat_mode: 11860,
    name: "HMAC-Streebog-512 (key = $salt), big-endian",
    category: :raw_hash_authenticated,
    enabled: true
  },
  {
    hashcat_mode: 11900,
    name: "PBKDF2-HMAC-MD5",
    category: :generic_kdf,
    enabled: true
  },
  {
    hashcat_mode: 12000,
    name: "PBKDF2-HMAC-SHA1",
    category: :generic_kdf,
    enabled: true
  },
  {
    hashcat_mode: 12001,
    name: "Atlassian (PBKDF2-HMAC-SHA1)",
    category: :framework,
    enabled: true
  },
  {
    hashcat_mode: 12100,
    name: "PBKDF2-HMAC-SHA512",
    category: :generic_kdf,
    enabled: true
  },
  {
    hashcat_mode: 12200,
    name: "eCryptfs",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 12300,
    name: "Oracle T: Type (Oracle 12+)",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 12400,
    name: "BSDi Crypt, Extended DES",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 12500,
    name: "RAR3-hp",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 12600,
    name: "ColdFusion 10+",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 12700,
    name: "Blockchain, My Wallet",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 12800,
    name: "MS-AzureSync PBKDF2-HMAC-SHA256",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 12900,
    name: "Android FDE (Samsung DEK)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13000,
    name: "RAR5",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 13100,
    name: "Kerberos 5, etype 23, TGS-REP",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 13200,
    name: "AxCrypt 1",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 13300,
    name: "AxCrypt 1 in-memory SHA1",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 13400,
    name: "KeePass 1 (AES/Twofish) and KeePass 2 (AES)",
    category: "password_manager",
    enabled: true
  },
  {
    hashcat_mode: 13500,
    name: "PeopleSoft PS_TOKEN",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 13600,
    name: "WinZip",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 13711,
    name: "VeraCrypt RIPEMD160 + XTS 512 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13712,
    name: "VeraCrypt RIPEMD160 + XTS 1024 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13713,
    name: "VeraCrypt RIPEMD160 + XTS 1536 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13721,
    name: "VeraCrypt SHA512 + XTS 512 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13722,
    name: "VeraCrypt SHA512 + XTS 1024 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13723,
    name: "VeraCrypt SHA512 + XTS 1536 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13731,
    name: "VeraCrypt Whirlpool + XTS 512 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13732,
    name: "VeraCrypt Whirlpool + XTS 1024 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13733,
    name: "VeraCrypt Whirlpool + XTS 1536 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13741,
    name: "VeraCrypt RIPEMD160 + XTS 512 bit + boot-mode (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13742,
    name: "VeraCrypt RIPEMD160 + XTS 1024 bit + boot-mode (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13743,
    name: "VeraCrypt RIPEMD160 + XTS 1536 bit + boot-mode (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13751,
    name: "VeraCrypt SHA256 + XTS 512 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13752,
    name: "VeraCrypt SHA256 + XTS 1024 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13753,
    name: "VeraCrypt SHA256 + XTS 1536 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13761,
    name: "VeraCrypt SHA256 + XTS 512 bit + boot-mode (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13762,
    name: "VeraCrypt SHA256 + XTS 1024 bit + boot-mode (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13763,
    name: "VeraCrypt SHA256 + XTS 1536 bit + boot-mode (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13771,
    name: "VeraCrypt Streebog-512 + XTS 512 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13772,
    name: "VeraCrypt Streebog-512 + XTS 1024 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13773,
    name: "VeraCrypt Streebog-512 + XTS 1536 bit (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13781,
    name: "VeraCrypt Streebog-512 + XTS 512 bit + boot-mode (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13782,
    name: "VeraCrypt Streebog-512 + XTS 1024 bit + boot-mode (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13783,
    name: "VeraCrypt Streebog-512 + XTS 1536 bit + boot-mode (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 13800,
    name: "Windows Phone 8+ PIN/password",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 13900,
    name: "OpenCart",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 14000,
    name: "DES (PT = $salt, key = $pass)",
    category: "raw_cipher",
    enabled: true
  },
  {
    hashcat_mode: 14100,
    name: "3DES (PT = $salt, key = $pass)",
    category: "raw_cipher",
    enabled: true
  },
  {
    hashcat_mode: 14400,
    name: "sha1(CX)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 14500,
    name: "Linux Kernel Crypto API (2.4)",
    category: "raw_cipher",
    enabled: true
  },
  {
    hashcat_mode: 14600,
    name: "LUKS v1 (legacy)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 14700,
    name: "iTunes backup < 10.0",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 14800,
    name: "iTunes backup >= 10.0",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 14900,
    name: "Skip32 (PT = $salt, key = $pass)",
    category: "raw_cipher",
    enabled: true
  },
  {
    hashcat_mode: 15000,
    name: "FileZilla Server >= 0.9.55",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 15100,
    name: "Juniper/NetBSD sha1crypt",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 15200,
    name: "Blockchain, My Wallet, V2",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 15300,
    name: "DPAPI masterkey file v1 (context 1 and 2)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 15310,
    name: "DPAPI masterkey file v1 (context 3)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 15400,
    name: "ChaCha20",
    category: "raw_cipher",
    enabled: true
  },
  {
    hashcat_mode: 15500,
    name: "JKS Java Key Store Private Keys (SHA1)",
    category: "private_key",
    enabled: true
  },
  {
    hashcat_mode: 15600,
    name: "Ethereum Wallet, PBKDF2-HMAC-SHA256",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 15700,
    name: "Ethereum Wallet, SCRYPT",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 15900,
    name: "DPAPI masterkey file v2 (context 1 and 2)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 15910,
    name: "DPAPI masterkey file v2 (context 3)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 16000,
    name: "Tripcode",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 16100,
    name: "TACACS+",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 16200,
    name: "Apple Secure Notes",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 16300,
    name: "Ethereum Pre-Sale Wallet, PBKDF2-HMAC-SHA256",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 16400,
    name: "CRAM-MD5 Dovecot",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 16500,
    name: "JWT (JSON Web Token)",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 16600,
    name: "Electrum Wallet (Salt-Type 1-3)",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 16700,
    name: "FileVault 2",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 16800,
    name: "WPA-PMKID-PBKDF2",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 16801,
    name: "WPA-PMKID-PMK",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 16900,
    name: "Ansible Vault",
    category: "password_manager",
    enabled: true
  },
  {
    hashcat_mode: 17010,
    name: "GPG (AES-128/AES-256 (SHA-1($pass)))",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 17200,
    name: "PKZIP (Compressed)",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 17210,
    name: "PKZIP (Uncompressed)",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 17220,
    name: "PKZIP (Compressed Multi-File)",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 17225,
    name: "PKZIP (Mixed Multi-File)",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 17230,
    name: "PKZIP (Mixed Multi-File Checksum-Only)",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 17300,
    name: "SHA3-224",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 17400,
    name: "SHA3-256",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 17500,
    name: "SHA3-384",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 17600,
    name: "SHA3-512",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 17700,
    name: "Keccak-224",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 17800,
    name: "Keccak-256",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 17900,
    name: "Keccak-384",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 18000,
    name: "Keccak-512",
    category: :raw_hash,
    enabled: true
  },
  {
    hashcat_mode: 18100,
    name: "TOTP (HMAC-SHA1)",
    category: "otp",
    enabled: true
  },
  {
    hashcat_mode: 18200,
    name: "Kerberos 5, etype 23, AS-REP",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 18300,
    name: "Apple File System (APFS)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 18400,
    name: "Open Document Format (ODF) 1.2 (SHA-256, AES)",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 18500,
    name: "sha1(md5(md5($pass)))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 18600,
    name: "Open Document Format (ODF) 1.1 (SHA-1, Blowfish)",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 18700,
    name: "Java Object hashCode()",
    category: "raw_checksum",
    enabled: true
  },
  {
    hashcat_mode: 18800,
    name: "Blockchain, My Wallet, Second Password (SHA256)",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 18900,
    name: "Android Backup",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 19000,
    name: "QNX /etc/shadow (MD5)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 19100,
    name: "QNX /etc/shadow (SHA256)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 19200,
    name: "QNX /etc/shadow (SHA512)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 19300,
    name: "sha1($salt1.$pass.$salt2)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 19500,
    name: "Ruby on Rails Restful-Authentication",
    category: :framework,
    enabled: true
  },
  {
    hashcat_mode: 19600,
    name: "Kerberos 5, etype 17, TGS-REP",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 19700,
    name: "Kerberos 5, etype 18, TGS-REP",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 19800,
    name: "Kerberos 5, etype 17, Pre-Auth",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 19900,
    name: "Kerberos 5, etype 18, Pre-Auth",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 20011,
    name: "DiskCryptor SHA512 + XTS 512 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 20012,
    name: "DiskCryptor SHA512 + XTS 1024 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 20013,
    name: "DiskCryptor SHA512 + XTS 1536 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 20200,
    name: "Python passlib pbkdf2-sha512",
    category: :framework,
    enabled: true
  },
  {
    hashcat_mode: 20300,
    name: "Python passlib pbkdf2-sha256",
    category: :framework,
    enabled: true
  },
  {
    hashcat_mode: 20400,
    name: "Python passlib pbkdf2-sha1",
    category: :framework,
    enabled: true
  },
  {
    hashcat_mode: 20500,
    name: "PKZIP Master Key",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 20510,
    name: "PKZIP Master Key (6 byte optimization)",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 20600,
    name: "Oracle Transportation Management (SHA256)",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 20710,
    name: "sha256(sha256($pass).$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 20711,
    name: "AuthMe sha256",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 20720,
    name: "sha256($salt.sha256($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 20800,
    name: "sha256(md5($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 20900,
    name: "md5(sha1($pass).md5($pass).sha1($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 21000,
    name: "BitShares v0.x - sha512(sha512_bin(pass))",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 21100,
    name: "sha1(md5($pass.$salt))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 21200,
    name: "md5(sha1($salt).md5($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 21300,
    name: "md5($salt.sha1($salt.$pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 21400,
    name: "sha256(sha256_bin($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 21420,
    name: "sha256($salt.sha256_bin($pass))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 21500,
    name: "SolarWinds Orion",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 21501,
    name: "SolarWinds Orion v2",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 21600,
    name: "Web2py pbkdf2-sha512",
    category: :framework,
    enabled: true
  },
  {
    hashcat_mode: 21700,
    name: "Electrum Wallet (Salt-Type 4)",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 21800,
    name: "Electrum Wallet (Salt-Type 5)",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 22000,
    name: "WPA-PBKDF2-PMKID+EAPOL",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 22001,
    name: "WPA-PMK-PMKID+EAPOL",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 22100,
    name: "BitLocker",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 22200,
    name: "Citrix NetScaler (SHA512)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 22300,
    name: "sha256($salt.$pass.$salt)",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 22301,
    name: "Telegram Mobile App Passcode (SHA256)",
    category: :instant_messaging,
    enabled: true
  },
  {
    hashcat_mode: 22400,
    name: "AES Crypt (SHA256)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 22500,
    name: "MultiBit Classic .key (MD5)",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 22600,
    name: "Telegram Desktop < v2.1.14 (PBKDF2-HMAC-SHA1)",
    category: :instant_messaging,
    enabled: true
  },
  {
    hashcat_mode: 22700,
    name: "MultiBit HD (scrypt)",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 22911,
    name: "RSA/DSA/EC/OpenSSH Private Keys ($0$)",
    category: "private_key",
    enabled: true
  },
  {
    hashcat_mode: 22921,
    name: "RSA/DSA/EC/OpenSSH Private Keys ($6$)",
    category: "private_key",
    enabled: true
  },
  {
    hashcat_mode: 22931,
    name: "RSA/DSA/EC/OpenSSH Private Keys ($1, $3$)",
    category: "private_key",
    enabled: true
  },
  {
    hashcat_mode: 22941,
    name: "RSA/DSA/EC/OpenSSH Private Keys ($4$)",
    category: "private_key",
    enabled: true
  },
  {
    hashcat_mode: 22951,
    name: "RSA/DSA/EC/OpenSSH Private Keys ($5$)",
    category: "private_key",
    enabled: true
  },
  {
    hashcat_mode: 23001,
    name: "SecureZIP AES-128",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 23002,
    name: "SecureZIP AES-192",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 23003,
    name: "SecureZIP AES-256",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 23100,
    name: "Apple Keychain",
    category: "password_manager",
    enabled: true
  },
  {
    hashcat_mode: 23200,
    name: "XMPP SCRAM PBKDF2-SHA1",
    category: :instant_messaging,
    enabled: true
  },
  {
    hashcat_mode: 23300,
    name: "Apple iWork",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 23400,
    name: "Bitwarden",
    category: "password_manager",
    enabled: true
  },
  {
    hashcat_mode: 23500,
    name: "AxCrypt 2 AES-128",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 23600,
    name: "AxCrypt 2 AES-256",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 23700,
    name: "RAR3-p (Uncompressed)",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 23900,
    name: "BestCrypt v3 Volume Encryption",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 24100,
    name: "MongoDB ServerKey SCRAM-SHA-1",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 24200,
    name: "MongoDB ServerKey SCRAM-SHA-256",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 24300,
    name: "sha1($salt.sha1($pass.$salt))",
    category: :salted_hash,
    enabled: true
  },
  {
    hashcat_mode: 24410,
    name: "PKCS#8 Private Keys (PBKDF2-HMAC-SHA1 + 3DES/AES)",
    category: "private_key",
    enabled: true
  },
  {
    hashcat_mode: 24420,
    name: "PKCS#8 Private Keys (PBKDF2-HMAC-SHA256 + 3DES/AES)",
    category: "private_key",
    enabled: true
  },
  {
    hashcat_mode: 24500,
    name: "Telegram Desktop >= v2.1.14 (PBKDF2-HMAC-SHA512)",
    category: :instant_messaging,
    enabled: true
  },
  {
    hashcat_mode: 24600,
    name: "SQLCipher",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 24700,
    name: "Stuffit5",
    category: "archive",
    enabled: true
  },
  {
    hashcat_mode: 24800,
    name: "Umbraco HMAC-SHA1",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 24900,
    name: "Dahua Authentication MD5",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 25000,
    name: "SNMPv3 HMAC-MD5-96/HMAC-SHA1-96",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 25100,
    name: "SNMPv3 HMAC-MD5-96",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 25200,
    name: "SNMPv3 HMAC-SHA1-96",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 25300,
    name: "MS Office 2016 - SheetProtection",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 25400,
    name: "PDF 1.4 - 1.6 (Acrobat 5 - 8) - user and owner pass",
    category: "document",
    enabled: true
  },
  {
    hashcat_mode: 25500,
    name: "Stargazer Stellar Wallet XLM",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 25600,
    name: "bcrypt(md5($pass)) / bcryptmd5",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 25700,
    name: "MurmurHash",
    category: "raw_checksum",
    enabled: true
  },
  {
    hashcat_mode: 25800,
    name: "bcrypt(sha1($pass)) / bcryptsha1",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 25900,
    name: "KNX IP Secure - Device Authentication Code",
    category: :ftp_http_smtp_ldap_server,
    enabled: true
  },
  {
    hashcat_mode: 26000,
    name: "Mozilla key3.db",
    category: "password_manager",
    enabled: true
  },
  {
    hashcat_mode: 26100,
    name: "Mozilla key4.db",
    category: "password_manager",
    enabled: true
  },
  {
    hashcat_mode: 26200,
    name: "OpenEdge Progress Encode",
    category: :enterprise_application_software,
    enabled: true
  },
  {
    hashcat_mode: 26300,
    name: "FortiGate256 (FortiOS256)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 26401,
    name: "AES-128-ECB NOKDF (PT = $salt, key = $pass)",
    category: "raw_cipher",
    enabled: true
  },
  {
    hashcat_mode: 26402,
    name: "AES-192-ECB NOKDF (PT = $salt, key = $pass)",
    category: "raw_cipher",
    enabled: true
  },
  {
    hashcat_mode: 26403,
    name: "AES-256-ECB NOKDF (PT = $salt, key = $pass)",
    category: "raw_cipher",
    enabled: true
  },
  {
    hashcat_mode: 26500,
    name: "iPhone passcode (UID key + System Keybag)",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 26600,
    name: "MetaMask Wallet",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 26700,
    name: "SNMPv3 HMAC-SHA224-128",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 26800,
    name: "SNMPv3 HMAC-SHA256-192",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 26900,
    name: "SNMPv3 HMAC-SHA384-256",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 27000,
    name: "NetNTLMv1 / NetNTLMv1+ESS (NT)",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 27100,
    name: "NetNTLMv2 (NT)",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 27200,
    name: "Ruby on Rails Restful Auth (one round, no sitekey)",
    category: :framework,
    enabled: true
  },
  {
    hashcat_mode: 27300,
    name: "SNMPv3 HMAC-SHA512-384",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 27400,
    name: "VMware VMX (PBKDF2-HMAC-SHA1 + AES-256-CBC)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 27500,
    name: "VirtualBox (PBKDF2-HMAC-SHA256 & AES-128-XTS)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 27600,
    name: "VirtualBox (PBKDF2-HMAC-SHA256 & AES-256-XTS)",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 27700,
    name: "MultiBit Classic .wallet (scrypt)",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 27800,
    name: "MurmurHash3",
    category: "raw_checksum",
    enabled: true
  },
  {
    hashcat_mode: 27900,
    name: "CRC32C",
    category: "raw_checksum",
    enabled: true
  },
  {
    hashcat_mode: 28000,
    name: "CRC64Jones",
    category: "raw_checksum",
    enabled: true
  },
  {
    hashcat_mode: 28100,
    name: "Windows Hello PIN/Password",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 28200,
    name: "Exodus Desktop Wallet (scrypt)",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 28300,
    name: "Teamspeak 3 (channel hash)",
    category: :instant_messaging,
    enabled: true
  },
  {
    hashcat_mode: 28400,
    name: "bcrypt(sha512($pass)) / bcryptsha512",
    category: :forums_cms_ecommerce,
    enabled: true
  },
  {
    hashcat_mode: 28501,
    name: "Bitcoin WIF private key (P2PKH), compressed",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 28502,
    name: "Bitcoin WIF private key (P2PKH), uncompressed",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 28503,
    name: "Bitcoin WIF private key (P2WPKH, Bech32), compressed",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 28504,
    name: "Bitcoin WIF private key (P2WPKH, Bech32), uncompressed",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 28505,
    name: "Bitcoin WIF private key (P2SH(P2WPKH)), compressed",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 28506,
    name: "Bitcoin WIF private key (P2SH(P2WPKH)), uncompressed",
    category: "cryptocurrency",
    enabled: true
  },
  {
    hashcat_mode: 28600,
    name: "PostgreSQL SCRAM-SHA-256",
    category: :database_server,
    enabled: true
  },
  {
    hashcat_mode: 28700,
    name: "Amazon AWS4-HMAC-SHA256",
    category: :raw_hash_authenticated,
    enabled: true
  },
  {
    hashcat_mode: 28800,
    name: "Kerberos 5, etype 17, DB",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 28900,
    name: "Kerberos 5, etype 18, DB",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 29000,
    name: "sha1($salt.sha1(utf16le($username).':'.utf16le($pass)))",
    category: :operating_system,
    enabled: true
  },
  {
    hashcat_mode: 29100,
    name: "Flask Session Cookie ($salt.$salt.$pass)",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 29200,
    name: "Radmin3",
    category: :network_protocol,
    enabled: true
  },
  {
    hashcat_mode: 29311,
    name: "TrueCrypt RIPEMD160 + XTS 512 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29312,
    name: "TrueCrypt RIPEMD160 + XTS 1024 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29313,
    name: "TrueCrypt RIPEMD160 + XTS 1536 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29321,
    name: "TrueCrypt SHA512 + XTS 512 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29322,
    name: "TrueCrypt SHA512 + XTS 1024 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29323,
    name: "TrueCrypt SHA512 + XTS 1536 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29331,
    name: "TrueCrypt Whirlpool + XTS 512 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29332,
    name: "TrueCrypt Whirlpool + XTS 1024 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29333,
    name: "TrueCrypt Whirlpool + XTS 1536 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29341,
    name: "TrueCrypt RIPEMD160 + XTS 512 bit + boot-mode",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29342,
    name: "TrueCrypt RIPEMD160 + XTS 1024 bit + boot-mode",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29343,
    name: "TrueCrypt RIPEMD160 + XTS 1536 bit + boot-mode",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29411,
    name: "VeraCrypt RIPEMD160 + XTS 512 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29412,
    name: "VeraCrypt RIPEMD160 + XTS 1024 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29413,
    name: "VeraCrypt RIPEMD160 + XTS 1536 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29421,
    name: "VeraCrypt SHA512 + XTS 512 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29422,
    name: "VeraCrypt SHA512 + XTS 1024 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29423,
    name: "VeraCrypt SHA512 + XTS 1536 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29431,
    name: "VeraCrypt Whirlpool + XTS 512 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29432,
    name: "VeraCrypt Whirlpool + XTS 1024 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29433,
    name: "VeraCrypt Whirlpool + XTS 1536 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29441,
    name: "VeraCrypt RIPEMD160 + XTS 512 bit + boot-mode",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29442,
    name: "VeraCrypt RIPEMD160 + XTS 1024 bit + boot-mode",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29443,
    name: "VeraCrypt RIPEMD160 + XTS 1536 bit + boot-mode",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29451,
    name: "VeraCrypt SHA256 + XTS 512 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29452,
    name: "VeraCrypt SHA256 + XTS 1024 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29453,
    name: "VeraCrypt SHA256 + XTS 1536 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29461,
    name: "VeraCrypt SHA256 + XTS 512 bit + boot-mode",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29462,
    name: "VeraCrypt SHA256 + XTS 1024 bit + boot-mode",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29463,
    name: "VeraCrypt SHA256 + XTS 1536 bit + boot-mode",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29471,
    name: "VeraCrypt Streebog-512 + XTS 512 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29472,
    name: "VeraCrypt Streebog-512 + XTS 1024 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29473,
    name: "VeraCrypt Streebog-512 + XTS 1536 bit",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29481,
    name: "VeraCrypt Streebog-512 + XTS 512 bit + boot-mode",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29482,
    name: "VeraCrypt Streebog-512 + XTS 1024 bit + boot-mode",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29483,
    name: "VeraCrypt Streebog-512 + XTS 1536 bit + boot-mode",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29511,
    name: "LUKS v1 SHA-1 + AES",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29512,
    name: "LUKS v1 SHA-1 + Serpent",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29513,
    name: "LUKS v1 SHA-1 + Twofish",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29521,
    name: "LUKS v1 SHA-256 + AES",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29522,
    name: "LUKS v1 SHA-256 + Serpent",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29523,
    name: "LUKS v1 SHA-256 + Twofish",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29531,
    name: "LUKS v1 SHA-512 + AES",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29532,
    name: "LUKS v1 SHA-512 + Serpent",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29533,
    name: "LUKS v1 SHA-512 + Twofish",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29541,
    name: "LUKS v1 RIPEMD-160 + AES",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29542,
    name: "LUKS v1 RIPEMD-160 + Serpent",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29543,
    name: "LUKS v1 RIPEMD-160 + Twofish",
    category: :fulldisk_encryption_software,
    enabled: true
  },
  {
    hashcat_mode: 29600,
    name: "Terra Station Wallet (AES256-CBC(PBKDF2($pass)))",
    category: :cryptocurrency,
    enabled: true
  },
  {
    hashcat_mode: 29700,
    name: "KeePass 1 (AES/Twofish) and KeePass 2 (AES) - keyfile only mode",
    category: :password_manager,
    enabled: true
  },
  {
    hashcat_mode: 30000,
    name: "Python Werkzeug MD5 (HMAC-MD5 (key = $salt))",
    category: :framework,
    enabled: true
  },
  {
    hashcat_mode: 30120,
    name: "Python Werkzeug SHA256 (HMAC-SHA256 (key = $salt))",
    category: :framework,
    enabled: true
  },
  {
    hashcat_mode: 99999,
    name: "Plaintext",
    category: :plaintext,
    enabled: true
  }
].each do |hashcat_mode|
  HashType.find_or_create_by(hashcat_mode)
end
