# DGT Balizas v16 Activas

[Ver Mapa](https://rserranoga.github.io/v16monitor/v16activas.html)
# 🛰️ DGT Balizas v16 Activas en Tiempo Real

[![Update Status](https://img.shields.io/badge/Status-Live-success?style=for-the-badge&logo=google-cloud)](https://rserranoga.github.io/v16monitor/v16activas.html)
[![Refresh Rate](https://img.shields.io/badge/Refresh-2_Minutes-blue?style=for-the-badge)](https://rserranoga.github.io/v16monitor/v16activas.html)

### ⏱️  Última actualización: 2026-01-14 16:00:00

Proyecto para la  visualización de balizas v16 activas conectadas a la plataforma DGT3.0 de la Dirección General de Tráfico en las carreteras de España.

---

## 🏗️ System Architecture
This project operates as an autonomous data pipeline, decoupled from the GitHub repository for maximum performance.


| Component | Technology | Role |
| :--- | :--- | :--- |
| **Ingestion Engine** | R (httr, xml2) | Polls DGT XML feeds and parses IoT coordinates. |
| **Automation** | GCP Compute Engine | E2-micro instance running a 24/7 persistent loop. |
| **Hosting** | GitHub Pages | Serves the processed map to the public. |

## 🛠️ Technical Implementation
* **Reboot Guard:** Managed via `crontab @reboot` to ensure 100% uptime.
* **Smart Sync:** Uses `git pull --rebase -X ours` to prevent merge conflicts.
* **Storage Management:** Automatic 24-hour retention policy for local CSV files.

## 👨‍ Autores
* **Sara Helena Otal Franco** - [sarah.otal@uah.es](mailto:sarah.otal@uah.es)
* **Ramiro Serrano-Garcia** - [@rserranoga][@rserranoga](https://github.com/rserranoga)

---
*Disclaimer: La precisión de la información mostrada depende de la calidad y frecuencia de los datos ofrecidos en su portal por la DGT.*














