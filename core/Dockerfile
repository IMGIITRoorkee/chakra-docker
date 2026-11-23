# Python 3.6 and Java 11 for the chakra-core Flask wrapper and the transpiler jar
FROM python:3.6.15-slim-bullseye

LABEL maintainer="IMG, IIT Roorkee <https://img.channeli.in>"

# Debian 11 is end of life; its package indexes live on archive.debian.org
RUN sed -i -E 's#https?://(deb|security)\.debian\.org#http://archive.debian.org#; /bullseye-updates/d' /etc/apt/sources.list

RUN mkdir -p /usr/share/man/man1 \
    && apt-get update \
    && apt-get install -y --no-install-recommends openjdk-11-jre-headless \
    && rm -rf /var/lib/apt/lists/*

COPY ./requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

ENV HOME=/tmp
