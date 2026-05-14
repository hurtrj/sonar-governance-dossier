#!/bin/bash

###############################################################################
# Script seguro para exportação de issues do SonarQube
###############################################################################

set -euo pipefail

# ===============================
# CARREGAR VARIÁVEIS (.env opcional)
# ===============================
if [ -f ".env" ]; then
  source .env
fi

# ===============================
# VALIDAÇÃO DE CONFIGURAÇÃO
# ===============================
SONAR_URL="${SONAR_URL:-}"
PROJECT_KEY="${PROJECT_KEY:-}"
BRANCH="${BRANCH:-main}"
PAGE_SIZE="${PAGE_SIZE:-100}"

if [ -z "$SONAR_URL" ] || [ -z "$PROJECT_KEY" ]; then
  echo "Erro: SONAR_URL e PROJECT_KEY são obrigatórios."
  exit 1
fi

if [ -z "${SONAR_TOKEN:-}" ]; then
  echo "Erro: SONAR_TOKEN não definido."
  exit 1
fi

# ===============================
# VALIDAÇÃO DE ENTRADAS
# ===============================
validar_param() {
  local valor="$1"
  if [[ ! "$valor" =~ ^[a-zA-Z0-9._:/-]+$ ]]; then
    echo "Erro: valor inválido -> $valor"
    exit 1
  fi
}

validar_param "$SONAR_URL"
validar_param "$PROJECT_KEY"
validar_param "$BRANCH"

# ===============================
# VALIDAÇÃO DE DEPENDÊNCIAS
# ===============================
command -v curl >/dev/null 2>&1 || { echo "Erro: curl não encontrado"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Erro: jq não encontrado"; exit 1; }

# ===============================
# CONFIG DE EXECUÇÃO
# ===============================
OUTPUT_FILE="sonarqube-issues.json"
page=1
all_issues="[]"

echo "Iniciando coleta de issues..."

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
    -o $response_file \
    -u "$SONAR_TOKEN:" \
    "$SONAR_URL/api/issues/search?componentKeys=$PROJECT_KEY&branch=$BRANCH&page=$page&ps=$PAGE_SIZE")

  if [ "$HTTP_STATUS" -ne 200 ]; then
    echo "Erro API (status $HTTP_STATUS)"
    exit 1
  fi

  issues=$(jq '.issues' "$response_file")
  count=$(echo "$issues" | jq 'length')

  if [ "$count" -eq 0 ]; then
    echo "Fim da coleta."
    break
  fi

  all_issues=$(jq -s 'add' <(echo "$all_issues") <(echo "$issues"))

  page=$((page+1))
done

# ===============================
# SALVAR RESULTADO
# ===============================
echo "$all_issues" > "$OUTPUT_FILE"

echo "Arquivo gerado: $OUTPUT_FILE"
echo "Total de issues: $(echo "$all_issues" | jq 'length')"

###############################################################################
# FIM
###############################################################################
