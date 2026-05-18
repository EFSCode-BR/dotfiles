#!/bin/bash

set -e

# ╭──────────────────────────────────────────────╮
# │ Funções auxiliares                           │
# ╰──────────────────────────────────────────────╯
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_section() {
    echo ""
    echo "╭──────────────────────────────────────────────╮"
    printf "│ %-44s │\n" "$1"
    echo "╰──────────────────────────────────────────────╯"
}

log_install() {
    log_info "📦  Instalando $1"
}

log_info() {
    echo "ℹ️  [$(date '+%H:%M:%S')] $1"
}

log_success() {
    echo "✅ [$(date '+%H:%M:%S')] $1"
}

log_warning() {
    echo "⚠️  [$(date '+%H:%M:%S')] $1"
}

log_error() {
    echo "❌ [$(date '+%H:%M:%S')] $1"
}

# ╭──────────────────────────────────────────────╮
# │ Início e Validações de Sistema               │
# ╰──────────────────────────────────────────────╯
log_info "🚀 [+] Iniciando script de preparação..."
log_info "Data/hora: $(date '+%Y-%m-%d %H:%M:%S')"
log_info "Usuário: $USER"
log_info "Sistema: $(uname -s) $(uname -r)"

if [[ -z "$GITHUB_USERNAME" ]]; then
    GITHUB_USERNAME="EFSCode-BR"
    log_info "Usando GITHUB_USERNAME padrão: $GITHUB_USERNAME"
fi

if ! command_exists apt; then
    log_error "Gerenciador de pacotes 'apt' não encontrado. Este script requer Debian/Ubuntu."
    exit 1
fi

if ! sudo -v 2>/dev/null; then
    log_info "Este script requer privilégios de sudo. Solicitando acesso..."
    if ! sudo -v; then
        log_error "Falha ao validar sudo. Finalizando."
        exit 1
    fi
fi
log_success "Validações de sistema concluídas"


# ╭──────────────────────────────────────────────╮
# │ Atualização do sistema                       │
# ╰──────────────────────────────────────────────╯
print_section "Atualizando sistema"
log_info "Criando arquivo .hushlogin para suprimir mensagens de login..."
touch "$HOME"/.hushlogin

log_info "Atualizando lista de pacotes..."
sudo apt update

log_info "Atualizando pacotes instalados..."
sudo apt upgrade -y

log_info "Instalando utilitários básicos..."
sudo apt install -y bash-completion curl unzip
log_success "Sistema atualizado e utilitários instalados"

# ╭──────────────────────────────────────────────╮
# │ Instalação de Ferramentas                    │
# ╰──────────────────────────────────────────────╯
for pkg in fzf zsh neovim jq git keychain; do
    print_section "Processando: $pkg"
    if command_exists "$pkg"; then
        log_info "$pkg já está instalado. Verificando atualizações..."

        case "$pkg" in
        zsh)
            CURRENT_VERSION=$(zsh --version | awk '{print $2}')
            log_info "Versão atual do Zsh: $CURRENT_VERSION"
            sudo apt install --only-upgrade -y zsh
            NEW_VERSION=$(zsh --version | awk '{print $2}')
            if [[ "$CURRENT_VERSION" != "$NEW_VERSION" ]]; then
                log_success "Zsh atualizado: $CURRENT_VERSION → $NEW_VERSION"
            else
                log_success "Zsh já está na versão mais recente"
            fi
            ;;
        neovim)
            CURRENT_VERSION=$(nvim --version | head -n1 | awk '{print $2}')
            log_info "Versão atual do Neovim: $CURRENT_VERSION"
            sudo apt install --only-upgrade -y neovim
            NEW_VERSION=$(nvim --version | head -n1 | awk '{print $2}')
            if [[ "$CURRENT_VERSION" != "$NEW_VERSION" ]]; then
                log_success "Neovim atualizado: $CURRENT_VERSION → $NEW_VERSION"
            else
                log_success "Neovim já está na versão mais recente"
            fi
            ;;
        jq)
            CURRENT_VERSION=$(jq --version 2>&1 | grep -oP '\d+\.\d+')
            log_info "Versão atual do jq: $CURRENT_VERSION"
            sudo apt install --only-upgrade -y jq
            log_success "jq verificado/atualizado"
            ;;
        git)
            CURRENT_VERSION=$(git --version | awk '{print $3}')
            log_info "Versão atual do Git: $CURRENT_VERSION"
            sudo apt install --only-upgrade -y git
            NEW_VERSION=$(git --version | awk '{print $3}')
            if [[ "$CURRENT_VERSION" != "$NEW_VERSION" ]]; then
                log_success "Git atualizado: $CURRENT_VERSION → $NEW_VERSION"
            else
                log_success "Git já está na versão mais recente"
            fi
            ;;
        keychain)
            CURRENT_VERSION=$(keychain --version 2>/dev/null | head -n1 || echo "desconhecida")
            log_info "Versão atual do keychain: $CURRENT_VERSION"
            sudo apt install --only-upgrade -y keychain
            log_success "keychain verificado/atualizado"
            ;;
        fzf)
            CURRENT_VERSION=$(fzf --version 2>/dev/null || echo "desconhecida")
            log_info "Versão atual do fzf: $CURRENT_VERSION"
            sudo apt install --only-upgrade -y fzf
            log_success "fzf verificado/atualizado"
            ;;
        esac
    else
        log_install "$pkg..."
        sudo apt install -y "$pkg"
        log_success "$pkg instalado com sucesso"
    fi
done

# ╭──────────────────────────────────────────────╮
# │ Configurar Zsh como Shell Padrão             │
# ╰──────────────────────────────────────────────╯
print_section "Configurando Zsh"

CURRENT_SHELL=$(basename "$SHELL")
log_info "Shell atual: $CURRENT_SHELL"

if [[ "$CURRENT_SHELL" != "zsh" ]]; then
    log_info "Configurando Zsh como shell padrão..."

    ZSH_PATH=$(which zsh)
    log_info "Caminho do Zsh: $ZSH_PATH"

    if ! grep -q "$ZSH_PATH" /etc/shells; then
        log_info "Adicionando Zsh ao /etc/shells..."
        echo "$ZSH_PATH" | sudo tee -a /etc/shells
    fi

    log_info "Alterando shell padrão para Zsh..."
    sudo chsh -s "$ZSH_PATH" "$USER"
    log_success "Zsh configurado como shell padrão (requer logout/login)"
else
    log_success "Zsh já é o shell padrão"
fi

# Instalar/Atualizar Oh My Zsh
OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
if [[ -d "$OH_MY_ZSH_DIR" ]]; then
    log_info "Oh My Zsh já está instalado"
    log_info "Verificando atualizações do Oh My Zsh..."

    cd "$OH_MY_ZSH_DIR"
    BEFORE_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

    git pull origin master 2>/dev/null || log_warning "Não foi possível atualizar Oh My Zsh"

    AFTER_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

    if [[ "$BEFORE_COMMIT" != "$AFTER_COMMIT" && "$BEFORE_COMMIT" != "unknown" ]]; then
        log_success "Oh My Zsh atualizado"
    else
        log_success "Oh My Zsh já está na versão mais recente"
    fi

    cd - >/dev/null
else
    log_install "Oh My Zsh..."

    if [[ -f "$HOME/.zshrc" ]]; then
        log_info "Fazendo backup de .zshrc existente..."
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date '+%Y%m%d%H%M%S')"
    fi

    log_info "Baixando e instalando Oh My Zsh..."
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    if [[ -d "$OH_MY_ZSH_DIR" ]]; then
        log_success "Oh My Zsh instalado com sucesso"
    else
        log_warning "Falha ao instalar Oh My Zsh"
    fi
fi

# ╭──────────────────────────────────────────────╮
# │ Instalar/Atualizar Docker                    │
# ╰──────────────────────────────────────────────╯
print_section "Processando: Docker"
if command_exists docker; then
    log_info "Docker já está instalado"
    CURRENT_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    log_info "Versão atual do Docker: $CURRENT_VERSION"

    log_info "Verificando atualizações do Docker..."
    sudo apt update
    sudo apt install --only-upgrade -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true

    NEW_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    if [[ "$CURRENT_VERSION" != "$NEW_VERSION" ]]; then
        log_success "Docker atualizado: $CURRENT_VERSION → $NEW_VERSION"
    else
        log_success "Docker já está na versão mais recente"
    fi
else
    log_install "Docker..."

    log_info "Removendo pacotes conflitantes..."
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        sudo apt remove -y $pkg 2>/dev/null || true
    done

    log_install "certificados CA..."
    sudo apt install -y ca-certificates

    log_info "Configurando repositório Docker"
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # shellcheck source=/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    log_info "Atualizando lista de pacotes..."
    sudo apt update

    log_install "componentes Docker..."
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    log_info "Configurando grupo docker..."
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker "$USER"

    INSTALLED_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    log_success "Docker instalado com sucesso: $INSTALLED_VERSION"
    log_warning "Você precisará fazer logout/login para usar Docker sem sudo"
fi

# ╭──────────────────────────────────────────────╮
# │ Instalar Bitwarden CLI                       │
# ╰──────────────────────────────────────────────╯
print_section "Processando: Bitwarden CLI"
BW_BIN=/usr/local/bin/bw

if command_exists bw; then
    log_info "Bitwarden CLI já está instalado"
    CURRENT_VERSION=$("$BW_BIN" --version 2>/dev/null || echo "desconhecida")
    log_info "Versão atual: $CURRENT_VERSION"

    log_info "Verificando atualizações do Bitwarden CLI..."
    UPDATE_OUTPUT=$("$BW_BIN" update 2>&1 || true)

    if echo "$UPDATE_OUTPUT" | grep -q "Updated"; then
        NEW_VERSION=$("$BW_BIN" --version)
        log_success "Bitwarden CLI atualizado: $CURRENT_VERSION → $NEW_VERSION"
    elif echo "$UPDATE_OUTPUT" | grep -q "up to date"; then
        log_success "Bitwarden CLI já está na versão mais recente"
    else
        log_info "Resultado da verificação: $UPDATE_OUTPUT"
    fi
else
    log_install "Bitwarden CLI..."
    sudo mkdir -p /usr/local/bin

    log_info "Baixando Bitwarden CLI..."
    BW_ZIP=$(mktemp)
    curl -fsSL "https://bitwarden.com/download/?app=cli&platform=linux" -o "$BW_ZIP"

    log_info "Extraindo e instalando..."
    sudo unzip -j "$BW_ZIP" bw -d /usr/local/bin
    sudo chmod +x "$BW_BIN"
    rm "$BW_ZIP"

    if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
        log_info "Adicionando /usr/local/bin ao PATH..."
        echo 'export PATH="/usr/local/bin:$PATH"' >>"$HOME/.bashrc"
    fi

    INSTALLED_VERSION=$("$BW_BIN" --version)
    log_success "Bitwarden CLI instalado com sucesso: $INSTALLED_VERSION"
fi

# ╭──────────────────────────────────────────────╮
# │ Acesso Bitwarden e SSH                       │
# ╰──────────────────────────────────────────────╯
print_section "Configuração Bitwarden e SSH"

get_ssh_key() {
    local key_name="$1"
    local key_path="$HOME/.ssh/$key_name"

    log_info "Processando chave: $key_name"

    if [[ -f "$key_path" ]]; then
        log_info "Arquivo $key_path encontrado. Validando..."
        if ssh-keygen -l -f "$key_path" >/dev/null 2>&1; then
            log_success "Chave $key_name já existe e é válida"
            return 0
        else
            log_warning "Chave $key_name existe mas é inválida. Removendo..."
            rm -f "$key_path" "$key_path.pub" || {
                log_error "Falha ao remover chave inválida"
                return 1
            }
        fi
    fi

    log_info "🔑 Buscando chave no Bitwarden: $key_name"

    local raw_item
    raw_item=$("$BW_BIN" get item "$key_name" --raw 2>&1)
    local bw_exit_code=$?

    if [[ $bw_exit_code -ne 0 ]]; then
        log_warning "Erro ao buscar '$key_name' no Bitwarden (exit code: $bw_exit_code)"
        log_info "Resposta do bw: ${raw_item:0:100}"
        return 1
    fi

    if [[ -z "$raw_item" || "$raw_item" == "null" ]]; then
        log_warning "Chave $key_name não encontrada no Bitwarden (resposta vazia)"
        return 1
    fi

    log_info "Item encontrado. Extraindo chaves..."

    if echo "$raw_item" | jq -e '.sshKey.privateKey' >/dev/null 2>&1; then
        log_info "Usando formato .sshKey (tipo SSH Key nativo)"
        echo "$raw_item" | jq -r '.sshKey.privateKey' >"$key_path" || {
            log_error "Falha ao extrair chave privada"
            return 1
        }

        if echo "$raw_item" | jq -e '.sshKey.publicKey' >/dev/null 2>&1; then
            echo "$raw_item" | jq -r '.sshKey.publicKey' >"$key_path.pub" || {
                log_warning "Falha ao extrair chave pública"
            }
        fi
    else
        log_info "Usando formato alternativo (notes + fields)"

        local notes_content
        notes_content=$(echo "$raw_item" | jq -r '.notes // empty')

        if [[ -z "$notes_content" || "$notes_content" == "null" ]]; then
            log_error "Chave privada não encontrada em .notes"
            return 1
        fi

        echo "$notes_content" >"$key_path" || {
            log_error "Falha ao salvar chave privada"
            return 1
        }

        local pub_key
        pub_key=$(echo "$raw_item" | jq -r '.fields[]? | select(.name == "public_key" or .name == "publicKey" or .name == "public") | .value' 2>/dev/null | head -n1)

        if [[ -n "$pub_key" && "$pub_key" != "null" ]]; then
            log_info "Chave pública encontrada em campo customizado"
            echo "$pub_key" >"$key_path.pub"
        else
            pub_key=$(echo "$raw_item" | jq -r '.fields[0].value // empty' 2>/dev/null)
            if [[ -n "$pub_key" && "$pub_key" != "null" ]]; then
                log_info "Chave pública encontrada no primeiro campo"
                echo "$pub_key" >"$key_path.pub"
            else
                log_warning "Chave pública não encontrada nos campos"
            fi
        fi
    fi

    if [[ ! -f "$key_path" ]]; then
        log_error "Arquivo de chave não foi criado: $key_path"
        return 1
    fi

    if [[ ! -s "$key_path" ]]; then
        log_error "Arquivo de chave está vazio: $key_path"
        rm -f "$key_path" "$key_path.pub"
        return 1
    fi

    log_info "Configurando permissões..."
    chmod 600 "$key_path" || {
        log_error "Falha ao configurar permissões da chave privada"
        return 1
    }

    if [[ -f "$key_path.pub" ]]; then
        chmod 644 "$key_path.pub" || {
            log_warning "Falha ao configurar permissões da chave pública"
        }
    fi

    # Validar formato da chave
    log_info "Validando formato da chave..."
    if ! ssh-keygen -l -f "$key_path" >/dev/null 2>&1; then
        log_error "Chave $key_name tem formato inválido"
        log_info "Primeira linha: $(head -n1 "$key_path" | cut -c1-60)..."
        log_info "Tamanho do arquivo: $(wc -c <"$key_path") bytes"
        return 1
    fi

    log_success "Chave $key_name configurada com sucesso"
    return 0
}

if [[ ! (-n "$BW_SESSION") ]]; then
    log_info "Verificando status do Bitwarden..."
    BW_STATUS=$("$BW_BIN" status | jq -r '.status')
    log_info "Status atual: $BW_STATUS"
    BW_SESSION=""

    if [[ "$BW_STATUS" == "unauthenticated" || "$BW_STATUS" == "locked" ]]; then
        log_info "🔐 Desbloqueando Bitwarden..."
        BW_CMD=$([[ "$BW_STATUS" == "unauthenticated" ]] && echo "login" || echo "unlock")

        if [[ -f "$HOME/.pswds/bw" ]]; then
            log_info "Usando arquivo de senha: $HOME/.pswds/bw"
            BW_SESSION=$("$BW_BIN" "$BW_CMD" --raw --passwordfile "$HOME/.pswds/bw")
        elif [[ -n "$BW_PASSWORD" ]]; then
            log_info "Usando variável de ambiente BW_PASSWORD"
            BW_SESSION=$("$BW_BIN" "$BW_CMD" --raw --passwordenv BW_PASSWORD)
        else
            log_info "Solicitando senha interativamente..."
            BW_SESSION=$("$BW_BIN" "$BW_CMD" --raw)
        fi

        if [[ -n "$BW_SESSION" ]]; then
            log_success "Bitwarden desbloqueado com sucesso"
        else
            log_error "Falha ao desbloquear Bitwarden"
        fi
    fi
else
    log_info "Sessão Bitwarden já está ativa"
fi

if [[ -n "$BW_SESSION" ]]; then
    export BW_SESSION


    log_info "Sincronizando vault do Bitwarden..."
    "$BW_BIN" sync
    log_success "Vault sincronizado"

    log_info "Criando diretório .ssh..."
    mkdir -p "$HOME"/.ssh && chmod 700 "$HOME"/.ssh

    log_info "Buscando chaves SSH do Bitwarden..."
    SSH_KEYS=("dev_server_deploy_key")
    KEYS_FOUND=0
    KEYS_FAILED=0

    log_info "Total de chaves a processar: ${#SSH_KEYS[@]}"

    for key in "${SSH_KEYS[@]}"; do
        log_info "═══════════════════════════════════════════════"
        log_info "Iniciando processamento da chave: $key"

        if get_ssh_key "$key"; then
            ((KEYS_FOUND++)) || true
            log_success "✓ Chave $key processada com sucesso (total: $KEYS_FOUND)"
        else
            ((KEYS_FAILED++)) || true
            log_warning "✗ Falha ao processar chave $key (total falhas: $KEYS_FAILED)"
        fi

        log_info "Status: $KEYS_FOUND encontradas, $KEYS_FAILED falharam"
    done

    log_info "═══════════════════════════════════════════════"
    log_success "Chaves processadas: $KEYS_FOUND encontradas, $KEYS_FAILED não encontradas"

    log_info "Configurando credenciais Git..."

    git config --global user.name "$GITHUB_USERNAME"

    GIT_EMAIL=$("$BW_BIN" get username "GitHub" 2>/dev/null || echo "")
    if [[ -n "$GIT_EMAIL" ]]; then
        git config --global user.email "$GIT_EMAIL"
        log_success "Git user.email configurado: $GIT_EMAIL"
    else
        log_warning "Não foi possível recuperar email do Git Hub"
    fi

    log_success "Configurações Bitwarden/SSH concluídas"
else
    log_warning "⚠️  Bitwarden não disponível. Iniciando configuração manual do Git:"
    read -pr "👤 Username do Git [$GITHUB_USERNAME]: " manual_user
    git config --global user.name "${manual_user:-$GITHUB_USERNAME}"

    read -pr "📧 Email do Git: " manual_email
    [[ -n "$manual_email" ]] && git config --global user.email "$manual_email"
fi

# ╭──────────────────────────────────────────────╮
# │ Finalização e Resumo                         │
# ╰──────────────────────────────────────────────╯
print_section "Resumo da Execução"

echo ""
echo "📊 Ferramentas instaladas/atualizadas:"
echo "   • Zsh:           $(zsh --version 2>/dev/null | awk '{print $2}' || echo 'N/A')"
echo "   • Neovim:        $(nvim --version 2>/dev/null | head -n1 | awk '{print $2}' || echo 'N/A')"
echo "   • jq:            $(jq --version 2>&1 | grep -oP '\d+\.\d+' || echo 'N/A')"
echo "   • Git:           $(git --version 2>/dev/null | awk '{print $3}' || echo 'N/A')"
echo "   • Keychain:      $(keychain --version 2>/dev/null | head -n1 | awk '{print $2}' || echo 'N/A')"
echo "   • Docker:        $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || echo 'N/A')"
echo "   • Bitwarden CLI: $("$BW_BIN" --version 2>/dev/null || echo 'N/A')"
echo ""

echo "🐚 Configuração do Shell:"
echo "   • Shell padrão:  $(basename "$SHELL")"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo "   • Oh My Zsh:     Instalado"
    if [[ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]]; then
        echo "   • Plugins:       zsh-autosuggestions ✓"
    fi
    if [[ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]]; then
        echo "                    zsh-syntax-highlighting ✓"
    fi
else
    echo "   • Oh My Zsh:     Não instalado"
fi
echo ""

if [[ -n "$BW_SESSION" ]]; then
    echo "🔐 Configurações Git:"
    echo "   • user.name:  $(git config --global user.name || echo 'não configurado')"
    echo "   • user.email: $(git config --global user.email || echo 'não configurado')"
    echo ""

    echo "🔑 Chaves SSH baixadas:"
    for key in "${SSH_KEYS[@]}"; do
        if [[ -f "$HOME/.ssh/$key" ]]; then
            echo "   • $key ✓"
        fi
    done
    echo ""
fi

echo "🏁 Script concluído com sucesso em $(date '+%H:%M:%S')"
log_info "Logs salvos na saída padrão"