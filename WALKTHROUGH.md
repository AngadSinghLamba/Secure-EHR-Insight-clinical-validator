# 📖 Project Walkthrough & Verification Log

This document tracks all completed stages, architectural decisions, live verification results, and the **real-world debugging playbook** for the **Secure-EHR-Insight Clinical Validator** project.

---

## 🏛️ Stage 0: Cloud Infrastructure & Database (AWS)

| Component | Specification | Status |
| :--- | :--- | :--- |
| **Cloud Provider** | AWS (Region: `ap-south-1` / Mumbai) | Verified |
| **Instance Type** | `c7i-flex.large` (2 vCPU, 4 GiB RAM, 4th Gen Intel Xeon) | Verified |
| **Instance Tag Name** | `test-FDE-Database` | Verified |
| **Storage Volume** | 20 GiB gp3 EBS SSD | Verified |
| **Static Elastic IP** | `13.206.4.210` | Verified & Associated |
| **Security Group** | `ABCD` ("This is a test secutity group") | Verified |
| **Firewall Ingress** | Ports 22 (SSH) & 5432 (Postgres) locked to caller IP `49.36.136.233/32` | Verified |
| **Key Pair** | `test-FDE-Database` (RSA 4096-bit `.pem` key) | Verified |
| **Database Engine** | PostgreSQL 14 with `pgvector` AI extension | Verified |
| **Database & User** | Database: `ehr_db`, User: `fde_admin` | Verified |
| **Environment File** | Auto-generated `.env` in project root | Verified |

---

## 📊 Stage 1: EHR Baseline Data Ingestion

| Component | Specification / Metric | Status |
| :--- | :--- | :--- |
| **Dataset Source** | `data/MIMIC_IV_Trasncript.csv` (73.5 MB) | Loaded |
| **Database Schema** | `src/database/schema.sql` (`patient_encounters` table) | Created |
| **Ingestion Pipeline** | `scripts/01_ingest_baseline_data.py` | Executed |
| **Total Rows Ingested** | **232,158** records | **100% Verified** |

### Live Database Verification Query
```sql
SELECT count(*) FROM patient_encounters;
-- Verified Count: 232,158 records
```

---

## 🧬 Stage 2: pgvector AI Schema Upgrade (768 Dimensions)

| Component | Specification / Metric | Status |
| :--- | :--- | :--- |
| **PostgreSQL Extension** | `pgvector` (Installed via Terraform `apt`) | Verified Active |
| **Target Table** | `patient_encounters` | Modified |
| **New Column** | `clinical_embedding` (`vector(768)`) | **Verified Added** |
| **Dimension Size** | `768` (Optimized for HuggingFace BioBERT / ClinicalBERT) | Verified |
| **Migration Script** | `scripts/03_apply_vector_schema.py` | Executed Successfully |

### Live Schema Confirmation:
```text
✅ Schema upgrade complete. Confirmed column: clinical_embedding (USER-DEFINED / vector)
```

---

## 🧠 Debugging Playbook & Key Learnings (Bookmark for Future Projects!)

### 1. The "Ghost in the Shell" Alias Trap
* **Symptom:** `ModuleNotFoundError: No module named 'sqlalchemy'` — even though packages were installed and `(.venv)` was visible in the prompt!
* **Root Cause:** Mac's `~/.zshrc` had an alias: `alias python=python3.14`. In Unix shells, **aliases have higher priority than virtual environments**. Typing `python` bypassed `.venv` and executed the global Mac Python!
* **How to Diagnose:**
  ```bash
  which python
  # If output shows: "python: aliased to python3.14" -> That is the trap!
  ```
* **Permanent Fix:**
  - Option A: Run `unalias python` in the terminal session.
  - Option B: Run via `uv run python script.py` (bypasses aliases automatically).
  - Option C: Explicitly call `.venv/bin/python script.py`.

---

### 2. PostgreSQL Driver Mismatch (`psycopg2` vs `psycopg 3`)
* **Symptom:** `ModuleNotFoundError: No module named 'psycopg2'`.
* **Root Cause:** SQLAlchemy URLs starting with `postgresql://` default to the older `psycopg2` driver. Modern environments that install `psycopg==3.x` don't have `psycopg2` unless explicitly installed.
* **Fix Options:**
  - Fast fix: `uv pip install psycopg2-binary` (0 code changes).
  - Modern fix: Change URL prefix in code to `postgresql+psycopg://` to use Psycopg 3.

---

### 3. Mac Local Terminal vs Remote EC2 Server Confusion
* **Symptom:** Running `cd terraform` inside the EC2 server gave: `-bash: cd: terraform: No such file or directory`.
* **Learning:**
  - **Mac Terminal (`%`)**: Holds Terraform code, `.env`, datasets, and Python app.
  - **Remote Server (`ubuntu@ip:~$`)**: The virtual machine created in the cloud. It runs Postgres and does NOT have the terraform code.
  - Always run `exit` to return to your Mac before executing Terraform commands!

---

### 4. Ghostty Terminal Warning on Ubuntu
* **Symptom:** `'xterm-ghostty': unknown terminal type` and `clear` command failure on remote server.
* **Fix:**
  ```bash
  export TERM=xterm-256color
  ```

---

### 5. Why `schema.sql` vs Pandas Auto `df.to_sql()`
* **The Danger of Pandas Auto Ingestion:**
  1. A single empty/missing value in an integer column forces Pandas to convert patient IDs to **Float** (`10000032.0`). This causes search failures and floating-point comparison bugs in healthcare systems.
  2. Pandas creates NO Primary Keys, Foreign Keys, or Unique constraints — leading to duplicate data on re-runs.
  3. Pandas knows nothing about `pgvector` (`vector(384)`), treating AI embeddings as plain text strings.
* **Rule:** Always enforce table structure via `schema.sql` first; use Pandas only as the transport mechanism!

---

### 6. Security Group "My IP" Locking
* **Best Practice:** Never open database ports (`5432`) or SSH (`22`) to `0.0.0.0/0`.
* **Terraform Automation:** Use `data "http" "my_ip"` to dynamically fetch your public IP (`49.36.136.233/32`) and lock the firewall to only your laptop.

---

## 🛠️ Operational Quick Reference

```bash
# 1. SSH into the server:
ssh -i ~/.ssh/test-FDE-Database.pem ubuntu@13.206.4.210

# 2. Check total database records:
python -c "
import os, sqlalchemy; from dotenv import load_dotenv; load_dotenv()
engine = sqlalchemy.create_engine(f'postgresql://{os.getenv(\"DB_USER\")}:{os.getenv(\"DB_PASSWORD\")}@{os.getenv(\"DB_HOST\")}:{os.getenv(\"DB_PORT\")}/{os.getenv(\"DB_NAME\")}')
with engine.connect() as conn:
    print('Total Rows:', conn.execute(sqlalchemy.text('SELECT count(*) FROM patient_encounters')).scalar())
"

# 3. Teardown when done ($0 AWS cost):
cd terraform && terraform destroy -auto-approve
```
