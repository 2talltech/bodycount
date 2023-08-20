package require Tcl 8.6-

# These commands can block for up to 20? seconds if samba is unavailable.
# This does not implement Kerberos, or NUMEROUS other samba features, sooo...
# not for a secure/corporate environment.
# This is telnet-level security - fine for a home LAN, behind a firewall.

namespace eval samba {
namespace export baseName cached connect creds dirname find get ls mess serverTitle servers \
	shareName sharePath shares tail valid
namespace ensemble create

# last msg from smbclient
variable msg

# cached shares and their credentials
variable conns

# gets or sets credentials ($conns)
# specify "import" or "export" for $op
# "export" returns a list of share-credential pairs
# "import" populates $conns with share-credential pairs,
# where $args is key, value, key, value, ...
proc creds { op {arg ""} } {
	variable conns
	if { ![info exists conns] } { return }
	switch $op {
	import {
		if {$arg eq ""} { return }
		foreach {key val} $arg {
			dict set conns $key $val
		}
	}
	export {
		return [dict get $conns]
	}
	default {
		; # TODO throw an error maybe?
	}
	} ; # switch
}

# like 'file dirname', but for samba
# expects path like '\\server\share\dir\path'
proc dirname { path } {
	set ln [string length $path]
	if {$ln < 3} { return $path }
	set a [string first \\ $path 2]
	if {$a == -1} { return $path }
	incr a
	if {$a == $ln} { return $path }
	set b [string first \\ $path $a]
	if {$b == -1} { return $path }
	if {[expr $b + 1] == $ln} { return $path }
	# set tree [string range $path $b end]
	set c [string last \\ $path]
	return [string range $path 0 $c-1]
}

# return the last bit of smbclient output
proc mess {} {
	variable msg
	return $msg
}

# test if $str begins with \\ (could be a samba location)
proc valid { str } {
	expr {[string first {\\} $str] == 0}
}

# get just the server part of $str, no \\
proc serverTitle { str } {
	set ind [string first \\ $str 2]
	if {$ind == -1} { return [string range $str 2 end] }
	return [string range $str 2 $ind-1]
}

# get the \\server part of $path
proc baseName { path } {
	set ind [string first \\ $path 2]
	if {$ind == -1} { return [string range $path 0 end] }
	return [string range $path 0 $ind-1]
}

# Get the \\server\share part of $path
# This does not handle malformed $path (\\SERVER\\share will return \\SERVER\),
# but if you have malformed path, you have other problems.
proc shareName { path } {
	set ind [string first \\ $path 2]
	if {$ind == -1} { return "" }
	set ind [string first \\ $path $ind+1]
	if {$ind == -1} { return $path }
	return [string range $path 0 $ind-1]
}

# Get the 'path' part of \\server\share\path
proc sharePath { path } {
	set ind [string first \\ $path 2]
	if {$ind == -1} { return "" }
	set ind [string first \\ $path $ind+1]
	if {$ind == -1} { return "" }
	return [string range $path $ind end]
}

# Returns a list of smb servers. DNS-SD is used for service discovery. This is
# often provided by 'avahi-daemon' on machines in the network. If 'avahi-browse'
# returns no services, check firewall rules. DOUBLE-CHECK firewall rules very
# carefully, and avahi-daemon configuration.
# 
# *This could block for some time.*
proc servers { } {
	variable msg
	set result [list]
	# -pt 'parse-friendly''terminate'
        set rc [catch { exec avahi-browse -pt _smb._tcp } msg]
        if { $rc == 0 } {
		# some sample outputs:
		# +;eno1;IPv4;funkbot;_smb._tcp;local
		# +;wlan0:IPv6;funkbot;Microsoft Windows Network;local
                set lns [split $msg \n]
                foreach ln $lns {
			set parts [split $ln \;]
			set ip [lindex $parts 2]
			set srvr {\\}
                        append srvr [lindex $parts 3]
			append srvr {.}
			append srvr [lindex $parts 5]
			# do not add duplicates
			set match 0
			foreach nm $result {if {$nm eq $srvr} {set match 1}}
			if {!$match} {lappend result $srvr}
		}
		return $result
        }
	puts stderr "samba unavailable"
	return ""
}

# Defaults to "anon" for anonymous access. Use "user%password" for actual credentials.
# Returns a list of accessible shares.
#
# *This could block for some time.*
proc shares { server { credentials anon }} {
	variable msg
	if {![valid $server]} { return "" }
	if {$credentials eq "anon"} {
		set rc [catch { exec smbclient -N -L $server } msg]
	} else {
		set rc [catch { exec smbclient -U $creds -L $server } msg]
	}
	if { $rc == 0 } {
		set lns [split $msg \n]
		foreach ln $lns {
			set ln [string trim $ln]
			if {[string range $ln end-3 end] eq "Disk"} {
				lappend dirs [string trim [string range $ln 0 end-4]]
			}
		}
		return $dirs
	}
	# samba error?
	return ""
}

proc cached { share } {
	variable conns
	if {[info exists conns]} {
		set lst [dict get $conns]
		foreach {key val} $lst {
			if {$key eq $share} { return true }
		}
	}
	return false
}

# Use "anon" for anonymous access or "user%password" for actual credentials.
# If the share is accessible, save the credentials and return true.
proc connect { share { credentials anon } } {
	variable msg
	variable conns

	if {![valid $share]} { return -1}
	if {$credentials eq ""} { return -1}
	if {$credentials eq "anon"} {
		set rc [catch { exec smbclient -N $share -c ls } msg]
	} else {
		set rc [catch { exec smbclient -U $credentials $share -c ls } msg]
	}
	if { $rc == 0 } {
		# success
		dict set conns $share $credentials
		return 0
	} elseif { [string first NT_STATUS_LOGON_FAILURE $msg] > -1 } {
		# bad password or username?
#		puts stderr "bad password or username"
		return 1
	} elseif { [string first NT_STATUS_ACCESS_DENIED $msg] > -1} {
		# anonymous login okay, but no access?
#		puts stderr "no anonymous access"
		return 2
	} elseif { [string first NT_STATUS_NOT_FOUND $msg] > -1 } {
		# bad share name or samba not running
#		puts stderr "bad share name or no service"
		return 3
	} elseif { [string first NT_STATUS_CONNECTION_REFUSED $msg ] > -1 } {
		# samba not running
#		puts stderr "no service"
		return 4
	}
	# undetermined (yet!)
	return 5
}

if 0 {
# sample 'smbclient' output for '-c cd dir ; ls'
  .                                   D        0  Wed Oct  5 04:49:42 2022
  ..                                  D        0  Wed Mar  1 14:45:47 2023
  settings                            D        0  Wed Jan 25 14:23:35 2023
  misc                                D        0  Fri Jan 20 02:28:13 2023
  hands                               D        0  Wed Jul 13 18:34:15 2022
  poses                               D        0  Mon May 23 22:17:48 2022
  feet                                D        0  Wed Jul 13 18:34:39 2022

                1921578192 blocks of size 1024. 1657774348 blocks available
} ; # endif

# Returns a dictionary, with a list for key 'dirs' and a list for key 'files'
# Entries are not fully-qualified, just file names.
proc ls { share {dir ""} } {
	variable msg
	variable conns

	set result [dict create dirs [list] files [list]]
	if {![valid $share]} {return $result}
	set creds [dict get $conns $share]
	if {$dir eq ""} {
		set rc [catch { exec smbclient -U $creds $share "-c ls" } msg]
	} else {
		set rc [catch { exec smbclient -U $creds $share "-c cd \"$dir\"; ls" } msg]
	}
	if {!$rc} {
		# bad dir?
		if {[string first NT_STATUS_OBJECT_NAME_NOT_FOUND $msg] > 0} { return $result }
		# skip first 2 lines "." and ".." and last 2 lines (total blocksize)
		set rcv [lrange [split $msg \n] 2 end-2]
                foreach line $rcv {
                        # work backwards from end of line
                        # strip date, time info, and blocksize
                        set ln [string replace $line end-34 end]
                        # get attributes
                        set attr [string range $ln end-6 end]
                        # and file/directory name, whitespace removed
                        set nm [string trim [string replace $ln end-6 end]]
                        # look for 'D' (directory) attribute amongst the mess
                        if { [string first D $attr] == -1 } {
                                dict lappend result files $nm
                        } else {
                                dict lappend result dirs $nm
                        }
                }
	} else { puts stderr $msg }
	return $result
}

# Traverse all subdirectories of 'share', beginning with initial directory 'dir', and
# find all files that match expression 'exp' (case-insensitive). Files are
# fully-qualified (e.g. \dir\subdir\filename)
proc find { share dir exp } {
	variable conns

	set result [list]
	if {![valid $share]} {return $result}
	set creds [dict get $conns $share]
	set entries [samba ls $share $dir]
	foreach f [dict get $entries files] {
		set fqn [string cat $dir \\ $f]
		if {[string match -nocase $exp $f]} {lappend result $fqn}
	}
	foreach d [dict get $entries dirs] {
		set fqn [string cat $dir \\ $d]
		append result " " [find $share $fqn $exp]
	}
	return $result
}

proc get { share remoteName localName } {
	variable msg
	variable conns

	if {![valid $share]} {error "Invalid share name"}
	set creds [dict get $conns $share]
	set rc [catch { exec smbclient -U $creds $share "-c get \"$remoteName\" \"$localName\""} msg opts]
	# TODO figure out errors, if any. smbclient returns non-zero on success
}

# return just the name part of \\server\share\path\name
proc tail { path } {
	set ind [string last \\ $path]
	if {$ind == -1} {return $path}
	return [string range $path $ind+1 end]
}

}
if 0 {
# sample usage
#set share \\\\FUNKBOT\\tenthousand
#set rc [samba connect $share goober%mysecretpassword]
if {!$rc} {
	set jpgs [samba find $share {refers\poses} {*.jpg}]
	puts "[llength $jpgs] files"
	set rc [catch { samba get $share {\refers\poses\sample.jpg} {/tmp/sample.jpg} } msg]
	if {$rc} { puts $msg }
}
} ; # endif
