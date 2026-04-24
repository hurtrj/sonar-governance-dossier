#!/bin/bash
###############################################################################
# Script: sonar_export_issues_v1.sh
#
# Descrição:
#   Script responsável por coletar issues de qualidade de código a partir da
#   API do SonarQube, consolidando os dados em um arquivo JSON estruturado,
#   seguro e auditável.
#
# Objetivo:
#   - Extrair issues abertas ou confirmadas de um projeto SonarQube
#   - Consolidar dados técnicos das issues
#   - Associar informações completas das regras SonarQube
#   - Gerar um artefato único para governança e auditoria
#
# Público-alvo:
#   - Governança de TI
#   - Qualidade de Software
#   - Auditoria Técnica
#   - Engenharia de Software
#
# Requisitos:
#   - bash
#   - curl
#   - jq
#
# Segurança:
#   - Este script NÃO contém tokens ou credenciais hardcoded
#   - Tokens devem ser fornecidos via variável de ambiente
#
# Variáveis sensíveis:
#   - SONAR_TOKEN (obrigatória)
#
# Versão:
#   v1.0 – versão sanitizada e documentada para publicação
#
# Data:
#   2026-04-24
###############################################################################

# ===============================
# VALIDAÇÃO DE DEPENDÊNCIAS
# ===============================
command -v curl >/dev/null 2>&1 || {
  echo "Erro: 'curl' não encontrado."
  exit 1
}

command -v jq >/dev/null 2>&1 || {
  echo "Erro: 'jq' não encontrado."
  exit 1
}

# ===============================
# CONFIGURAÇÕES DO CONTEXTO
# ===============================
SONAR_URL="https://sonarqube.exemplo.com"
PROJECT_KEY="meu-projeto"
BRANCH="main"
PAGE_SIZE=500
TIMEOUT=15

# ===============================
# VALIDAÇÃO DE TOKEN
# ===============================
if [ -z "$SONAR_TOKEN" ]; then
  echo "Erro: variável de ambiente SONAR_TOKEN não definida."
  echo "Exemplo:"
  echo "export SONAR_TOKEN=seu_token_aqui"
  exit 1
fi

# ===============================
# ARQUIVO DE SAÍDA
# ===============================
OUTPUT_FILE="sonarqube-issues-safe.json"

echo "=============================================="
echo "Iniciando coleta de issues do SonarQube"
echo "Projeto : $PROJECT_KEY"
echo "Branch  : $BRANCH"
echo "=============================================="

# ===============================
# CONSULTA PRINCIPAL DE ISSUES
# Endpoint: /api/issues/search
# ===============================
BASE_JSON=$(curl -sk --max-time "$TIMEOUT" \
  -u "$SONAR_TOKEN:" \
  "$SONAR_URL/api/issues/search?componentKeys=$PROJECT_KEY&branch=$BRANCH&statuses=OPEN,CONFIRMED&ps=$PAGE_SIZE")

# Validação básica da resposta
if ! echo "$BASE_JSON" | jq -e '.issues' >/dev/null 2>&1; then
  echo "Erro: resposta inválida da API de issues."
  exit 1
fi

TOTAL_ISSUES=$(echo "$BASE_JSON" | jq '.issues | length')

echo "Issues encontradas: $TOTAL_ISSUES"
echo "[" > "$OUTPUT_FILE"

FIRST=true
COUNT=0

# ===============================
# PROCESSAMENTO INDIVIDUAL DE ISSUES
# ===============================
echo "$BASE_JSON" | jq -c '.issues[]' | while read -r ISSUE; do

  COUNT=$((COUNT+1))

  ISSUE_KEY=$(echo "$ISSUE" | jq -r '.key')
  RULE_KEY=$(echo "$ISSUE" | jq -r '.rule // empty')

  STATUS="OK"
  ERRORS=()

  RULE_JSON="null"

  echo "[$COUNT/$TOTAL_ISSUES] Processando issue: $ISSUE_KEY"

  # ===============================
  # BUSCA DA REGRA ASSOCIADA
  # Endpoint: /api/rules/show
  # ===============================
  if [ -n "$RULE_KEY" ]; then
    RULE_RAW=$(curl -sk --max-time "$TIMEOUT" \
      -u "$SONAR_TOKEN:" \
      "$SONAR_URL/api/rules/show?key=$RULE_KEY")

    # Valida se a resposta da regra é JSON válido
    if echo "$RULE_RAW" | jq -e . >/dev/null 2>&1; then
      if echo "$RULE_RAW" | jq -e '.errors' >/dev/null; then
        STATUS="PARTIAL"
        ERRORS+=("Erro ao buscar regra $RULE_KEY")
      else
        RULE_JSON="$RULE_RAW"
      fi
    else
      STATUS="PARTIAL"
      ERRORS+=("Resposta inválida ao buscar regra $RULE_KEY")
    fi
  else
    STATUS="PARTIAL"
    ERRORS+=("Issue sem rule key")
  fi

  # ===============================
  # ESCRITA SEGURA NO JSON FINAL
  # ===============================
  if [ "$FIRST" = false ]; then
    echo "," >> "$OUTPUT_FILE"
  fi
  FIRST=false

  jq -n \
    --arg issueKey "$ISSUE_KEY" \
    --arg status "$STATUS" \
    --argjson issue "$ISSUE" \
    --arg rule "$(echo "$RULE_JSON" | jq -c '.')" \
    --argjson errors "$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .)" \
    '{
      meta: {
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
echo "Coleta finalizada com sucesso"
echo "Arquivo gerado: $OUTPUT_FILE"
echo "=============================================="
