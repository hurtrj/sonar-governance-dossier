#!/bin/bash

SONAR_URL=""
PROJECT_KEY="serviceorder"
BRANCH="feature"
TOKEN="SEU TOKEN"

OUTPUT="sonarqube-issues-safe.json"
TIMEOUT=10   # segundos por chamada curl

echo "========================================"
echo "Exportação SonarQube – modo seguro (v3)"
echo "Projeto : $PROJECT_KEY"
echo "Branch  : $BRANCH"
echo "========================================"

echo "[" > "$OUTPUT"
FIRST=true

BASE_JSON=$(curl -sk --max-time $TIMEOUT -u "$TOKEN:" \
"$SONAR_URL/api/issues/search?componentKeys=$PROJECT_KEY&branch=$BRANCH&statuses=OPEN,CONFIRMED&ps=500")

TOTAL=$(echo "$BASE_JSON" | jq '.issues | length')
COUNT=0

echo "Total de issues encontradas: $TOTAL"
echo "----------------------------------------"

echo "$BASE_JSON" | jq -c '.issues[]' | while read -r ISSUE; do
  COUNT=$((COUNT+1))

  ISSUE_KEY=$(echo "$ISSUE" | jq -r '.key')
  RULE_KEY=$(echo "$ISSUE" | jq -r '.rule // empty')

  echo "[${COUNT}/${TOTAL}] Processando issue: $ISSUE_KEY"

  STATUS="OK"
  ERRORS=()
  RULE_JSON="null"

  if [ -n "$RULE_KEY" ]; then
    echo "   ↳ Buscando regra $RULE_KEY"

    RULE_RAW=$(curl -sk --max-time $TIMEOUT -u "$TOKEN:" \
      "$SONAR_URL/api/rules/show?key=$RULE_KEY")

    if echo "$RULE_RAW" | jq -e . >/dev/null 2>&1; then
      if echo "$RULE_RAW" | jq -e '.errors' >/dev/null; then
        STATUS="PARTIAL"
        ERRORS+=("Erro ao buscar regra $RULE_KEY")
        echo "   ⚠ Falha ao buscar regra"
      else
        RULE_JSON="$RULE_RAW"
        echo "   ✔ Regra obtida"
      fi
    else
      STATUS="PARTIAL"
      ERRORS+=("Resposta inválida da API rules/show")
      echo "   ⚠ Resposta não JSON"
    fi
  else
    STATUS="PARTIAL"
    ERRORS+=("Rule key ausente")
    echo "   ⚠ Issue sem rule key"
  fi

  if [ "$FIRST" = false ]; then
    echo "," >> "$OUTPUT"
  fi
  FIRST=false

  jq -n \
    --arg issueKey "$ISSUE_KEY" \
    --arg status "$STATUS" \
    --argjson issue "$ISSUE" \
    --arg rule "$(echo "$RULE_JSON" | jq -c '.') " \
    --argjson errors "$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .)" \
    '{
      meta: {
        issueKey: $issueKey,
        status: $status
      },
      issue: $issue,
      rule: ($rule | fromjson?),
      errors: (if ($errors | length) > 0 then $errors else null end)
    }' >> "$OUTPUT"

done

echo "]" >> "$OUTPUT"

echo "----------------------------------------"
echo "Exportação concluída com sucesso ✅"
echo "Arquivo gerado: $OUTPUT"
echo "----------------------------------------"
``
