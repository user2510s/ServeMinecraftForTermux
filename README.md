
# 🚀 Servidor Minecraft no Termux

Este repositório permite iniciar um servidor **Minecraft Java** diretamente no **Termux** de forma simples e rápida.



## 📋 Pré-requisitos

Antes de começar, você precisa ter o **Termux** instalado:

📥 **Baixe aqui:** [Termux na Google Play](https://play.google.com/store/apps/details?id=com.termux&hl=pt_BR)

Também será necessário ter o **Git** instalado no Termux:

```bash
pkg install git
````

E conceder **permissão de armazenamento** para o Termux:

```bash
termux-setup-storage
```

---

## 📥 Como instalar e iniciar

1. **Clone o repositório**

   ```bash
   git clone https://github.com/user2510s/ServeMinecraftForTermux.git
   ```

2. **Acesse a pasta do projeto**

   ```bash
   cd ServeMinecraftForTermux
   ```

3. **Dê permissão de execução para o script**

   ```bash
   chmod +x start.sh
   ```

4. **Inicie o servidor**

   ```bash
   ./start.sh
   ```

---

## 📂 Estrutura do projeto

```
ServeMinecraftForTermux/
├── start.sh   # Script principal para iniciar o servidor
├── server.jar # Arquivo do servidor Minecraft (caso incluído)
└── ...        # Outros arquivos de configuração
```

---

## 💡 Observações

* O script instalará automaticamente os pacotes necessários, caso não estejam presentes.
* Certifique-se de ter espaço livre no armazenamento.
* Para parar o servidor, pressione **CTRL + C** no Termux.

---

## 📜 Licença

Este projeto está sob a licença MIT. Sinta-se livre para modificá-lo e distribuí-lo.
