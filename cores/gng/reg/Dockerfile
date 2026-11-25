FROM jotego/simulator:arm64

# Install lwtools (6809 cross-assembler) from source
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        python3 \
        zip \
    && rm -rf /var/lib/apt/lists/*

# Build lwtools from source (not in Debian repos)
ARG LWTOOLS_VERSION=4.23
RUN cd /tmp && \
    curl -sL "https://www.lwtools.ca/releases/lwtools/lwtools-${LWTOOLS_VERSION}.tar.gz" \
        -o lwtools.tar.gz && \
    tar xzf lwtools.tar.gz && \
    cd lwtools-${LWTOOLS_VERSION} && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/lwtools*

ENTRYPOINT []
WORKDIR /work
