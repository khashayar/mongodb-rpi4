# mongodb-rpi4: unofficial MongoDB Community build for Raspberry Pi 4
# (cortex-a72, ARMv8.0). Official MongoDB >= 5.0 needs ARMv8.2-A and will not
# start on a Pi 4 / CM4.
#
# Binaries come from themattman/mongodb-raspberrypi-binaries, the same source
# the joaodrp/mongodb-raspberrypi4-unofficial images were built from. The tarball is pinned by sha256 from the GitHub release page.
#
# Base is ubuntu:22.04, not 20.04 like the joaodrp images: the
# 7.0.x binaries need GLIBCXX_3.4.29 / CXXABI_1.3.13 (libstdc++ from GCC >= 11),
# and focal only has GLIBCXX_3.4.28. Verified 2026-10-07 with ldd.
#
# The same binaries also link OpenSSL 1.1 (libssl.so.1.1 / libcrypto.so.1.1),
# which jammy no longer ships. That library comes from focal's libssl1.1
# package, pinned by sha256 from the focal-security Packages index. OpenSSL
# 1.1 is end-of-life upstream; if you terminate client TLS in mongod, weigh
# that before using this image.
#
# No USER line on purpose: mongod runs as whatever user starts the container
# (root by default). Set `--user` / `runAsUser` to match your data directory's
# owner.
FROM --platform=linux/arm64 ubuntu:22.04

ARG MONGO_VERSION=7.0.40
ARG MONGO_SHA256=ebbf873eeee24f2fedf7f418e08d0acd7fd68016ba46a0c6fda18b93fb44e7fa
ARG LIBSSL11_DEB=libssl1.1_1.1.1f-1ubuntu2.24_arm64.deb
ARG LIBSSL11_SHA256=dded4572af8b0a9e0310909f211a519cc6409fda31ea81132a77e268b0ec0f2f

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends ca-certificates curl numactl; \
  curl -fsSL -o "/tmp/${LIBSSL11_DEB}" \
    "http://ports.ubuntu.com/ubuntu-ports/pool/main/o/openssl/${LIBSSL11_DEB}"; \
  echo "${LIBSSL11_SHA256}  /tmp/${LIBSSL11_DEB}" | sha256sum -c -; \
  apt-get install -y --no-install-recommends "/tmp/${LIBSSL11_DEB}"; \
  rm "/tmp/${LIBSSL11_DEB}"; \
  curl -fsSL -o /tmp/mongodb.tgz \
    "https://github.com/themattman/mongodb-raspberrypi-binaries/releases/download/r${MONGO_VERSION}-rpi-unofficial/mongodb.ce.pi4.r${MONGO_VERSION}.tar.gz"; \
  echo "${MONGO_SHA256}  /tmp/mongodb.tgz" | sha256sum -c -; \
  mkdir /tmp/mongodb; \
  tar -xzf /tmp/mongodb.tgz -C /tmp/mongodb; \
  find /tmp/mongodb -type f \( -name mongod -o -name mongos -o -name mongo \) \
    -exec install -m 0755 {} /usr/local/bin/ \; ; \
  rm -rf /tmp/mongodb /tmp/mongodb.tgz; \
  rm -rf /var/lib/apt/lists/*; \
  # curl stays: mongod links libcurl.so.4 dynamically. Fail the build on any
  # other unresolved library rather than at pod start on a CM4.
  ! ldd /usr/local/bin/mongod /usr/local/bin/mongo | grep 'not found'; \
  mongod --version; \
  mongo --version

VOLUME /data/db
EXPOSE 27017
CMD ["mongod", "--bind_ip_all"]
