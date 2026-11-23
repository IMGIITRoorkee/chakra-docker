# Use Memcached from the Debian Linux project
FROM memcached:1.6.16

# Need to undo the misdeeds of Memcached developers
USER root

# Add labels for metadata
LABEL maintainer="IMG, IIT Roorkee <https://img.channeli.in>"

# Debian 11 is end of life; its package indexes live on archive.debian.org
RUN sed -i -E 's#https?://(deb|security)\.debian\.org#http://archive.debian.org#; /bullseye-updates/d' /etc/apt/sources.list

# Install dependencies
RUN apt-get update \
    && apt-get install -y netcat \
    && rm -rf /var/lib/apt/lists/*

# Undo our undoing of Memcache's misdeeds, just in case they are important
USER memcache
