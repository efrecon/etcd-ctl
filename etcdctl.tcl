array set CTL {
    peers     {}
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
    -h       ""                  "Print this help and exit"
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

array set CTL {}
foreach {arg val dsc} $prg_args {
    set CTL($arg) $val
}

foreach opt [array names CTL -*] {
    getopt argv $opt CTL($opt) $CTL($opt)
}

# No remaining args? dump help and exit
if { [llength $argv] <= 0 } {
    ::help:dump "No command specified!"
}

# Declare context for peers
foreach pspec [split $CTL(-peers) ","] {
    foreach {hst prt} [split [string trim $pspec] :] break
    if { $prt eq "" } {
	lappend CTL(peers) [::etcd::new -host $hst]
    } else {
	lappend CTL(peers) [::etcd::new -host $hst -port $prt]
    }
}

switch -nocase -- [lindex $argv 0] {
    "write" {
	set dirname [lindex $argv 1]
	set fpath [lindex $argv 2]
	if { [catch {open $fpath} fd] == 0 } {
	    fconfigure $fd -encoding binary -translation binary
	    set fname [file tail $fpath]
	    set key [file join $dirname $fname]
	    set dta [read $fd]
	    foreach p $CTL(peers) {
		::etcd::write $p $key $dta
	    }
	    close $fd
	} else {
	    puts stderr "Could not open $fpath: $fd"
	}
    }
}

