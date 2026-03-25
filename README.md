# Recone 🎯

**Recone** is a comprehensive, automated PowerShell suite designed to be the "one" tool you need for the initial stages of a security audit. It combines the power of ProjectDiscovery's best tools into a single, high-performance pipeline.

## ✨ Key Features
* **Recon + One:** A unified workflow that handles everything from discovery to vulnerability reporting.
* **Auto-Update Engine:** Stays current by checking the latest version from GitHub on every launch.
* **Smart Probing:** Efficiently filters alive hosts and identifies technologies/titles.
* **Deep Asset Discovery:** Uses recursive crawling to find hidden endpoints and parameters.
* **Modular Scanning:** Runs targeted Nuclei audits with customizable rate limits and severity levels.
* **Automated Reporting:** Clean, organized output categorized by severity (Critical to Info).

## 📋 Pre-requirements

Recone acts as an orchestrator. To function correctly, ensure the following binary tools are in the **same directory** as the script:

| Binary | Role |
| :--- | :--- |
| **Subfinder** | Subdomain Enumeration |
| **Naabu** | Fast Port Scanning |
| **Httpx** | Service & Tech Fingerprinting |
| **Katana** | Next-gen Web Crawling |
| **Nuclei** | Template-based Vulnerability Scanning |

> **Pro Tip:** Use the built-in **Maintenance Mode** during startup to automatically update these binaries and your Nuclei templates.

## 🚀 Getting Started

1.  **Clone the Repository:**
    ```bash
    git clone [https://github.com/BERKVY/Recone.git](https://github.com/BERKVY/Recone.git)
    cd Recone
    ```
2.  **Add Binaries:** Copy your `subfinder.exe`, `naabu.exe`, etc., into the root folder.
3.  **Run Recone:**
    ```powershell
    .\recone.ps1
    ```

## 🛠 Workflow Logic
1.  **Integrity Check:** Verifies all required `.exe` files are present.
2.  **Self-Update:** Checks GitHub for a newer version of the `recone.ps1` script.
3.  **Discovery Phase:** Runs subdomain scans and port discovery.
4.  **Analysis Phase:** Fingerprints active services and crawls for endpoints.
5.  **Audit Phase:** Executes vulnerability scans via Nuclei.
6.  **Data Categorization:** Results are saved and sorted into target-specific folders.

## ⚠️ Ethical Use & Disclaimer
Recone was developed for **legal security testing and educational purposes only**. Using this tool against targets without prior written consent is illegal. The developer (**BERKVY**) assumes no liability for any misuse or damage caused by this program.

---
Crafted with 🛡️ by [BERKVY](https://github.com/BERKVY)
