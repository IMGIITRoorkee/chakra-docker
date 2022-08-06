#!/bin/bash

file_name=$1

declare -A config_vars
declare -a services

while IFS=$':= \t' read key value
do
        config_vars[$key]=$value
done < $1


temp=${config_vars["services"]}
IFS=', ' read -a services <<< $temp

func()
{
        service_script="${config_vars[services_directory]}/${1}"
        echo ${service_script}
        ( $service_script )
}

#TODAY_DIR="`date +%Y-%m-%d`"
TODAY_DIR="daily_backup"
export "BASE_DIR=${config_vars["backup_directory"]}/${TODAY_DIR}"
mkdir ${BASE_DIR}
export "CONFIG_DIR=${config_vars["configs_directory"]}"

for element in "${services[@]}"
do
        func $element
done

rm -rf ${BASE_DIR}

