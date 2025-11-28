#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <source_file>" >&2
    exit 1
fi

SOURCE="$1"

if [ ! -f "$SOURCE" ]; then
    echo "Error: file '$SOURCE' does not exist." >&2
    exit 2
fi

cleanup() {
    if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
        rm -rf "$TMPDIR"
    fi
}

trap cleanup EXIT INT TERM

TMPDIR=$(mktemp -d) || {
    echo "Error: failed to create temporary directory." >&2
    exit 3
}

OUTPUT_NAME=""
case "$SOURCE" in
    *.c|*.cpp|*.cc|*.cxx)
        OUTPUT_NAME=$(awk '/^[[:space:]]*\/\// { if (match($0, /Output:[[:space:]]*([^\r\n]+)/, m)) print m[1] }' "$SOURCE" | head -n1)
        ;;
    *.tex)
        OUTPUT_NAME=$(awk '/^[[:space:]]*%/ { if (match($0, /Output:[[:space:]]*([^\r\n]+)/, m)) print m[1] }' "$SOURCE" | head -n1)
        ;;
    *)
        echo "Error: unsupported file extension '$SOURCE'." >&2
        exit 4
        ;;
esac

if [ -z "$OUTPUT_NAME" ]; then
    echo "Error: 'Output:' comment not found in file '$SOURCE'." >&2
    exit 5
fi

FINAL_OUTPUT="$(dirname "$SOURCE")/$OUTPUT_NAME"

cp "$SOURCE" "$TMPDIR/" || {
    echo "Error: failed to copy source file to temporary directory." >&2
    exit 6
}

cd "$TMPDIR" || {
    echo "Error: failed to change to temporary directory." >&2
    exit 7
}

BASENAME=$(basename "$SOURCE")

case "$SOURCE" in
    *.c)
        cc -o "$OUTPUT_NAME" "$BASENAME" || {
            echo "Error: C file compilation '$SOURCE' failed." >&2
            exit 8
        }
        ;;
    *.cpp|*.cc|*.cxx)
        c++ -o "$OUTPUT_NAME" "$BASENAME" || {
            echo "Error: C++ file compilation '$SOURCE' failed." >&2
            exit 9
        }
        ;;
    *.tex)
        if command -v pdflatex > /dev/null; then
            pdflatex -interaction=nonstopmode "$BASENAME" > /dev/null || {
                echo "Error: TeX file build '$SOURCE' failed." >&2
                exit 10
            }

            if [ "$OUTPUT_NAME" != "${BASENAME%.tex}.pdf" ]; then
                mv "${BASENAME%.tex}.pdf" "$OUTPUT_NAME" || {
                    echo "Error: failed to rename PDF to '$OUTPUT_NAME'." >&2
                    exit 11
                }
            fi
        elif command -v latex > /dev/null && command -v dvipdf > /dev/null; then
            latex -interaction=nonstopmode "$BASENAME" > /dev/null || {
                echo "Error: TeX file build '$SOURCE' failed." >&2
                exit 10
            }
            dvipdf "${BASENAME%.tex}.dvi" "$OUTPUT_NAME" > /dev/null || {
                echo "Error: DVI to PDF conversion failed." >&2
                exit 12
            }
        else
            echo "Error: neither pdflatex nor latex+dvipdf found." >&2
            exit 13
        fi
        ;;
esac

if [ ! -f "$OUTPUT_NAME" ]; then
    echo "Error: build output '$OUTPUT_NAME' not found in temporary directory." >&2
    exit 14
fi

cp "$OUTPUT_NAME" "$FINAL_OUTPUT" || {
    echo "Error: failed to copy output '$OUTPUT_NAME' to '$FINAL_OUTPUT'." >&2
    exit 15
}

# Успешное завершение
exit 0
