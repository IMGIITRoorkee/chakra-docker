#!/bin/bash

# Assumed layout: year/month/week/day, each level holding its own tar file,
# with the postgres dump under day.


source ${CONFIG_DIR}/zip_config.env

sha256sum_file="${CURRENT_BACKUP_DIR}_shasum"

date_now=$(date +'%F')
week_number=$(date +%U)

#This day_tar_file is the tar file containing all the backup of a day. It is stored in a 'week' directory
day_tar_file="${CURRENT_BACKUP_DIR}.tar.gz"
month_tar_file="`date +%Y-%m`"

tar czC ${CURRENT_BACKUP_DIR} . --transform='s,^\./,,' >| ${day_tar_file}

mkdir ${MONTHLY_BACKUP_DIR}

# #This block runs every month end. Create a month_tar_file from the present week_tar_files and store them in the year directory. Also clear the month directory.
end_date="`date -d "-$(date +%d) days  month" +%d`"
curr_date="`date +%d`"
if [ $((end_date)) == $((curr_date)) ]; then
    rm "${MONTHLY_BACKUP_DIR}/*"
    mkdir ${YEARLY_BACKUP_DIR}
    mv $day_tar_file "${YEARLY_BACKUP_DIR}/${month_tar_file}"
else
    mv ${day_tar_file} ${MONTHLY_BACKUP_DIR}/
fi

