#!/bin/sh

# Проверка аргумента
if [ "$#" -ne 1 ]; then
    echo "Использование: $0 <исходный_файл>" >&2
    exit 1
fi

SOURCE="$1"

# Проверка существования исходного файла
if [ ! -f "$SOURCE" ]; then
    echo "Ошибка: файл '$SOURCE' не существует." >&2
    exit 2
fi

# Функция очистки временного каталога
cleanup() {
    if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
        rm -rf "$TMPDIR"
    fi
}

# Установка обработчика завершения и сигналов
trap cleanup EXIT INT TERM

# Создание временного каталога
TMPDIR=$(mktemp -d) || {
    echo "Ошибка: не удалось создать временный каталог." >&2
    exit 3
}

# Извлечение имени выходного файла из комментария "Output:"
OUTPUT_NAME=""
case "$SOURCE" in
    *.c|*.cpp|*.cc|*.cxx)
        # Для C/C++ ищем комментарий вида // Output: имя
        OUTPUT_NAME=$(awk '/^[[:space:]]*\/\// { if (match($0, /Output:[[:space:]]*([^\r\n]+)/, m)) print m[1] }' "$SOURCE" | head -n1)
        ;;
    *.tex)
        # Для TeX ищем комментарий вида % Output: имя
        OUTPUT_NAME=$(awk '/^[[:space:]]*%/ { if (match($0, /Output:[[:space:]]*([^\r\n]+)/, m)) print m[1] }' "$SOURCE" | head -n1)
        ;;
    *)
        echo "Ошибка: неподдерживаемое расширение файла '$SOURCE'." >&2
        exit 4
        ;;
esac

if [ -z "$OUTPUT_NAME" ]; then
    echo "Ошибка: не найден комментарий 'Output:' в файле '$SOURCE'." >&2
    exit 5
fi

# Полный путь к выходному файлу рядом с исходным
FINAL_OUTPUT="$(dirname "$SOURCE")/$OUTPUT_NAME"

# Копируем исходник во временный каталог
cp "$SOURCE" "$TMPDIR/" || {
    echo "Ошибка: не удалось скопировать исходный файл во временный каталог." >&2
    exit 6
}

# Переходим в временный каталог
cd "$TMPDIR" || {
    echo "Ошибка: не удалось перейти во временный каталог." >&2
    exit 7
}

# Имя скопированного исходника
BASENAME=$(basename "$SOURCE")

# Выполняем сборку в зависимости от расширения
case "$SOURCE" in
    *.c)
        cc -o "$OUTPUT_NAME" "$BASENAME" || {
            echo "Ошибка: компиляция C-файла '$SOURCE' не удалась." >&2
            exit 8
        }
        ;;
    *.cpp|*.cc|*.cxx)
        c++ -o "$OUTPUT_NAME" "$BASENAME" || {
            echo "Ошибка: компиляция C++-файла '$SOURCE' не удалась." >&2
            exit 9
        }
        ;;
    *.tex)
        # Пытаемся собрать с помощью latex -> dvipdf или pdflatex
        if command -v pdflatex > /dev/null; then
            pdflatex -interaction=nonstopmode "$BASENAME" > /dev/null || {
                echo "Ошибка: сборка TeX-файла '$SOURCE' не удалась." >&2
                exit 10
            }
            # pdflatex создаёт .pdf с тем же именем, что и исходник
            # но мы хотим именно OUTPUT_NAME
            if [ "$OUTPUT_NAME" != "${BASENAME%.tex}.pdf" ]; then
                mv "${BASENAME%.tex}.pdf" "$OUTPUT_NAME" || {
                    echo "Ошибка: не удалось переименовать PDF в '$OUTPUT_NAME'." >&2
                    exit 11
                }
            fi
        elif command -v latex > /dev/null && command -v dvipdf > /dev/null; then
            latex -interaction=nonstopmode "$BASENAME" > /dev/null || {
                echo "Ошибка: сборка TeX-файла '$SOURCE' не удалась." >&2
                exit 10
            }
            dvipdf "${BASENAME%.tex}.dvi" "$OUTPUT_NAME" > /dev/null || {
                echo "Ошибка: преобразование DVI в PDF не удалось." >&2
                exit 12
            }
        else
            echo "Ошибка: не найдены ни pdflatex, ни latex+dvipdf." >&2
            exit 13
        fi
        ;;
esac

# Проверка, что выходной файл действительно создан
if [ ! -f "$OUTPUT_NAME" ]; then
    echo "Ошибка: результат сборки '$OUTPUT_NAME' не найден во временном каталоге." >&2
    exit 14
fi

# Копируем результат рядом с исходным файлом
cp "$OUTPUT_NAME" "$FINAL_OUTPUT" || {
    echo "Ошибка: не удалось скопировать результат '$OUTPUT_NAME' в '$FINAL_OUTPUT'." >&2
    exit 15
}

# Успешное завершение
exit 0