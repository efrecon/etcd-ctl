FROM efrecon/tcl
MAINTAINER Emmanuel Frecon <emmanuel@sics.se>

# Set the env variable DEBIAN_FRONTEND to noninteractive to get
# apt-get working without error output.
ENV DEBIAN_FRONTEND noninteractive

# Update underlying ubuntu image and all necessary packages.
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y subversion

# Copy current version of the bridge software to /opt/bridge/
COPY *.tcl /opt/etcdctl/
RUN svn checkout https://github.com/efrecon/etcd-tcl/trunk/etcd /opt/etcdctl/lib/etcd

VOLUME /data
WORKDIR /data

# Arrange to autoexecute etcdctl on start, connecting to the interface that
# usually corresponds to docker0
ENTRYPOINT ["tclsh8.6", "/opt/etcdctl/etcdctl.tcl", "-peers", "172.17.42.1:4001"]
