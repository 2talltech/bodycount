namespace eval ttk::theme::app {
    variable colors
    array set colors {
	-background		"#383838"
	-foreground		"#cdd0d1"
	-selectbg		"#6aa0bd"
	-selectfg		"#ffffff"
	-disabledbg		"#3f3f3f"
	-disabledfg		"#8d8e8e"
	-window			"#404040"
	-button			"#454545"
	-hover			"#525252"
	-dark			"#cfcdc8"
	-darker			"#3d3d3d"
	-darkest		"#292929"
	-border			"#292929"
	-lighter		"#404040"
	-lightest 		"#787878"
	-altindicator		"#5895bc"
	-disabledaltindicator	"#a0a0a0"
    }
	font create myFont -family Helvetica -size 12
	font create urlFont -family Helvetica -size 12 -underline 1
	font create timerFont -family Helvetica -size 20
	#tk_setPalette #d6eadf

	ttk::style theme create app -parent clam -settings {

	ttk::style configure "." -font myFont

	# DO NOT REMOVE, the root window is stubborn
	tk_setPalette background $colors(-background)
	# root window style, which many controls inherit
	ttk::style configure "." \
	    	-bordercolor $colors(-border) \
		-background $colors(-background) \
	    	-foreground $colors(-foreground) \
		-selectbackground $colors(-selectbg) \
		-selectforeground $colors(-selectfg)
	ttk::style configure TButton \
	    	-anchor center -width -11 -padding 5 \
		-shiftrelief 2 -borderwidth 1
	ttk::style map TButton \
		-background [list !hover $colors(-button) hover $colors(-hover)] \
		-relief [list !hover flat hover solid] \
		-font [list !disabled myFont]
	ttk::style configure Flat.TButton -anchor w -relief flat -padding 2
	ttk::style map Flat.TButton \
		-background [list !hover $colors(-background) hover $colors(-selectbg)]

	font create fileChooserLabelFont -size 12 -weight bold
	ttk::style configure fileChooser.TLabel -font fileChooserLabelFont

	ttk::style map Accent.TButton \
		-relief [list !disabled solid] \
		-borderwidth [list !disabled 2]

	ttk::style map URL.TButton \
		-background [list !disabled $colors(-background)] \
		-relief [list !disabled flat] \
		-font [list !hover myFont hover urlFont]

	ttk::style configure TEntry -fieldbackground $colors(-window) -padding 5
	ttk::style configure TFrame -background $colors(-background)
	ttk::style configure TLabel -background $colors(-background)
	ttk::style configure Sash -sashthickness 6 -gripcount 10
	ttk::style configure TScrollbar \
		-background $colors(-lightest) \
		-bordercolor $colors(-border) \
		-lightcolor $colors(-window) \
		-darkcolor $colors(-window) \
		-troughcolor $colors(-window) \
		-gripcount 0


	} ; # ttk::style theme create app
} ; # namespace eval ttk::theme::app
