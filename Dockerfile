ARG LINUX_IMAGE="ubuntu"
ARG LINUX_IMAGE_VERSION="25.04"


# Build stage
FROM --platform=$BUILDPLATFORM ${LINUX_IMAGE}:${LINUX_IMAGE_VERSION} AS build

ARG TARGETPLATFORM
ARG SPHERE_GIT="https://github.com/SphereServer/Source-X.git"

ENV DEBIAN_FRONTEND noninteractive

# Install dependencies for build
RUN apt update && \
    apt install -y \
        git cmake libmariadb-dev libmariadb3 build-essential && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /source
WORKDIR "/source"

# Clone and build
RUN git clone ${SPHERE_GIT}
WORKDIR "/source/Source-X"
RUN mkdir build
RUN case ${TARGETPLATFORM:-linux/amd64} in \
        "linux/amd64")   export TOOLCHAIN_ARCH="x86_64"  ;; \
        "linux/arm64")   export TOOLCHAIN_ARCH="AArch64" ;; \
        *)               export TOOLCHAIN_ARCH="x86"     ;; \
    esac && \
    cmake -DCMAKE_TOOLCHAIN_FILE="cmake/toolchains/Linux-GNU-${TOOLCHAIN_ARCH}.cmake" \
        -G "Unix Makefiles" \
        -DCMAKE_BUILD_TYPE="Nightly" \
        -B ./build -S ./

WORKDIR "/source/Source-X/build"
RUN case ${TARGETPLATFORM:-linux/amd64} in \
        "linux/amd64")   export BIN_ARCH="x86_64"  ;; \
        "linux/arm64")   export BIN_ARCH="aarch64" ;; \
        *)               export BIN_ARCH="x86"     ;; \
    esac && \
    cmake --build . && \
    mv bin-${BIN_ARCH} bin


# Release stage
FROM --platform=$BUILDPLATFORM ${LINUX_IMAGE}:${LINUX_IMAGE_VERSION} AS release

ENV DEBIAN_FRONTEND noninteractive

# Install dependencies for runtime
RUN apt update && \
    apt install -y --no-install-recommends \
        mariadb-client && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /sphereserver
WORKDIR /sphereserver

COPY --from=build /source/Source-X/build/bin/SphereSvrX64_nightly /sphereserver/spheresvr
COPY --from=build /source/Source-X/src/sphereCrypt.ini /sphereserver/sphereCrypt.ini
COPY --from=build /source/Source-X/src/sphere.ini /sphereserver/sphere.ini
RUN chmod +x /sphereserver/spheresvr

EXPOSE 2593

ENTRYPOINT ["./spheresvr"]