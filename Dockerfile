FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
  build-essential \
  wget \
  git \
  subversion \
  libjansson-dev \
  libxml2-dev \
  libxslt1-dev \
  libsqlite3-dev \
  libedit-dev \
  libssl-dev \
  uuid-dev \
  libncurses5-dev \
  libncurses-dev \
  libsrtp2-dev \
  libopus-dev \
  libmp3lame-dev \
  libspeex-dev \
  libspeexdsp-dev \
  libogg-dev \
  libvorbis-dev \
  ca-certificates \
  automake \
  autoconf \
  libtool \
  pkg-config \
  curl \
  yasm \
  nasm \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

# ------------------------------
# Build PJSIP (pjproject)
# ------------------------------
RUN git clone https://github.com/pjsip/pjproject.git && \
  cd pjproject && \
  ./configure CFLAGS="-DNDEBUG -DPJ_HAS_IPV6=1" && \
  make -j$(nproc) && make install && ldconfig

# ------------------------------
# Build Asterisk 20.x
# ------------------------------
RUN git clone -b 20 https://github.com/asterisk/asterisk.git

WORKDIR /usr/src/asterisk

# Download MP3 support
RUN contrib/scripts/get_mp3_source.sh

# Configure Asterisk
RUN ./configure

# Create menuselect options
RUN make menuselect.makeopts

# Enable required modules
RUN menuselect/menuselect \
    --enable chan_pjsip \
 #   --enable res_http \
    --enable res_http_websocket \
 #   --enable res_pjsip_transport_tls \
    --enable res_pjsip_transport_websocket \
    --enable res_srtp \
    --enable codec_opus \
    --enable format_mp3 \
    menuselect.makeopts

# Build & install
RUN make -j$(nproc)
RUN make install
RUN make samples
RUN make config
RUN ldconfig

# ------------------------------
# Entrypoint
# ------------------------------
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 5060/udp 5060/tcp 5061/tcp \
       8088/tcp 8089/tcp \
       10000-20000/udp

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/sbin/asterisk", "-f", "-U", "root", "-vvv"]
