#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "Error: There must be only 1 argument in $0" >&2
    exit 1
fi

SOURCE_FILE="$1"

if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: File '$SOURCE_FILE' does not exist" >&2
    exit 2
fi

SOURCE_DIR=$(dirname "$SOURCE_FILE")
SOURCE_DIR=$(cd "$SOURCE_DIR" && pwd) || {
    echo "Error: Cannot resolve source directory" >&2
    exit 3
}

TEMP_DIR=$(mktemp -d) || {
    echo "Error: Failed to create temp directory" >&2
    exit 4
}

cleanup() {
    rm -rf "$TEMP_DIR"
    exit "$1"
}

trap 'cleanup $?' EXIT

case "$SOURCE_FILE" in
    *.c|*.cpp|*.cc|*.cxx)
        OUTPUT=$(awk '
            /^[[:space:]]*\/\// {
                if (match($0, /Output:[[:space:]]+([^[:space:]]+)/, m)) {
                    print m[1]
                    exit
                }
            }
        ' "$SOURCE_FILE")
        OUTPUT=$(awk '
            /^[[:space:]]*\/\// && /Output:[[:space:]]/ {
                line = $0
                sub(/.*Output:[[:space:]]+/, "", line)
                if (line ~ /^[^[:space:]]+/) {
                    sub(/[[:space:]].*$/, "", line)
                    print line
                    exit
                }
            }
        ' "$SOURCE_FILE")
        ;;
    *.tex)
        OUTPUT=$(awk '
            /^[[:space:]]*%/ && /Output:[[:space:]]/ {
                line = $0
                sub(/.*Output:[[:space:]]+/, "", line)
                if (line ~ /^[^[:space:]]+/) {
                    sub(/[[:space:]].*$/, "", line)
                    print line
                    exit
                }
            }
        ' "$SOURCE_FILE")
        ;;
    *)
        echo "Error: Unsupported file type" >&2
        cleanup 5
        ;;
esac

if [ -z "$OUTPUT" ]; then
    echo "Error: No 'Output:' comment found in '$SOURCE_FILE'" >&2
    cleanup 6
fi

cp "$SOURCE_FILE" "$TEMP_DIR/" || {
    echo "Error: Failed to copy source file" >&2
    cleanup 7
}

cd "$TEMP_DIR" || {
    echo "Error: Failed to enter temp directory" >&2
    cleanup 8
}

SOURCE_BASE=$(basename "$SOURCE_FILE")

# Сборка
case "$SOURCE_FILE" in
    *.c)
        cc -o "$OUTPUT" "$SOURCE_BASE" 2>/dev/null || {
            echo "Error: C compilation failed" >&2
            cleanup 9
        }
        ;;
    *.cpp|*.cc|*.cxx)
        c++ -o "$OUTPUT" "$SOURCE_BASE" 2>/dev/null || {
            echo "Error: C++ compilation failed" >&2
            cleanup 10
        }
        ;;
    *.tex)
        if ! command -v pdflatex >/dev/null; then
            echo "Error: pdflatex not found" >&2
            cleanup 11
        fi
        pdflatex -interaction=nonstopmode "$SOURCE_BASE" >/dev/null 2>/dev/null || {
            echo "Error: TeX build failed" >&2
            cleanup 12
        }
        if [ "$OUTPUT" != "${SOURCE_BASE%.tex}.pdf" ]; then
            mv "${SOURCE_BASE%.tex}.pdf" "$OUTPUT" || {
                echo "Error: Failed to rename PDF" >&2
                cleanup 13
            }
        fi
        ;;
esac


if [ ! -f "$OUTPUT" ]; then
    echo "Error: Output file '$OUTPUT' was not produced" >&2
    cleanup 14
fi

cp "$OUTPUT" "$SOURCE_DIR/" || {
    echo "Error: Failed to copy output to source directory" >&2
    cleanup 15
}


cleanup 0
