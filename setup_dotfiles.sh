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
    sudo apt-get update || true
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
  echo "==> 1. Instalando dependencias del sistema..."

  FAILED_PACKAGES=()

  # Intentamos la instalación rápida en bloque
  if ! $INSTALL_CMD $PACKAGES; then
    echo -e "\n⚠️ Falló la instalación en bloque. Aislando paquetes problemáticos e instalando uno por uno...\n"
    for pkg in $PACKAGES; do
      if ! $INSTALL_CMD "$pkg" >/dev/null 2>&1; then
        FAILED_PACKAGES+=("$pkg")
        echo "❌ Falló: $pkg"
      else
        echo "✅ Instalado: $pkg"
      fi
    done
  fi

  # Gestiones específicas para Kali/Debian (bat y alias)
  if [[ "$OS_FAMILIA" == "linux" ]] && [[ "$ID" == "kali" || "$ID" == "parrot" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
    if ! $INSTALL_CMD bat >/dev/null 2>&1; then
      FAILED_PACKAGES+=("bat")
    else
      mkdir -p ~/.local/bin
      ln -sf /usr/bin/batcat ~/.local/bin/bat 2>/dev/null || true
      ln -sf /usr/bin/fdfind ~/.local/bin/fd 2>/dev/null || true
    fi
  fi

  # Gestiones específicas para macOS (pynvim)
  if [[ "$OS_FAMILIA" == "macos" ]]; then
    if command -v pip3 &>/dev/null; then
      if ! pip3 install --user --upgrade --break-system-packages pynvim >/dev/null 2>&1; then
        FAILED_PACKAGES+=("pynvim (pip3)")
      fi
    fi
  fi

  # ---------------------------------------------------------
  # REPORTE DE ERRORES
  # ---------------------------------------------------------
  if [ ${#FAILED_PACKAGES[@]} -ne 0 ]; then
    echo -e "\n======================================================"
    echo " ⚠️  REPORTE DE PAQUETES NO INSTALADOS"
    echo "======================================================"
    for failed in "${FAILED_PACKAGES[@]}"; do
      echo "   - $failed"
    done
    echo "======================================================"
    echo "El script continuará, pero algunas herramientas podrían no funcionar al 100%."
    read -p "Presiona Enter para continuar de todos modos..."
  else
    echo "✅ Todas las dependencias se instalaron correctamente."
  fi

  echo -e "\n==> 2. Imponiendo configuraciones de Usuario..."
  mkdir -p "$DOTFILES_DIR/.config"
  mkdir -p "$HOME/.config"

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
  echo "==> Evaluando cambios en tu entorno local..."
  cd "$DOTFILES_DIR"
  if [ ! -d ".git" ]; then
    git init
    git branch -M main
    git remote add origin "$REPO_URL"
  fi
  git status -s

  git add .
  echo "Abriendo Neovim para redactar el commit..."
  # Al quitar el '-m', Git invocará automáticamente a Neovim con tu template
  git commit || {
    echo "No hay cambios nuevos o el commit fue cancelado."
    return
  }

  git push -u origin main
  echo "✅ Cambios subidos a GitHub."
}
do_repair_links() {
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

do_fonts() {
  echo "==> 🔠 Instalando MesloLGS Nerd Font..."
  mkdir -p "$HOME/.local/share/fonts"
  cd "$HOME/.local/share/fonts"
  wget -q -O "MesloLGS NF Regular.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
  wget -q -O "MesloLGS NF Bold.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
  wget -q -O "MesloLGS NF Italic.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
  wget -q -O "MesloLGS NF Bold Italic.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"

  if command -v fc-cache &>/dev/null; then fc-cache -f -v &>/dev/null; fi
  echo "✅ Fuentes instaladas. Recuerda configurar tu terminal para usar 'MesloLGS NF'."
}

do_git_setup() {
  echo "==> 🔑 Configurando Git (Llave SSH y Template)..."

  # 1. Configurar Identidad y Template
  local template_file="$DOTFILES_DIR/.gitmessage"
  if [ ! -f "$template_file" ]; then
    echo "📝 Creando template de commit personalizado..."
    cat <<'EOF' >"$template_file"
<tipo>(<alcance>): <título descriptivo>

[Cuerpo detallado del commit explicando el por qué de los cambios]

-------------------☾ ꥟--------------------
  Signed by : Edgar Luna
              <luncie.vii@gmail.com>

  Refs :
-------------------𖤓 ༄--------------------
# Tipos comunes: 
# feat     (nueva función)
# fix      (corrección de error)
# chore    (mantenimiento, actualizar dependencias)
# refactor (optimización de código sin cambiar funcionalidad)
# docs     (cambios en README o documentación)
EOF
  fi

  git config --global commit.template "$template_file"
  git config --global user.name "Edgar Luna"
  git config --global user.email "luncie.vii@gmail.com"
  git config --global core.editor "nvim"

  # 2. Configurar Llave SSH
  if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -C "luncie.vii@gmail.com" -f "$HOME/.ssh/id_ed25519" -N ""
    eval "$(ssh-agent -s)" >/dev/null
    ssh-add "$HOME/.ssh/id_ed25519"
    echo "✅ Llave SSH generada exitosamente."
  else
    echo "✅ Ya existe una llave SSH en este sistema."
  fi

  echo "✅ Git configurado globalmente con tu firma y template."
  echo -e "\nCopia el siguiente bloque y pégalo en GitHub (Settings -> SSH Keys):"
  echo -e "\e[36m--------------------------------------------------------\e[0m"
  cat "$HOME/.ssh/id_ed25519.pub"
  echo -e "\e[36m--------------------------------------------------------\e[0m"
}

# ==========================================
# MENÚ INTERACTIVO (LOOP)
# ==========================================
while true; do
  clear
  echo "======================================================"
  echo " ⚙️ GESTOR DE DOTFILES DIRECTO"
  echo "======================================================"
  echo " 1) 🚀 Instalar (Respalda sistema y fuerza repo)"
  echo " 2) ⬇️ Descargar de GitHub (Actualizar sistema)"
  echo " 3) ⬆️ Subir a GitHub (Guardar cambios locales)"
  echo " 4) 🔨 Reparar Enlaces (Reconectar symlinks rotos)"
  echo " 5) ⏪ Restaurar Sistema (Deshacer instalación)"
  echo " 6) 🔠 Instalar Nerd Fonts (MesloLGS NF)"
  echo " 7) 🔑 Configurar GitHub (Llave SSH y Firma)"
  echo " 8) ❌ Salir"
  echo "======================================================"
  read -p "Selecciona una opción [1-8]: " OPCION

  case $OPCION in
  1) do_install ;;
  2) do_pull ;;
  3) do_push ;;
  4) do_repair_links ;;
  5) do_restore ;;
  6) do_fonts ;;
  7) do_git_setup ;;
  8)
    echo "Saliendo del gestor..."
    exit 0
    ;;
  *) echo "Opción inválida." ;;
  esac

  echo ""
  read -p "Presiona Enter para volver al menú..."
done
