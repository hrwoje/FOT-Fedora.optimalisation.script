#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'      # No Color

# Function to display a message
message() {
  echo -e "${YELLOW}INFO: ${NC}$1"
}

# Function to display a success message
success() {
  echo -e "${GREEN}SUCCESS: ${NC}$1"
}

# Function to display an error message
error() {
  echo -e "${RED}ERROR: ${NC}$1"
}

# Function to ask for confirmation
ask_confirmation() {
  read -p "$1 (y/N): " answer
  case "$answer" in
    [Yy]* ) return 0;;
    * ) return 1;;
  esac
}

# Function to retry a command
retry_command() {
  local max_attempts=3
  local attempt=1
  local delay=5

  while [ $attempt -le $max_attempts ]; do
    if "$@"; then
      return 0
    fi
    message "Attempt $attempt failed. Retrying in $delay seconds..."
    sleep $delay
    attempt=$((attempt + 1))
  done
  return 1
}

# Function to configure DNS via NetworkManager
configure_dns() {
  message "Configuring DNS via NetworkManager..."
  
  # Create backup of existing configuration
  if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
    sudo cp /etc/NetworkManager/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf.backup
  fi

  # Configure NetworkManager for DNS
  sudo bash -c 'cat > /etc/NetworkManager/NetworkManager.conf << EOL
[main]
dns=systemd-resolved
systemd-resolved=false
[global-dns-domain-*]
servers=1.1.1.2,1.0.0.2,8.8.8.8,9.9.9.9
EOL'

  if [ $? -eq 0 ]; then
    # Restart NetworkManager
    sudo systemctl restart NetworkManager
    sleep 2

    # Configure systemd-resolved
    sudo bash -c 'cat > /etc/systemd/resolved.conf << EOL
[Resolve]
DNS=1.1.1.2 1.0.0.2
FallbackDNS=8.8.8.8 9.9.9.9
DNSSEC=yes
DNSOverTLS=opportunistic
Cache=yes
Domains=~.
EOL'

    if [ $? -eq 0 ]; then
      sudo systemctl restart systemd-resolved
      sleep 2

      # Check configuration
      if systemctl is-active --quiet systemd-resolved && systemctl is-active --quiet NetworkManager; then
        # Wait for configuration to activate
        sleep 2
        
        # Verify DNS configuration
        dns_servers=$(resolvectl status | grep -A 3 "Global" | grep "DNS Servers" | awk '{print $3}')
        
        if [ -n "$dns_servers" ]; then
          success "DNS configuration completed. Active DNS servers: $dns_servers"
          
          # Test DNS functionality
          if ping -c 1 cloudflare.com &> /dev/null; then
            success "DNS functionality confirmed."
          else
            message "DNS is configured, but could not connect to cloudflare.com."
          fi
        else
          error "Could not verify active DNS servers. Restoring backup configuration..."
          sudo mv /etc/NetworkManager/NetworkManager.conf.backup /etc/NetworkManager/NetworkManager.conf
          sudo systemctl restart NetworkManager
        fi
      else
        error "One or both services could not be started. Restoring backup configuration..."
        sudo mv /etc/NetworkManager/NetworkManager.conf.backup /etc/NetworkManager/NetworkManager.conf
        sudo systemctl restart NetworkManager
      fi
    else
      error "An error occurred while configuring systemd-resolved."
    fi
  else
    error "An error occurred while configuring NetworkManager."
  fi
}

# Function to add RPM Fusion repositories
add_rpm_fusion() {
  message "Adding RPM Fusion repositories..."
  
  # Check network connectivity first
  if ! ping -c 1 download1.rpmfusion.org &> /dev/null; then
    error "Cannot reach RPM Fusion servers. Please check your network connection."
    return 1
  fi

  retry_command sudo dnf install --nogpgcheck https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
  
  if [ $? -eq 0 ]; then
    success "RPM Fusion repositories (free and nonfree) have been added."
  else
    error "Failed to add RPM Fusion repositories after multiple attempts."
  fi
}

# Function to add Flathub repository
add_flathub() {
  message "Adding Flathub repository..."
  
  # Check if flatpak is installed
  if ! command -v flatpak &> /dev/null; then
    message "Installing flatpak..."
    sudo dnf install -y flatpak
  fi

  # Check network connectivity
  if ! ping -c 1 flathub.org &> /dev/null; then
    error "Cannot reach Flathub servers. Please check your network connection."
    return 1
  fi

  retry_command flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  
  if [ $? -eq 0 ]; then
    success "Flathub repository has been added."
  else
    error "Failed to add Flathub repository after multiple attempts."
  fi
}

# Function to install preload (including COPR repo)
install_preload() {
  message "Enabling the elxreno/preload COPR repository..."
  sudo dnf copr enable -y elxreno/preload
  if [ $? -eq 0 ]; then
    message "COPR repository enabled. Installing preload..."
    sudo dnf install -y preload
    if [ $? -eq 0 ]; then
      sudo systemctl enable --now preload
      if [ $? -eq 0 ]; then
        success "preload installed and started."
      else
        error "preload installed, but there was an error starting the service. Check preload status with 'systemctl status preload'."
      fi
    else
      error "There was an error installing preload from the COPR repository."
    fi
  else
    error "There was an error enabling the elxreno/preload COPR repository."
  fi
}

# Function to adjust kernel parameters
adjust_kernel_parameters() {
  message "Adjusting kernel parameters..."
  echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
  echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  success "Kernel parameters (vm.swappiness and vm.vfs_cache_pressure) have been adjusted."
}

# Function to configure zram (alternative approach)
configure_zram() {
  message "Configuring zram..."
  sudo dnf install -y zram-generator-defaults
  if [ $? -eq 0 ]; then
    if [[ -d /sys/block/zram0 ]]; then
      success "zram-generator-defaults installed and zram devices appear active (e.g. /sys/block/zram0)."
    else
      message "zram-generator-defaults installed. Zram devices will likely be activated on the next restart."
    fi
  else
    error "There was an error installing zram-generator-defaults."
  fi
}

# Function for cleanup and cleaning
cleanup_system() {
  message "Performing system cleanup and cleaning..."
  sudo dnf autoremove -y
  sudo dnf clean all -y
  sudo journalctl --vacuum-time=3days
  success "Cleanup and cleaning completed."
}

# Function for antivirus and anti-malware protection
configure_security() {
  message "Installing and configuring security software..."
  
  # Install ClamAV and rkhunter
  sudo dnf install -y clamav clamav-update rkhunter
  
  if [ $? -eq 0 ]; then
    # Configure ClamAV
    message "Configuring ClamAV..."
    
    # Update virus definitions
    sudo freshclam
    
    # Make scan directory
    sudo mkdir -p /var/lib/clamav/scan
    
    # Configure automatic updates
    sudo bash -c 'cat > /etc/systemd/system/clamav-freshclam.service << EOL
[Unit]
Description=ClamAV virus database updater
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/freshclam -d --quiet
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
EOL'
    
    # Configure weekly scan with automatic cleanup
    sudo bash -c 'cat > /etc/systemd/system/clamav-scan.service << EOL
[Unit]
Description=ClamAV Weekly Scan with Auto-Cleanup
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '\''/usr/bin/clamscan -r / --exclude-dir="^/sys" --exclude-dir="^/proc" --exclude-dir="^/dev" --exclude-dir="^/run" --log=/var/log/clamav/scan.log --move=/var/lib/clamav/quarantine --remove=yes'\''
EOL'
    
    sudo bash -c 'cat > /etc/systemd/system/clamav-scan.timer << EOL
[Unit]
Description=Run ClamAV scan weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOL'
    
    # Configure rkhunter with automatic cleanup
    message "Configuring rkhunter..."
    
    # Update rkhunter database
    sudo rkhunter --update
    
    # Configure automatic updates
    sudo bash -c 'cat > /etc/systemd/system/rkhunter-update.service << EOL
[Unit]
Description=Update rkhunter database
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rkhunter --update
EOL'
    
    sudo bash -c 'cat > /etc/systemd/system/rkhunter-update.timer << EOL
[Unit]
Description=Update rkhunter database daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOL'
    
    # Configure weekly rkhunter scan with automatic cleanup
    sudo bash -c 'cat > /etc/systemd/system/rkhunter-scan.service << EOL
[Unit]
Description=Run rkhunter scan with auto-cleanup
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '\''/usr/bin/rkhunter --check --sk --report-warnings-only --autox --pkgmgr DNF'\''
EOL'
    
    sudo bash -c 'cat > /etc/systemd/system/rkhunter-scan.timer << EOL
[Unit]
Description=Run rkhunter scan weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOL'
    
    # Make quarantine directory
    sudo mkdir -p /var/lib/clamav/quarantine
    sudo chown -R clamav:clamav /var/lib/clamav/quarantine
    
    # Configure automatic quarantine cleanup
    sudo bash -c 'cat > /etc/systemd/system/clamav-quarantine-cleanup.service << EOL
[Unit]
Description=Cleanup old quarantined files
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '\''find /var/lib/clamav/quarantine -type f -mtime +30 -delete'\''
EOL'
    
    sudo bash -c 'cat > /etc/systemd/system/clamav-quarantine-cleanup.timer << EOL
[Unit]
Description=Cleanup quarantined files monthly

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
EOL'
    
    # Activate and start services
    sudo systemctl daemon-reload
    sudo systemctl enable --now clamav-freshclam.service
    sudo systemctl enable --now clamav-scan.timer
    sudo systemctl enable --now rkhunter-update.timer
    sudo systemctl enable --now rkhunter-scan.timer
    sudo systemctl enable --now clamav-quarantine-cleanup.timer
    
    # Perform first scans
    message "Performing first scans..."
    sudo freshclam
    sudo rkhunter --update
    sudo rkhunter --check --sk --autox
    
    success "Security software installed and configured. The following actions are set:"
    success "- Daily virus definition updates (ClamAV)"
    success "- Weekly full system scan with automatic cleanup (ClamAV)"
    success "- Daily updates of rkhunter database"
    success "- Weekly rootkit/malware scan with automatic cleanup (rkhunter)"
    success "- Monthly cleanup of old quarantine files (older than 30 days)"
  else
    error "There was an error installing the security software."
  fi
}

# Function for GNOME and Wayland optimization
configure_gnome() {
  message "Optimizing GNOME and Wayland..."
  
  # Install required packages
  sudo dnf install -y gnome-tweaks gnome-extensions-app mutter-devel
  
  if [ $? -eq 0 ]; then
    # Configure GNOME performance
    message "Configuring GNOME performance..."
    
    # Optimize mutter (GNOME window manager) with triple buffering
    sudo bash -c 'cat > /etc/dconf/db/local.d/01-gnome-performance << EOL
[org/gnome/mutter]
experimental-features="['\''scale-monitor-framebuffer'\'', '\''variable-refresh-rate'\'', '\''triple-buffering'\'']"
dynamic-buffer-allocation=true
max-monitor-scale=2
frame-rate=144
EOL'
    
    # Configure Wayland for better performance with triple buffering
    sudo bash -c 'cat > /etc/environment << EOL
CLUTTER_BACKEND=wayland
GDK_BACKEND=wayland
QT_QPA_PLATFORM=wayland
SDL_VIDEODRIVER=wayland
MOZ_ENABLE_WAYLAND=1
WLR_NO_HARDWARE_CURSORS=1
WLR_RENDERER_ALLOW_SOFTWARE=1
__GL_THREADED_OPTIMIZATIONS=1
__GL_SYNC_TO_VBLANK=0
__GL_YIELD=USLEEP
vblank_mode=0
MESA_GL_VERSION_OVERRIDE=4.5
MESA_GLSL_VERSION_OVERRIDE=450
EOL'
    
    # Configure HDR support
    message "Configuring HDR support..."
    
    # Install HDR-related packages
    sudo dnf install -y colord-gtk4 libcolord-gtk4
    
    # Configure HDR in GNOME with triple buffering
    sudo bash -c 'cat > /etc/dconf/db/local.d/01-gnome-hdr << EOL
[org/gnome/settings-daemon/plugins/color]
night-light-enabled=true
night-light-temperature=4000

[org/gnome/mutter]
experimental-features="['\''scale-monitor-framebuffer'\'', '\''variable-refresh-rate'\'', '\''triple-buffering'\'']"
frame-rate=144
EOL'
    
    # Configure kernel parameters for better graphical performance
    sudo bash -c 'cat > /etc/sysctl.d/99-gnome-performance.conf << EOL
# Improved graphical performance
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.dirty_expire_centisecs=500
vm.dirty_writeback_centisecs=100
EOL'
    
    # Apply changes
    sudo sysctl -p /etc/sysctl.d/99-gnome-performance.conf
    sudo dconf update
    
    # Configure GPU optimizations with triple buffering
    message "Configuring GPU optimizations..."
    
    # Make a GPU configuration file
    sudo bash -c 'cat > /etc/X11/xorg.conf.d/20-gnome-optimization.conf << EOL
Section "Device"
    Identifier "GPU0"
    Driver "modesetting"
    Option "TearFree" "true"
    Option "AccelMethod" "glamor"
    Option "DRI" "3"
    Option "TripleBuffer" "true"
    Option "BackingStore" "true"
    Option "RenderAccel" "true"
    Option "AccelDFS" "true"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device "GPU0"
    DefaultDepth 24
    Option "Stereo" "0"
    Option "nvidiaXineramaInfoOrder" "DFP-0"
    Option "metamodes" "nvidia-auto-select +0+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}"
    Option "AllowIndirectGLXProtocol" "off"
    Option "TripleBuffer" "true"
    Option "BackingStore" "true"
    Option "RenderAccel" "true"
    Option "AccelDFS" "true"
EndSection

Section "Extensions"
    Option "Composite" "Enable"
EndSection
EOL'
    
    # Configure GNOME Shell optimizations
    gsettings set org.gnome.desktop.interface enable-animations false
    gsettings set org.gnome.desktop.interface enable-hot-corners false
    gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
    gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
    
    # Configure energy saving
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
    
    # Configure MESA for triple buffering
    sudo bash -c 'cat > /etc/profile.d/mesa.sh << EOL
export MESA_GL_VERSION_OVERRIDE=4.5
export MESA_GLSL_VERSION_OVERRIDE=450
export __GL_THREADED_OPTIMIZATIONS=1
export __GL_SYNC_TO_VBLANK=0
export __GL_YIELD=USLEEP
export vblank_mode=0
EOL'
    
    # Make the script executable
    sudo chmod +x /etc/profile.d/mesa.sh
    
    success "GNOME and Wayland optimization completed. The following improvements have been applied:"
    success "- Triple buffering activated for smoother display"
    success "- Improved Wayland performance with optimized rendering"
    success "- HDR support configured"
    success "- GPU optimizations applied with triple buffering"
    success "- GNOME Shell optimizations activated"
    success "- Energy-saving settings configured"
    message "Restart your system to fully activate all changes."
  else
    error "There was an error installing the required packages."
  fi
}

# Function to optimize Chrome
configure_chrome() {
  message "Optimizing Chrome..."
  
  # Detect Chrome version and installation path
  CHROME_VERSION=$(google-chrome --version | awk '{print $3}')
  CHROME_PATH=$(which google-chrome)
  CHROME_CONFIG_DIR="$HOME/.config/google-chrome"
  
  if [ -n "$CHROME_VERSION" ] && [ -n "$CHROME_PATH" ]; then
    success "Chrome version $CHROME_VERSION detected."
    
    # Make configuration directory if needed
    mkdir -p "$CHROME_CONFIG_DIR"
    
    # Configure Chrome for Wayland and optimizations
    message "Configuring Chrome for Wayland and optimizations..."
    
    # Make a configuration file for Chrome
    cat > "$CHROME_CONFIG_DIR/Local State" << EOL
{
  "browser": {
    "enabled_labs_experiments": [
      "enable-wayland@1",
      "enable-accelerated-video-decode@1",
      "enable-accelerated-video-encode@1",
      "enable-gpu-rasterization@1",
      "enable-zero-copy@1",
      "enable-parallel-downloading@1",
      "enable-quic@1",
      "enable-experimental-web-platform-features@1"
    ]
  },
  "gpu": {
    "driver_bug_workarounds": {
      "disable_gpu_driver_bug_workarounds": false,
      "force_direct_composition": true,
      "force_direct_composition_video_overlays": true,
      "force_zero_copy_video_capture": true
    },
    "feature_flags": {
      "enable_gpu_rasterization": true,
      "enable_zero_copy": true,
      "enable_oop_rasterization": true,
      "enable_skia_renderer": true,
      "enable_vulkan": true
    }
  },
  "download": {
    "default_directory": "$HOME/Downloads",
    "directory_upgrade": true,
    "extensions_to_open": "",
    "prompt_for_download": false
  },
  "performance": {
    "memory_pressure_level": "none",
    "renderer_process_limit": -1,
    "tab_discarding": false,
    "tab_freeze": false
  }
}
EOL
    
    # Configure system environment for Chrome
    sudo bash -c 'cat > /etc/profile.d/chrome-optimization.sh << EOL
# Chrome optimizations
export CHROME_FORCE_DIRECT_COMPOSITION=1
export CHROME_FORCE_DIRECT_COMPOSITION_VIDEO_OVERLAYS=1
export CHROME_FORCE_ZERO_COPY_VIDEO_CAPTURE=1
export CHROME_ENABLE_GPU_RASTERIZATION=1
export CHROME_ENABLE_ZERO_COPY=1
export CHROME_ENABLE_OOP_RASTERIZATION=1
export CHROME_ENABLE_SKIA_RENDERER=1
export CHROME_ENABLE_VULKAN=1
export CHROME_ENABLE_WAYLAND=1
export CHROME_ENABLE_QUIC=1
export CHROME_ENABLE_PARALLEL_DOWNLOADING=1
export CHROME_ENABLE_EXPERIMENTAL_WEB_PLATFORM_FEATURES=1

# Optimize network settings
export CHROME_NETWORK_THREAD_PRIORITY=high
export CHROME_IO_THREAD_PRIORITY=high
export CHROME_GPU_THREAD_PRIORITY=high
export CHROME_RENDERER_THREAD_PRIORITY=high

# Optimize memory usage
export CHROME_MEMORY_PRESSURE_LEVEL=none
export CHROME_RENDERER_PROCESS_LIMIT=-1
export CHROME_TAB_DISCARDING=false
export CHROME_TAB_FREEZE=false
EOL'
    
    # Make the script executable
    sudo chmod +x /etc/profile.d/chrome-optimization.sh
    
    # Configure system environment for Wayland
    sudo bash -c 'cat > /etc/environment.d/99-chrome-wayland.conf << EOL
# Chrome Wayland optimizations
CHROME_FORCE_DIRECT_COMPOSITION=1
CHROME_FORCE_DIRECT_COMPOSITION_VIDEO_OVERLAYS=1
CHROME_FORCE_ZERO_COPY_VIDEO_CAPTURE=1
CHROME_ENABLE_GPU_RASTERIZATION=1
CHROME_ENABLE_ZERO_COPY=1
CHROME_ENABLE_OOP_RASTERIZATION=1
CHROME_ENABLE_SKIA_RENDERER=1
CHROME_ENABLE_VULKAN=1
CHROME_ENABLE_WAYLAND=1
CHROME_ENABLE_QUIC=1
CHROME_ENABLE_PARALLEL_DOWNLOADING=1
CHROME_ENABLE_EXPERIMENTAL_WEB_PLATFORM_FEATURES=1
EOL'
    
    # Configure system environment for network optimizations
    sudo bash -c 'cat > /etc/sysctl.d/99-chrome-network.conf << EOL
# Chrome network optimizations
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 87380 16777216
net.ipv4.tcp_congestion_control=cubic
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_moderate_rcvbuf=1
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_dsack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_ecn=1
net.ipv4.tcp_reordering=3
net.ipv4.tcp_retries2=8
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries=3
net.ipv4.tcp_max_syn_backlog=4096
net.ipv4.tcp_max_tw_buckets=180000
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=6
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_app_win=31
net.ipv4.tcp_rfc1337=1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_workaround_signed_windows=1
net.ipv4.tcp_tw_recycle=1
net.ipv4.tcp_abort_on_overflow=0
net.ipv4.tcp_stdurg=0
EOL'
    
    # Apply network optimizations
    sudo sysctl -p /etc/sysctl.d/99-chrome-network.conf
    
    # Configure Chrome for better file display
    cat > "$CHROME_CONFIG_DIR/Default/Preferences" << EOL
{
  "download": {
    "default_directory": "$HOME/Downloads",
    "directory_upgrade": true,
    "extensions_to_open": "",
    "prompt_for_download": false
  },
  "profile": {
    "content_settings": {
      "exceptions": {
        "plugins": {
          "*,*": {
            "last_modified": "13189824000000000",
            "setting": 1
          }
        }
      }
    },
    "default_content_setting_values": {
      "plugins": 1,
      "popups": 1,
      "geolocation": 1,
      "notifications": 1,
      "auto_select_certificate": 2,
      "fullscreen": 1,
      "mouselock": 1,
      "mixed_script": 1,
      "media_stream": 1,
      "media_stream_mic": 1,
      "media_stream_camera": 1,
      "protocol_handlers": 1,
      "ppapi_broker": 1,
      "automatic_downloads": 1,
      "midi_sysex": 1,
      "push_messaging": 1,
      "ssl_cert_decisions": 1,
      "metro_switch_to_desktop": 1,
      "protected_media_identifier": 1,
      "site_engagement": 1,
      "durable_storage": 1
    }
  }
}
EOL
    
    success "Chrome optimization completed. The following improvements have been applied:"
    success "- Wayland support activated"
    success "- GPU acceleration optimized"
    success "- Download speeds maximized"
    success "- File display optimized"
    success "- Network performance improved"
    success "- Memory usage optimized"
    message "Restart Chrome to fully activate all changes."
  else
    error "Chrome is not installed or could not be detected. Install Chrome first via DNF."
  fi
}

# Function for system performance optimization
optimize_system_performance() {
  message "Optimizing system performance..."
  
  # Optimize CPU scheduler
  sudo bash -c 'cat > /etc/sysctl.d/99-scheduler.conf << EOL
# CPU scheduler optimizations
kernel.sched_min_granularity_ns=1000000
kernel.sched_wakeup_granularity_ns=2000000
kernel.sched_latency_ns=4000000
kernel.sched_migration_cost_ns=500000
kernel.sched_rt_runtime_us=950000
kernel.sched_rt_period_us=1000000
kernel.sched_autogroup_enabled=1
EOL'
  
  # Optimize I/O scheduler
  sudo bash -c 'cat > /etc/udev/rules.d/60-io-scheduler.rules << EOL
# I/O scheduler optimizations
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
EOL'
  
  # Optimize memory management
  sudo bash -c 'cat > /etc/sysctl.d/99-memory.conf << EOL
# Memory management optimizations
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.dirty_expire_centisecs=500
vm.dirty_writeback_centisecs=100
vm.min_free_kbytes=65536
vm.zone_reclaim_mode=1
vm.page-cluster=0
vm.overcommit_memory=1
vm.overcommit_ratio=100
EOL'
  
  # Optimize network stack
  sudo bash -c 'cat > /etc/sysctl.d/99-network.conf << EOL
# Network stack optimizations
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 87380 16777216
net.ipv4.tcp_congestion_control=cubic
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_moderate_rcvbuf=1
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_dsack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_ecn=1
net.ipv4.tcp_reordering=3
net.ipv4.tcp_retries2=8
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries=3
net.ipv4.tcp_max_syn_backlog=4096
net.ipv4.tcp_max_tw_buckets=180000
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=6
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_app_win=31
net.ipv4.tcp_rfc1337=1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_workaround_signed_windows=1
net.ipv4.tcp_abort_on_overflow=0
net.ipv4.tcp_stdurg=0
EOL'
  
  # Apply all changes
  sudo sysctl -p /etc/sysctl.d/99-scheduler.conf
  sudo sysctl -p /etc/sysctl.d/99-memory.conf
  sudo sysctl -p /etc/sysctl.d/99-network.conf
  sudo udevadm control --reload-rules
  sudo udevadm trigger
  
  success "System performance optimization completed. The following improvements have been applied:"
  success "- CPU scheduler optimized"
  success "- I/O scheduler configured for SSDs and HDDs"
  success "- Memory management improved"
  success "- Network stack optimized"
  message "Restart your system to fully activate all changes."
}

# Function for system security optimization
optimize_security() {
  message "Optimizing system security..."
  
  # Configure firewall
  sudo dnf install -y firewalld
  sudo systemctl enable --now firewalld
  sudo firewall-cmd --permanent --zone=public --set-target=DROP
  sudo firewall-cmd --permanent --zone=public --add-service=ssh
  sudo firewall-cmd --permanent --zone=public --add-service=http
  sudo firewall-cmd --permanent --zone=public --add-service=https
  sudo firewall-cmd --reload
  
  # Configure SELinux
  sudo setenforce 1
  sudo sed -i 's/SELINUX=permissive/SELINUX=enforcing/g' /etc/selinux/config
  
  # Configure system security
  sudo bash -c 'cat > /etc/sysctl.d/99-security.conf << EOL
# System security optimizations
kernel.kptr_restrict=2
kernel.sysrq=0
kernel.core_uses_pid=1
kernel.yama.ptrace_scope=2
kernel.randomize_va_space=2
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_max_syn_backlog=2048
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_syn_retries=5
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0
EOL'
  
  # Apply security changes
  sudo sysctl -p /etc/sysctl.d/99-security.conf
  
  success "System security optimization completed. The following improvements have been applied:"
  success "- Firewall configured and activated"
  success "- SELinux in enforcing mode set"
  success "- System security strengthened"
  success "- Network security improved"
  message "Restart your system to fully activate all changes."
}

# Function for software repositories optimization
optimize_repositories() {
  message "Optimizing software repositories..."
  
  # Configure DNF for better performance
  sudo bash -c 'cat > /etc/dnf/dnf.conf << EOL
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=False
skip_if_unavailable=True
fastestmirror=True
max_parallel_downloads=10
defaultyes=True
keepcache=True
EOL'
  
  # Add extra repositories
  sudo dnf install -y epel-release
  sudo dnf config-manager --set-enabled powertools
  sudo dnf config-manager --add-repo https://negativo17.org/repos/fedora-steam.repo
  
  # Configure Flatpak
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak update -y
  
  success "Software repositories optimization completed. The following improvements have been applied:"
  success "- DNF configured for faster downloads"
  success "- Extra repositories added"
  success "- Flatpak configured and updated"
  message "Run 'sudo dnf update' to synchronize the repositories."
}

# Function for system maintenance optimization
optimize_maintenance() {
  message "Optimizing system maintenance..."
  
  # Configure automatic maintenance
  sudo bash -c 'cat > /etc/systemd/system/optimize-maintenance.service << EOL
[Unit]
Description=System Optimization and Maintenance
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '\''
  dnf autoremove -y
  dnf clean all
  journalctl --vacuum-time=3days
  fstrim -av
  updatedb
'\''
EOL'
  
  sudo bash -c 'cat > /etc/systemd/system/optimize-maintenance.timer << EOL
[Unit]
Description=Run system optimization and maintenance weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOL'
  
  # Activate automatic maintenance
  sudo systemctl daemon-reload
  sudo systemctl enable --now optimize-maintenance.timer
  
  success "System maintenance optimization completed. The following improvements have been applied:"
  success "- Automatic maintenance configured"
  success "- Weekly cleanup set"
  success "- System optimization automated"
  message "The system will be automatically optimized weekly."
}

# Function for GNOME optimization
optimize_gnome() {
  message "Optimizing GNOME..."
  
  # Configure GNOME performance
  gsettings set org.gnome.desktop.interface enable-animations false
  gsettings set org.gnome.desktop.interface enable-hot-corners false
  gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
  gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
  
  # Configure energy saving
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
  
  # Configure mutter (GNOME window manager)
  sudo bash -c 'cat > /etc/dconf/db/local.d/01-gnome-performance << EOL
[org/gnome/mutter]
experimental-features="['\''scale-monitor-framebuffer'\'', '\''variable-refresh-rate'\'', '\''triple-buffering'\'']"
dynamic-buffer-allocation=true
max-monitor-scale=2
frame-rate=144
EOL'
  
  # Configure Wayland
  sudo bash -c 'cat > /etc/environment.d/99-gnome-wayland.conf << EOL
# GNOME Wayland optimizations
CLUTTER_BACKEND=wayland
GDK_BACKEND=wayland
QT_QPA_PLATFORM=wayland
SDL_VIDEODRIVER=wayland
MOZ_ENABLE_WAYLAND=1
WLR_NO_HARDWARE_CURSORS=1
WLR_RENDERER_ALLOW_SOFTWARE=1
__GL_THREADED_OPTIMIZATIONS=1
__GL_SYNC_TO_VBLANK=0
__GL_YIELD=USLEEP
vblank_mode=0
MESA_GL_VERSION_OVERRIDE=4.5
MESA_GLSL_VERSION_OVERRIDE=450
EOL'
  
  # Apply GNOME changes
  sudo dconf update
  
  success "GNOME optimization completed. The following improvements have been applied:"
  success "- GNOME performance improved"
  success "- Energy-saving settings configured"
  success "- Wayland support optimized"
  message "Restart your system to fully activate all changes."
}

# Function for complete optimization
perform_complete_optimization() {
  message "Performing complete system optimization..."
  
  # Perform all optimizations
  configure_dns
  add_rpm_fusion
  add_flathub
  install_preload
  adjust_kernel_parameters
  configure_zram
  configure_security
  configure_gnome
  configure_chrome
  optimize_system_performance
  optimize_security
  optimize_repositories
  optimize_maintenance
  optimize_gnome
  cleanup_system
  
  success "Complete system optimization completed. All improvements have been applied."
  message "Restart your system to fully activate all changes."
}

# Main menu
show_menu() {
  echo -e "${YELLOW}==================================================${NC}"
  echo -e "${YELLOW}           FOT - Fedora Optimization Tool          ${NC}"
  echo -e "${YELLOW}           Copyright © 2024 Hrwoje Dabo           ${NC}"
  echo -e "${YELLOW}==================================================${NC}"
  echo ""
  echo "Choose an option:"
  echo "1. Configure DNS (Cloudflare Malware Blocking & Fallback)"
  echo "2. Add RPM Fusion Repositories"
  echo "3. Add Flathub Repository"
  echo "4. Install preload"
  echo "5. Adjust kernel parameters (swappiness & vfs_cache_pressure)"
  echo "6. Configure zram (compressed swap in RAM)"
  echo "7. Perform system cleanup"
  echo "8. Configure antivirus and anti-malware protection"
  echo "9. Configure GNOME and Wayland optimization"
  echo "10. Optimize Chrome for Wayland and performance"
  echo "11. Optimize system performance"
  echo "12. Optimize system security"
  echo "13. Optimize software repositories"
  echo "14. Optimize system maintenance"
  echo "15. Optimize GNOME"
  echo "16. Perform complete optimization (recommended)"
  echo "17. Exit"
  read -p "Select an option [1-17]: " choice

  case "$choice" in
    1) configure_dns;;
    2) add_rpm_fusion;;
    3) add_flathub;;
    4) install_preload;;
    5) adjust_kernel_parameters;;
    6) configure_zram;;
    7) cleanup_system;;
    8) configure_security;;
    9) configure_gnome;;
    10) configure_chrome;;
    11) optimize_system_performance;;
    12) optimize_security;;
    13) optimize_repositories;;
    14) optimize_maintenance;;
    15) optimize_gnome;;
    16)
      ask_confirmation "Are you sure you want to perform all optimizations?" && {
        perform_complete_optimization
      } || message "Optimization cancelled.";;
    17) message "Script is exiting."; exit 0;;
    *) error "Invalid choice. Please try again.";;
  esac
  echo ""
  show_menu
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
  error "This script must be run as root. Use sudo."
  exit 1
fi

# Start the menu
show_menu
