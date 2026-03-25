# recone 🎯

**recone** is an automated PowerShell-based suite designed for high-performance reconnaissance and vulnerability scanning. It streamlines asset discovery and security auditing by orchestrating industry-standard tools into a single, seamless workflow.

## ✨ Key Features
* **Zero-Setup Installer:** Automatically detects and downloads missing binary tools from official sources.
* **Auto-Update Engine:** Checks GitHub for the latest version of the script on every launch.
* **Smart Probing:** Efficiently filters alive hosts and identifies technologies and page titles.
* **Deep Asset Discovery:** Utilizes recursive crawling to extract hidden endpoints and parameters.
* **Modular Scanning:** Executes targeted Nuclei audits with customizable rate limits and severity filters.
* **Organized Reporting:** Automatically categorizes findings into severity-based directories.

## 📋 Prerequisites

recone handles the heavy lifting for you. While the following tools are required, the script will automatically download and install the latest versions if they are not found in the directory:

| Binary | Role |
| :--- | :--- |
| **Subfinder** | Subdomain Discovery |
| **Naabu** | Fast Port Probing |
| **Httpx** | Service & Tech Fingerprinting |
| **Katana** | Advanced Web Crawling |
| **Nuclei** | Vulnerability Scanning |

> **Maintenance Mode:** Use the built-in maintenance prompt during startup to keep your binaries and Nuclei templates updated.

## 🚀 Getting Started

1. **Clone the Repository:**
   ```powershell
   git clone [https://github.com/BERKVY/recone.git](https://github.com/BERKVY/recone.git)
   cd recone
   ```
2. **Run the Script:**
   ```powershell
   .\recone.ps1
   ```
   *Note: On first run, the script will offer to download any missing .exe tools for you.*

## 🛠 Workflow Logic
1. **Tool Check:** Verifies presence of required binaries; initiates auto-install if missing.
2. **Self-Update:** Syncs with the GitHub repository for script updates.
3. **Discovery:** Performs subdomain enumeration and active port discovery.
4. **Analysis:** Fingerprints services and crawls for active endpoints.
5. **Audit:** Runs vulnerability scans based on user-selected severity levels.
6. **Reporting:** Saves sorted results into target-specific folders.

## ⚠️ Ethical Use & Disclaimer
recone is intended for **legal and ethical security testing only**. Using this tool against targets without prior written consent is illegal. The developer (**BERKVY**) assumes no liability for any misuse or damage caused by this program.

---
Developed by [BERKVY](https://github.com/BERKVY)
