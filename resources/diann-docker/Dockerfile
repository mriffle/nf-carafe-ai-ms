FROM ubuntu:22.04

ARG DIANN_VERSION

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget unzip libgomp1 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data /tmp/diann-build && \
    cd /tmp/diann-build && \
    wget -q https://github.com/vdemichev/DiaNN/releases/download/2.0/DIA-NN-${DIANN_VERSION}-Academia-Linux.zip && \
    unzip DIA-NN-${DIANN_VERSION}-Academia-Linux.zip && \
    mkdir -p /usr/diann && \
    mv diann-${DIANN_VERSION} /usr/diann/${DIANN_VERSION} && \
    chmod +x /usr/diann/${DIANN_VERSION}/diann-linux && \
    ln -s /usr/diann/${DIANN_VERSION}/diann-linux /usr/bin/diann && \
    rm -rf /tmp/diann-build

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /data

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
