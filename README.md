# etcd-ctl
A (re)implementation of the etcd client in Tcl
# Usage
This behaves more or less similarly to etcdctl, except that it only has one command
at this time, `write` will write the content of a local file to a key in the etcd
key space.  The name of the key will be the same as the one of the local file.
