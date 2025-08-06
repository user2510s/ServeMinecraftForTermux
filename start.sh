#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Caminho do seu servidor Minecraft
SERVER_JAR="server.jar"
JAVA_VERSION="21" # só informativo

# --- Configuráveis ---
# Fração da memória total a reservar para a JVM (ex.: 3/4 = 75%)
MEM_FRACTION_NUM=3
MEM_FRACTION_DEN=4

# Heap mínimo e máximo em MB (valores de segurança)
HEAP_MIN_MB=512
HEAP_RESERVED_MB=256  # RAM mínima reservada pro SO

# Flags Aikar base (você pode editar)
AIKAR_FLAGS="-Daikars.new.flags=true -Dusing.aikars.flags=https://mcflags.emc.gs"

# --- Funções utilitárias ---
# Ler número de CPUs via /proc (fallback para nproc)
detect_cpus() {
    if [[ -r /proc/cpuinfo ]]; then
        grep -c '^processor' /proc/cpuinfo || nproc
    else
        nproc
    fi
}

# Ler memória total em KB via /proc/meminfo e converter para MB (inteiro)
detect_mem_mb() {
    if [[ -r /proc/meminfo ]]; then
        awk '/MemTotal/{print int($2/1024)}' /proc/meminfo
    else
        # fallback conservador
        echo 1024
    fi
}

# Calcula Xmx/Xms em MB (inteiro)
calc_heap_mb() {
    local mem_mb=$1
    local want=$(( mem_mb * MEM_FRACTION_NUM / MEM_FRACTION_DEN ))
    # garante espaço reservado para SO
    if (( want > mem_mb - HEAP_RESERVED_MB )); then
        want=$(( mem_mb - HEAP_RESERVED_MB ))
    fi
    # garante mínimo
    if (( want < HEAP_MIN_MB )); then
        want=$HEAP_MIN_MB
    fi
    echo "$want"
}

# Verifica se java existe e versão principal começa com 21
check_java() {
    if command -v java >/dev/null 2>&1; then
        local ver
        ver=$(java -version 2>&1 | head -n1 | grep -oP '(?<=version ")[^"]+' || true)
        if [[ "${ver:-}" == 21* ]]; then
            echo "✅ Java 21 encontrado: $ver"
            return 0
        else
            echo "⚠️ Java encontrado, mas versão não é 21 (achado: ${ver:-unknown})"
            return 1
        fi
    fi
    echo "⚠️ Java não encontrado."
    return 1
}

install_java() {
    echo "📦 Instalando Java (openjdk-21) pelo pkg..."
    pkg update -y || true
    pkg upgrade -y || true
    pkg install -y openjdk-21 || pkg install -y openjdk || true
}

# --- Start server com detecção via /proc ---
start_server() {
    # detecta recursos
    local cpu_count mem_mb heap_mb gc_choice java_bin nproc_list

    cpu_count=$(detect_cpus)
    mem_mb=$(detect_mem_mb)
    heap_mb=$(calc_heap_mb "$mem_mb")

    # decidir coletor de lixo: usar ZGC se houver >= 4GB (4096 MB)
    if (( mem_mb >= 4096 )); then
        gc_choice="-XX:+UseZGC"
    else
        gc_choice="-XX:+UseG1GC"
    fi

    # Reservas/flags de CPU e GC
    local parallel_threads="-XX:ParallelGCThreads=${cpu_count}"
    local conc_threads="-XX:ConcGCThreads=${cpu_count}"
    local active_proc="-XX:ActiveProcessorCount=${cpu_count}"
    local paper_threads="-Dpaper.maxChunkThreads=${cpu_count}"

    # formar args da JVM
    local XMX_ARG="-Xmx${heap_mb}M"
    # definir Xms como metade do Xmx para aquecer menos memória (opcional); se quiser igual coloque Xms=${heap_mb}M
    local XMS_ARG="-Xms$(( heap_mb / 2 ))M"

    # where java is
    java_bin="$(command -v java || true)"
    if [[ -z "$java_bin" ]]; then
        echo "❌ java não encontrado no PATH."
        return 1
    fi

    echo "🔎 Recursos detectados: CPUs=${cpu_count}, RAM=${mem_mb}MB, JVM heap=${heap_mb}MB"
    echo "🔧 Usando GC: ${gc_choice#-}"
    echo "🔁 O servidor irá reiniciar automaticamente se travar. Pressione CTRL+C para parar o loop."

    # Captura SIGINT/SIGTERM pra parar o loop de restart
    trap 'echo "Interrompendo..."; exit 0' SIGINT SIGTERM

    while true; do
        # taskset para permitir usar todos os núcleos (0..N-1)
        local cpu_range="0-$(( cpu_count - 1 ))"
        echo "🚀 Iniciando: taskset -c ${cpu_range} ${java_bin} ${XMS_ARG} ${XMX_ARG} ${gc_choice} ${parallel_threads} ${conc_threads} ${active_proc} ${paper_threads} ${AIKAR_FLAGS} -jar \"${SERVER_JAR}\" nogui"

        # Execução (substitui o processo do shell com exec quando não quiser loop, mas aqui mantemos loop)
        taskset -c "${cpu_range}" "${java_bin}" \
            ${XMS_ARG} ${XMX_ARG} \
            ${gc_choice} \
            ${parallel_threads} \
            ${conc_threads} \
            ${active_proc} \
            ${paper_threads} \
            ${AIKAR_FLAGS} \
            -XX:+ParallelRefProcEnabled \
            -XX:MaxGCPauseMillis=200 \
            -XX:+UnlockExperimentalVMOptions \
            -XX:+DisableExplicitGC \
            -XX:+AlwaysPreTouch \
            -XX:G1HeapWastePercent=5 \
            -XX:G1MixedGCCountTarget=4 \
            -XX:InitiatingHeapOccupancyPercent=15 \
            -XX:G1MixedGCLiveThresholdPercent=90 \
            -XX:G1RSetUpdatingPauseTimePercent=5 \
            -XX:SurvivorRatio=32 \
            -XX:+PerfDisableSharedMem \
            -XX:MaxTenuringThreshold=1 \
            -XX:G1NewSizePercent=30 \
            -XX:G1MaxNewSizePercent=40 \
            -XX:G1HeapRegionSize=8M \
            -XX:G1ReservePercent=20 \
            -jar "${SERVER_JAR}" nogui || {
                echo "⚠️ O servidor finalizou com código $?. Reiniciando em 5s..."
                sleep 5
            }
    done
}

# -------- EXECUÇÃO --------
if ! check_java; then
    echo "Tentando instalar Java 21 automaticamente..."
    install_java
    if ! check_java; then
        echo "❌ Falha ao instalar/confirmar Java 21. Saindo."
        exit 1
    fi
fi

if [[ ! -f "$SERVER_JAR" ]]; then
    echo "❌ Arquivo ${SERVER_JAR} não encontrado!"
    exit 1
fi

start_server
