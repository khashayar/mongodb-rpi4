# MongoDB for Raspberry Pi 4 (Docker image)

MongoDB Community Edition built for the **Raspberry Pi 4 / CM4** (Cortex-A72,
ARMv8.0). Official MongoDB images from 5.0 onward require ARMv8.2-A and fail
on a Pi 4 with `Illegal instruction`. This image packages the unofficial Pi 4
binaries from [themattman/mongodb-raspberrypi-binaries](https://github.com/themattman/mongodb-raspberrypi-binaries),
which include `mongod`, `mongos`, and the legacy `mongo` shell (no `mongosh`).

These binaries are **not supported by MongoDB Inc.** and are licensed under the
[Server Side Public License](https://github.com/mongodb/mongo/blob/master/LICENSE-Community.txt).

## Image

```
docker.io/khashayar/mongodb-rpi4:<mongo version>   # e.g. 7.0.40
```

What's in it (see the `Dockerfile` for details):

- `ubuntu:22.04` base: the 7.0.x binaries need libstdc++ from GCC 11 or newer
  (`GLIBCXX_3.4.29`).
- OpenSSL 1.1 from Ubuntu 20.04's `libssl1.1` package, since the binaries link
  against it and 22.04 doesn't ship it. OpenSSL 1.1 is end-of-life upstream.
- The MongoDB tarball and the `libssl1.1` `.deb` are both pinned by sha256.
- The build fails if `ldd` reports any unresolved library.
- No `USER` line: mongod runs as the container's user (root by default).

## Run

```bash
docker run -d -p 27017:27017 -v mongo-data:/data/db \
  khashayar/mongodb-rpi4:7.0.40 \
  mongod --bind_ip_all --replSet rs0
```

The default command is `mongod --bind_ip_all`. Pass your own `mongod ...`
arguments to override it.

## Build locally

```bash
docker build -t mongodb-rpi4:local .
```

Build arguments:

- `MONGO_VERSION`: release from themattman's repo (tag `r<version>-rpi-unofficial`).
- `MONGO_SHA256`: sha256 of `mongodb.ce.pi4.r<version>.tar.gz`, listed in that release's notes.
- `LIBSSL11_DEB` / `LIBSSL11_SHA256`: the focal `libssl1.1` arm64 package and its
  sha256 from `ports.ubuntu.com/ubuntu-ports/dists/focal-security/main/binary-arm64/Packages.gz`.

## Release flow

Same as [rocketchat-arm64](https://github.com/khashayar/rocketchat-arm64):

1. Update `MONGO_VERSION` and `MONGO_SHA256` in the `Dockerfile`, build and test
   locally, and merge into `main`.
2. Tag the release, e.g. `git tag -a v7.0.40 -m "MongoDB 7.0.40"`, and push the tag.
3. The tag push triggers `Release MongoDB` (creates a GitHub release) and
   `Docker Publish` (builds on a native arm64 runner and pushes
   `khashayar/mongodb-rpi4:<version>` to Docker Hub).
4. `latest` only moves when `Docker Publish` runs on `main`, either by hand from
   the Actions tab or from a release event.

`Docker Publish` needs the `DOCKER_HUB_USER` and `DOCKER_HUB_TOKEN` repository
secrets. It fails fast if they are missing.

## Testing on a Pi

A build that passes CI only proves the binary runs on the runner's CPU, which
is newer than a Cortex-A72. Before using a new version, start it once on a
real Pi 4:

```bash
docker run --rm khashayar/mongodb-rpi4:7.0.40 sh -c \
  'mongod --dbpath /tmp --fork --logpath /tmp/m.log && mongo --quiet --eval "db.version()"'
```

`Illegal instruction` means a CPU mismatch, and `GLIBCXX_… not found` or
`lib… not found` means a missing library.
