# Dossiê de Governança – SonarQube

Este projeto apresenta uma solução completa para:

- Extração automatizada de issues do SonarQube
- Consolidação dos dados em JSON auditável
- Visualização dinâmica em HTML5 (offline)
- Apoio a governança, auditoria e qualidade de software

## Conteúdo
- Script de coleta via API do SonarQube
- JSON consolidado com todos os dados das issues
- Página HTML5 para consulta dinâmica
- Documentação técnica passo a passo

## Como usar
1. Abra o arquivo `index.html`
2. Clique em **Carregar JSON**
3. Selecione `sonarqube-issues-safe.json`
4. Navegue pelas issues

## Contexto
Projeto usado como evidência técnica e estudo de caso para governança de código e dívida técnica.

## Script de Coleta de Dados do SonarQube

O arquivo `sonar_export_issues_v0.sh` é um script Bash responsável por
extrair informações de qualidade de código a partir da API do SonarQube,
gerando um arquivo JSON consolidado para uso em relatórios de governança.

### Objetivo
- Automatizar a coleta de issues do SonarQube
- Consolidar dados técnicos e metadados das regras
- Criar um artefato auditável e independente da interface gráfica

### Escopo da coleta
O script coleta:
- Issues abertas ou confirmadas
- Severidade, mensagem, arquivo e linha
- Esforço estimado (technical debt)
- Detalhes completos das regras associadas

### O que o script **não faz**
- Não coleta histórico de alterações (changelog)
- Não executa correções automáticas
- Não realiza chamadas administrativas na API

### Segurança
Esta versão do script é **sanitizada**, não contendo:
- Tokens sensíveis
- URLs internas hardcoded
- Credenciais de usuário

Tokens e parâmetros sensíveis devem ser fornecidos via variáveis de ambiente
ou edição manual antes da execução.

### Uso
```bash
chmod +x sonar_export_issues_v0.sh
./sonar_export_issues_v0.sh
