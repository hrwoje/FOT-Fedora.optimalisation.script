# 🚀 FOT - Fedora Optimization Tool

[![Fedora](https://img.shields.io/badge/Fedora-294172?style=for-the-badge&logo=fedora&logoColor=white)](https://getfedora.org/)
[![Shell Script](https://img.shields.io/badge/Shell_Script-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

## 📝 Overview

FOT (Fedora Optimization Tool) is a comprehensive system optimization script designed specifically for Fedora Linux. It provides a collection of optimizations to enhance system performance, security, and user experience.

## ✨ Features

### 🖥️ Kernel Optimizations
- **Process Scheduler**
  - Optimized latency settings
  - Improved process priority handling
  - Enhanced CPU scheduling
  - Reduced wake-up latency
- **I/O Performance**
  - Optimized I/O scheduler per device type
  - Enhanced disk write behavior
  - Improved file system responsiveness
  - Reduced I/O latency
- **Memory Management**
  - Optimized memory allocation
  - Enhanced cache management
  - Improved swap behavior
  - Better memory pressure handling
- **Network Stack**
  - Low-latency network configuration
  - Enhanced TCP/IP performance
  - Optimized packet processing
  - Improved network buffer management

### 🌐 Network Optimizations
- **DNS Configuration**
  - Cloudflare Malware Blocking DNS
  - Fallback DNS servers
  - DNSSEC and DNS over TLS support
- **WiFi Optimization**
  - Dynamic power management
  - WiFi 6 (802.11ax) optimization
  - Automatic signal strength adjustment
  - Maximum performance configuration
  - Periodic optimization service
- **Network Performance**
  - QoS configuration with wondershaper
  - Local DNS cache with dnsmasq
  - MTU optimization for better throughput
  - Network buffer management
  - TCP/IP stack optimization

### 💾 Storage Optimizations
- **SSD Maintenance**
  - Automatic TRIM with fstrim
  - I/O scheduler optimization
  - Write cache management
  - Wear leveling support
- **HDD Optimization**
  - BFQ scheduler configuration
  - Write-back caching
  - Disk queue management
  - I/O priority handling
- **Storage Maintenance**
  - Automatic disk space cleanup
  - Temporary file management
  - Journal cleanup
  - Cache optimization

### 🔊 Audio/Video Optimizations
- **Audio Enhancement**
  - PipeWire configuration
  - Low-latency audio processing
  - Audio buffer optimization
  - Sample rate management
- **Video Performance**
  - Hardware acceleration
  - Video codec optimization
  - Frame buffer management
  - GPU acceleration
- **Quality Management**
  - Automatic quality adjustment
  - Dynamic bitrate control
  - Memory usage optimization
  - Performance monitoring

### 💻 System Performance
- **Kernel Parameter Optimization**
  - Swappiness configuration
  - VFS cache pressure adjustment
  - I/O scheduler optimization
- **Memory Management**
  - ZRAM configuration
  - Preload implementation
  - Dynamic memory allocation
- **CPU Optimization**
  - Scheduler configuration
  - Process priority management
  - Power management settings

### 🛡️ Security Enhancements
- **Antivirus & Anti-malware**
  - ClamAV installation and configuration
  - Automatic virus definition updates
  - Weekly system scans
  - RKHunter rootkit detection
- **System Hardening**
  - Firewall configuration
  - SELinux enforcement
  - Network security parameters
  - System logging optimization

### 🖥️ Desktop Environment
- **GNOME Optimization**
  - Performance tweaks
  - Animation settings
  - Memory usage optimization
  - Wayland improvements
- **Graphics Enhancement**
  - GPU optimization
  - Triple buffering
  - HDR support
  - VSync configuration

### 🌐 Browser Optimization
- **Chrome Configuration**
  - Wayland native support
  - Hardware acceleration
  - Memory management
  - Network performance tweaks

### 📦 Software Management
- **Repository Configuration**
  - RPM Fusion (Free & Non-Free)
  - Flathub integration
  - COPR repositories
  - DNF optimization
- **System Maintenance**
  - Automatic updates
  - Cache management
  - System cleanup
  - Log rotation

## 🚀 Getting Started

### Prerequisites
- Fedora Linux (Latest Version)
- Root access (sudo privileges)
- Internet connection

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/fot.git
   cd fot
   ```

2. Make the script executable:
   ```bash
   chmod +x optimize.sh
   ```

3. Run the script:
   ```bash
   sudo ./optimize.sh
   ```

## 📋 Menu Options

1. Configure DNS (Cloudflare Malware Blocking & Fallback)
2. Add RPM Fusion Repositories
3. Add Flathub Repository
4. Install preload
5. Adjust kernel parameters
6. Configure zram
7. Perform system cleanup
8. Configure antivirus and anti-malware protection
9. Configure GNOME and Wayland optimization
10. Optimize Chrome for Wayland and performance
11. Optimize system performance
12. Optimize system security
13. Optimize software repositories
14. Optimize system maintenance
15. Optimize GNOME
16. Optimize WiFi performance
17. Optimize kernel for responsiveness
18. Optimize network performance
19. Optimize storage performance
20. Optimize audio/video performance
21. Perform complete optimization (recommended)
22. Exit

## ⚠️ Important Notes

- **Backup**: Always create a system backup before running optimizations
- **Root Access**: Script requires root privileges (sudo)
- **System Restart**: Some optimizations require a system restart
- **Compatibility**: Designed for Fedora Linux
- **Recovery**: Backup configurations are created where possible
- **Kernel Optimization**: Some kernel optimizations may affect power consumption

## 🔄 Automatic Optimization Features

- **Kernel Performance**
  - Automatic CPU governor management
  - Dynamic I/O scheduler optimization
  - Adaptive process scheduling
  - Real-time performance tuning

- **Dynamic WiFi Optimization**
  - Automatic signal strength monitoring
  - Power adjustment based on conditions
  - WiFi 6 feature enablement
  - Periodic performance checks

- **Storage Optimization**
  - Automatic TRIM scheduling
  - Dynamic I/O scheduler selection
  - Disk space management
  - Cache optimization

- **Audio/Video Optimization**
  - Dynamic quality adjustment
  - Hardware acceleration management
  - Buffer size optimization
  - Performance monitoring

## 📊 Performance Monitoring

The script includes various optimization services that run in the background:
- WiFi performance monitoring and adjustment
- System resource optimization
- Security scan scheduling
- Maintenance task automation

## 🔧 Customization

Each optimization can be run individually or as part of the complete optimization process. Users can choose specific optimizations based on their needs.

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👤 Author

Hrwoje Dabo

## 🙏 Acknowledgments

- Fedora Community
- Open Source Contributors
- Testing and Feedback Providers

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the issues page.

---

<div align="center">
  <sub>Built with ❤️ by Hrwoje Dabo</sub>
</div> 