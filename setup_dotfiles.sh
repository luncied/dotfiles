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
    echo "🐧 Sistema Arch detectado."
    INSTALL_CMD="sudo pacman -S --needed --noconfirm"
    PACKAGES="zsh git eza bat neovim ripgrep fd gcc make npm unzip wget curl python python-pip xclip wl-clipboard python-pynvim"
  elif [[ "$ID" == "kali" || "$ID" == "parrot" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
    echo "🐉 Sistema Kali/Parrot/Debian detectado."
    sudo apt-get update
    INSTALL_CMD="sudo apt-get install -y"
    PACKAGES="zsh git eza neovim ripgrep fd-find build-essential npm unzip wget curl python3 python3-pip xclip wl-clipboard python3-pynvim"
  fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS_FAMILIA="macos"
  echo "🍏 macOS detectado."
  if ! command -v brew &>/dev/null; then
    echo "Homebrew no está instalado. Por favor, instálalo primero."
    exit 1
  fi
  INSTALL_CMD="brew install"
  PACKAGES="zsh git eza bat neovim ripgrep fd gcc make node unzip wget curl python"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  OS_FAMILIA="windows"
  echo "🪟 Windows detectado."
  INSTALL_CMD="winget install --accept-package-agreements --accept-source-agreements"
  PACKAGES="Git.Git Neovim.Neovim BurntSushi.ripgrep.MSVC sharkdp.fd OpenJS.NodeJS GNU.Make Python.Python.3"
fi

echo "==> 1. Creando directorio de dotfiles ..."
mkdir -p "$DOTFILES_DIR/.config"

move_and_link() {
  local source_file="$1"
  local target_name="$2"
  if [ -e "$source_file" ] && [ ! -L "$source_file" ]; then
    mv "$source_file" "$DOTFILES_DIR/$target_name"
    ln -sf "$DOTFILES_DIR/$target_name" "$source_file"
  elif [ -f "$DOTFILES_DIR/$target_name" ]; then
    ln -sf "$DOTFILES_DIR/$target_name" "$source_file"
  fi
}

move_and_link "$HOME/.zshrc" ".zshrc"
move_and_link "$HOME/.p10k.zsh" "p10k-user.zsh"
move_and_link "$HOME/.eza.plugin.zsh" ".eza.plugin.zsh"
move_and_link "$HOME/.bat.plugin.zsh" ".bat.plugin.zsh"

# ==========================================
# GESTIÓN DE NEOVIM (LAZYVIM & TEMAS)
# ==========================================

if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
  echo "📦 Respaldando configuración existente de Neovim..."
  mv "$HOME/.config/nvim" "$DOTFILES_DIR/.config/"
  ln -sf "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
elif [ -d "$DOTFILES_DIR/.config/nvim" ]; then
  echo "🔗 Enlazando configuración de Neovim desde dotfiles..."
  ln -sf "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
else
  echo "✨ Instalando LazyVim base..."
  git clone https://github.com/LazyVim/starter "$DOTFILES_DIR/.config/nvim"
  rm -rf "$DOTFILES_DIR/.config/nvim/.git"
  ln -sf "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
fi

echo "==> 2. Instalando dependencias del sistema y de LazyVim..."
$INSTALL_CMD $PACKAGES

if [[ "$OS_FAMILIA" == "linux" ]] && [[ "$ID" == "kali" || "$ID" == "parrot" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
  $INSTALL_CMD bat
  mkdir -p ~/.local/bin
  ln -sf /usr/bin/batcat ~/.local/bin/bat || true
  ln -sf /usr/bin/fdfind ~/.local/bin/fd || true
fi

if [[ "$OS_FAMILIA" == "macos" || "$OS_FAMILIA" == "windows" ]]; then
  echo "Instalando módulo pynvim vía pip..."
  if command -v pip3 &>/dev/null; then
    pip3 install --user --upgrade --break-system-packages pynvim || true
  elif command -v pip &>/dev/null; then
    pip install --user --upgrade --break-system-packages pynvim || true
  fi
fi

echo "==> 3. Descargando Powerlevel10k ..."
if [ ! -d "$HOME/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k"
fi

# ==========================================
# CONFIGURACIÓN DE ROOT (LINUX & MACOS)
# ==========================================
if [[ "$OS_FAMILIA" == "linux" || "$OS_FAMILIA" == "macos" ]]; then
  echo "==> 4. Importando y enlazando configuración de Root..."

  # Detectar directorio dinámicamente
  ROOT_HOME="/root"
  if [ "$OS_FAMILIA" == "macos" ]; then
    ROOT_HOME="/var/root"
  fi

  if ! sudo [ -d "$ROOT_HOME/powerlevel10k" ]; then
    sudo git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ROOT_HOME/powerlevel10k"
  fi

  if sudo [ -f "$ROOT_HOME/.p10k.zsh" ] && sudo [ ! -L "$ROOT_HOME/.p10k.zsh" ]; then
    sudo cp "$ROOT_HOME/.p10k.zsh" "$DOTFILES_DIR/p10k-root.zsh"
    # Asignar propiedad compatible con grupos de Linux y macOS
    sudo chown $(id -un):$(id -gn) "$DOTFILES_DIR/p10k-root.zsh"
  fi

  sudo ln -sf "$DOTFILES_DIR/.zshrc" "$ROOT_HOME/.zshrc"
  sudo ln -sf "$DOTFILES_DIR/p10k-root.zsh" "$ROOT_HOME/.p10k.zsh"

  if [ -f "$DOTFILES_DIR/.eza.plugin.zsh" ]; then sudo ln -sf "$DOTFILES_DIR/.eza.plugin.zsh" "$ROOT_HOME/.eza.plugin.zsh"; fi
  if [ -f "$DOTFILES_DIR/.bat.plugin.zsh" ]; then sudo ln -sf "$DOTFILES_DIR/.bat.plugin.zsh" "$ROOT_HOME/.bat.plugin.zsh"; fi

  sudo mkdir -p "$ROOT_HOME/.config"
  sudo ln -sf "$DOTFILES_DIR/.config/nvim" "$ROOT_HOME/.config/nvim"

  # macOS SIP (System Integrity Protection) a veces protege chsh para root,
  # agregamos un fallback para evitar que el script colapse.
  sudo chsh -s "$(which zsh)" root || echo "⚠️ Aviso: macOS protegió el cambio de shell de root. Ignóralo."
else
  echo "==> 4. Omitiendo configuración de Root (No aplicable en $OS_FAMILIA)..."
fi

# Establecer Zsh como predeterminado para el usuario actual
if [ "$SHELL" != "$(which zsh)" ]; then
  chsh -s "$(which zsh)" "$USER" || sudo chsh -s "$(which zsh)" "$USER"
fi

echo "==> 5. Inicializando Git y preparando subida a GitHub..."
cd "$DOTFILES_DIR"
if [ ! -d ".git" ]; then
  git init
  git branch -M main
  git remote add origin "$REPO_URL"
fi
git add .
git commit -m "feat: setup de entorno completo (zsh, p10k, lazyvim + dependencias core)" || echo "Sin cambios nuevos."

echo ""
echo "¡Instalación completada y entorno estructurado!"
