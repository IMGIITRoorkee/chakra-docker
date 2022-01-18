#!/bin/bash

# This script build the environment for running the chakra core transpiler
# Run this as a sudoer

sudo apt-get install openjdk-11-jdk

# Install coursier and add it to the SYSTEM PATH
curl -fLo cs https://git.io/coursier-cli-"$(uname | tr LD ld)"
chmod +x cs
./cs install cs

export PATH="$PATH:/home/${USER}/.local/share/coursier/bin"

# Hit the coursier setup command and enjoy!
cs install scala
cs install sbt

# Unpack chakra core into its scripts directory.
cd codebase/chakra-core
./pack.sh

#Create a virtualenv and install requirements

# apt-get install python3
# apt-get install python3-pip

pip3 install virtualenv

virtualenv --python=python3 chakra-core-env
source chakra-core-env/bin/activate
pip3 install -r requirements.txt

cd ../../
