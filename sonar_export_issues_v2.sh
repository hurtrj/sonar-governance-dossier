#!/bin/bash
###############################################################################
# Script: sonar_export_issues_v2.sh
#
# Descrição:
#   Script responsável por coletar issues de qualidade de código a partir da
#   API do SonarQube para MÚLTIPLOS PROJETOS, consolidando os dados em um único
#   arquivo JSON seguro e auditável.
#
# Objetivo:
#   - Coletar issues OPEN ou CONFIRMED de múltiplos projetos
#   - Associar informações completas das regras SonarQube
#   - Preservar rastreabilidade por projeto
#
# Segurança:
#   - Nenhuma credencial hardcoded
#   - Token fornecido via variável de ambiente SONAR_TOKEN
#
# Versão:
#   v2.0 – suporte a múltiplos projetos
#
# Data:
#   2026-04-24
###############################################################################

# ===============================
# VALIDAÇÃO DE DEPENDÊNCIAS
# ===============================
command -v curl >/dev/null 2>&1 || { echo "Erro: curl não encontrado"; exit 1; }
command -v jq   >/dev/null 2>&1 || { echo "Erro: jq não encontrado"; exit 1; }

# ===============================
# CONFIGURAÇÃO DO CONTEXTO
# ===============================
SONAR_URL="https://sonarqube.exemplo.com"
BRANCH="main"
PAGE_SIZE=500
TIMEOUT=15

# 🔹 LISTA DE PROJETOS (MULTI‑PROJETO)
PROJECT_KEYS=(
  "serviceorder-ecm-digitaldocuments-svc"
  "outro-projeto-exemplo"
)

OUTPUT_FILE="sonarqube-issues-safe.json"

# ===============================
# VALIDAÇÃO DE TOKEN
# ===============================
if [ -z "$SONAR_TOKEN" ]; then
  echo "Erro: variável SONAR_TOKEN não definida."
  exit 1
fi

echo "=============================================="
echo "Coleta SonarQube – Múltiplos Projetos"
echo "Branch: $BRANCH"
echo "=============================================="

echo "[" > "$OUTPUT_FILE"
FIRST_GLOBAL=true

# ===============================
# LOOP POR PROJETO
# ===============================
for PROJECT_KEY in "${PROJECT_KEYS[@]}"; do

  echo "----------------------------------------------"
  echo "Processando projeto: $PROJECT_KEY"
  echo "----------------------------------------------"

  BASE_JSON=$(curl -sk --max-time "$TIMEOUT" \
    -u "$SONAR_TOKEN:" \
    "$SONAR_URL/api/issues/search?componentKeys=$PROJECT_KEY&branch=$BRANCH&statuses=OPEN,CONFIRMED&ps=$PAGE_SIZE")

  if ! echo "$BASE_JSON" | jq -e '.issues' >/dev/null 2>&1; then
    echo "⚠ Falha ao consultar projeto $PROJECT_KEY. Pulando."
    continue
  fi

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
    # ESCRITA NO JSON FINAL
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

done

echo "]" >> "$OUTPUT_FILE"

echo "=============================================="
echo "Coleta concluída com sucesso"
echo "Arquivo gerado: $OUTPUT_FILE"
echo "=============================================="
