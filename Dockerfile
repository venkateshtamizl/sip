FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
  build-essential \
  wget \
  git \
  subversion \
  libjansson-dev \
  libxslt1-dev \
  xsltproc \
  libxml2-dev \
  uuid-dev \
  libedit-dev \
  libssl-dev \
  libncurses5-dev \
  curl \
  pkg-config \
  libsqlite3-dev \
  ca-certificates \
  libsrtp2-dev \
  libopus-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

# Build pjproject (PJSIP)
RUN git clone https://github.com/pjsip/pjproject.git && \
  cd pjproject && \
  ./configure CFLAGS="-DNDEBUG -DPJ_HAS_IPV6=1" && \
  make -j$(nproc) && make install && ldconfig

# Build Asterisk 20.x
RUN git clone -b 20 https://github.com/asterisk/asterisk.git

WORKDIR /usr/src/asterisk

# keep mp3/samples/etc and enable codecs/features you need
RUN contrib/scripts/get_mp3_source.sh && \
  ./configure && \
  make menuselect.makeopts && \
  menuselect/menuselect --enable chan_pjsip \
                        --enable res_http_websocket \
                        --enable format_mp3 \
                        --enable res_srtp \
                        --enable codec_opus \
                        menuselect.makeopts && \
  make -j$(nproc) && make install && make samples && make config && ldconfig

# Add entrypoint script (will copy local configs into container and start Asterisk)
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 5060/udp 5060/tcp 5061/tcp 8088/tcp 8089/tcp 10000-20000/udp

# Use entrypoint to replace configs from mounted local directory and then start asterisk
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/sbin/asterisk", "-f", "-U", "root", "-vvv"]
