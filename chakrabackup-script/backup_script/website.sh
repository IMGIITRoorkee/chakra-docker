#!/bin/bash

#website

source ${CONFIG_DIR}/website_config.env


tar czC ${CODEBASE_DIR}/${BACKEND_DIR}/${WEBSITE_DIR} . --transform='s,^\./,,' >| website.tar.gz
mv website.tar.gz ${BACKUP_DIR}

