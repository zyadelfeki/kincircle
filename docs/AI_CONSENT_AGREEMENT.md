# KinCircle Smart Alerts – User Consent Agreement

By tapping **"I Agree – Enable Smart Alerts"** you acknowledge and accept the following:

1. **Purpose of Data Processing**  
   KinCircle will analyse up to 30 days of your location history to learn typical daily routines (e.g.
   school hours, commute times) so that it can notify you only when something appears unusual.

2. **Data Collected**  
   • GPS coordinates & timestamps  
   • Basic device context (battery level, screen state)  
   • Anonymised identifiers (user ID, family ID)

3. **How the Data Is Used**  
   • Train and continuously improve an anomaly-detection model hosted on Google Vertex AI.  
   • Generate real-time "Anomaly Alerts" in the KinCircle app.  
   • Produce aggregate insights to refine model accuracy.

4. **Storage & Retention**  
   • Raw location events are stored in Google Cloud Firestore, copied to BigQuery, and rotated after 30 days.  
   • Derived ML features may be retained longer in de-identified form for model evaluation.

5. **Your Controls**  
   • You may disable Smart Alerts at any time in **Settings → Smart Alerts**.  
   • You can request deletion of your location history via **Settings → Privacy**.

6. **Risks & Benefits**  
   • _Benefit:_ Fewer, more meaningful notifications; increased family peace-of-mind.  
   • _Risk:_ As with any ML system, false positives or negatives may occur. Smart Alerts are a helpful signal—not a guarantee of safety.

7. **Withdrawal of Consent**  
   You may withdraw consent at any time. Doing so will disable Smart Alerts and delete any routine-learning datasets associated with your account within 30 days.

If you have questions, contact **privacy@kincircle.app** before agreeing.

---

**□ I have read and understand the above.**

**[I Agree – Enable Smart Alerts]** 