#!/bin/bash
set -e

# ==========================================
# DETECCIÓN DE SISTEMA
# ==========================================
OS_FAMILIA="desconocido"
INSTALL_CMD=""

# Herramientas Base compartidas por ambos sistemas
CYBER_PACKAGES=(
  # Reconocimiento y Escaneo
  "sqlmap" "nmap" "rustscan" "masscan" "gobuster" "ffuf" "subfinder"

  # Redes y WiFi
  "aircrack-ng" "hcxtools" "hcxdumptool" "bettercap" "wireshark-qt" "tcpdump" "openvpn" "proxychains-ng"

  # Explotación y Shells
  "metasploit" "exploitdb" "netcat" "socat" "impacket" "netexec"

  # Craqueo de contraseñas
  "john" "hashcat"

  # Web y Proxies
  "burpsuite" "nikto"

  # Forense, OSINT y Esteganografía
  "binwalk" "foremost" "steghide" "exiftool" "recon-ng"

  # Ingeniería Inversa y Análisis de Binarios
  "ghidra" "radare2" "gdb" "pwndbg"

  # Diccionarios y Utilidades
  "seclists" "curl" "wget" "git" "jq" "python-pip"
)

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  source /etc/os-release

  if [[ "$ID" == "arch" || "$ID_LIKE" == *"arch"* ]]; then
    OS_FAMILIA="arch"

    # 1. Instalar Paru (Principal)
    if ! command -v paru &>/dev/null; then
      echo "==> 📦 Instalando gestor AUR (Paru)..."
      sudo pacman -S --needed --noconfirm base-devel git
      git clone https://aur.archlinux.org/paru.git /tmp/paru
      cd /tmp/paru && makepkg -si --noconfirm
      rm -rf /tmp/paru
    fi

    # 2. Instalar Yay (Alternativo)
    if ! command -v yay &>/dev/null; then
      echo "==> 📦 Instalando gestor AUR alternativo (Yay)..."
      sudo pacman -S --needed --noconfirm base-devel git
      git clone https://aur.archlinux.org/yay.git /tmp/yay
      cd /tmp/yay && makepkg -si --noconfirm
      rm -rf /tmp/yay
    fi

    INSTALL_CMD="paru -S --needed --noconfirm"

    # Añadir dependencias con nombres específicos de Arch Linux
    CYBER_PACKAGES+=(
      "thc-hydra"     # Nombre correcto de Hydra en Arch
      "sherlock-git"  # Versión mantenida en AUR
      "caido-desktop" # Interfaz gráfica de Caido
      "caido-cli"     # Motor de línea de comandos de Caido
      "bloodhound"
      "volatility3"
      "ruby" # Necesario para Evil-WinRM
    )

  elif [[ "$ID" == "kali" || "$ID" == "parrot" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
    OS_FAMILIA="debian"
    sudo apt-get update || true
    INSTALL_CMD="sudo apt-get install -y"

    # Añadir dependencias con nombres de repositorios APT
    CYBER_PACKAGES+=(
      "hydra"
      "sherlock"
      "evil-winrm"
      "bloodhound"
      "volatility3"
    )
  fi
else
  echo "❌ Este script de ciberseguridad está diseñado para Linux (Arch/Kali/Debian)."
  exit 1
fi

# ==========================================
# INSTALACIÓN RESILIENTE
# ==========================================
echo "==> 🛡️ Instalando arsenal de ciberseguridad..."
FAILED_PACKAGES=()

for pkg in "${CYBER_PACKAGES[@]}"; do
  if ! $INSTALL_CMD "$pkg" >/dev/null 2>&1; then
    FAILED_PACKAGES+=("$pkg")
    echo "❌ Falló: $pkg"
  else
    echo "✅ Instalado: $pkg"
  fi
done

# ==========================================
# CONFIGURACIONES POST-INSTALACIÓN
# ==========================================

# 1. Evil-WinRM para Arch Linux (vía Gem)
if [[ "$OS_FAMILIA" == "arch" ]]; then
  echo "==> 💎 Instalando Evil-WinRM (vía Ruby Gems)..."
  if command -v gem &>/dev/null; then
    sudo gem install evil-winrm || FAILED_PACKAGES+=("evil-winrm (gem)")
    echo "✅ Instalado: evil-winrm"
  else
    FAILED_PACKAGES+=("evil-winrm (gem no encontrado)")
  fi
fi

# 2. Configurar grupo Wireshark automáticamente
if getent group wireshark >/dev/null; then
  sudo usermod -aG wireshark "$USER"
  echo "==> 🦈 Usuario '$USER' añadido al grupo 'wireshark' para capturar paquetes sin sudo."
fi

# ==========================================
# REPORTE FINAL
# ==========================================
if [ ${#FAILED_PACKAGES[@]} -ne 0 ]; then
  echo -e "\n======================================================"
  echo " ⚠️  REPORTE DE HERRAMIENTAS NO INSTALADAS"
  echo "======================================================"
  for failed in "${FAILED_PACKAGES[@]}"; do
    echo "   - $failed"
  done
  echo "======================================================"
  echo "Nota: Puedes intentar instalar estas manualmente para ver el error exacto."
else
  echo -e "\n✅ Arsenal ofensivo desplegado completamente y sin errores."
fi
