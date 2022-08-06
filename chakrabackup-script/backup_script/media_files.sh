#!/bin/bash

#media_files_backend

source ${CONFIG_DIR}/media_files_config.env


tar czC ${CODEBASE_DIR}/${BACKEND_DIR}/${MEDIA_FILES_DIR} . --transform='s,^\./,,' >| media_files.tar.gz
mv media_files.tar.gz ${BACKUP_DIR}

