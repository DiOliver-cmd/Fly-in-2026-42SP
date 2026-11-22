#!/usr/bin/env bash
# CLI de verificações do projeto Fly-In (42).
# Executa localmente as mesmas checagens do GitHub Actions.
#
# Uso:
#   bash scripts/ci.sh
#
# Requisitos: python3 >= 3.10, flake8, mypy, pytest (instalados pelo workflow
# ou via `make install` quando o Makefile existir).

set -euo pipefail

PYTHON="${PYTHON:-python3}"

echo "== Versão do Python =="
"$PYTHON" - <<'PY'
import sys

if sys.version_info < (3, 10):
    sys.exit("ERRO: Python 3.10+ é obrigatório (encontrado %s)." % sys.version.split()[0])
print(sys.version.split()[0])
PY

echo
echo "== Arquivos Python rastreados =="
PYFILES=()
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r f; do
        [ -n "$f" ] && PYFILES+=("$f")
    done < <(git ls-files '*.py')
else
    while IFS= read -r f; do
        [ -n "$f" ] && PYFILES+=("$f")
    done < <(find . -name '*.py' -not -path './.git/*' -not -path './venv/*' -not -path './.venv/*')
fi

if [ "${#PYFILES[@]}" -eq 0 ]; then
    echo "Nenhum arquivo .py encontrado ainda — etapa de setup inicial."
    echo "Pulando lint/type/tests (a checagem volta a valer quando houver código)."
    exit 0
fi

printf '  %s\n' "${PYFILES[@]}"

echo
echo "== Bibliotecas de grafo proibidas (networkx/graphlib) =="
if grep -nE '^[[:space:]]*(import|from)[[:space:]]+(networkx|graphlib)([[:space:].]|$)' "${PYFILES[@]}"; then
    echo "ERRO: uso de biblioteca de grafo proibida pelo subject." >&2
    exit 1
fi
echo "OK: nenhuma importação proibida."

echo
echo "== flake8 =="
flake8 "${PYFILES[@]}"

echo
echo "== mypy (flags do subject) =="
mypy "${PYFILES[@]}" \
    --warn-return-any \
    --warn-unused-ignores \
    --ignore-missing-imports \
    --disallow-untyped-defs \
    --check-untyped-defs

echo
echo "== pytest =="
has_tests=0
if compgen -G 'test_*.py' >/dev/null || compgen -G '*_test.py' >/dev/null; then
    has_tests=1
fi
if [ -d tests ] && find tests -type f \( -name 'test_*.py' -o -name '*_test.py' \) -print -quit | grep -q .; then
    has_tests=1
fi
if [ "$has_tests" -eq 1 ]; then
    pytest -q
else
    echo "Sem testes encontrados — pulando pytest."
fi

echo
echo "✅ Todas as verificações passaram."
