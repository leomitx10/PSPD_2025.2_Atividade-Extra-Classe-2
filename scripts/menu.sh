#!/bin/bash

echo "=========================================="
echo "HADOOP CLUSTER - MENU PRINCIPAL"
echo "=========================================="
echo ""

mostrar_menu() {
    echo "Escolha uma opção:"
    echo ""
    echo "PREPARAÇÃO:"
    echo "  1) Gerar dados para testes"
    echo "  2) Executar wordcount único (teste básico)"
    echo "  3) Executar múltiplos wordcounts simultâneos"
    echo ""
    echo "MONITORAMENTO:"
    echo "  4) Monitorar cluster (snapshot)"
    echo "  5) Monitorar cluster (contínuo)"
    echo ""
    echo "TESTES:"
    echo "  6) Teste de Performance (escalabilidade)"
    echo "  7) Teste de Resiliência (tolerância a falhas)"
    echo "  8) Simular falhas (interativo)"
    echo ""
    echo "CLUSTER:"
    echo "  9) Iniciar cluster (docker-compose up)"
    echo "  10) Parar cluster (docker-compose down)"
    echo "  11) Reiniciar cluster"
    echo "  12) Ver logs do cluster"
    echo ""
    echo "  0) Sair"
    echo ""
}

executar_opcao() {
    case $1 in
        1)
            echo ""
            echo "Gerando dados..."
            ./gerar_dados.sh
            ;;
        2)
            echo ""
            echo "Executando wordcount único..."
            ./executar_wordcount.sh
            ;;
        3)
            echo ""
            read -p "Quantos jobs simultâneos? (padrão: 3): " num_jobs
            num_jobs=${num_jobs:-3}
            echo "Executando $num_jobs wordcounts simultâneos..."
            ./executar_multiplos_wordcount.sh $num_jobs
            ;;
        4)
            echo ""
            echo "Monitorando cluster (snapshot)..."
            ./monitorar_jobs.sh
            ;;
        5)
            echo ""
            read -p "Intervalo de atualização em segundos (padrão: 5): " intervalo
            intervalo=${intervalo:-5}
            echo "Monitorando cluster continuamente..."
            echo "Pressione Ctrl+C para parar"
            ./monitorar_jobs.sh -c $intervalo
            ;;
        6)
            echo ""
            echo "Iniciando teste de performance..."
            echo "Este teste levará aproximadamente 15-20 minutos"
            read -p "Continuar? (s/n): " confirma
            if [ "$confirma" == "s" ]; then
                ./testar_performance.sh
            else
                echo "Teste cancelado."
            fi
            ;;
        7)
            echo ""
            echo "Iniciando teste de resiliência..."
            echo "Este teste levará aproximadamente 20-30 minutos"
            read -p "Continuar? (s/n): " confirma
            if [ "$confirma" == "s" ]; then
                ./testar_resiliencia.sh
            else
                echo "Teste cancelado."
            fi
            ;;
        8)
            echo ""
            echo "Abrindo simulador de falhas..."
            ./simular_falhas.sh
            ;;
        9)
            echo ""
            echo "Iniciando cluster..."
            cd ..
            docker-compose up -d
            echo ""
            echo "Aguardando serviços iniciarem (30s)..."
            sleep 30
            echo ""
            echo "Cluster iniciado!"
            echo "Interfaces disponíveis:"
            echo "  ResourceManager: http://localhost:8088"
            echo "  NameNode: http://localhost:9870"
            cd scripts
            ;;
        10)
            echo ""
            echo "Parando cluster..."
            cd ..
            docker-compose down
            cd scripts
            echo "Cluster parado!"
            ;;
        11)
            echo ""
            echo "Reiniciando cluster..."
            cd ..
            docker-compose restart
            echo "Aguardando serviços iniciarem (30s)..."
            sleep 30
            echo "Cluster reiniciado!"
            cd scripts
            ;;
        12)
            echo ""
            echo "Logs do cluster:"
            echo ""
            echo "Escolha um container:"
            echo "  1) hadoop-master"
            echo "  2) hadoop-slave1"
            echo "  3) hadoop-slave2"
            echo "  4) Todos"
            read -p "Opção: " log_opt
            
            case $log_opt in
                1) docker logs --tail 50 hadoop-master ;;
                2) docker logs --tail 50 hadoop-slave1 ;;
                3) docker logs --tail 50 hadoop-slave2 ;;
                4) 
                    echo "=== MASTER ==="
                    docker logs --tail 20 hadoop-master
                    echo ""
                    echo "=== SLAVE1 ==="
                    docker logs --tail 20 hadoop-slave1
                    echo ""
                    echo "=== SLAVE2 ==="
                    docker logs --tail 20 hadoop-slave2
                    ;;
                *) echo "Opção inválida" ;;
            esac
            ;;
        0)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo "ERRO: Opção inválida!"
            ;;
    esac
}

# Verificar se estamos no diretório correto
if [ ! -f "executar_wordcount.sh" ]; then
    echo "ERRO: Execute este script de dentro do diretório scripts/"
    exit 1
fi

# Loop principal
while true; do
    mostrar_menu
    read -p "Escolha uma opção: " opcao
    executar_opcao $opcao
    
    echo ""
    read -p "Pressione Enter para continuar..."
    clear
done
