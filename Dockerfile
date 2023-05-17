# Build exporter
FROM python:3.9.16-bullseye AS exporter-builder

WORKDIR /usr/src/

COPY requirements.txt /usr/src/
RUN pip3 install -r requirements.txt
ADD exporter.py /usr/src/
RUN pyinstaller --name exporter \
    --onefile exporter.py && \
    mv dist/exporter wal-g-prometheus-exporter

# Download wal-g
FROM debian:11.6-slim as downloader
ARG TARGETARCH
RUN apt-get update && apt-get install -y wget && rm -rf /var/lib/apt/lists/*
RUN if [ "${TARGETARCH}" = "arm64" ]; then \
      WALG_ARCH="aarch64"; \
    else \
      WALG_ARCH="${TARGETARCH}"; \
    fi
RUN wget -O /wal-g-pg-ubuntu-20.04.tar.gz https://github.com/wal-g/wal-g/releases/download/v2.0.1/wal-g-pg-ubuntu-20.04-${WALG_ARCH}.tar.gz

# Build final image
FROM debian:11.6-slim
COPY --from=exporter-builder /usr/src/wal-g-prometheus-exporter /usr/bin/
COPY --from=downloader /wal-g-pg-ubuntu-20.04.tar.gz /usr/bin/

RUN apt-get update && \
    apt-get install -y ca-certificates daemontools && \
    apt-get upgrade -y -q && \
    apt-get dist-upgrade -y -q && \
    apt-get -y -q autoclean && \
    apt-get -y -q autoremove

RUN cd /usr/bin/ && \
    tar -zxvf wal-g-pg-ubuntu-20.04.tar.gz && \
    rm wal-g-pg-ubuntu-20.04.tar.gz && \
    mv wal-g-pg-ubuntu-20.04-* wal-g

COPY scripts/entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
