#!/bin/bash
###############################################################################
# Script: sonar_export_issues_v4.sh
#
# Descrição:
#   Coleta issues do SonarQube a partir de URL (dashboard ou issues).
#
# Token:
#   export SONAR_TOKEN="SEU_TOKEN_AQUI"  # BATATINHA
###############################################################################

# ===============================
# VALIDAÇÃO DE DEPENDÊNCIAS
# ===============================
command -v curl >/dev/null 2>&1 || { echo "Erro: curl não encontrado"; exit 1; }
command -v jq   >/dev/null 2>&1 || { echo "Erro: jq não encontrado"; exit 1; }

# ===============================
# ENTRADA DO USUÁRIO
# ===============================
echo "Cole a URL do SonarQube (dashboard ou issues):"
read -r SONAR_UI_URL

# ===============================
# NORMALIZAÇÃO DA URL
# ===============================
# Corrige &amp; -> &
SONAR_UI_URL=$(echo "$SONAR_UI_URL" | sed 's/&amp;/\&/g')

# ===============================
# VALIDAÇÃO DE TOKEN
# ===============================
if [ -z "$SONAR_TOKEN" ]; then
  echo "Erro: variável SONAR_TOKEN não definida."
  exit 1
fi

# ===============================
# EXTRAÇÃO DE DADOS
# ===============================
SONAR_URL=$(echo "$SONAR_UI_URL" | cut -d'/' -f1-3)

PROJECT_KEY=$(echo "$SONAR_UI_URL" | sed -n 's/.*[?&]id=\([^&]*\).*/\1/p')

BRANCH_RAW=$(echo "$SONAR_UI_URL" | sed -n 's/.*[?&]branch=\([^&]*\).*/\1/p')

# Decodifica %2F → /
BRANCH=$(echo "$BRANCH_RAW" | sed 's/%2F/\//g')

STATUSES_RAW=$(echo "$SONAR_UI_URL" | sed -n 's/.*[?&]issueStatuses=\([^&]*\).*/\1/p')

# Default de status
[ -z "$STATUSES_RAW" ] && STATUSES="OPEN,CONFIRMED" || STATUSES="$STATUSES_RAW"

# Default branch
[ -z "$BRANCH" ] && BRANCH="main"

# ===============================
# CONFIGURAÇÕES
# ===============================
OUTPUT_FILE="sonarqube-issues-safe.json"
PAGE_SIZE=500
TIMEOUT=15

echo "=============================================="
echo "Coleta SonarQube – automática"
echo "Host: $SONAR_URL"
echo "Projeto: $PROJECT_KEY"
echo "Branch: $BRANCH"
echo "Statuses: $STATUSES"
echo "=============================================="

# ===============================
# MONTA QUERY FINAL
# ===============================
QUERY="$SONAR_URL/api/issues/search?componentKeys=$PROJECT_KEY&branch=$BRANCH&statuses=$STATUSES&ps=$PAGE_SIZE"

echo "Query API:"
echo "$QUERY"
echo "=============================================="

# ===============================
# EXECUÇÃO
# ===============================
echo "[" > "$OUTPUT_FILE"
FIRST_GLOBAL=true

BASE_JSON=$(curl -sk --max-time "$TIMEOUT" \
  -u "$SONAR_TOKEN:" \
  "$QUERY")

if ! echo "$BASE_JSON" | jq -e '.issues' >/dev/null 2>&1; then
  echo "Erro ao consultar API."
  exit 1
fi

TOTAL=$(echo "$BASE_JSON" | jq '.total')
echo "Total de issues encontradas: $TOTAL"

echo "$BASE_JSON" | jq -c '.issues[]' | while read -r ISSUE; do

  ISSUE_KEY=$(echo "$ISSUE" | jq -r '.key')
  RULE_KEY=$(echo "$ISSUE" | jq -r '.rule // empty')

  STATUS="OK"
  ERRORS=()
  RULE_JSON="null"

  # ===============================
  # BUSCA DA REGRA
  # ===============================
  if [ -n "$RULE_KEY" ]; then
    RULE_RAW=$(curl -sk --max-time "$TIMEOUT" \
      -u "$SONAR_TOKEN:" \
      "$SONAR_URL/api/rules/show?key=$RULE_KEY")

    if echo "$RULE_RAW" | jq -e . >/dev/null 2>&1; then
      if echo "$RULE_RAW" | jq -e '.errors' >/dev/null; then
        STATUS="PARTIAL"
        ERRORS+=("Erro ao buscar regra $RULE_KEY")
      else
        RULE_JSON="$RULE_RAW"
      fi
    else
      STATUS="PARTIAL"
      ERRORS+=("Resposta inválida da API de regras")
    fi
  else
    STATUS="PARTIAL"
    ERRORS+=("Issue sem rule key")
  fi

  # ===============================
  # ESCRITA JSON
  # ===============================
  if [ "$FIRST_GLOBAL" = false ]; then
    echo "," >> "$OUTPUT_FILE"
  fi
  FIRST_GLOBAL=false

  jq -n \
    --arg projectKey "$PROJECT_KEY" \
    --arg issueKey "$ISSUE_KEY" \
    --arg status "$STATUS" \
    --argjson issue "$ISSUE" \
    --arg rule "$(echo "$RULE_JSON" | jq -c '.')" \
    --argjson errors "$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .)" \
    '{
      meta: {
        projectKey: $projectKey,
        issueKey: $issueKey,
        coletaStatus: $status
      },
      issue: $issue,
      rule: ($rule | fromjson?),
      errors: (if ($errors | length) > 0 then $errors else null end)
    }' >> "$OUTPUT_FILE"

done

echo "]" >> "$OUTPUT_FILE"

echo "=============================================="
echo "Coleta concluída com sucesso"
echo "Arquivo gerado: $OUTPUT_FILE"
echo "=============================================="
