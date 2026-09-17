#!/bin/bash
set -e

DOTFILES_DIR="$HOME/dotfiles"
REPO_URL="git@github.com:luncied/dotfiles.git"

# ==========================================
# DETECCIÓN DE SISTEMA OPERATIVO Y DEPENDENCIAS
# ==========================================
OS_FAMILIA="desconocido"
INSTALL_CMD=""
PACKAGES=""

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_FAMILIA="linux"
    source /etc/os-release
    if [[ "$ID" == "arch" || "$ID_LIKE" == *"arch"* ]]; then
        INSTALL_CMD="sudo pacman -Sy --needed --noconfirm"
        # Se añade kdiff3 a la lista de instalación
        PACKAGES="zsh git eza bat neovim ripgrep fd gcc make npm unzip wget curl python python-pip xclip wl-clipboard python-pynvim kdiff3"
    elif [[ "$ID" == "kali" || "$ID" == "parrot" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
        sudo apt-get update
        INSTALL_CMD="sudo apt-get install -y"
        PACKAGES="zsh git eza neovim ripgrep fd-find build-essential npm unzip wget curl python3 python3-pip xclip wl-clipboard python3-pynvim kdiff3"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_FAMILIA="macos"
    INSTALL_CMD="brew install"
    PACKAGES="zsh git eza bat neovim ripgrep fd gcc make node unzip wget curl python"
fi

# ==========================================
# FUNCIÓN: ENLACE INTELIGENTE Y KDIFF3
# ==========================================
safe_link() {
    local source_file="$1"
    local target_name="$2"
    local repo_file="$DOTFILES_DIR/$target_name"

    # 1. Si el archivo local es un enlace o está vacío (0 bytes / no existe)
    if [ -L "$source_file" ] || [ ! -s "$source_file" ]; then
        if [ -f "$repo_file" ]; then
            echo "🔗 $target_name (vacío o enlace): Inyectando configuración del repositorio..."
            rm -f "$source_file"
            ln -sf "$repo_file" "$source_file"
        fi
    else
        # 2. El archivo local existe, NO es un enlace y TIENE contenido
        if [ -f "$repo_file" ]; then
            echo "⚠️  Conflicto detectado en: $target_name"
            echo "   📦 Respaldando archivo local original a ${source_file}.bak"
            cp -p "$source_file" "${source_file}.bak"

            if command -v kdiff3 &> /dev/null; then
                echo "   🔍 Abriendo kdiff3... (El script está pausado)"
                echo "      => Resuelve los conflictos, guarda y cierra kdiff3 para continuar."
                # Comparamos A (Repo) con B (Local) y guardamos el resultado en Repo
                kdiff3 "$repo_file" "$source_file" -o "$repo_file"
            else
                echo "   ⚠️ kdiff3 no disponible. Sobrescribiendo temporalmente para git diff manual."
                cp -p "$source_file" "$repo_file"
            fi
            
            echo "   🔗 Creando enlace simbólico..."
            rm -f "$source_file"
            ln -sf "$repo_file" "$source_file"
        else
            # 3. No existe en el repo aún
            echo "📥 Importando nuevo archivo $target_name al repositorio..."
            mv "$source_file" "$repo_file"
            ln -sf "$repo_file" "$source_file"
        fi
    fi
}

# ==========================================
# RUTINAS PRINCIPALES
# ==========================================
do_install() {
    echo "==> 1. Verificando dependencias base (incluyendo kdiff3)..."
    $INSTALL_CMD $PACKAGES

    if [[ "$OS_FAMILIA" == "linux" ]] && [[ "$ID" == "kali" || "$ID" == "parrot" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
        $INSTALL_CMD bat
        mkdir -p ~/.local/bin
        ln -sf /usr/bin/batcat ~/.local/bin/bat || true
        ln -sf /usr/bin/fdfind ~/.local/bin/fd || true
    fi

    if [[ "$OS_FAMILIA" == "macos" ]]; then
        if command -v pip3 &> /dev/null; then pip3 install --user --upgrade --break-system-packages pynvim || true; fi
    fi

    echo "==> 2. Procesando configuraciones de Usuario..."
    mkdir -p "$DOTFILES_DIR/.config"
    
    # Aquí se invocará kdiff3 si hay conflictos
    safe_link "$HOME/.zshrc" ".zshrc"
    safe_link "$HOME/.p10k.zsh" "p10k-user.zsh"
    safe_link "$HOME/.eza.plugin.zsh" ".eza.plugin.zsh"
    safe_link "$HOME/.bat.plugin.zsh" ".bat.plugin.zsh"
    
    if [ ! -d "$DOTFILES_DIR/.config/nvim" ] && [ ! -d "$HOME/.config/nvim" ]; then
        echo "✨ Instalando LazyVim base..."
        git clone https://github.com/LazyVim/starter "$DOTFILES_DIR/.config/nvim"
        rm -rf "$DOTFILES_DIR/.config/nvim/.git"
    fi
    # Nota: Kdiff3 no fusionará el directorio completo de Neovim automáticamente. 
    # Solo enlazamos el directorio.
    if [ ! -L "$HOME/.config/nvim" ] && [ -d "$HOME/.config/nvim" ]; then
        echo "📦 Respaldando directorio local de Neovim..."
        mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak"
    fi
    ln -sfn "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"

    echo "==> 3. Entorno P10k..."
    [ ! -d "$HOME/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k"

    if [ "$OS_FAMILIA" == "linux" ]; then
        echo "==> 4. Enlazando Root..."
        sudo bash -c '[ ! -d "/root/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /root/powerlevel10k'
        
        if sudo [ -f /root/.p10k.zsh ] && sudo [ ! -L /root/.p10k.zsh ]; then
            sudo cp /root/.p10k.zsh "$DOTFILES_DIR/p10k-root.zsh"
            sudo chown $(id -un):$(id -gn) "$DOTFILES_DIR/p10k-root.zsh"
        fi
        
        sudo ln -sf "$DOTFILES_DIR/.zshrc" "/root/.zshrc"
        sudo ln -sf "$DOTFILES_DIR/p10k-root.zsh" "/root/.p10k.zsh"
        sudo mkdir -p /root/.config
        sudo ln -sf "$DOTFILES_DIR/.config/nvim" "/root/.config/nvim"
        sudo chsh -s "$(which zsh)" root
    fi

    if [ "$SHELL" != "$(which zsh)" ]; then
        chsh -s "$(which zsh)" "$USER" || sudo chsh -s "$(which zsh)" "$USER"
    fi
    echo -e "\n✅ Configuración y merge completados."
}

do_update() {
    echo "==> Conectando con GitHub para buscar actualizaciones..."
    cd "$DOTFILES_DIR"
    if [ -d ".git" ]; then
        git pull origin main
        echo "✅ Repositorio actualizado. Tus symlinks ya reflejan los cambios."
    else
        echo "❌ Este directorio no es un repositorio de Git."
    fi
}

do_push() {
    echo "==> Evaluando cambios en el repositorio..."
    cd "$DOTFILES_DIR"
    if [ ! -d ".git" ]; then
        git init
        git branch -M main
        git remote add origin "$REPO_URL"
    fi
    git status -s
    read -p "¿Mensaje del commit? (Enter para usar default): " msg
    msg=${msg:-"chore: actualizacion de configuracion interactiva (kdiff3)"}
    
    git add .
    git commit -m "$msg" || echo "No hay cambios nuevos para confirmar."
    git push -u origin main
    echo "✅ Cambios subidos a GitHub."
}

do_force_link() {
    echo "==> 🔨 Imponiendo estado del repositorio al sistema..."
    
    # Borrar archivos locales y crear enlaces estrictos
    rm -f "$HOME/.zshrc" && ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
    rm -f "$HOME/.p10k.zsh" && ln -sf "$DOTFILES_DIR/p10k-user.zsh" "$HOME/.p10k.zsh"
    
    if [ -f "$DOTFILES_DIR/.eza.plugin.zsh" ]; then
        rm -f "$HOME/.eza.plugin.zsh" && ln -sf "$DOTFILES_DIR/.eza.plugin.zsh" "$HOME/.eza.plugin.zsh"
    fi
    
    if [ -f "$DOTFILES_DIR/.bat.plugin.zsh" ]; then
        rm -f "$HOME/.bat.plugin.zsh" && ln -sf "$DOTFILES_DIR/.bat.plugin.zsh" "$HOME/.bat.plugin.zsh"
    fi
    
    # Forzar Neovim
    if [ -d "$DOTFILES_DIR/.config/nvim" ]; then
        rm -rf "$HOME/.config/nvim"
        ln -sfn "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
    fi
    
    echo "✅ Enlaces forzados con éxito. El sistema ahora obedece estrictamente a tu repositorio."
}

# ==========================================
# MENÚ INTERACTIVO
# ==========================================
clear
echo "======================================================"
echo " ⚙️ GESTOR DE DOTFILES MULTIPLATAFORMA (CON KDIFF3)"
echo "======================================================"
echo " 1) 🚀 Instalar Entorno (Merge automático si hay datos)"
echo " 2) ⬇️ Actualizar (Git Pull desde GitHub)"
echo " 3) ⬆️ Sincronizar (Git Push hacia GitHub)"
echo " 4) 🔨 Imponer Enlaces (Forzar repo -> sistema post-conflicto)"
echo " 5) ❌ Salir"
echo "======================================================"
read -p "Selecciona una opción [1-5]: " OPCION

case $OPCION in
    1) do_install ;;
    2) do_update ;;
    3) do_push ;;
    4) do_force_link ;;
    5) echo "Saliendo..."; exit 0 ;;
    *) echo "Opción inválida."; exit 1 ;;
esac
