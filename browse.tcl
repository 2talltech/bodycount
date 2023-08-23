# Example usage:
# set dir [fileChooser chooseDirectory]
#
# external package dependencies (not Tcl/Tk): gnome-icon-theme samba-client
#
package require Tk
# get the directory where this script resides
set thisFile [ dict get [ info frame 0 ] file ]
set dataDir [ file dirname $thisFile ]
source [file join $dataDir iconlist.tcl]
source [file join $dataDir samba.tcl]

namespace eval fileChooser {
namespace export buildWindow configure forgetWindow mapWindow getPath showPath
namespace ensemble create 

variable parent
variable cbCancel
variable cbOpen
variable showFiles
variable cmdpath
variable milist
variable myFont
variable locImg [image create photo -file /usr/share/icons/gnome/16x16/places/folder.png]
variable locRemoteImg [image create photo -file /usr/share/icons/gnome/16x16/places/folder-remote.png]
variable dirImg [image create photo -file /usr/share/icons/gnome/32x32/places/folder.png]
variable remoteImg [image create photo -file /usr/share/icons/gnome/32x32/places/folder-remote.png]
variable fileImg [image create photo -file /usr/share/icons/gnome/32x32/mimetypes/text-x-preview.png]
variable loc
variable locs
variable smb
variable server
variable share
variable path
variable creds

proc configure { args } {
	variable milist
	foreach {opt val} $args {
		switch -- $opt {
		-style {
			$milist configure -style $val
			$milist deleteall

		}
		default {error "bad option to fileChooser::configure"}
		}
	}
}

proc setFont { fnt } {
	variable myFont fnt
}

# adds all existing xdg-dirs
# sets initial path to home folder
# TODO add specific icons for xdg-dirs
proc xdgLocs {} {
	variable path
	variable loc
	variable locs
	
	# test xdg-user-dir
	set rc [catch { exec xdg-user-dir HOME } msg]
	if { $rc == 0 } {
		set path $msg
		foreach xloc [list HOME DESKTOP DOCUMENTS DOWNLOAD MUSIC PICTURES PUBLICSHARE TEMPLATES VIDEOS] {
			set xdir [exec xdg-user-dir $xloc]
			if {[file exists $xdir]} {
				set loc($xloc) $xdir
				lappend locs $xloc
			}
		}
	} else {
		if { $path eq "" } {
			set path $env(HOME)
		}
		set loc(HOME) $path
		lappend locs HOME
	}
}


proc sambaLocs {} {
	variable loc
	variable locs
	set srvrs [samba servers]
	foreach srv $srvrs {
		set nm [samba serverTitle $srv]
		set loc($nm) $srv
		lappend locs $nm
	}
}

proc mapWindow {} {
	variable parent
	pack $parent.dlg -anchor center -expand 1 -fill both
	focus $parent.dlg.b.c
}

proc forgetWindow {} {
	variable parent
	pack forget $parent.dlg
}

proc showPath { pth } {
	variable parent
	variable path $pth
	variable smb
	variable server
	variable share
	variable dirs
	variable fls
	variable milist
	variable fileImg
	variable dirImg
	variable remoteImg
	variable creds
	variable showFiles

	$parent.dlg configure -cursor watch ; update
	if {[samba valid $path]} {
		set smb 1	
                set server [samba baseName $path]
                set share [samba shareName $path]
               	set path [samba sharePath $path]
		if {$share ne ""} {
			if {![samba cached $share]} {
				set creds ""
				# try anonymous first
				set rc [samba connect $share]
				if {$rc == 0} {
					set creds "anon"
				} elseif {$rc == 1 || $rc == 2} {
					# bad password or username or access denied
					getCredentials
				} else {
					# oh well
					set share ""
					tk_messagebox -type ok -message \
						"Cannot connect to share.\n\n[samba mess]"
					$parent.dlg configure -cursor "" ; update
					return
				}
				if {$creds ne "anon"} {
					set rc [samba connect $share $creds]
					while {$rc == 1} {
						# bad password or username
						getCredentials
						set rc [samba connect $share $creds]
					}
					if {$rc} {
						if {$creds == ""} {
							# user canceled credentials dialog
							set share ""
							$parent.dlg configure -cursor "" ; update
							return
						}
						 # give up
						set share ""
						set creds "" ; # possibly no good
						tk_messageBox -type ok -message \
						"Cannot connect to share.\n\n[samba mess]"
						$parent.dlg configure -cursor "" ; update
						return
					}
				}
			}
			set creds "" ; # samba cached it
			set entries [samba ls $share $path]
			set dirs [lsort [dict get $entries dirs]]
			set fls [lsort [dict get $entries files]]
			$milist deleteall
			$milist add $remoteImg $dirs
			if {$showFiles} {$milist add $fileImg $fls}
			setCmdpath $share$path
		} else {
			locInvoke [samba serverTitle]
		}
	} else {
		set smb 0
		set dirs [lsort [glob -nocomplain -tails -directory $path -types {d r} *]]
		set fls [lsort [glob -nocomplain -tails -directory $path -types {f r} *]]
		$milist deleteall
		$milist add $dirImg $dirs
		setCmdpath $path
		if {$showFiles} {$milist add $fileImg $fls}
	}
	$parent.dlg configure -cursor "" ; update
}

proc upDir { } {
	variable share
	variable path
	variable smb
	if {$smb} {
		set path [samba dirname $share$path]
	} else {
		set path [file dirname $path]
	}
	showPath $path
}

proc normalize { itm } {
	return [string map { . _ } $itm]
}

proc setCmdpath { txt } {
	variable cmdpath
	set MAX_CMD 40

	if { [string length $txt] > $MAX_CMD } {
		append pth "..." [string range $txt end-$MAX_CMD end]
		$cmdpath configure -text $pth
	} else {	
		$cmdpath configure -text $txt
	}
}

proc buildWindow { par cbCncl cbOpn {pth ""}} {
	variable parent $par
	variable cbCancel $cbCncl
	variable cbOpen $cbOpn
	variable showFiles 0 ; # act as folder selection
	variable milist
	variable cmdpath
	variable loc
	array unset loc
	variable locs
	unset -nocomplain locs
	variable locImg
	variable locRemoteImg
	variable dirImg
	variable remoteImg
	variable fileImg
	variable dirs
	variable fls
	variable smb 0
	variable server
	variable share
	variable path

	xdgLocs
	sambaLocs
	if {$pth ne ""} { set path $pth }
	ttk::frame $parent.dlg
	ttk::panedwindow $parent.dlg.p -orient horizontal
	pack [ttk::frame $parent.dlg.l] -expand 1 -fill both
	foreach itm $locs {
		if {[string range $loc($itm) 0 1] eq {\\} } {
			grid [ttk::button $parent.dlg.l.loc([normalize $itm]) -image $locRemoteImg -text $itm -compound left \
				-command "fileChooser::locInvoke $itm" -style Flat.TButton] -sticky we
		} else {
			grid [ttk::button $parent.dlg.l.loc([normalize $itm]) -image $locImg -text [file tail $loc($itm)] -compound left \
				-command "fileChooser::locInvoke $itm" -style Flat.TButton] -sticky we
		}
	}
	$parent.dlg.p add $parent.dlg.l
	pack [ttk::frame $parent.dlg.f] -expand 1 -fill both
	pack [ttk::frame $parent.dlg.f.f] -side top -fill x
	set cmdpath $parent.dlg.f.f.path

	pack [ttk::label $cmdpath -style fileChooser.TLabel] -side left
	setCmdpath $path
	pack [ttk::button $parent.dlg.f.f.up -text "<<" -command fileChooser::upDir] -side right
	pack [ttk::separator $parent.dlg.f.f.sep -orient horizontal] -side bottom
	set milist $parent.dlg.f.w
	::tk::MiconList create $milist -command fileChooser::dlgInvoke -font myFont
	showPath $path
	pack $milist -anchor center -expand 1 -fill both
	$parent.dlg.p add $parent.dlg.f
	pack $parent.dlg.p -anchor center -expand 1 -fill both
	pack [ttk::frame $parent.dlg.b] -side bottom -fill x
	pack [ttk::button $parent.dlg.b.x -text "Open" -command fileChooser::selectDir] -side right
	pack [ttk::button $parent.dlg.b.c -text "Cancel" -command fileChooser::cancel] -side right
}

proc locInvoke { l } {
	variable showFiles
	variable milist
	variable smb
	variable path
	variable dirs [list]
	variable fls [list]
	variable dirImg
	variable fileImg
	variable remoteImg
	variable server
	variable share
	variable loc

	$milist deleteall
	if {[samba valid $loc($l)]} {
		set smb 1
		set path ""
		set share ""
		set server $loc($l)
		set dirs [lsort [samba shares $loc($l) anon]]
		$milist add $remoteImg $dirs
		setCmdpath $server
	} else {
		# local filesystem
		set smb 0
		set path $loc($l)
		set dirs [lsort [glob -nocomplain -tails -directory $path -types {d r} *]]
		set fls [lsort [glob -nocomplain -tails -directory $path  -types {f r} *]]
		$milist add $dirImg $dirs
		if {$showFiles} {$milist add $fileImg $fls}
		setCmdpath $path
	}
}

# Show.Modal win ?-onclose script? ?-destroy bool?
# display $win as a modal dialog
# (courtesy "Duoas", https://wiki.tcl-lang.org/page/Modal dialogs)
#
# If -destroy is true then $win is destroyed when the dialog is closed.
# Otherwise, caller must do it.
#
# If an -onclose script is provided, it is executed if the user terminates the
# dialog through the window manager (such as clicking on the [X] button on the
# window decoration), and the result of that script is returned. The default
# script does nothing and returns an empty string.
#
# Otherwise, the dialog terminates when the global :Modal.Result is set to a value.
#
# Do not use more than one modal dialog.
#
# Ex:
#   -onclose {return cancel} -->  Show.Modal returns the word 'cancel'
#   -onclose {list 1 2 3}    -->  Show.Modal returns the list {1 2 3}
#   -onclose {set ::x zap!}  -->  zap!
#
proc Show.Modal { win args } {
        set ::Modal.Result {}
        array set options [list -onclose {} -destroy 0 {*}$args]
        wm transient $win .
        wm protocol $win WM_DELETE_WINDOW [list catch $options(-onclose) ::Modal.Result]
        set x [expr {([winfo width .] - [winfo reqwidth $win]) / 2 + [winfo rootx .]}]
        set y [expr {([winfo height .] - [winfo reqheight $win]) / 2 + [winfo rooty .]}]
        wm geometry $win +$x+$y
        raise $win
        focus $win
        grab $win
        tkwait variable ::Modal.Result
        grab release $win
        if {$options(-destroy)} {destroy $win}
        return ${::Modal.Result}
}

proc dlgOk {} {
	variable creds
	set creds [string cat [.dlg.f.user get] % [.dlg.f.pass get]]
	set ::Modal.Result 1
}

proc dlgCancel {} {
	variable creds
	set creds ""
	set ::Modal.Result 2
}

proc getCredentials {} {
	variable share
        # dialog window
	toplevel .dlg
	wm title .dlg "$share"
	pack [ttk::frame .dlg.f] -side top -expand 1 -fill x -padx 10 -pady 10
	grid [ttk::label .dlg.f.lu -text "Username"] -column 0 -row 0
	grid [ttk::entry .dlg.f.user] -column 1 -row 0
	grid [ttk::label .dlg.f.lp -text "Password"] -column 0 -row 1
	grid [ttk::entry .dlg.f.pass] -column 1 -row 1
	pack [ttk::frame .dlg.bf] -side bottom -expand 1 -fill x -padx 10 -pady 10
	pack [ttk::button .dlg.bf.ok -text "Open" -command fileChooser::dlgOk] -side right 
	pack [ttk::button .dlg.bf.cancel -text "Cancel" -command fileChooser::dlgCancel] -side left
        bind .dlg <Return> fileChooser::dlgOk
        bind .dlg <Escape> fileChooser::dlgCancel
        # Okay button
        focus .dlg.f.user
        Show.Modal .dlg -destroy 1 -onclose fileChooser::dlgCancel
}

proc dlgInvoke {} {
	variable parent
	variable showFiles
	variable milist
	variable smb
	variable dirs
	variable fls
	variable dirImg
	variable fileImg
	variable remoteImg
	variable server
	variable share
	variable path
	variable creds

	set i [$milist selection get]
	set sel [$milist get $i]
	# do nothing for files
	if { $i >= [llength $dirs] } { return }

	$parent.dlg configure -cursor watch ; update
	if { $smb } {
		if {$share eq ""} {
			set share [string cat $server \\ $sel]
			set path ""
			# TODO much more testing! only tested with Samba server on a LAN with a
			# fixed username and password
			# This is a tricky bit...
			if {![samba cached $share]} {
				set creds ""
				# try anonymous first
				set rc [samba connect $share]
				if {$rc == 0} {
					set creds "anon"
				} elseif {$rc == 1 || $rc == 2} {
					# bad password or username or access denied
					getCredentials
				} else {
					# oh well
					set share ""
					tk_messagebox -type ok -message \
						"Cannot connect to share.\n\n[samba mess]"
					$parent.dlg configure -cursor "" ; update
					return
				}
				if {$creds ne "anon"} {
					set rc [samba connect $share $creds] 
					while {$rc == 1} {
						# bad password or username
						getCredentials
						set rc [samba connect $share $creds]
					}
					if {$rc} {
						if {$creds == ""} {
							# user canceled credentials dialog
							set share ""
							$parent.dlg configure -cursor "" ; update
							return
						}
						# give up
						set share ""
						set creds "" ; # possibly no good
						tk_messageBox -type ok -message \
						"Cannot connect to share.\n\n[samba mess]"
						$parent.dlg configure -cursor "" ; update
						return
					}
				}
			}
			setCmdpath $share
		} else {
			append path \\ $sel
			setCmdpath $share$path
		}
		set creds "" ; # samba cached it
		# set result [samba ls $share $path]
		set entries [samba ls $share $path]
		set dirs [lsort [dict get $entries dirs]]
		set fls [lsort [dict get $entries files]]
		$milist deleteall
		$milist add $remoteImg $dirs
	} else {
		set path [file join $path $sel]
		setCmdpath $path
		set dirs [lsort [glob -nocomplain -tails -directory $path -types {d r} *]]
		set fls [lsort [glob -nocomplain -tails -directory $path -types {f r} *]]
		$milist deleteall
		$milist add $dirImg $dirs
	}
	if {$showFiles} {$milist add $fileImg $fls}
	$parent.dlg configure -cursor "" ; update
}

proc cancel {} {
	variable cbCancel
	$cbCancel
}

proc selectDir {} {
	variable parent
	variable cbOpen
	$parent.dlg configure -cursor watch ; update
	$cbOpen
	$parent.dlg configure -cursor "" ; update
}

proc getPath {} {
	variable smb
	variable share
	variable path
	if {$smb} { return $share$path }
	return $path
}

} ; # namespace

