📊 SonarQube Issues Export & Interactive Report
📌 Descrição
Este projeto permite:

✅ Coletar issues do SonarQube via API (usando uma URL da interface web)
✅ Consolidar os dados em um JSON estruturado
✅ Visualizar as informações em um relatório HTML interativo e amigável

O foco é atender tanto:

👨‍💻 usuários técnicos (detalhes completos)
🧑‍💼 usuários não técnicos (visão simplificada e clara)


🚀 Funcionalidades
🔹 1. Coleta automatizada via URL
O script agora aceita diretamente:

URL de Issues
URL de Dashboard

Exemplo:
/project/issues?id=projeto&branch=main
/dashboard?id=projeto&branch=feature/x

✅ O script extrai automaticamente:

Projeto (projectKey)
Branch
Status das issues


🔹 2. Segurança

✅ Nenhuma credencial armazenada no código
✅ Uso de variável de ambiente:

Shellexport SONAR_TOKEN="seu_token"  # BATATINHAMostrar mais linhas

🔹 3. Estrutura de dados enriquecida
Cada issue contém:
JSON{  "meta": {    "projectKey": "...",    "issueKey": "...",    "coletaStatus": "OK | PARTIAL"  },  "issue": { ... },  "rule": { ... },  "errors": [...]}Mostrar mais linhas
✅ Inclui:

dados completos da issue
detalhes da regra Sonar
rastreabilidade
logs de erro


🔹 4. Relatório HTML interativo
Nova interface com foco em usabilidade:
✅ Visão amigável (para não técnicos)


Classificação por impacto:

Alta prioridade
Média prioridade
Baixo impacto



Resumo simples:

descrição clara do problema
arquivo afetado
tipo de issue




✅ Painel de indicadores

Contagem por prioridade
Visão rápida de risco do sistema


✅ Filtros e busca

🔍 Busca por texto
🔎 Filtragem implícita por relevância


✅ Detalhes sob demanda
Cada issue possui botão:
Ver detalhes técnicos

✅ Ao clicar:

exibe JSON completo
mostra dados técnicos detalhados
mantém a interface limpa inicialmente


🎯 Benefícios
Para usuários não técnicos
✔ Interface limpa e organizada
✔ Linguagem simplificada
✔ Fácil entendimento do impacto
✔ Foco em decisão, não em código

Para usuários técnicos
✔ Acesso ao JSON completo
✔ Rastreamento por rule e issue
✔ Facilidade para debug
✔ Dados prontos para auditoria

🛠️ Como usar
1. Definir token
Shellexport SONAR_TOKEN="seu_token"Mostrar mais linhas

2. Executar script
Shell./sonar_export_issues_v4.shMostrar mais linhas

3. Informar URL
Exemplo:
http://sonarqube.../dashboard?id=projeto&branch=feature%2Fteste


4. Abrir relatório

Abra o arquivo HTML no navegador
Carregue o JSON gerado
Navegue pelas issues


📄 Saída
Arquivo gerado:
sonarqube-issues-safe.json


🔒 Considerações de Segurança

Token não é armazenado
Comunicação pode ignorar SSL em ambiente interno (-k)
Nenhum dado sensível é persistido fora do JSON gerado


🚧 Próximas melhorias (roadmap)

📈 Gráficos (distribuição de severidades)
📊 Dashboard executivo (nível gestão)
⚡ Cache de regras (melhor performance)
📄 Exportação para Excel
🔍 Agrupamento por componente
🧠 Insights automáticos (recomendações)


✅ Conclusão
Este projeto transforma dados técnicos do SonarQube em:
👉 Informação acessível
👉 Visual amigável
👉 Relatório auditável
👉 Ferramenta de decisão
