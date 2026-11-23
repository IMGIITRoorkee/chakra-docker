FROM node:17.4.0-stretch-slim

LABEL maintainer="IMG, IIT Roorke <https://img.channeli.in>"

ARG IMAGETYPE

WORKDIR /

RUN yarn global add pm2@5.1.2

COPY ./package.json package.json
COPY ./yarn.lock yarn.lock

# Add some terminal jazz
RUN echo "PS1='docker@\$NAME:\w\$ '" >> /etc/bash.bashrc

# Enter the chakra directory
WORKDIR /chakra-frontend
