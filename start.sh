#!/bin/bash

# Caminho do seu servidor Minecraft
SERVER_JAR="server.jar"
JAVA_VERSION="21"

# Função para verificar se o Java 21 está instalado
check_java() {
    if command -v java >/dev/null 2>&1; then
        CURRENT_VERSION=$(java -version 2>&1 | head -n 1 | grep -oP '(?<=version ")[^"]+')
        if [[ "$CURRENT_VERSION" == "$JAVA_VERSION"* ]]; then
            echo "✅ Java $JAVA_VERSION já está instalado."
            return 0
        else
            echo "⚠️ Java encontrado, mas não é a versão $JAVA_VERSION (versão atual: $CURRENT_VERSION)"
            return 1
        fi
    else
        echo "⚠️ Java não encontrado."
        return 1
    fi
}

# Função para instalar Java 21 no Termux
install_java() {
    echo "📦 Instalando Java $JAVA_VERSION..."
    pkg update -y
    pkg upgrade -y
    pkg install -y openjdk-$JAVA_VERSION
}

start_server() {
    echo "🚀 Iniciando servidor Minecraft..."
    taskset -c 0-$(($(nproc)-1)) java \
    -Xms2G -Xmx2G \
    -XX:+UseG1GC \
    -XX:ParallelGCThreads=$(nproc) \
    -XX:ConcGCThreads=$(nproc) \
    -XX:ActiveProcessorCount=$(nproc) \
    -Dpaper.maxChunkThreads=$(nproc) \
    -XX:+UseZGC \
    -jar "$SERVER_JAR" nogui
}


# -------- EXECUÇÃO --------
check_java
if [ $? -ne 0 ]; then
    install_java
fi

if [ ! -f "$SERVER_JAR" ]; then
    echo "❌ Arquivo $SERVER_JAR não encontrado!"
    exit 1
fi

start_server
