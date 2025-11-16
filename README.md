# WordCount Hadoop MapReduce - PSPD 2025.2

Implementação do clássico WordCount usando o framework MapReduce do Apache Hadoop, como atividade da disciplina **PSPD - Programação para Sistemas Paralelos e Distribuídos** (UnB).

## Objetivo

Executar e analisar o processamento distribuído de contagem de palavras em grandes volumes de dados, utilizando um cluster Hadoop simulado via Docker Compose, com scripts automatizados para geração de dados, execução e testes.

## Estrutura do Projeto


```
build.sh           # Build do projeto
comorodar.md       # Guia de execução
docker-compose.yml # Orquestração Hadoop
Dockerfile         # Imagem Hadoop customizada
pom.xml            # Configuração Maven
config/            # Configurações Hadoop
config_testes/     # Configs para experimentos
scripts/           # Scripts de automação
src/               # Código-fonte Java
```

## Como Executar

Veja o arquivo [`comorodar.md`](comorodar.md) para instruções detalhadas. Resumo dos passos principais:

1. **Pré-requisitos:**
   - Docker e Docker Compose instalados
   - Linux (recomendado Ubuntu 20.04+)

2. **Clonar o repositório:**
   ```bash
   git clone <url-do-repositorio>
   cd PSPD_2025.2_Atividade-Extra-Classe-2
   ```

3. **Build do projeto:**
   ```bash
   ./build.sh
   ```

4. **Subir o cluster Hadoop:**
   ```bash
   docker-compose up --build -d
   ```

5. **Acessar o container master:**
   ```bash
   docker exec -it hadoop-master bash
   ```

6. **Gerar dados de teste:**
   ```bash
   cd scripts
   ./gerar_dados.sh
   ```

7. **Executar o WordCount:**
   ```bash
   ./executar_wordcount.sh
   ```

## Scripts Principais

- `build.sh`: Compila e empacota o projeto Java em um JAR pronto para Hadoop.
- `scripts/gerar_dados.sh`: Gera um arquivo massivo de texto para teste de performance.
- `scripts/executar_wordcount.sh`: Automatiza upload dos dados ao HDFS e executa o WordCount.
- `scripts/start-master.sh` e `scripts/start-slave.sh`: Inicializam os serviços Hadoop nos containers.

## Código-Fonte Java

- `WordCountDriver.java`: Configura e executa o job MapReduce.
- `WordCountMapper.java`: Mapeia cada palavra para o valor 1.
- `WordCountReducer.java`: Soma as ocorrências de cada palavra.

## Configurações

- `config/`: Arquivos de configuração do Hadoop (core-site.xml, hdfs-site.xml, etc).
- `config_testes/`: Configurações alternativas para experimentos (blocksize, replicação, memória, vcores).

## Resultados e Monitoramento

- Acompanhe o progresso e resultados via:
  - ResourceManager UI: http://localhost:8088
  - NameNode UI:        http://localhost:9870
- Saída do WordCount disponível no HDFS em `/user/root/wordcount_output`.

## Observações

- O projeto é totalmente automatizado para facilitar testes e experimentos didáticos.
- Para alterar parâmetros do Hadoop, utilize os arquivos em `config_testes/` e reinicie o cluster.

---

Desenvolvido para fins acadêmicos na UnB - FCTE.
