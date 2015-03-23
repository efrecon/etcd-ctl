#! /usr/bin/env tclsh

array set CTL {
    peers     {}
    levels    {1 CRITICAL 2 ERROR 3 WARN 4 NOTICE 5 INFO 6 DEBUG}
    verbose   0
    write     {
	-ignore    {*~ *.bak}
	-encoding  "utf-8"
	-recurse   0
    }
}

set rootdir [file normalize [file dirname [info script]]]
lappend auto_path [file join $rootdir .. lib] [file join $rootdir lib]
foreach external [list etcd-tcl] {
    foreach td [list [file join $rootdir .. .. .. .. common $external] \
		    [file join $rootdir .. $external] \
		    [file join $rootdir .. lib $external]] {
	if { [file isdirectory $td] } {
	    lappend auto_path $td
	}
    }
}

package require etcd

set prg_args {
    -peers   {127.0.0.1:4001}    "Comma separated list of peers to communicate with"
    -v       0                   "Verbosity level \[0-6\]"
    -h       ""                  "Print this help and exit"
    -dryrun  0                   "Dry run will only show what would be done"
}

# Dump help based on the command-line option specification and exit.
proc ::help:dump { { hdr "" } } {
    if { $hdr ne "" } {
	puts $hdr
	puts ""
    }
    puts "NAME:"
    puts "\tetcdctl - A simple command line client for etcd"
    puts ""
    puts "USAGE"
    puts "\tetcdctl \[global options\] command \[command options\] \[arguments...\]"
    puts ""
    puts "COMMANDS:"
    puts "\twrite\tWrite content of file to key with same name"
    puts "\tput\tSet keys and to (new) values"
    puts "\tget\tGet content of keys"
    puts ""
    puts "GLOBAL OPTIONS:"
    foreach { arg val dsc } $::prg_args {
	puts "\t${arg}\t$dsc (default: ${val})"
    }
    exit
}


proc ::getopt {_argv name {_var ""} {default ""}} {
    upvar $_argv argv $_var var
    set pos [lsearch -regexp $argv ^$name]
    if {$pos>=0} {
	set to $pos
	if {$_var ne ""} {
	    set var [lindex $argv [incr to]]
	}
	set argv [lreplace $argv $pos $to]
	return 1
    } else {
	# Did we provide a value to default?
	if {[llength [info level 0]] == 5} {set var $default}
	return 0
    }
}

proc ::log { lvl msg} {
    global CTL

    if { $CTL(-v) >= $lvl } {
	array set L $CTL(levels)
	puts stderr "\[$L($lvl)\] $msg"
    }
}

array set CTL {}
foreach {arg val dsc} $prg_args {
    set CTL($arg) $val
}

if { [getopt argv -h] } {
    ::help:dump
}
for {set eaten ""} {$eaten ne $argv} {} {
    set eaten $argv
    foreach opt [array names CTL -*] {
	getopt argv $opt CTL($opt) $CTL($opt)
    }
}

# No remaining args? dump help and exit
if { [llength $argv] <= 0 } {
    ::help:dump "No command specified!"
}

# Hook in log facility in etcd
::etcd::verbosity $CTL(-v)
::etcd::logger ::log

# Declare context for peers
foreach pspec [split $CTL(-peers) ","] {
    foreach {hst prt} [split [string trim $pspec] :] break
    if { $prt eq "" } {
	lappend CTL(peers) [::etcd::new -host $hst]
    } else {
	lappend CTL(peers) [::etcd::new -host $hst -port $prt]
    }
}

proc ::cmdopt { cmd minargs {msg ""}} {
    global argv
    global CTL

    # Get default options for write command
    array set CMD {}
    if { [info exists CTL($cmd)] } {
	array set CMD $CTL($cmd)
    }
    
    # Parse command specific options
    foreach opt [array names CMD -*] {
	getopt argv $opt CMD($opt) $CMD($opt)
    }

    if { [llength $argv] < $minargs } {
	if { $msg eq "" } {
	    ::help:dump "$cmd takes at least $minargs argument(s)"
	} else {
	    ::help:dump $msg
	}
    }

    return [array get CMD]
}

proc ::wrKeys { dirname fspec wropts } {
    global CTL

    array set CMD $wropts
    foreach fpath [glob -nocomplain -- $fspec] {
	# If name of file matches ignore list, we won't write
	# the file.
	set ignore 0
	foreach ptn $CMD(-ignore) {
	    if { [string match $ptn [file tail $fpath]] } {
		log 5 "File $fpath matches $ptn, ignoring"
		set ignore 1
		break
	    }
	}
		
	if { !$ignore } {
	    if { [file isdirectory $fpath] } {
		if { [string is true $CMD(-recurse)] } {
		    log 5 "Recursing in $fpath to push to $dirname"
		    set ptn [file tail $fspec]
		    wrKeys \
			[file join $dirname [file tail $fpath]] \
			[file join $fpath $ptn] \
			$wropts
		}
	    } else {
		set fname [file tail $fpath]
		set key [file join $dirname $fname]
		log 5 "Reading content of file $fpath to key $key"
		if { [catch {open $fpath} fd] == 0 } {
		    fconfigure $fd -translation binary
		    if { $CMD(-encoding) ne "" } {
			fconfigure $fd -encoding $CMD(-encoding)
		    }
		    set dta [read $fd]
		    if { [string is false $CTL(-dryrun)] } {
			foreach p $CTL(peers) {
			    ::etcd::write $p $key $dta
			}
		    }
		    close $fd
		} else {
		    log 2 "Could not open $fpath: $fd"
		}
	    }
	}
    }
}


set cmd [string tolower [lindex $argv 0]]
set argv [lrange $argv 1 end]
switch -nocase -- $cmd {
    "write" {
	set wropts [::cmdopt $cmd 2 "CMD USAGE! $cmd etcd_dir file ..."]
	# Now find files to be written to etcd
	set dirname [lindex $argv 0]
	foreach fspec [lrange $argv 1 end] {
	    log 4 "Copying content of files matching $fspec into $dirname"
	    wrKeys $dirname $fspec $wropts
	}
    }
    "get" {
	array set CMD [::cmdopt $cmd 1 "CMD USAGE! $cmd key ..." ]
	
	foreach key $argv {
	    log 5 "Getting content of key $key"
	    if { [string is false $CTL(-dryrun)] } {
		foreach p $CTL(peers) {
		    puts "[::etcd::read $p $key]"
		}
	    }
	}
    }
    "put" {
	array set CMD [::cmdopt $cmd 2 "CMD USAGE! $cmd \[key val\] ..." ]
	
	foreach {key val} $argv {
	    log 5 "Setting content of key $key to $val"
	    if { [string is false $CTL(-dryrun)] } {
		foreach p $CTL(peers) {
		    puts "[::etcd::write $p $key $val]"
		}
	    }
	}
    }
}

