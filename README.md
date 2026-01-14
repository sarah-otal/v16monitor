# DGT Balizas v16 Monitor
### Last successful update:  Actualizado: 14-January-2026 15:22:33

# DGT Balizas v16 Activas (en tiempo real)
Este proyecto muestra en tiempo real las balizas v16 activas en España.

Los datos utlizados son públicos, propoercionados por la Dirección General de Tráfico.

## 🚀Visualizar el  Mapa en tiempo real
**[https://rserranoga.github.io/v16monitor/v16activas.html](https://rserranoga.github.io/v16monitor/v16activas.html)**

## 🛠 System Architecture
- **Engine:** R Script running on Google Cloud Platform (e2-micro).
- **Update Frequency:** Every 2 minutes.
- **Data Source:** DGT (Dirección General de Tráfico) Open Data.
- **Automation:** Persistent R loop inside a `screen` session.

---
*Note: The `data/` folder and scripts are hosted privately on the VM to keep this repository clean.
