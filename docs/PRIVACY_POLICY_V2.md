# KinCircle Privacy Policy (v2)
_Last updated: 2025-08-15_

KinCircle is committed to protecting your family's privacy. This policy explains **what data we collect**, **why we collect it**, and **how you can control it**. Version 2 adds new disclosures related to our AI-powered _Smart Alerts_ features.

---

## 1. Information We Collect

| Data Category | Examples | Purpose |
|---------------|----------|---------|
| Account Info  | Name, email, profile photo | Create & manage your KinCircle account |
| Location Data | GPS coordinates, device sensors | Show family on the map; power Smart Alerts |
| Diagnostic Data | Crash reports, performance logs | Improve stability & performance |
| Consent Records | Date/time of AI opt-in | Demonstrate your consent to optional AI features |

### 1.1 Location History for Machine Learning
When you **opt-in** to Smart Alerts, KinCircle stores **30 days** of location events in Google Cloud Firestore / BigQuery. These records are **pseudonymised** (referenced by your app User ID, not your real name).

---

## 2. How We Use Your Information

1. **Provide Core Features** – Real-time family location sharing, invitations, geofences.
2. **Smart Alerts (Machine Learning)** – Detect unusual activity based on learned routines. See Section 4.
3. **Product Improvement** – Aggregate, anonymised analytics to understand feature usage.
4. **Safety & Compliance** – Detect fraud, enforce our Terms of Service, and comply with legal requests.

We **never** sell your personal data or location history to advertisers.

---

## 3. Legal Basis
We process your data under the following legal bases (GDPR):
* **Consent** – For Smart Alerts and marketing communications.
* **Legitimate Interests** – To maintain secure, reliable service.
* **Contract** – To provide the services you requested.

You may withdraw consent at any time from _Settings → Privacy_.

---

## 4. Smart Alerts & Machine Learning

1. **Opt-In Required** – Smart Alerts are **disabled by default**. You must view the AI Consent screen and tap **"I Agree & Opt-In."**
2. **Data Minimisation** – Only the last 30 days of location events are used for training.
3. **On-Device / Cloud Processing** – A Vertex AI model hosted in Google Cloud returns an *anomaly score*. Raw data is not shared outside our Google Cloud project.
4. **Anonymisation** – Models are trained on user IDs, not real names or emails.
5. **Tunable Sensitivity** – You (or an admin) can adjust the _anomaly threshold_ to balance sensitivity vs. noise.
6. **Right to Opt-Out & Delete** – Turning off Smart Alerts stops new data collection and schedules deletion of historical ML data within 30 days.

---

## 5. Data Retention
| Data Type | Retention Period |
|-----------|-----------------|
| Location events (non-AI users) | 3 days |
| Location events (Smart Alerts users) | 30 days |
| Crash & diagnostic logs | 90 days |
| Account data | Until you delete your account |

---

## 6. Your Rights
Depending on your jurisdiction, you may have rights to access, correct, delete or port your personal data. Request these via **privacy@kincircle.app**.

---

## 7. Security Measures
We use industry-standard encryption (TLS 1.3 in transit, AES-256 at rest) and least-privilege IAM. Access to ML datasets is restricted to authorised engineers.

---

## 8. Changes to This Policy
We will notify you of material changes via in-app message or email at least 7 days before they take effect.

---

## 9. Contact Us
Questions? Email **privacy@kincircle.app** or write to **KinCircle, Inc., 123 Family Way, San Francisco, CA 94105, USA**. 