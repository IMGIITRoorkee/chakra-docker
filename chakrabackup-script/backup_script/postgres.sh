#!/bin/bash

#chakra-backup

source ${CONFIG_DIR}/postgres_config.env
source ${CHAKRA_DIR}/postgres/database.env

# mkdir chakra-backup
mkdir ${BACKUP_DIR}
touch ${OUTPUT_FILE}
touch ${OUTPUT_FILE_VERBOSE}


docker-compose -f ${CHAKRA_DIR}/docker-compose.yml exec -T database pg_dump -v -U ${POSTGRES_USER} ${POSTGRES_DB} > ${OUTPUT_FILE_VERBOSE}
docker-compose -f ${CHAKRA_DIR}/docker-compose.yml exec -T database pg_dump -U ${POSTGRES_USER} ${POSTGRES_DB} > ${OUTPUT_FILE}
sha256sum  ${OUTPUT_FILE} > "${OUTPUT_FILE}-sha256sum.txt"

tar czC ${BACKUP_DIR} . --transform='s,^\./,,' >| ${BASE_DIR}/postgres-backup.tar.gz
rm -rf ${BACKUP_DIR}

