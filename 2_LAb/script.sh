#!/bin/bash

SHARED_DIR="/app/shared_volume"
LOCK_FILE="${SHARED_DIR}/sync.lock"
SEQ_NUMBER=1

if [ ! -d "$SHARED_DIR" ]; then
    echo "Error: Shared volume ${SHARED_DIR} does not exist." >&2
    exit 1
fi

CONTAINER_ID=$(hostname)

while true; do
    CREATED_FILENAME=""
    {
        flock -x 200

        for i in $(seq -w 999); do
            FILENAME="${SHARED_DIR}/${i}.txt"

            if [ ! -f "$FILENAME" ]; then
                echo "$CONTAINER_ID $SEQ_NUMBER" > "$FILENAME"
                CREATED_FILENAME="$FILENAME"
                SEQ_NUMBER=$((SEQ_NUMBER + 1))
                echo "create ${CONTAINER_ID}, ${SEQ_NUMBER},$(basename "$FILENAME")"
                break
	        fi
        done

    } 200> "$LOCK_FILE"
    
    sleep 1
    
    if [ -n "$CREATED_FILENAME" ]; then
        rm -f "$CREATED_FILENAME"
	echo "delete ${CONTAINER_ID}, ${SEQ_NUMBER}, $(basename "$CREATED_FILENAME")"
    fi
    
    sleep 1
done