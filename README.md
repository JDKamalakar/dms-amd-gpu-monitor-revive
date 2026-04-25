<div align="center">

<a href="https://github.com/JDKamalakar/DMS-AMD_GPU_Monitor_Revive">
    <img src="https://github.com/user-attachments/assets/c94111c7-f60f-48ab-ae07-a7e912a79184" alt="AMD GPU Monitor logo" title="AMD GPU Monitor logo" width="80"/>
</a>

# [DMS-AMD_GPU_Monitor_Revive](#)

### Real-Time GPU Performance
High-performance monitoring suite for AMD GPUs in the Dank Material Shell – track vitals and metrics with precision.

[![DMS Compatible](https://img.shields.io/badge/DMS-Compatible-purple.svg?labelColor=27303D)](https://github.com/Dank-Material-Shell)
[![Driver](https://img.shields.io/badge/Driver-AMDGPU-orange.svg?labelColor=27303D)](https://www.kernel.org/doc/html/latest/gpu/amdgpu.html)
[![Backend](https://img.shields.io/badge/Backend-amdgpu__top-blue.svg?labelColor=27303D)](https://github.com/Umio-Yasuno/amdgpu_top)
[![Maintenance Status](https://img.shields.io/badge/Status-Maintained-green.svg?labelColor=27303D&color=946300)](https://github.com/JDKamalakar/DMS-AMD_GPU_Monitor_Revive/graphs/commit-activity)

## Download

[![DMS Plugin Gallery](https://img.shields.io/badge/DMS-Plugin%20Gallery-06599d?style=flat-square&logo=linux&logoColor=white)](https://danklinux.com/plugins)


*Requires Dank Material Shell (DMS) 1.0 or higher.*

## Features

<div align="left">

* **📊 Comprehensive Monitoring**: Real-time tracking of GFX, Memory, and Media Engine utilization.
* **🌡️ Thermal & Power**: Live edge/junction temperature data and socket power consumption metrics.
* **💾 VRAM Insights**: Detailed capacity visualization and granular allocation statistics.
* **🔍 Per-Process Metrics**: Identify VRAM, GFX, and CPU consumption on a per-application basis.
* **🚨 Smart Indicators**: Visual alerts with configurable Normal/Warning/Critical thresholds.
* **✨ Dynamic Layouts**: Supports Legacy, Alternate, DMS Standard, and DMS Extended modes.

</div>

## Interface

<div align="center">
  <img src="assets/DMS_Extended.png" width="45%" />
  <img src="assets/DMS.png" width="45%" />
</div>

<div align="center">
  <img src="assets/Alternative.png" width="45%" />
  <img src="assets/Legacy.png" width="45%" />
</div>

## Configuration

<div align="center">
  <img src="assets/Settings.png" width="80%" />
</div>

## Installation

<div align="left">

### 1. Prerequisites
Ensure you have the following installed:
* **Driver:** AMDGPU (Standard Linux Kernel driver)
* **Backend:** `amdgpu_top`

```bash
# Arch Linux example
yay -S amdgpu_top
```

### 2. Plugin Installation
* **Recommended:** Use the **DMS Plugin Manager** in settings.
* **Manual:** Clone this repo into your DMS plugins folder:
```bash
git clone https://github.com/JDKamalakar/DMS-AMD_GPU_Monitor_Revive.git
```

</div>

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Before reporting a new issue, take a look at the [opened issues](https://github.com/JDKamalakar/DMS-AMD_GPU_Monitor_Revive/issues).


### Credits

Built with ❤️ for the [Dank Material Shell](https://github.com/DankMaterialShell) community. Uses [amdgpu_top](https://github.com/Umio-Yasuno/amdgpu_top).

<a href="https://github.com/JDKamalakar/DMS-AMD_GPU_Monitor_Revive/graphs/contributors">
    <img src="https://contrib.rocks/image?repo=JDKamalakar/DMS-AMD_GPU_Monitor_Revive" alt="Contributors" title="Contributors" width="100"/>
</a>

### Disclaimer

This application is an independent utility for Dank Material Shell.

### 📜 License

Part of DankMaterialShell. Check the main repository for license information.

</div>
