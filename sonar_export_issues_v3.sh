#!/bin/bash

###############################################################################
# Script seguro - coleta de issues SonarQube a partir de URL completa
###############################################################################

set -euo pipefail

# ===============================
# FUNÇÃO DE VALIDAÇÃO
# ===============================
validar_param() {
  local valor="$1"
  local nome="$2"

  if [[ ! "$valor" =~ ^[a-zA-Z0-9._:/?=&-]+$ ]]; then
    echo "Erro: $nome inválido -> $valor"
    exit 1
  fi
}

# ===============================
# ENTRADA DA URL
# ===============================
echo "=== Informe a URL do SonarQube (copie do navegador) ==="
read -p "URL: " SONAR_FULL_URL

if [ -z "$SONAR_FULL_URL" ]; then
  echo "Erro: URL não informada"
  exit 1
fi

validar_param "$SONAR_FULL_URL" "URL"

# ===============================
# EXTRAÇÃO DE DADOS DA URL
# ===============================

# Base URL
SONAR_URL="$(echo "$SONAR_FULL_URL" | awk -F'/dashboard' '{print $1}')"

# Project Key
PROJECT_KEY="$(echo "$SONAR_FULL_URL" | grep -oP 'id=\K[^&]+')"

# Branch (opcional)
BRANCH="$(echo "$SONAR_FULL_URL" | grep -oP 'branch=\K[^&]+' || true)"
BRANCH="${BRANCH:-main}"

# ===============================
# TOKEN (OCULTO)
# ===============================
read -s -p "Informe o Token do Sonar: " SONAR_TOKEN
echo

if [ -z "$SONAR_TOKEN" ]; then
  echo "Erro: token não informado"
  exit 1
fi

# ===============================
# VALIDAÇÃO FINAL
# ===============================
validar_param "$SONAR_URL" "SONAR_URL"
validar_param "$PROJECT_KEY" "PROJECT_KEY"
validar_param "$BRANCH" "BRANCH"

# ===============================
# LOG DE CONFIG
# ===============================
echo
echo "===== CONFIG EXTRAÍDA ====="
echo "SONAR_URL  : $SONAR_URL"
echo "PROJECT_KEY: $PROJECT_KEY"
echo "BRANCH     : $BRANCH"
echo "==========================="
echo

# ===============================
# VALIDAR DEPENDÊNCIAS
# ===============================
command -v curl >/dev/null || { echo "Erro: curl não encontrado"; exit 1; }
command -v jq >/dev/null || { echo "Erro: jq não encontrado"; exit 1; }

# ===============================
# CONFIG EXECUÇÃO
# ===============================
PAGE_SIZE=100
OUTPUT_FILE="sonarqube-issues.json"
page=1
all_issues="[]"

echo "Iniciando coleta..."

# ===============================
# LOOP DE PAGINAÇÃO
# ===============================
while true; do
  echo "Coletando página $page..."

  response_file="response.json"

  HTTP_STATUS=$(curl --fail --silent --show-error \
    --connect-timeout 10 \
    --retry 3 \
    -w "%{http_code}" \
    -o "$response_file" \
    -u "$SONAR_TOKEN:" \
    "$SONAR_URL/api/issues/search?componentKeys=$PROJECT_KEY&branch=$BRANCH&page=$page&ps=$PAGE_SIZE")

  if [ "$HTTP_STATUS" -ne 200 ]; then
    echo "Erro ao chamar API (HTTP $HTTP_STATUS)"
    exit 1
  fi

  issues=$(jq '.issues' "$response_file")
  count=$(echo "$issues" | jq 'length')

  if [ "$count" -eq 0 ]; then
    echo "Fim da coleta."
    break
  fi

  all_issues=$(jq -s 'add' <(echo "$all_issues") <(echo "$issues"))

  page=$((page + 1))
done

# ===============================
# SALVAR RESULTADO
# ===============================
echo "$all_issues" > "$OUTPUT_FILE"

echo
echo "Arquivo gerado: $OUTPUT_FILE"
echo "Total de issues: $(echo "$all_issues" | jq 'length')"

###############################################################################
# FIM
###############################################################################
