# 📖 Project Walkthrough, Learnings & FDE Engineering Log

This document tracks all completed stages, architectural decisions, live verification results, and the **real-world Forward Deployed Engineer (FDE) playbook** for the **Secure-EHR-Insight Clinical Validator** project.

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

---

## 🧬 Stage 2: pgvector AI Schema Upgrade (768 Dimensions)

| Component | Specification / Metric | Status |
| :--- | :--- | :--- |
| **PostgreSQL Extension** | `pgvector` (Installed via Terraform `apt`) | Verified Active |
| **Target Table** | `patient_encounters` | Modified |
| **New Column** | `clinical_embedding` (`vector(768)`) | **Verified Added** |
| **Dimension Size** | `768` (Optimized for HuggingFace BioBERT / ClinicalBERT) | Verified |
| **Migration Script** | `scripts/03_apply_vector_schema.py` | Executed Successfully |

---

## 🤖 Stage 3: Clinical Embeddings Generation & Vectorization

| Component | Specification / Metric | Status |
| :--- | :--- | :--- |
| **Model** | `NeuML/bioclinical-modernbert-base-embeddings` | Loaded & Cached |
| **Embedding Dimension** | 768 float values per record | **100% Verified** |
| **Batch Size & Efficiency** | 128 rows/batch (~26 rows/sec on CPU) | Executed |
| **Feature Engineering** | Super-string composite (Admission + Drug + Lab + Severity + Diagnosis + Notes) | Encoded |
| **Total Rows Vectorized** | **11,008** records | **100% Verified** |
| **Verification Script** | `scripts/05_verify_embeddings.py` | Verified Live in AWS Postgres |

---

## 🛡️ Stage 4: Zero-Trust PII / PHI Redaction (Microsoft Presidio)

| Component | Specification / Metric | Status |
| :--- | :--- | :--- |
| **Security Framework** | HIPAA Safe Harbor Compliance (Zero-Trust Middleware) | Implemented |
| **Analyzer Engine** | `AnalyzerEngine` with Spacy `en_core_web_lg` | Active |
| **Anonymizer Engine** | `AnonymizerEngine` (Masks to `<PERSON>`, `<PHONE_NUMBER>`, etc.) | Active |
| **Custom FDE Fix 1** | Catch-all SSN Pattern Recognizer (`\d{3}-\d{2}-\d{4}`) | Added |
| **Custom FDE Fix 2** | Hospital Deny-List (`Massachusetts General Hospital`, etc.) | Added |
| **Service Location** | `src/pii_redaction/presidio_service.py` | Implemented |

---

## 🌟 What Makes an FDE (Forward Deployed Engineer) Different from a Conventional Software Engineer?

| Dimension | Conventional Software Engineer (SWE) | AI Forward Deployed Engineer (AIFDE) |
| :--- | :--- | :--- |
| **Problem Ownership** | Waits for product managers to write clean Jira tickets. | Sits with the client, understands business/legal risks, and writes the specs. |
| **Data Reality** | Expects clean, sanitized, well-structured CSV/JSON inputs. | Knows real-world enterprise data is messy, incomplete, and full of hidden edge cases. |
| **Compliance & Privacy** | Treats security as a DevOps problem or after-thought. | Designs **Zero-Trust** from Day 1 (HIPAA, PII masking before LLM touches data). |
| **Library Usage** | Blindly trusts libraries (`df.to_sql()`, default Presidio). | Understands mathematical & edge-case flaws in libraries and writes custom guardrails. |
| **Value Delivered** | Writes code features. | Bridges client compliance, cloud infrastructure, AI models, and deployment into a working solution. |

---

## 🧠 Real-World Challenges & Learnings by Stage

### Stage 0: Cloud Infrastructure & Cost Control
* **Challenge:** Leaving cloud instances running accumulates high monthly bills.
* **FDE Solution:** Parameterized Terraform (`terraform.tfvars`) allows 1-command teardown (`terraform destroy` = $0) and 1-command startup (`terraform apply` = 60s).
* **Security Insight:** Never open database port 5432 to `0.0.0.0/0`. Dynamic detection (`data "http" "my_ip"`) locks the firewall strictly to the developer's current IP.

### Stage 1: Data Types in Healthcare (Float vs Integer)
* **Challenge:** Using Pandas `df.to_sql()` auto-mode converts patient IDs with missing values into Floats (`10000032.0`). In hospital systems, float IDs break primary keys and patient record lookups!
* **FDE Solution:** Pre-define strict database constraints in `schema.sql` (`subject_id BIGINT NOT NULL`). Pandas is only a transport pipe, not the architect.

### Stage 2: Embedding Dimensions (Why 768 vs 1536?)
* **Challenge:** OpenAI embeddings (1536 dim) cost money per API call and fail data residency compliance. General models (MiniLM) don't understand clinical drug names (`Furosemide`, `Vancomycin`).
* **FDE Solution:** Open-source `BioClinical ModernBERT` (768 dim) runs locally for free, understands clinical vocabulary, and matches the PostgreSQL `vector(768)` column exactly.

### Stage 3: Feature Engineering the "Super-String"
* **Challenge:** Embedding only the doctor's comments misses the prescribed drug, admission type, and diagnosis.
* **FDE Solution:** Concatenate 6 clinical dimensions into one composite string (`Admission | Prescribed | Lab Test | Severity | Diagnosis | Notes`). One vector captures the patient's entire encounter.

### Stage 4: Zero-Trust PII Redaction & The SSN Checksum Gotcha
* **Challenge 1 (Strict Checksum Bug):** Default Presidio checks if an SSN adheres to official US government issue rules. In synthetic or dummy healthcare test data (`SSN: 234-00-1234`), Presidio considered it an "invalid" SSN and **refused to redact it**, leaking sensitive data!
* **FDE Solution:** Added a custom `PatternRecognizer` with regex `r"\d{3}-\d{2}-\d{4}"` (score 0.9) to redact ANY number matching the SSN pattern, regardless of government checksums.
* **Challenge 2 (Missing Facility Names):** Default NLP models don't know specialized hospital names ("Massachusetts General Hospital").
* **FDE Solution:** Discovered during Exploratory Data Analysis (EDA) and injected via a custom `deny_list` scored at 1.0.

---

## 🛠️ Operational Command Quick Reference

```bash
# Verify Database Records:
python scripts/02_verify_ingestion.py

# Verify Vector Embeddings:
python scripts/05_verify_embeddings.py

# Run Vector Similarity Search:
python scripts/05_test_vector_search.py

# Test PII Redaction Service:
python src/pii_redaction/presidio_service.py
```
