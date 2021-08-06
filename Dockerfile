FROM ubuntu:18.04

RUN apt -y update
RUN apt-get install -y build-essential
RUN apt-get install -y libnetcdf-dev libnetcdff-dev

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
