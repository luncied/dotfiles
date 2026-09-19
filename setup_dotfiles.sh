#!/bin/bash
set -e

DOTFILES_DIR="$HOME/dotfiles"
REPO_URL="git@github.com:luncied/dotfiles.git"
BACKUP_DIR="$HOME/.dotfiles_backup"

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
    PACKAGES="zsh git eza bat neovim ripgrep fd gcc make npm unzip wget curl python python-pip xclip wl-clipboard python-pynvim"
  elif [[ "$ID" == "kali" || "$ID" == "parrot" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
    sudo apt-get update
    INSTALL_CMD="sudo apt-get install -y"
    PACKAGES="zsh git eza neovim ripgrep fd-find build-essential npm unzip wget curl python3 python3-pip xclip wl-clipboard python3-pynvim"
  fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS_FAMILIA="macos"
  INSTALL_CMD="brew install"
  PACKAGES="zsh git eza bat neovim ripgrep fd gcc make node unzip wget curl python"
fi

# ==========================================
# FUNCIÓN: ENLACE IMPOSITIVO Y BACKUP
# ==========================================
safe_link() {
  local target_path="$1" # ej. /home/usuario/.zshrc
  local repo_name="$2"   # ej. .zshrc
  local repo_file="$DOTFILES_DIR/$repo_name"

  # Reemplazamos diagonales por guiones bajos para nombres planos en el backup (ej. .config_nvim.bak)
  local backup_name="${repo_name//\//_}.bak"
  local backup_file="$BACKUP_DIR/$backup_name"

  # 1. Si existe en el sistema y NO es un symlink, lo movemos a la carpeta de backups
  if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
    echo "📦 Moviendo configuración del sistema a backup: $backup_name"
    mv "$target_path" "$backup_file"
  # 2. Si ya es un symlink (viejo o roto), lo borramos para refrescarlo
  elif [ -L "$target_path" ]; then
    rm -f "$target_path"
  fi

  # 3. Imponemos el archivo del repositorio al sistema
  if [ -e "$repo_file" ]; then
    echo "🔗 Enlazando: $target_path -> $repo_name"
    ln -sfn "$repo_file" "$target_path"
  else
    echo "⚠️  Advertencia: $repo_name no existe en tu repositorio aún."
  fi
}

# ==========================================
# RUTINAS PRINCIPALES
# ==========================================
do_install() {
  echo "==> 1. Verificando dependencias base..."
  $INSTALL_CMD $PACKAGES

  # Configuración específica para binarios en Debian/Kali
  if [[ "$OS_FAMILIA" == "linux" ]] && [[ "$ID" == "kali" || "$ID" == "parrot" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
    $INSTALL_CMD bat
    mkdir -p ~/.local/bin
    ln -sf /usr/bin/batcat ~/.local/bin/bat || true
    ln -sf /usr/bin/fdfind ~/.local/bin/fd || true
  fi

  # Configuración específica de Python para macOS
  if [[ "$OS_FAMILIA" == "macos" ]]; then
    if command -v pip3 &>/dev/null; then pip3 install --user --upgrade --break-system-packages pynvim || true; fi
  fi

  echo "==> 2. Preparando entorno de Neovim y Zsh..."
  mkdir -p "$DOTFILES_DIR/.config"
  mkdir -p "$BACKUP_DIR"

  if [ ! -d "$DOTFILES_DIR/.config/nvim" ]; then
    echo "✨ Descargando LazyVim base en dotfiles..."
    git clone https://github.com/LazyVim/starter "$DOTFILES_DIR/.config/nvim"
    rm -rf "$DOTFILES_DIR/.config/nvim/.git"
  fi

  echo "==> 3. Imponiendo configuraciones (Backup + Symlinks)..."
  safe_link "$HOME/.zshrc" ".zshrc"
  safe_link "$HOME/.p10k.zsh" "p10k-user.zsh"
  safe_link "$HOME/.eza.plugin.zsh" ".eza.plugin.zsh"
  safe_link "$HOME/.bat.plugin.zsh" ".bat.plugin.zsh"
  safe_link "$HOME/.config/nvim" ".config/nvim"

  echo "==> 4. Entorno P10k..."
  [ ! -d "$HOME/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k"

  if [ "$OS_FAMILIA" == "linux" ]; then
    echo "==> 5. Enlazando Root..."
    sudo bash -c '[ ! -d "/root/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /root/powerlevel10k'

    if sudo [ -f /root/.p10k.zsh ] && sudo [ ! -L /root/.p10k.zsh ]; then
      sudo cp /root/.p10k.zsh "$DOTFILES_DIR/p10k-root.zsh"
      sudo chown $(id -un):$(id -gn) "$DOTFILES_DIR/p10k-root.zsh"
    fi

    sudo ln -sf "$DOTFILES_DIR/.zshrc" "/root/.zshrc"
    sudo ln -sf "$DOTFILES_DIR/p10k-root.zsh" "/root/.p10k.zsh"
    sudo mkdir -p /root/.config
    sudo ln -sfn "$DOTFILES_DIR/.config/nvim" "/root/.config/nvim"
    sudo chsh -s "$(which zsh)" root
  fi

  if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)" "$USER" || sudo chsh -s "$(which zsh)" "$USER"
  fi
  echo -e "\n✅ Instalación e imposición completada. Backups en $BACKUP_DIR"
}

do_update() {
  echo "==> Conectando con GitHub para buscar actualizaciones de otros equipos..."
  cd "$DOTFILES_DIR"
  if [ -d ".git" ]; then
    git pull origin main
    echo "✅ Repositorio actualizado. Tus symlinks reflejan los cambios instantáneamente."
  else
    echo "❌ Este directorio no es un repositorio de Git."
  fi
}

do_push() {
  echo "==> Evaluando tus modificaciones locales..."
  cd "$DOTFILES_DIR"
  if [ ! -d ".git" ]; then
    git init
    git branch -M main
    git remote add origin "$REPO_URL"
  fi
  git status -s
  read -p "¿Mensaje del commit? (Enter para usar default): " msg
  msg=${msg:-"chore: actualizacion de sistema (zsh, nvim, p10k)"}

  git add .
  git commit -m "$msg" || echo "No hay cambios nuevos para confirmar."
  git push -u origin main
  echo "✅ Cambios subidos a GitHub exitosamente."
}

do_relink() {
  echo "==> 🔨 Reparando symlinks rotos (Imponiendo repositorio sin instalar paquetes)..."
  mkdir -p "$BACKUP_DIR"
  safe_link "$HOME/.zshrc" ".zshrc"
  safe_link "$HOME/.p10k.zsh" "p10k-user.zsh"
  safe_link "$HOME/.eza.plugin.zsh" ".eza.plugin.zsh"
  safe_link "$HOME/.bat.plugin.zsh" ".bat.plugin.zsh"
  safe_link "$HOME/.config/nvim" ".config/nvim"
  echo "✅ Symlinks forzados y conectados al repositorio."
}

do_restore() {
  echo "==> ⏪ Modo Restauración (Revirtiendo a la configuración original del sistema)..."
  if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR")" ]; then
    echo "❌ No se encontraron archivos de respaldo en $BACKUP_DIR."
    return
  fi

  # Función interna para restaurar un solo archivo/directorio
  restore_item() {
    local target_path="$1"
    local repo_name="$2"
    local backup_name="${repo_name//\//_}.bak"
    local backup_file="$BACKUP_DIR/$backup_name"

    if [ -e "$backup_file" ]; then
      # Si el sistema actual tiene un symlink (o archivo corrupto), lo borramos
      if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        rm -f "$target_path"
      fi
      # Restauramos el original
      mv "$backup_file" "$target_path"
      echo "✅ Restaurado: $target_path"
    fi
  }

  restore_item "$HOME/.zshrc" ".zshrc"
  restore_item "$HOME/.p10k.zsh" "p10k-user.zsh"
  restore_item "$HOME/.eza.plugin.zsh" ".eza.plugin.zsh"
  restore_item "$HOME/.bat.plugin.zsh" ".bat.plugin.zsh"
  restore_item "$HOME/.config/nvim" ".config/nvim"

  echo "🎉 Restauración completada. Los enlaces al repositorio han sido eliminados."
}

# ==========================================
# MENÚ INTERACTIVO
# ==========================================
clear
echo "======================================================"
echo " ⚙️ GESTOR DE DOTFILES MULTIPLATAFORMA (STRICT MODE)"
echo "======================================================"
echo " 1) 🚀 Instalar e Imponer Repo (Mueve el sistema a backup)"
echo " 2) ⬇️ Actualizar de GitHub (Git Pull - Traer cambios)"
echo " 3) ⬆️ Sincronizar a GitHub (Git Push - Subir cambios)"
echo " 4) 🔨 Reparar Enlaces (Re-conecta los symlinks rotos)"
echo " 5) ⏪ Restaurar Sistema (Recupera los archivos del backup)"
echo " 6) ❌ Salir"
echo "======================================================"
read -p "Selecciona una opción [1-6]: " OPCION

case $OPCION in
1) do_install ;;
2) do_update ;;
3) do_push ;;
4) do_relink ;;
5) do_restore ;;
6)
  echo "Saliendo..."
  exit 0
  ;;
*)
  echo "Opción inválida."
  exit 1
  ;;
esac
