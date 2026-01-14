# DGT Balizas v16 Activas
### Last successful update:  Actualizado: 14-January-2026 15:22:33

Este proyecto muestra en tiempo real las balizas v16 activas en España.

Los datos utlizados son públicos, propercionados por la Dirección General de Tráfico.

# 🛰️ DGT Balizas V16 Activas en Tiempo Real

[![Actualizado](https://img.shields.io/badge/Status-Live-success?style=for-the-badge&logo=google-cloud)](https://rserranoga.github.io/v16monitor/v16activas.html)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Frecuencia de Actualización](https://img.shields.io/badge/Refresh-2_Minutes-blue?style=for-the-badge)](https://rserranoga.github.io/v16monitor/v16activas.html)

Este proyecto muestra las balizas v16 activas y conectadas a la plataforma de la Dirección General de Tráfico.

## 🔗 [er el Mapa en Tiempo Real](https://rserranoga.github.io/v16monitor/v16activas.html)

---

## 🏗️ System Architecture

This project operates as an autonomous data pipeline, decoupled from the GitHub repository for maximum performance and security.



| Component | Technology | Role |
| :--- | :--- | :--- |
| **Ingestion Engine** | R (httr, xml2) | Polls DGT XML feeds and parses IoT coordinates. |
| **Automation** | GCP Compute Engine | E2-micro instance running a 24/7 persistent loop. |
| **Processing** | OpenLayers | Generates a standalone, lightweight HTML/JS spatial interface. |
| **CDN / Hosting** | GitHub Pages | Serves the processed map to the public. |

## 🛠️ Technical Implementation

### **Decoupled Execution**
The core logic (`script.R`) and the orchestrator (`runner.R`) are hosted privately on the **Google Cloud VM**. This ensures that:
* Sensitive processing remains off-site.
* The GitHub repository remains clean, serving only the production assets.
* The `.gitignore` configuration prevents local historical CSV data from bloating the web repository.

### **High-Availability Features**
* **Reboot Guard:** A `crontab @reboot` trigger ensures the monitor restarts automatically after VM maintenance.
* **Concurrency Control:** The runner uses `git pull --rebase -X ours` to prevent synchronization conflicts between the VM and GitHub's web interface.
* **Automatic Cleanup:** A built-in retention policy deletes local CSV files older than 24 hours to manage VM storage.

## 📊Fuente de Datos
Los datos son se ofrecen en el portal de datos de la  **DGT (Dirección General de Tráfico)**.
---

## 👨‍💻 ores
**Sara Helena Otal Franco** - [sarah.otal@uah.es](mailto:sarah.otal@uah.es)
**Ramiro Serrano-Garcia** - GitHub: [@rserranoga](https://github.com/rserranoga)

---
*Disclaimer: Este proyecto se ha desarrollado para investigación y visualización. La exactitud de la información presentada depende del proveedor de los datos (la DGT).
