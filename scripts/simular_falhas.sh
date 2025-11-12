#!/bin/bash

echo "=========================================="
echo "SIMULADOR DE FALHAS NO CLUSTER HADOOP"
echo "=========================================="
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para parar um node
parar_node() {
    local NODE=$1
    echo -e "${RED}🔴 PARANDO: $NODE${NC}"
    docker stop $NODE
    echo "   Status: $(docker ps -a --filter name=$NODE --format '{{.Status}}')"
    echo ""
}

# Função para iniciar um node
iniciar_node() {
    local NODE=$1
    echo -e "${GREEN}🟢 INICIANDO: $NODE${NC}"
    docker start $NODE
    sleep 5  # Aguardar inicialização
    echo "   Status: $(docker ps -a --filter name=$NODE --format '{{.Status}}')"
    echo ""
}

# Função para reiniciar um node
reiniciar_node() {
    local NODE=$1
    echo -e "${YELLOW}🔄 REINICIANDO: $NODE${NC}"
    docker restart $NODE
    sleep 5  # Aguardar inicialização
    echo "   Status: $(docker ps -a --filter name=$NODE --format '{{.Status}}')"
    echo ""
}

# Função para matar um node (simular falha abrupta)
matar_node() {
    local NODE=$1
    echo -e "${RED}💀 MATANDO (kill): $NODE${NC}"
    docker kill $NODE
    echo "   Status: $(docker ps -a --filter name=$NODE --format '{{.Status}}')"
    echo ""
}

# Função para mostrar status
mostrar_status() {
    echo "📊 Status atual do cluster:"
    docker ps --filter "name=hadoop" --format "table {{.Names}}\t{{.Status}}"
    echo ""
}

# Menu de opções
mostrar_menu() {
    echo "=========================================="
    echo "CENÁRIOS DE FALHA DISPONÍVEIS"
    echo "=========================================="
    echo ""
    echo "1) Parar um slave (slave1)"
    echo "2) Parar um slave (slave2)"
    echo "3) Parar ambos os slaves"
    echo "4) Reiniciar um slave (slave1)"
    echo "5) Reiniciar um slave (slave2)"
    echo "6) Matar um slave abruptamente (slave1)"
    echo "7) Matar um slave abruptamente (slave2)"
    echo "8) Parar e iniciar slave1 após delay"
    echo "9) Parar e iniciar slave2 após delay"
    echo "10) Parar master (CUIDADO!)"
    echo "11) Reiniciar master (CUIDADO!)"
    echo "12) Iniciar todos os nodes parados"
    echo "13) Mostrar status do cluster"
    echo "14) Teste automático (ciclo de falhas)"
    echo "0) Sair"
    echo ""
}

# Teste automático de falhas
teste_automatico() {
    echo "=========================================="
    echo "TESTE AUTOMÁTICO DE RESILIÊNCIA"
    echo "=========================================="
    echo ""
    echo "Este teste irá:"
    echo "  1. Aguardar 30s (para job iniciar)"
    echo "  2. Parar slave1"
    echo "  3. Aguardar 45s"
    echo "  4. Reiniciar slave1"
    echo "  5. Aguardar 30s"
    echo "  6. Parar slave2"
    echo "  7. Aguardar 45s"
    echo "  8. Reiniciar slave2"
    echo ""
    read -p "Continuar? (s/n): " resposta
    
    if [ "$resposta" != "s" ]; then
        echo "Teste cancelado."
        return
    fi
    
    echo ""
    echo "⏰ Aguardando 30s para job iniciar..."
    sleep 30
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Iniciando teste automático" >> logs_resiliencia/teste_automatico.log
    
    parar_node "hadoop-slave1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Slave1 parado" >> logs_resiliencia/teste_automatico.log
    mostrar_status
    
    echo "⏰ Aguardando 45s com slave1 parado..."
    sleep 45
    
    iniciar_node "hadoop-slave1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Slave1 reiniciado" >> logs_resiliencia/teste_automatico.log
    mostrar_status
    
    echo "⏰ Aguardando 30s..."
    sleep 30
    
    parar_node "hadoop-slave2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Slave2 parado" >> logs_resiliencia/teste_automatico.log
    mostrar_status
    
    echo "⏰ Aguardando 45s com slave2 parado..."
    sleep 45
    
    iniciar_node "hadoop-slave2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Slave2 reiniciado" >> logs_resiliencia/teste_automatico.log
    mostrar_status
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Teste automático concluído" >> logs_resiliencia/teste_automatico.log
    echo ""
    echo "✅ Teste automático concluído!"
    echo "Log salvo em: logs_resiliencia/teste_automatico.log"
    echo ""
}

# Criar diretório de logs se não existir
mkdir -p logs_resiliencia

# Verificar se foi passado argumento para modo não-interativo
if [ $# -gt 0 ]; then
    case $1 in
        parar-slave1)
            parar_node "hadoop-slave1"
            ;;
        parar-slave2)
            parar_node "hadoop-slave2"
            ;;
        iniciar-slave1)
            iniciar_node "hadoop-slave1"
            ;;
        iniciar-slave2)
            iniciar_node "hadoop-slave2"
            ;;
        reiniciar-slave1)
            reiniciar_node "hadoop-slave1"
            ;;
        reiniciar-slave2)
            reiniciar_node "hadoop-slave2"
            ;;
        matar-slave1)
            matar_node "hadoop-slave1"
            ;;
        matar-slave2)
            matar_node "hadoop-slave2"
            ;;
        teste-auto)
            teste_automatico
            ;;
        status)
            mostrar_status
            ;;
        *)
            echo "Uso: $0 {parar-slave1|parar-slave2|iniciar-slave1|iniciar-slave2|reiniciar-slave1|reiniciar-slave2|matar-slave1|matar-slave2|teste-auto|status}"
            exit 1
            ;;
    esac
    exit 0
fi

# Modo interativo
mostrar_status

while true; do
    mostrar_menu
    read -p "Escolha uma opção: " opcao
    echo ""
    
    case $opcao in
        1)
            parar_node "hadoop-slave1"
            mostrar_status
            ;;
        2)
            parar_node "hadoop-slave2"
            mostrar_status
            ;;
        3)
            parar_node "hadoop-slave1"
            parar_node "hadoop-slave2"
            mostrar_status
            ;;
        4)
            reiniciar_node "hadoop-slave1"
            mostrar_status
            ;;
        5)
            reiniciar_node "hadoop-slave2"
            mostrar_status
            ;;
        6)
            matar_node "hadoop-slave1"
            mostrar_status
            ;;
        7)
            matar_node "hadoop-slave2"
            mostrar_status
            ;;
        8)
            parar_node "hadoop-slave1"
            mostrar_status
            read -p "Delay em segundos antes de reiniciar (ex: 60): " delay
            echo "⏰ Aguardando ${delay}s..."
            sleep $delay
            iniciar_node "hadoop-slave1"
            mostrar_status
            ;;
        9)
            parar_node "hadoop-slave2"
            mostrar_status
            read -p "Delay em segundos antes de reiniciar (ex: 60): " delay
            echo "⏰ Aguardando ${delay}s..."
            sleep $delay
            iniciar_node "hadoop-slave2"
            mostrar_status
            ;;
        10)
            echo -e "${RED}⚠️  ATENÇÃO: Parar o master pode comprometer o cluster!${NC}"
            read -p "Tem certeza? (digite 'SIM' para confirmar): " confirmacao
            if [ "$confirmacao" == "SIM" ]; then
                parar_node "hadoop-master"
                mostrar_status
            else
                echo "Operação cancelada."
            fi
            ;;
        11)
            echo -e "${YELLOW}⚠️  ATENÇÃO: Reiniciar o master pode afetar jobs em execução!${NC}"
            read -p "Tem certeza? (digite 'SIM' para confirmar): " confirmacao
            if [ "$confirmacao" == "SIM" ]; then
                reiniciar_node "hadoop-master"
                mostrar_status
            else
                echo "Operação cancelada."
            fi
            ;;
        12)
            echo "🔄 Iniciando todos os nodes parados..."
            docker start hadoop-master hadoop-slave1 hadoop-slave2 2>/dev/null
            sleep 5
            mostrar_status
            ;;
        13)
            mostrar_status
            ;;
        14)
            teste_automatico
            ;;
        0)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo -e "${RED}Opção inválida!${NC}"
            ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
    clear
done
