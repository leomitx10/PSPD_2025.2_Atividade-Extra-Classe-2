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

## Como Rodar os Testes de Configuração

O projeto inclui diversos scripts para testar e analisar o comportamento do Hadoop em diferentes cenários. Todos estão no diretório `scripts/` e podem ser executados de dentro do container master ou do host (caso o Docker esteja rodando).

### Exemplos de execução:

```bash
# Execute dentro da pasta do projeto (no host ou dentro do container master)
cd scripts
./testar_blocksize.sh           # Testa diferentes tamanhos de bloco do HDFS
./testar_memoria_nm.sh          # Testa diferentes quantidades de memória para NodeManagers
./testar_memoria_tasks.sh       # Testa diferentes quantidades de memória para tasks Map/Reduce
./testar_replicacao.sh          # Testa diferentes fatores de replicação do HDFS
./testar_tolerancia_falhas.sh   # Testa tolerância a falhas (DataNodes)
./testar_vcores_nm.sh           # Testa diferentes quantidades de vCores por NodeManager
```

### O que cada script faz:

- **testar_blocksize.sh**: Avalia o impacto do tamanho de bloco do HDFS na performance do WordCount.
- **testar_memoria_nm.sh**: Mede o efeito de diferentes quantidades de memória disponíveis para NodeManagers.
- **testar_memoria_tasks.sh**: Analisa o impacto da memória alocada para tasks Map/Reduce.
- **testar_replicacao.sh**: Testa o desempenho e uso de espaço com diferentes fatores de replicação.
- **testar_tolerancia_falhas.sh**: Simula falhas de DataNodes durante a execução do WordCount para avaliar a tolerância a falhas do cluster.
- **testar_vcores_nm.sh**: Avalia o efeito de diferentes quantidades de vCores por NodeManager no desempenho do processamento.

Os resultados de cada teste são exibidos ao final da execução de cada script, facilitando a análise comparativa.

## Resultados e Monitoramento

- Acompanhe o progresso e resultados via:
  - ResourceManager UI: http://localhost:8088
  - NameNode UI:        http://localhost:9870
- Saída do WordCount disponível no HDFS em `/user/root/wordcount_output`.

---

Desenvolvido para fins acadêmicos na UnB - FCTE.
