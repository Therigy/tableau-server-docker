FROM ubuntu:16.04

ENV container docker
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY

# Don't start any optional services except for the few we need.
RUN find /etc/systemd/system \
    /lib/systemd/system \
    -path '*.wants/*' \
    -not -name '*journald*' \
    -not -name '*systemd-tmpfiles*' \
    -not -name '*systemd-user-sessions*' \
    -exec rm \{} \;

RUN echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections && \
    echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" > /etc/apt/sources.list.d/webupd8team-java-trusty.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886 && \    
    apt-get update && \
    apt-get install -y \
    dbus wget oracle-java8-installer oracle-java8-set-default python3 python3-pip \
    alien at autotools-dev bash-completion bc bsdmainutils ca-certificates-java \
    cpio cron cups-bsd cups-client cups-common debhelper debugedit \
    dh-strip-nondeterminism distro-info-data ed fontconfig fontconfig-config \
    freeglut3 fuse gettext gettext-base groff-base intltool-debian krb5-locales \
    lib32z1 libarchive-zip-perl libarchive13 libasprintf-dev libasprintf0v5 \
    libavahi-client3 libavahi-common-data libavahi-common3 \
    libboost-filesystem1.58.0 libboost-system1.58.0 libbsd0 libc6-i386 \
    libcapnp-0.5.3 libcroco3 libcups2 libcupsfilters1 libcupsimage2 \
    libdrm-amdgpu1 libdrm-common libdrm-intel1 libdrm-nouveau2 libdrm-radeon1 \
    libdrm2 libedit2 libegl1-mesa libelf1 libffi6 \
    libfile-stripnondeterminism-perl libfontconfig1 libfuse2 libgbm1 \
    libgettextpo-dev libgettextpo0 libgl1-mesa-dri libgl1-mesa-glx libglapi-mesa \
    libglib2.0-0 libglib2.0-data libgnutls30 libgssapi-krb5-2 libhogweed4 \
    libicu55 libjbig0 libjpeg-turbo8 libjpeg8 libk5crypto3 libkeyutils1 \
    libkrb5-3 libkrb5support0 libllvm5.0 liblua5.2-0 liblzo2-2 \
    libmail-sendmail-perl libmirclient9 libmircommon7 libmircore1 \
    libmirprotobuf3 libnettle6 libnspr4 libnss3 libnss3-nssdb libp11-kit0 \
    libpciaccess0 libpipeline1 libpopt0 libprotobuf-lite9v5 librpm3 librpmbuild3 \
    librpmio3 librpmsign3 libsensors4 libsigsegv2 libsys-hostname-long-perl \
    libtasn1-6 libtiff5 libtimedate-perl libtxc-dxtn-s2tc0 libunistring0 \
    libwayland-client0 libwayland-server0 libx11-6 libx11-data libx11-xcb1 \
    libxau6 libxcb-dri2-0 libxcb-dri3-0 libxcb-glx0 libxcb-present0 libxcb-sync1 \
    libxcb-xfixes0 libxcb1 libxcomposite1 libxdamage1 libxdmcp6 libxext6 gdebi-core \
    libxfixes3 libxi6 libxkbcommon0 libxml2 libxrender1 libxshmfence1 libxslt1.1 \
    libxxf86vm1 lsb-core lsb-invalid-mta lsb-release lsb-security m4 man-db \
    ncurses-term net-tools pax po-debconf psmisc rpm rpm-common rpm2cpio rsync \
    s-nail sgml-base shared-mime-info time ucf xdg-user-dirs xkb-data xml-core sudo && \
    apt-get clean && \
    pip3 install awscli && \
    rm -rf /var/lib/apt/lists/* && \
    adduser --disabled-password --gecos "" tsm && \
    usermod -aG sudo tsm && \
    mkdir -p /opt/tableau/docker_build /etc/systemd/system/ && \
    (echo tsm:tsm | chpasswd) && \
    (echo 'tsm ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tsm)


RUN systemctl set-default multi-user.target

COPY support/scripts/setup-systemd /sbin/

STOPSIGNAL SIGRTMIN+3

ENV TABLEAU_VERSION="10-5-1"
ENV LANG=en_US.UTF-8

# Did not combine this into the next RUN instruction because this file is large (150 MB) and takes forever to download
#RUN echo "version: "$(echo "$TABLEAU_VERSION" | sed 's/-/./')
#wget https://downloads.tableau.com/esdalt/$(echo "$TABLEAU_VERSION" | sed 's/-/./')/tableau-server-${TABLEAU_VERSION}_amd64.deb
#RUN ewgtfgreh

RUN apt-get update && \
    apt-get install -y iproute && \
    wget https://downloads.tableau.com/drivers/linux/deb/tableau-driver/tableau-postgresql-odbc_9.5.3_amd64.deb && \
    wget https://downloads.tableau.com/drivers/linux/deb/tableau-driver/tableau-freetds_1.00.40_amd64.deb && \
    wget https://downloads.tableau.com/esdalt/$(echo $TABLEAU_VERSION | sed 's/-/\./g')/tableau-server-${TABLEAU_VERSION}_amd64.deb && \
    gdebi tableau-postgresql-odbc_9.5.3_amd64.deb && \
    gdebi tableau-freetds_1.00.40_amd64.deb

COPY config/* /opt/tableau/docker_build/

RUN cp /opt/tableau/docker_build/tableau_server_install.service /etc/systemd/system/ && \
    sed -i 's/PrivateTmp.*//' /lib/systemd/system/systemd-localed.service && \
    sed -i 's/PrivateDevices.*//' /lib/systemd/system/systemd-localed.service && \
    sed -i 's/PrivateNetwork.*//' /lib/systemd/system/systemd-localed.service && \
    #sed -i 's/ProtectSystem.*//' /lib/systemd/system/systemd-localed.service && \
    #sed -i 's/ProtectHome.*//' /lib/systemd/system/systemd-localed.service && \
    sed -i 's/PrivateTmp.*//' /lib/systemd/system/systemd-hostnamed.service && \
    sed -i 's/PrivateDevices.*//' /lib/systemd/system/systemd-hostnamed.service && \
    sed -i 's/PrivateNetwork.*//' /lib/systemd/system/systemd-hostnamed.service && \
    sed -i 's/ProtectSystem.*//' /lib/systemd/system/systemd-hostnamed.service && \
    sed -i 's/ProtectHome.*//' /lib/systemd/system/systemd-hostnamed.service && \
    touch /etc/locale.conf && \
    touch /etc/vconsole.conf && \
    touch /etc/default/keyboard && \
    systemctl enable systemd-localed && \
    systemctl enable systemd-hostnamed && \
    systemctl enable tableau_server_install && \
    (echo 'tableau ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tableau) && \
    locale-gen en_US.UTF-8 && \
    localedef -i en_US -c -f UTF-8 en_US.UTF-8 && \
    echo "LANG=en_US.UTF-8" >> /etc/default/locale && \
    echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale && \
    echo "LANGUAGE=en_US.UTF-8" >> /etc/default/locale && \
    mv tableau-server-${TABLEAU_VERSION}_amd64.deb tableau-server.deb

 
EXPOSE 80 8850

# Workaround for docker/docker#27202, technique based on comments from docker/docker#9212
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
