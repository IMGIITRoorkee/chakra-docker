#!/bin/bash

# This script build the environment for running the chakra core transpiler
# Run this as a sudoer

apt-get install openjdk-11-jdk

# Install coursier and add it to the SYSTEM PATH
curl -fLo cs https://git.io/coursier-cli-"$(uname | tr LD ld)"
chmod +x cs
./cs install cs

# Hit the coursier setup command and enjoy!
cs install scala
cs install sbt

# Unpack chakra core into its scripts directory.
cd codebase/chakra-core
./pack.sh

#Create a virtualenv and install requirements

cd ../../
