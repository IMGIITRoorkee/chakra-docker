FROM python:3.8-slim-bullseye

LABEL maintainer="IMG, IIT Roorkee <https://img.channeli.in>"

# Install dependencies
RUN apt-get update \
    && apt-get install -y build-essential gcc libcairo2 libffi-dev \
        libgdk-pixbuf2.0-0 libpango-1.0-0 libpangocairo-1.0-0 poppler-utils \
        python3-cffi shared-mime-info \ 
        libpq-dev python3-dev\
    && rm -rf /var/lib/apt/lists/*

# Install pip packages
RUN pip install --upgrade pip \
    && pip install --upgrade setuptools \
    && pip install --upgrade supervisor

# Work in the root directory of the container
WORKDIR /

# Copy the file requirements.txt over to the container
# This command implies an image rebuild when PyPI requirements change
COPY ./requirements.txt ./requirements.txt

# Install dependencies from the file requirements.txt
RUN pip install -r requirements.txt

# Create the media files volume as a directory
RUN mkdir -p /media_files \
    && chmod -R o+r /media_files

# Create the personal files volume as a directory
RUN mkdir -p /website \
    && chmod -R o+r /website

# Create the supervisor configuration files volume as a directory
RUN mkdir -p /supervisor.d \
    && chmod -R o+r /supervisor.d

# Create the web server logs volume as a directory
RUN mkdir -p /web_server_logs/supervisord_logs  \
    && mkdir -p /web_server_logs/gunicorn_logs \
    && mkdir -p /web_server_logs/daphne_logs \
    && mkdir -p /web_server_logs/server_logs \
    && chmod -R o+r /web_server_logs

# Create the history volume as a directory
RUN mkdir -p /.history \
    && chmod -R o+r /.history

# Change the directories into volumes
VOLUME /media_files /website /web_server_logs /supervisor.d /.history
# Copy the supervisord.conf file over to the container
COPY ./supervisord.conf ./supervisord.conf

# Copy the gunicorn_config.py file over to the container
COPY ./gunicorn_config.py ./gunicorn_config.py

# Define environment variables
ENV PYTHONPATH="/chakra-backend:"
ENV HISTFILE="/.history/.bash_history"
ENV IPYTHONDIR="/.history/.ipython/"

# Add some terminal jazz
RUN echo "PS1='docker@\$NAME:\w\$ '" >> /etc/bash.bashrc

# Enter the chakra directory
WORKDIR /chakra-backend
