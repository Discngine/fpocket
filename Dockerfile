FROM centos:7

#RUN yum -y install epel-release && yum -y update && yum -y install gcc gcc-c++ make netcdf-devel; yum clean all
RUN yum -y install gcc gcc-c++ make netcdf-devel; yum clean all

# all of this mess is essentially to have a minimalistic build at the end
COPY makefile /opt/fpocket/
COPY src /opt/fpocket/src
COPY man /opt/fpocket/man
COPY headers /opt/fpocket/headers
COPY obj /opt/fpocket/obj
COPY scripts /opt/fpocket/scripts
COPY bin /opt/fpocket/bin
COPY plugins/LINUXAMD64 /opt/fpocket/plugins/LINUXAMD64
COPY plugins/include /opt/fpocket/plugins/include
COPY plugins/noarch /opt/fpocket/plugins/noarch

WORKDIR /opt/fpocket

RUN make; make install; make clean

WORKDIR /WORKDIR

CMD ["fpocket"]