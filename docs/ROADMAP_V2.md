# KinCircle – Version 2 Roadmap

With MVP adoption underway, Version 2 focuses on deepening value through advanced, safety-centric AI. The goal is to transition KinCircle from "location-sharing app" to indispensable **family safety companion**.

| Feature | Overview | Core User Benefit | Key Technical Components |
|---------|----------|-------------------|--------------------------|
| **1. AI Driver Safety Monitoring** | Continuously analyzes sensor & telematics data (speed, acceleration, gyroscope, screen-on state) to detect risky driving behaviors, then delivers weekly "Driver Safety Score" plus coaching tips. | Parents (and teen drivers) gain objective insights and actionable feedback that encourages safer habits, reducing anxiety and potential accidents. | • On-device sensor fusion module (Dart + platform channels)  
• Edge ML model for event detection (harsh braking, rapid acceleration, phone usage)  
• Cloud aggregation pipeline to compute scores & trends  
• Cloud Functions to trigger notifications & store `driver_scores` collection  
• Dashboard widgets & shareable scorecards  
• Remote Config toggles & consent gating |
| **2. Generative AI Family Summaries** | Uses LLM (e.g., Gemini 1.5 via Vertex AI) to turn raw activity logs (locations, alerts, messages) into a concise, friendly narrative of the family's day, delivered each evening. | Saves parents time: Instead of scrolling through feeds, they get an at-a-glance story ("Everyone got home by 5 pm; Noah left the safe zone once to visit Sam's house"). Builds emotional connection & daily engagement. | • Data mart in Firestore/BigQuery with day-level activity aggregates  
• Server-side LLM invocation (Vertex AI or Firebase Extensions) with system/persona prompt  
• Privacy layer: Pseudonymize & filter PII before model input  
• Cached summary stored in `daily_summaries` collection & sent via push / email  
• In-app "Ask KinCircle" chat view for follow-up questions  
• Cost controls via token limits & concurrency quotas |

---

## Milestones & Timeline (Quarter-level)

1. **Q1 – Research & Prototyping**  
   • Collect driving sensor sample data.  
   • Train and benchmark detection model (TFLite micro model).  
   • Pilot Gemini summarization on anonymized logs.

2. **Q2 – Alpha Releases**  
   • Release opt-in Driver Safety beta to 100 test families.  
   • Ship "Daily Digest" email version of AI summaries.

3. **Q3 – GA Launch**  
   • Full rollout with in-app score dashboard & coaching tips.  
   • Launch interactive "Family Summary" screen & voice readout.

4. **Q4 – Iteration & Partnerships**  
   • Integrate insurance discount APIs (e.g., Nationwide SmartRide) for high scores.  
   • Expand summaries to weekly/monthly wellness reports.

> Success will be measured by reduction in risky driving events (-15 %) and increased daily active usage (+25 %) compared with MVP baseline. 