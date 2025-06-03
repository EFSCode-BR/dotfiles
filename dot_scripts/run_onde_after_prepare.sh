#!/bin/bash

set -e


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

REQUIRED_VARS=("GITHUB_USERNAME" "BW_CLIENTID" "BW_CLIENTSECRET" "BW_PASSWORD" "SERVER_TYPE" "TS_AUTH_KEY")
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
    sudo tailscale completion bash > .config/bash_completions/tailscale.completion

    end_install "Tailscale"
fi


# ╭──────────────────────────────────────────────╮
# │ Instalação do Docker                         │
# ╰──────────────────────────────────────────────╯
start_section "Verificando Docker"
if command_exists docker; then
    end_section "Docker já está instalado"
else
    start_install "Docker..."
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        sudo apt remove -y $pkg || true
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
    sudo docker completion bash > .config/bash_completions/docker.completion

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
# │ Inicialização do Tailscale                   │
# ╰──────────────────────────────────────────────╯
start_section "Iniciando Tailscale"


tailscale up --advertise-tags=tag:server


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

git config --global pull.rebase false
git config --global merge.conflictstyle diff3
git config --global branch.autosetupmerge always

# Aliases serão gerenciados pelo Chezmoi
cat << EOF > ~/.gitconfig.local
[user]
    name = "$GITHUB_USERNAME"
    email = "{{ edimar.sa@efscode.com.br }}"

[alias]
    lg = log --oneline --graph --decorate --all
    undo = reset --soft HEAD~1
    ac = !git add -A && git commit -m
    st = status
    co = checkout
    cm = commit -m
EOF

end_section "Git configurado"


# ╭──────────────────────────────────────────────╮
# │ Configuração do Bitwarden e SSH              │
# ╰──────────────────────────────────────────────╯
bw logout 2>/dev/null || true

bw login --apikey
BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)

# Configura chave SSH
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Extrai e configura as chaves SSH
bw get item "$SSH_ITEM" --session "$BW_SESSION" --raw | \
    jq -r '.sshKey.privateKey' > ~/.ssh/deploy_key
chmod 600 ~/.ssh/deploy_key

end_section "Bitwarden e SSH configurados"


# ╭──────────────────────────────────────────────╮
# │ Finalização                                  │
# ╰──────────────────────────────────────────────╯
start_section "🏁 Finalizado!"
echo "🎉 Configuração concluída com sucesso!"
echo "⚠️ Reinicie seu terminal ou execute 'source ~/.bashrc' para aplicar as mudanças"
