#!/bin/bash

# Caminho do seu servidor Minecraft
SERVER_JAR="server.jar"
JAVA_VERSION="21" # Versão do Java que você deseja instalars

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
    while [ true ]; do
    java -Xms1536M -Xmx1536M --add-modules=jdk.incubator.vector -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -jar server.jar --nogui

    echo Server restarting...
    echo Press CTRL + C to stop.
    done
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
