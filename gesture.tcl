#!/usr/bin/wish
# TODO major rewrite with a namespace and possibly Windows,MacOS portability
# Bodycount depends on external binaries:
#   gnome-icon-theme imagemagick avahi-tools samba-client xdg-utils
# and other tcl packages
#   tcllib tcl-thread tkdnd
set state(title) "body count"
set state(version) "r2"
set state(url) "https://github.com/2talltech/bodycount"
# get the directory where this script resides
set thisFile [ dict get [ info frame 0 ] file ]
set state(dataDir) [ file dirname $thisFile ]
set state(appIcon) bodycount.png

package require Tcl 8.6-
package require Tk 8.6-
package require Thread 2.8-
# Tcllib
package require struct::list

# theme
source [file join $state(dataDir) theme.tcl]
ttk::style theme use app
# fileChooser
source [file join $state(dataDir) browse.tcl]

proc showDependencies { } {
	puts "body count depends on other system packages:\n  gnome-icon-theme\n  imagemagick\n  avahi-tools\n  samba-client\n  xdg-utils\n"
}

# determine ImageMagick version
set rc [catch { exec convert -version } msg]
if {$rc || [string first "ImageMagick" $msg] < 0} {
	set rc [catch { exec magick -version } msg]
	if {$rc || [string first "ImageMagick" $msg] < 0} {
		showDependencies
		exit
	} else { set MAGICK magick }
} else { set MAGICK convert }

# restore options
set restore 1
set initialCfg 1
set cfg [file join $env(HOME) .config bodycount]
set cfgFile [file join $cfg options.tcl]
if { ![file exists $cfg] } {
	set rc [catch { file mkdir $cfg } msg]
	if {$rc} {
		puts $msg
		set restore 0
	}
}
if { ![file exists $cfgFile] } {
	# try to create file for save state
	set rc [catch { set chan [open $cfgFile w 0600] } msg]
	if {$rc} {
		# give up
		puts $msg
		set restore 0
	} else {
		# ok
		close $chan
	}
} else {
	if { [file readable $cfgFile] && [file type $cfgFile] eq "file"} {
		set initialCfg 0
		# read $state() array
		source $cfgFile
	}
}
# no shenanigans
if { $initialCfg } {
	# initial window size
	set state(maximized) 0
	set state(size) 700x800
	# initial folder for the browser
	set state(folder) $env(HOME)
	# shuffle
	set state(shf) 1
	# theme
	set state(thm) {Moody Sunset}
	set state(creds) 0
}
# now attempt to restore our cached samba credentials
set credsFile [file join $cfg creds.smb]
if {$restore && $state(creds)} {
	if { ![file exists $credsFile] } {
		set rc [catch { set chan [open $credsFile w 0600] } msg]
		if {$rc} {
			puts $msg
			set restore 0
		} else {
			close $chan
		}
	} else {
		if { [file readable $credsFile] && [file type $credsFile] eq "file"} {
			# read $creds list
			source $credsFile
			samba creds import $creds
			set creds ""
		} else {
			puts "Cannot read credentials file."
			set restore 0
		}
	}
}

# all image resources
set state(icons) {background bnw color delay draw lborder logo menu next option order pause play previous rborder refresh open save shuffle}
set state(last) .mn.f.t1
set state(delay) 30
set state(images) 0
set state(i) 0
set state(files) ""
set state(build) 1
set state(play) 0
set state(tmpfile) ""
set state(stamp) 0
set state(imgobj) ""
set state(id) 0
set state(tid) 0
set state(time) 0
set state(themes) [list {Celestial Sea} {Moody Sunset}]
set state(smb) 0
set state(sharePath) ""
set state(smbDir) \\
set state(query) 0
set state(grayscale) 0

# generate a temporary filename
set chana [file tempfile state(tmpfile) gesture.png]
close $chana

# Traverse all subdirectories of 'dir' and
# find all files that match expression 'exp' (case-insensitive). Files are
# fully-qualified (e.g. \dir\subdir\filename)
proc find { dir exp } {
        set result [list]
        set dirs [lsort [glob -nocomplain -tails -directory $dir -types {d r} *]]
        set files [lsort [glob -nocomplain -tails -directory $dir -types {f r} $exp]]
        foreach f $files {
                set fqn [file join $dir $f]
                lappend result $fqn
        }
        foreach d $dirs {
                set fqn [file join $dir $d]
                append result " " [find $fqn $exp]
        }
        return $result
}

proc showFileChooser {} {
	pack forget .mn.f
	if {$::state(folder) ne ""} { fileChooser showPath $::state(folder) }
	fileChooser mapWindow
}

proc selectFolder {} {
	if {$::state(folder) eq ""} { return }
	if {[samba valid $::state(folder)]} {
		set ::state(smb) 1
		set ::state(smbDir) [samba sharePath $::state(folder)]
		set ::state(share) [samba shareName $::state(folder)]
		# (smbclient is not case-sensitive)
		set png_files [samba find $::state(share) $::state(smbDir) "*.png"]
		set jpg_files [samba find $::state(share) $::state(smbDir) "*.jpg"]
		set tl [samba tail $::state(folder)]
	} else {
		set ::state(smb) 0
		set png_files [find $::state(folder) *.{png,PNG}]
		set jpg_files [find $::state(folder) *.{jpg,JPG}]
		set tl [file tail $::state(folder)]
	}
	set ::state(files) [concat $png_files $jpg_files]
	set ::state(images) [llength $::state(files)]
	if {[string length $tl] > 30} {
		set fldr [string cat [string range $tl 0 26] "..."]
	} else {
		set fldr $tl
	}
	.mn.f.b configure -text $fldr
	.mn.f.msg configure -text "$::state(images) images"
	if {$::state(images)} {
		grid .mn.f.d
		focus .mn.f.d
	} else {
		grid remove .mn.f.d
	}
}

proc otherDelay { } {
}

proc incrLoop {} {
	set last [expr {$::state(images) - 1}]
	if {$::state(i) == $last} {
		set ::state(i) 0
        } else {
		incr ::state(i)
	}
}
proc decrLoop {} {
	set last [expr {$::state(images) - 1}]
	if {$::state(i) == 0} {
		set ::state(i) $last
	} else {
		incr ::state(i) -1
	}
}

proc wipeCanvas {} {
	.img delete "photo"
	image delete $::state(imgobj)
}

proc prepareImage {width height} {
	set filename [lindex $::state(files) $::state(i)]
	# obtain a good temporary filename
#	set chana [file tempfile ::state(tmpfile) gesture.png]
	set chana [file tempfile outfile gesture.png]
	set chanb [file tempfile infile gesture.png]
	close $chana
	close $chanb
	if {$::state(smb)} {
		set rc [catch { samba get $::state(share) "$filename" $infile } msg]
		if {$rc} {
			puts $msg
			return error
        	}
	} else {
		# ensure we don't accidentally alter/delete the original file
		# (redundant, but nice) (-force because we will overwrite the temp file)
		file copy -force $filename $infile
	}
	if {$::state(grayscale)} {
		set rc [catch { exec $::MAGICK "$infile" -colorspace Gray -auto-orient -resize ${width}x${height} "$outfile" } msg]
	} else {
		set rc [catch { exec $::MAGICK "$infile" -auto-orient -resize ${width}x${height} "$outfile" } msg]
	}
	# TODO log msg?
	if {$rc} {
		puts $msg
	}
	if {$::state(imgobj) != ""} { wipeCanvas }
	set ::state(imgobj) [image create photo -file $outfile]
	# careful!
	file delete $infile
	file delete $outfile
	return ok
}

proc drawCanvas {} {
	set w [winfo width .]
	set h [winfo height .]
	place .img -height $h -width $w -x 0 -y 0
	.img moveto "buttons" [expr ($w - 200) / 2] 2
	if {[prepareImage $w $h] eq "error"} { return error}
	set imgh [image height $::state(imgobj)]
	set imgw [image width $::state(imgobj)]
	.img create image [expr ($w - $imgw) / 2]  [expr ($h - $imgh) / 2] -image $::state(imgobj) -anchor nw -tags "photo"
}

proc advance {} {
	incrLoop
	drawCanvas
	reset
}

proc review {} {
	decrLoop
	drawCanvas
	reset
}

proc reset {} {
	if {$::state(play)} {
		after cancel $::state(id)
		after cancel $::state(tid)
	}
	if {!$::state(delay)} {
		.img delete "timer"
		.img create text 5 5 -text "Ꝏ" -anchor nw -fill white -tags "timer" -font timerFont
		return
	}
	set ::state(play) 1
	set ::state(time) $::state(delay)
	.img delete "timer"
	.img create text 5 5 -text "$::state(time)" -anchor nw -fill white -tags "timer" -font timerFont
	.img.play configure -image $::state(pauseImg)
	set ::state(id) [after [expr $::state(time) * 1000] {advance}]
	set ::state(tid) [after 1000 {updateTimer}]
}

proc play {} {
	if {!$::state(delay)} {
		return
	}
	.img.play configure -image $::state(pauseImg)
	set ::state(play) 1
	set ::state(id) [after [expr $::state(time) * 1000] {advance}]
	set ::state(tid) [after 1000 {updateTimer}]
}

proc pause {} {
	if {!$::state(delay)} {
		return
	}
	set ::state(play) 0
	after cancel $::state(id)
	after cancel $::state(tid)
	.img.play configure -image $::state(playImg)
}

# 'set .... [after 1000 {updateTimer}]' must be first statement
proc updateTimer {} {
	set ::state(tid) [after 1000 {updateTimer}]
	incr ::state(time) -1
	.img delete "timer"
	.img create text 5 5 -text "$::state(time)" -anchor nw -fill white -tags "timer" -font timerFont
}

proc playShow {} {
	place forget .mn
	set ::state(i) 0
	if {$::state(shf) == 1} {
		set ::state(files) [::struct::list shuffle $::state(files)]
	} else {
		set ::state(files) [lsort $::state(files)]
	}
	if {$::state(build)} {
		set ::state(build) 0
		set x 2
		.img create window $x 2 -anchor nw -window .img.menu -tags "buttons"
		incr x [winfo reqwidth .img.menu]
		.img create window $x 2 -anchor nw -window .img.prev -tags "buttons"
		incr x [winfo reqwidth .img.prev]
		.img create window $x 2 -anchor nw -window .img.play -tags "buttons"
		incr x [winfo reqwidth .img.play]
		.img create window $x 2 -anchor nw -window .img.next -tags "buttons"
		incr x [winfo reqwidth .img.next]
		.img create window $x 2 -anchor nw -window .img.refresh -tags "buttons"
		incr x [winfo reqwidth .img.refresh]
		.img create window $x 2 -anchor nw -window .img.bnw -tags "buttons"
		incr x [winfo reqwidth .img.bnw]
		.img create window $x 2 -anchor nw -window .img.open -tags "buttons"
	}
	focus .img.play
	# push out some extra configure events
	update
	drawCanvas
	reset
}

proc exitShow {} {
	pause
	place forget .img
	place .mn -x {-1} -y {-1} -relheight 1.0 -height 2 -relwidth 1.0 -width 2
	focus .mn.f.d
}

proc pauseBtn {} {
	if {$::state(play)} {
		pause
	} else {
		play
	}
}

# user-requested canvas refresh, reset timer
proc refreshBtn {} {
	drawCanvas
	reset
}

proc bnwBtn {} {
	set ::state(grayscale) [expr !$::state(grayscale)]
	if {$::state(grayscale)} {
		.img.bnw configure -image $::state(colorImg)
	} else {
		.img.bnw configure -image $::state(bnwImg)
	}
	refreshBtn
}

# xdg-open
proc openBtn {} {
	set filename [lindex $::state(files) $::state(i)]
	if {$::state(smb)} {
		set rc [catch { samba get $::state(share) "$filename" $::state(tmpfile) } msg]
		if {$rc} {
			puts $msg
			return
        	}
	} else {
		# ensure we don't accidentally alter/delete the original file
		# (redundant, but nice) (-force because we will overwrite the temp file)
		file copy -force "$filename" $::state(tmpfile)
	}
	set rc [catch { thread::create [list exec xdg-open $::state(tmpfile)] } msg]
	if {$rc} {
		puts $msg
	}
}

proc queryWnd { width height x y } {
	set ::state(maximized) [wm attributes . -zoomed]
	set ::state(size) ${width}x${height}+$x+$y
	set ::state(query) 0
}

# <Configure> events arrive in a flurry. Image rescaling is guaranteed
# to lag behind the window redraw time, so ignore <Configure> events for now.
# TODO make canvas an OpenGL canvas (!!)
proc wndResize { wnd width height x y } {
	# FYI, to maximize a window
	# Windows/Mac
	#wm state $win zoomed
	# X
	#wm attributes $win -zoomed 1
	if { $wnd eq "." } {
		if { $::state(query) eq 0 } {
			set ::state(query) [after 500 queryWnd $width $height $x $y]
		}	
	}
}

proc togDelay {wnd delay} {
	set ::state(delay) $delay
	$::state(last) configure -style TButton
	$wnd configure -style Accent.TButton
	set ::state(last) $wnd
}

proc shuffleBtn {} {
	if {$::state(shf) == 0} {
		set ::state(shf) 1
		.mn.f.f.shf configure -image $::state(shuffleImg)
	} else {
		set ::state(shf) 0
		.mn.f.f.shf configure -image $::state(orderImg)
	}
}

proc switchTheme {initial} {
	set chan [open [file join $::state(dataDir) $::state(thm) theme]]
	set data [read $chan]
	close $chan
	set lines [split $data \n]
	set pal [lindex $lines 0]
	set fnt [lindex $lines 1]
	set wnd [lindex $lines 2]
	set butt [lindex $lines 3]
	set hvr [lindex $lines 4]
	tk_setPalette background $pal foreground $fnt
	ttk::style configure app -background $pal -foreground $fnt -window $wnd -button $butt -hover $hvr
	ttk::style configure "." -background $pal -foreground $fnt
	ttk::style theme use app
	ttk::style configure TFrame -background $pal -foreground $fnt
	ttk::style configure TLabel -background $pal -foreground $fnt
	ttk::style configure TEntry -fieldbackground $wnd -foreground $fnt
	ttk::style map URL.TButton \
		-background [list !disabled $pal]
	set butt [lindex $lines 3]
	set hvr [lindex $lines 4]
	ttk::style map TButton \
		-background [list !hover $butt hover $hvr] \
		-foreground [list !disabled $fnt]
	ttk::style map Flat.TButton \
		-background [list !hover $pal hover $hvr] \
		-foreground [list !disabled $fnt]
	if {$initial} {
		foreach img $::state(icons) {
			set ::state(${img}Img) \
			[image create photo -file [file join $::state(dataDir) $::state(thm) $img.png]]
		}
	} else {
		# update fileChooser's iconlist with new style info (it caches -foreground color)
		fileChooser configure -style app
		foreach img $::state(icons) {
			image create photo \
			$::state(${img}Img) -file [file join $::state(dataDir) $::state(thm) $img.png]
		}
	}
}

proc openURL {} {
	exec xdg-open $::state(url)
}

proc optionBtn {} {
	pack forget .mn.f
#	place .op -x {-1} -y {-1} -relheight 1.0 -height 2 -relwidth 1.0 -width 2
	pack .mn.op -anchor center
}

proc saveOpts {} {
	pack forget .mn.op
	pack .mn.f -anchor center
}

proc selectTheme {args} {
	set ::state(thm) [join $args]
	switchTheme 0
}

proc fcCancel {} {
	fileChooser forgetWindow
	pack .mn.f -anchor center
}

proc fcOpen {} {
	set ::state(folder) [fileChooser getPath]
	selectFolder
	fileChooser forgetWindow
	pack .mn.f -anchor center
}

switchTheme 1
wm title . $::state(title)
wm geometry . $::state(size)
if { $::state(maximized) } { wm attributes . -zoomed }
wm iconphoto . -default [image create photo -file [file join $::state(dataDir) $::state(appIcon)]]

# menu frame
ttk::frame .mn
pack [ttk::label .mn.lb -image $::state(lborderImg)] -side left
pack [ttk::label .mn.rb -image $::state(rborderImg)] -side right
pack [ttk::label .mn.lo -image $::state(logoImg)] -side top
pack [ttk::frame .mn.f] -anchor center
pack [ttk::frame .mn.bf] -side bottom -fill x
pack [ttk::button .mn.bf.lnk -style URL.TButton -text $::state(url) -command openURL] -side left
pack [ttk::label .mn.bf.v -text $::state(version)] -side right
grid [ttk::frame .mn.f.spc1 -height 10m] -sticky we
grid [ttk::button .mn.f.b -text "select a folder" -command showFileChooser]
grid [ttk::frame .mn.f.spc2 -height 5m] -sticky we
grid [ttk::label .mn.f.msg -text "0 images"]
grid [ttk::frame .mn.f.spc3 -height 5m] -sticky we
grid [ttk::label .mn.f.l2 -image $::state(delayImg) -text "interval"]
grid [ttk::button .mn.f.t1 -style Accent.TButton -text "30s" -command {togDelay .mn.f.t1 30} ]
grid configure .mn.f.t1 -pady 1
grid [ttk::button .mn.f.t2 -text "45s" -command {togDelay .mn.f.t2 45} ]
grid [ttk::button .mn.f.t3 -text "1m"  -command {togDelay .mn.f.t3 60} ]
grid configure .mn.f.t3 -pady 1
grid [ttk::button .mn.f.t4 -text "2m"  -command {togDelay .mn.f.t4 120}]
grid [ttk::button .mn.f.t5 -text "5m"  -command {togDelay .mn.f.t5 300}]
grid configure .mn.f.t5 -pady 1
grid [ttk::button .mn.f.t6 -text "10m" -command {togDelay .mn.f.t6 600}]
grid [ttk::button .mn.f.t7 -text "Ꝏ" -command {togDelay .mn.f.t7 0}]
grid configure .mn.f.t7 -pady 1
# TODO other time dialog
#grid [ttk::button .f.t7 -text "other" -command otherDelay -state disabled]
#grid configure .f.t7 -pady 1
grid [ttk::frame .mn.f.spc4 -height 10m] -sticky we
grid [ttk::frame .mn.f.f]
pack [ttk::button .mn.f.f.opt -image $::state(optionImg) -text "option" -command optionBtn] -side left
pack [ttk::button .mn.f.f.shf -image $::state(shuffleImg) -text "shuffle" -command shuffleBtn] -side right -padx {1 0}
grid [ttk::frame .mn.f.spc5 -height 10m] -sticky we
ttk::button .mn.f.d -image $::state(drawImg) -text "draw!" -command playShow

# option frame
ttk::frame .mn.op
grid [ttk::frame .mn.op.spc1 -height 10m] -sticky we
grid [ttk::frame .mn.op.thm]
set oldpwd [pwd]
cd $::state(dataDir)
set dirs [glob -nocomplain -types d *]
foreach thm $dirs {
        # convert directory name to window name (as a courtesy):
        # remove common punctuation and make dirname lower-case
        set b [string tolower [string map {" " "" . "" , "" - "" + "" _ "" [ "" ] "" $ "" & "" % "" # "" @ "" ! ""} $thm]]
        # if it's dubious, forget it
        if [string is alnum $b] {
                # looking good so far, test the theme file for read access
		try {
	                set chan [open [file join $state(dataDir) $thm theme]]
		} on ok {} {
			# ok then
			close $chan
			set tmImg [image create photo -file [file join $::state(dataDir) $thm swatch.png]]
			grid [ttk::button .mn.op.thm.$b -image $tmImg -command "selectTheme $thm"]
		} on error {} {
			puts "skipping $thm"
		}
        } else {
                puts "skipping $thm"
        }
}
cd $oldpwd
grid [ttk::frame .mn.op.spc2 -height 10m] -sticky we
grid [ttk::button .mn.op.sav -image $::state(saveImg) -command saveOpts]

# directory browser
fileChooser buildWindow .mn fcCancel fcOpen

# image canvas
canvas .img -highlightthickness 0
.img create image 0 0 -image $::state(backgroundImg) -anchor nw -tags "background"
bind . <Configure> { wndResize %W %w %h %x %y }
ttk::button .img.menu -style kustom.TButton -image $::state(menuImg) -command exitShow
ttk::button .img.prev -style kustom.TButton -image $::state(previousImg) -command review
ttk::button .img.play -style kustom.TButton -image $::state(pauseImg) -command pauseBtn
ttk::button .img.next -style kustom.TButton -image $::state(nextImg) -command advance
ttk::button .img.refresh -style kustom.TButton -image $::state(refreshImg) -command refreshBtn
ttk::button .img.bnw -style kustom.TButton -image $::state(bnwImg) -command bnwBtn
ttk::button .img.open -style kustom.TButton -image $::state(openImg) -command openBtn

# show the menu and set focus button
place .mn -x {-1} -y {-1} -relheight 1.0 -height 2 -relwidth 1.0 -width 2
focus .mn.f.b

# cancel any modal dialog, so the app won't hang (see fileChooser.tcl)
bind . <Destroy> { set ::Modal.Result 2 }

# wait for the root window to close
# DRAW SOMETHING! LET'S FUCKING GOOOOOOOO!!
tkwait window .

# cleanup tmpfile
if { [file exists $state(tmpfile)] } { file delete $state(tmpfile) }

# save state to config folder
if { $restore } {
	if { [samba creds cached] } {
		set rc [catch { set chan [open $credsFile w 0600] } msg]
		if {$rc} {
			# give up
			puts $msg
		} else {
			# ok
			puts $chan "set creds \[list [samba creds export]\]"
			close $chan
			set state(creds) 1
		}
	}
	set rc [catch { set chan [open $cfgFile w 0600] } msg]
	if {$rc} {
		# give up
		puts $msg
	} else {
		# ok
		puts $chan [list array set state [list maximized $state(maximized) size $state(size) folder $state(folder) shf $state(shf) thm $state(thm) creds $state(creds)]]
		close $chan
	}
}
