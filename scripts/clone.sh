#!/bin/bash

# This script clone the different cms repos into the codebase folder

echo -e "Chakra -- Your one true CMS\n"

# Cloning chakra-core transpiler
echo -e "\e[0;32mCloning chakra-core into ./codebase/chakra-core\e[0m"
git clone https://github.com/IMGIITRoorkee/chakra-core ./codebase/chakra-core &>/dev/null

# Cloning chakra-backend
echo -e "\e[0;32mCloning chakra-backend into ./codebase/chakra-backend\e[0m"
git clone https://github.com/IMGIITRoorkee/chakra-backend ./codebase/chakra-backend &>/dev/null

#Cloning chakra-frontend
echo -e "\e[0;32mCloning chakra-frontend into ./codebase/chakra-frontend\e[0m"
git clone https://github.com/IMGIITRoorkee/chakra-frontend ./codebase/chakra-frontend &>/dev/null

#Cloning the chakra library
echo -e "\e[0;32mCloning chakra-core into ./codebase/chakra-library\e[0m\n"
git clone https://github.com/IMGIITRoorkee/chakra-library ./codebase/chakra-library &>/dev/null

echo "Everything cloned!"