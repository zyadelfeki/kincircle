# KinCircle – Post-Launch Analytics Plan

To understand early usage patterns and quickly identify friction points, we will instrument the **five custom Firebase Analytics events** below.  Each definition lists the `event_name` followed by the **key parameters** we will log.

> All events automatically include the Firebase defaults (\_userId, \_sessionId, device info, etc.).  The parameters below are *additions* that make the events actionable for product and growth analysis.

---

### 1. `family_created`
* **family_id** – Firestore document ID of the newly created family (string)
* **creator_role** – Role of the user who created the family (e.g. `parent`, `guardian`) (string)
* **initial_member_count** – Number of members added at creation time (int)
* **plan_tier** – `free` or `premium` at the moment of creation (string)

Why it matters: Measures funnel completion for onboarding and helps correlate family size with retention.

---

### 2. `invite_sent`
* **invite_id** – Firestore document ID for the invite (string)
* **channel** – `sms`, `email`, `link_share`, etc. (string)
* **recipient_relationship** – `parent`, `caregiver`, `child` (string)
* **family_id** – ID of the family the invite belongs to (string)

Why it matters: Reveals which channels and relationships drive the most successful invitations.

---

### 3. `invite_accepted`
* **invite_id** – Same ID used in `invite_sent` (string)
* **time_to_accept_sec** – Seconds between invite creation and acceptance (int)
* **new_member_role** – Role chosen by the joining user (`parent`, `child`, etc.) (string)
* **family_id** – Associated family ID (string)

Why it matters: Tracks conversion efficiency and informs improvements to onboarding flows.

---

### 4. `geofence_created`
* **geofence_id** – Firestore document ID (string)
* **place_label** – Human-friendly label supplied by the user (string)
* **radius_m** – Radius of the geofence in meters (int)
* **category** – `home`, `school`, `custom`, etc. (string)

Why it matters: Indicates engagement with core safety features and helps prioritize geofence UX enhancements.

---

### 5. `premium_subscription_started`
* **plan_type** – `monthly` or `annual` (string)
* **origin** – Where the purchase was initiated (`settings`, `paywall`, `referral_reward`, etc.) (string)
* **intro_discount** – `true` if an introductory offer was applied (bool)
* **price_usd** – Gross price paid in USD at the time of purchase (float)

Why it matters: Provides a clean signal for revenue attribution and A/B testing of pricing or paywall copy.

---

**Next Steps**
1. Add these events to the Flutter app using `firebase_analytics`.
2. Set up BigQuery export to join event data with backend metrics.
3. Create Looker Studio dashboards for real-time monitoring of each funnel. 