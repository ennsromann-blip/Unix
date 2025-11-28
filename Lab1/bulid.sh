#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "Error: There must me only 1 argument $0" >&2
    exit 1
fi

SOURCE_FILE="$1"
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: File '$SOURCE_FILE' does not exist" >&2
    exit 2
fi

SOURCE_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)
if [ $? -ne 0 ]; then
    echo "Error: Failed to create temp directory" >&2
    exit 3
fi

clean_tempdir() {
    rm -rf "$TEMP_DIR"
    exit "$1"
}
trap 'clean_tempdir $?' EXIT
trap 'clean_tempdir 130' INT
trap 'clean_tempdir 143' TERM


OUTPUT=$(grep 'Output:' "$SOURCE_FILE" | sed 's/.*Output:\s*//' | tr -d '[:space:]')

if [ -z "$OUTPUT" ]; then
    echo "Error: No output filename specified with Output:" >&2
    clean_tempdir 4
fi


SOURCE_NAME=$(basename "$SOURCE_FILE")

cp "$SOURCE_FILE" "$TEMP_DIR/"
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy '$SOURCE_FILE' to temp directory." >&2
    clean_tempdir 5
fi

cd "$TEMP_DIR" || {
    echo "Error: Failed to move temp dir" >&2
    clean_tempdir 6
}

case "$SOURCE_FILE" in
    *.c)
        cc "$SOURCE_NAME" -o "$OUTPUT" 2>/tmp/err$$
        if [ $? -ne 0 ]; then
            cat /tmp/err$$ >&2
            rm -f /tmp/err$$
            clean_tempdir 7
        fi
        rm -f /tmp/err$$
        ;;
    *.tex)
        pdflatex "$SOURCE_NAME" >/dev/null 2>/tmp/err$$
        if [ $? -ne 0 ]; then
            cat /tmp/err$$ >&2
            rm -f /tmp/err$$
            clean_tempdir 8
        fi

        mv "${SOURCE_NAME%.tex}.pdf" "$OUTPUT"
        rm -f /tmp/err$$
        ;;
esac


if [ -f "$OUTPUT" ]; then
    echo "Output file created: $OUTPUT" >&2
else
    clean_tempdir 9
fi

mv "$OUTPUT" "$SOURCE_DIR/" || {
    clean_tempdir 10
}

clean_tempdir 0
