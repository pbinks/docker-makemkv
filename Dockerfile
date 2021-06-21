#
# makemkv Dockerfile
#
# https://github.com/jlesage/docker-makemkv
#

# Build MakeMKV.
FROM ubuntu:bionic
COPY makemkv-builder /tmp/makemkv-builder
RUN /tmp/makemkv-builder/builder/build.sh /tmp/

# Build YAD.  The one from the Alpine repo doesn't support the multi-progress
# feature.
FROM alpine:3.12
ARG YAD_VERSION=0.40.0
ARG YAD_URL=https://downloads.sourceforge.net/project/yad-dialog/yad-${YAD_VERSION}.tar.xz
RUN apk --no-cache add \
    build-base \
    curl \
    gtk+2.0-dev \
    intltool
RUN \
    # Set same default compilation flags as abuild.
    export CFLAGS="-Os -fomit-frame-pointer" && \
    export CXXFLAGS="$CFLAGS" && \
    export CPPFLAGS="$CFLAGS" && \
    export LDFLAGS="-Wl,--as-needed" && \
    # Download.
    mkdir /tmp/yad && \
    curl -# -L "${YAD_URL}" | tar xJ --strip 1 -C /tmp/yad && \
    # Compile.
    cd /tmp/yad && \
    ./configure && \
    make -j$(nproc) && \
    strip src/yad

# Pull base image.
FROM jlesage/baseimage-gui:alpine-3.12-v3.5.7

# Docker image version is provided via build arg.
ARG DOCKER_IMAGE_VERSION=unknown

# Define working directory.
WORKDIR /tmp

# Install MakeMKV.
COPY --from=0 /tmp/makemkv-install /

# Install Java 8.
RUN \
    add-pkg openjdk8-jre-base && \
    # Removed uneeded stuff.
    rm -r \
        /usr/lib/jvm/java-1.8-openjdk/bin \
        /usr/lib/jvm/java-1.8-openjdk/lib \
        /usr/lib/jvm/java-1.8-openjdk/jre/lib/ext \
        && \
    # Cleanup.
    rm -rf /tmp/* /tmp/.[!.]*

# Install YAD.
COPY --from=1 /tmp/yad/src/yad /usr/bin/
RUN add-pkg gtk+2.0

# Install dependencies.
RUN \
    add-pkg \
        wget \
        sed \
        findutils \
        util-linux \
        lsscsi

# Adjust the openbox config.
RUN \
    # Maximize only the main window.
    sed-patch 's/<application type="normal">/<application type="normal" title="MakeMKV BETA">/' \
        /etc/xdg/openbox/rc.xml && \
    # Make sure the main window is always in the background.
    sed-patch '/<application type="normal" title="MakeMKV BETA">/a \    <layer>below</layer>' \
        /etc/xdg/openbox/rc.xml

# Generate and install favicons.
RUN \
    APP_ICON_URL=https://raw.githubusercontent.com/jlesage/docker-templates/master/jlesage/images/makemkv-icon.png && \
    install_app_icon.sh "$APP_ICON_URL"

# Add files.
COPY rootfs/ /

# Update the default configuration file with the latest beta key.
RUN /opt/makemkv/bin/makemkv-update-beta-key /defaults/settings.conf

# Set environment variables.
ENV APP_NAME="MakeMKV" \
    MAKEMKV_KEY="BETA"

# Define mountable directories.
VOLUME ["/config"]
VOLUME ["/storage"]
VOLUME ["/output"]

# Metadata.
LABEL \
      org.label-schema.name="makemkv" \
      org.label-schema.description="Docker container for MakeMKV" \
      org.label-schema.version="$DOCKER_IMAGE_VERSION" \
      org.label-schema.vcs-url="https://github.com/jlesage/docker-makemkv" \
      org.label-schema.schema-version="1.0"
