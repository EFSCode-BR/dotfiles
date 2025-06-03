#!/bin/bash

set -euo pipefail


# ╭──────────────────────────────────────────────╮
# │ Funções auxiliares                           │
# ╰──────────────────────────────────────────────╯
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

start_section() {
    echo -e "\n╭──────────────────────────────────────────────╮"
    echo "│ $1"
    echo "╰──────────────────────────────────────────────╯"
}

start_install() {
    echo "📦 Instalando $1..."
}

end_install() {
    echo "$1 instalado com sucesso."
}

end_section() {
    echo "✅ $1"
    echo -e "-----------------------------------------------\n"
}


# ╭──────────────────────────────────────────────╮
# │ Verificação de pré-requisitos                │
# ╰──────────────────────────────────────────────╯
start_section "Verificando variáveis de ambiente"

REQUIRED_VARS=("GITHUB_USERNAME" "BW_CLIENTID" "BW_CLIENTSECRET" "BW_PASSWORD" "SERVER_TYPE" "TS_AUTH_KEY" "HOSTNAME")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        MISSING_VARS+=("$var")
    fi
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
    echo "❌ Variáveis necessárias não definidas:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    echo -e "\nDefina-as com:"
    echo "export GITHUB_USERNAME=..."
    echo "export BW_CLIENTID=..."
    echo "export BW_CLIENTSECRET=..."
    echo "export BW_PASSWORD=..."
    echo "export SERVER_TYPE=(PROD|DEV)"
    echo "export TS_AUTH_KEY=... (https://login.tailscale.com/admin/settings/keys)"
    echo "export HOSTNAME=... (nome do servidor)"
    exit 1
fi

SERVER_TYPE=${SERVER_TYPE^^}  # Converte para maiúsculas

TS_TAGS="--auth-key=$TS_AUTH_KEY --hostname=$HOSTNAME"
if [[ "$SERVER_TYPE" == "PROD" ]]; then
    SSH_ITEM="prod_server_deply_key"
    TS_TAGS="$TS_TAGS --advertise-tags=tag:prod,tag:infra"
else
    SSH_ITEM="dev_server_deply_key"
    TS_TAGS="$TS_TAGS --advertise-tags=tag:dev,tag:infra"
fi

# ╭──────────────────────────────────────────────╮
# │ Atualização do sistema                       │
# ╰──────────────────────────────────────────────╯
start_section "Atualizando sistema"
touch ~/.hushlogin || true
sudo apt-get update && sudo apt-get upgrade -y
end_section "Sistema atualizado"


# ╭──────────────────────────────────────────────╮
# │ Início                                       │
# ╰──────────────────────────────────────────────╯
echo "🚀 [+] Iniciando script de preparação..."


# ╭──────────────────────────────────────────────╮
# │ Instalação do Tailscale                      │
# ╰──────────────────────────────────────────────╯
start_section "Verificando Tailscale"
if command_exists tailscale; then
    end_section "Tailscale já está instalado"
else
    start_install "Tailscale"
    curl -fsSL https://tailscale.com/install.sh | sh

    # Configurar completions
    mkdir -p ~/.config/bash_completions
    sudo tailscale completion bash > ~/.config/bash_completions/tailscale.completion 2>/dev/null || true

    end_install "Tailscale"
fi

# ╭──────────────────────────────────────────────╮
# │ Inicialização do Tailscale                   │
# ╰──────────────────────────────────────────────╯
start_section "Iniciando Tailscale"

sudo tailscale up $TS_TAGS

end_section "Tailscale configurado"


# ╭──────────────────────────────────────────────╮
# │ Instalação do Docker                         │
# ╰──────────────────────────────────────────────╯
start_section "Verificando Docker"
if command_exists docker; then
    end_section "Docker já está instalado"
else
    start_install "Docker..."
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        sudo apt remove -y $pkg 2>/dev/null || true
    done

    sudo apt install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo groupadd docker || true
    sudo usermod -aG docker "$USER"

    sudo docker completion bash > ~/.config/bash_completions/docker.completion 2>/dev/null || true

    end_install "Docker"
fi


# ╭──────────────────────────────────────────────╮
# │ Instalação do Bitwarden CLI                  │
# ╰──────────────────────────────────────────────╯
start_section "Verificando Bitwarden CLI"
if command_exists bw; then
    end_section "Bitwarden CLI já está instalado"
else
    start_install "Bitwarden CLI"

    mkdir -p ~/bin
    BW_ZIP=$(mktemp)

    curl -fsSL "https://bitwarden.com/download/?app=cli&platform=linux" -o "$BW_ZIP"
    unzip -j "$BW_ZIP" bw -d ~/bin
    chmod +x ~/bin/bw
    rm "$BW_ZIP"

    # Adicionar ao PATH se necessário
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    fi

    end_install "Bitwarden CLI"
fi


# ╭──────────────────────────────────────────────╮
# │ Instalação do jq                             │
# ╰──────────────────────────────────────────────╯
start_section "Verificando Jq"
if command_exists jq; then
    end_section "jq já está instalado"
else
    start_install "jq"
    sudo apt install jq -y
    end_install "jq"
fi


# ╭──────────────────────────────────────────────╮
# │ Instalação do Git                            │
# ╰──────────────────────────────────────────────╯
start_section "Verificando Git"
if command_exists git; then
    end_section "git já está instalado"
else
    start_install "git"
    sudo apt install git -y
    end_install "git"
fi


# ╭──────────────────────────────────────────────╮
# │ Configuração do Git                          │
# ╰──────────────────────────────────────────────╯
start_section "Configurando Git"
# Configurações básicas
git config --global pull.rebase false
git config --global merge.conflictstyle diff3
git config --global branch.autosetupmerge always

# Aliases
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.undo "reset --soft HEAD~1"
git config --global alias.ac '!git add -A && git commit -m'
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.cm 'commit -m'

# Configura usuário
git config --global user.name "$GITHUB_USERNAME"
git config --global user.email "edimar.sa@efscode.com.br"  # Atualize se necessário

end_section "Git configurado"


# ╭──────────────────────────────────────────────╮
# │ Configuração do Bitwarden e SSH              │
# ╰──────────────────────────────────────────────╯
start_section "Configurando Bitwarden e SSH"

# Login no Bitwarden
BW_CMD=~/bin/bw
"$BW_CMD" logout 2>/dev/null || true

"$BW_CMD" login --apikey
export BW_CLIENTID="$BW_CLIENTID"
export BW_CLIENTSECRET="$BW_CLIENTSECRET"
BW_SESSION=$("$BW_CMD" unlock --passwordenv BW_PASSWORD --raw)

# Configura chave SSH
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Extrai e configura as chaves SSH
"$BW_CMD" get item "$SSH_ITEM" --session "$BW_SESSION" --raw | \
    jq -r '.sshKey.privateKey' > ~/.ssh/deploy_key

"$BW_CMD" get item "$SSH_ITEM" --session "$BW_SESSION" --raw | \
    jq -r '.sshKey.publicKey' > ~/.ssh/deploy_key.pub

# Altera o nilve de permissão
chmod 600 ~/.ssh/deploy_key
chmod 644 ~/.ssh/deploy_key.pub

# Adicionar ao ssh-agent
eval "$(ssh-agent -s)" >/dev/null
ssh-add ~/.ssh/deploy_key

end_section "Bitwarden e SSH configurados"


# ╭──────────────────────────────────────────────╮
# │ Instalação do make                           │
# ╰──────────────────────────────────────────────╯
start_section "Verificando Make"
if command_exists make; then
    end_section "Make já está instalado"
else
    start_install "Make"
    sudo apt install make -y
    end_install "Make"
fi


# ╭──────────────────────────────────────────────╮
# │ Verificando e baixando arquivos de infra     │
# ╰──────────────────────────────────────────────╯
start_section "Configurando repositório de infra"

if [[ ! -d ~/InfraProdServer ]]; then
    git clone git@github.com:$GITHUB_USERNAME/InfraProdServer.git ~/InfraProdServer
    echo "Repositório clonado com sucesso"
else
    echo "Repositório já existe"
fi

end_section "Repositório configurado"


# ╭──────────────────────────────────────────────╮
# │ Finalização                                  │
# ╰──────────────────────────────────────────────╯
start_section "🏁 Configuração concluída!"
echo "🎉 Tudo pronto!"
echo "⚠️ Execute os seguintes passos:"
echo "1. Reinicie o terminal: 'exec bash'"
echo "2. Para usar Docker sem sudo, faça logout e login novamente"
echo "3. Verifique o Tailscale: 'tailscale status'"
echo "🔑 Chave SSH disponível em: ~/.ssh/deploy_key"
