# etcd-ctl

A (re)implementation of the etcd client in Tcl

## Usage

This behaves more or less similarly to `etcdctl`, except that it only
has one command at this time, `write` will write the content of a
local file to a key in the etcd key space.  The name of the key will
be the same as the one of the local file.  Other commands are rather
trivial to be implemented, they were left aside as an exercise.
However, `write` does not exist in the original client...

In other words, if you want to write the content of a file called
`README.md` into the directory called `/test` in the etcd key space,
you would write:

    tclsh8.6 etcdctl.tcl write /test README.md

Note that the name of the file really is a globbing pattern, meaning
that given a directory called `/home/emmanuel/mydir` on your local
disk, the following command would mirror all the files that it
contains (not recursively) into the etcd key space.  This would ignore
backup files as these are ignored by default.

    tclsh8.6 etcdctl.tcl write /test /home/emmanuel/mydir/*

## Docker

This project is automatically being built at the docker hub. To run a
similar example to the one above, you would then do as follows:

    docker run -it --rm -v /home/xxxx/:/data efrecon/etcdctl write /test README.md

Assuming the file to be written was located in the directory
`/home/xxxx/`.  Note that `/data` is exported by the Dockerfile so
that it can be mounted from within the component to access your
localfiles.  `/data` is also made the default working directory in the
Dockerfile.