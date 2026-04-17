# <img width="32" height="28" alt="image" src="https://github.com/user-attachments/assets/c94111c7-f60f-48ab-ae07-a7e912a79184" /> AMD GPU Monitor

[![DMS Version](https://img.shields.io/badge/DMS-Compatible-purple.svg)](https://github.com/Dank-Material-Shell)
[![Driver](https://img.shields.io/badge/Driver-AMDGPU-orange.svg)](https://www.kernel.org/doc/html/latest/gpu/amdgpu.html)
[![Backend](https://img.shields.io/badge/Backend-amdgpu__top-blue.svg)](https://github.com/Umio-Yasuno/amdgpu_top)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/JDKamalakar/DMS-AMD_GPU_Monitor_Revive/graphs/commit-activity)

A high-performance real-time monitoring suite for AMD GPUs, specifically engineered for the **Dank Material Shell** (DMS) environment. Track utilization, VRAM, thermals, and per-process metrics with native material styling.

> [!TIP]
> This plugin supports multiple display modes including **Legacy**, **Alternate**, **DMS Standard**, and **DMS Extended** to fit any desktop workflow.

---

## ✨ Features

* **📊 Comprehensive Monitoring:** Real-time GFX, Memory, and Media Engine usage.
* **🌡️ Thermal & Power:** Live tracking of edge/junction temperatures and socket power draw.
* **💾 VRAM Insights:** Detailed capacity display and allocation statistics.
* **🔍 Per-Process Metrics:** Identify which applications are consuming VRAM, GFX, and CPU cycles.
* **🚨 Smart Indicators:** Color-coded warnings (Normal/Warning/Critical) based on configurable thresholds.

---

## 📸 Interface Variations

The monitor adapts to your preferred layout with four distinct UI implementations:

| UI Mode | Description | Status |
| :--- | :--- | :--- |
| **DMS Extended** | Maximum data density with full process lists and charts. | <img width="756" height="836" alt="DMS_Extended" src="assets/DMS_Extended.png" /> |
| **DMS Standard** | The native material look—balanced and clean. | <img width="440" height="700" alt="DMS" src="assets/DMS.png" /> |
| **Alternate** | A modern, high-contrast take on the monitoring panel. | <img width="430" height="780" alt="Alternative" src="assets/Alternative.png" /> |
| **Legacy** | Same UI As OG dms-amg-gpu-monitor. | <img width="428" height="647" alt="Legacy" src="assets/Legacy.png" /> |

---
### ⚙️ Configuration
| Settings UI |
| :--- |
| <img width="310" height="620" alt="Settings" src="assets/Settings.png" /> |

---

## 🛠️ Installation

### 📋 1. Prerequisites
Ensure you have the following installed on your system before proceeding:
* **Driver:** AMDGPU (Standard Linux Kernel driver)
* **Shell:** QuickShell & DankMaterialShell
* **Backend:** `amdgpu_top`

```bash
# Install backend (Arch Linux example)
yay -S amdgpu_top
```

### 🚀 2. Plugin Installation

#### 🚀 Recommended: DMS Plugin Manager
The easiest way to install and stay updated:
1. Open your **DMS Settings**.
2. Navigate to the **Plugin Manager** tab.
3. Search for `DMS-AMD_GPU_Monitor_Revive` and click **Install**.
4. Alternatively, browse the [Dank Linux Plugin Gallery](https://danklinux.com/plugins#/).

#### 🛠️ Manual Installation
For developers or users who want the latest edge builds:
1. Clone this repository into your DMS extensions/plugins folder:
   ```bash
   git clone [https://github.com/JDKamalakar/DMS-AMD_GPU_Monitor_Revive.git](https://github.com/JDKamalakar/DMS-AMD_GPU_Monitor_Revive.git)

---

### 🐛 Feedback & Contributions

Found a bug or have a feature request? Let’s make this better together.

* **Report Issues:** [GitHub Issues](https://github.com/JDKamalakar/DMS-AMD_GPU_Monitor_Revive/issues/new/choose)
* **Contributions:** Pull requests are welcome! Please ensure your code follows the shell's design guidelines.

---

## 📜 License

Part of DankMaterialShell. Check the main repository for license information.

## 🤝 Credits

Built for [DankMaterialShell](https://github.com/DankMaterialShell) • Uses [amdgpu_top](https://github.com/Umio-Yasuno/amdgpu_top)
