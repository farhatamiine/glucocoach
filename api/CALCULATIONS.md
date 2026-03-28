# Clinical Glucose Calculations & Logic

This document explains the mathematical formulas and clinical rationale behind the calculations performed in the `api-cgm` service. These metrics are essential for effective diabetes management and providing actionable insights beyond raw glucose numbers.

---

## 1. Glucose Management Indicator (GMI)
The GMI provides an estimate of what a laboratory A1c (HbA1c) is likely to be, based on the average glucose data from a CGM.

- **Formula:** `3.31 + (0.02392 * average_glucose_mgdL)`
- **Why we need it:** HbA1c tests are typically done every 3 months. GMI allows users to track their progress in real-time between lab visits, helping them understand if their current management is trending toward their target A1c.

## 2. Time in Range (TIR) Metrics
Raw averages can be misleading (e.g., an average of 120 could be stable or a result of extreme highs and lows). TIR metrics provide a more granular view.

- **Time In Range (TIR):** Percentage of readings between **70–180 mg/dL**.
- **Time Above Range (TAR):** Percentage of readings **> 180 mg/dL**.
- **Time Below Range (TBR):** Percentage of readings **< 70 mg/dL**.
- **Why we need it:** Clinical guidelines (like the ATTD consensus) suggest a target of >70% TIR for most people with diabetes. High TBR indicates a risk of dangerous hypoglycemia, while high TAR indicates a risk of long-term complications.

## 3. Glucose Variability (CV & Std Dev)
Variability measures the "swing" or "bounce" in glucose levels.

- **Standard Deviation (SD):** Measures the spread of glucose readings.
- **Coefficient of Variation (CV):** `(Standard Deviation / Mean) * 100`.
- **Threshold:** A CV **≤ 36%** is considered stable.
- **Why we need it:** High variability (high CV) is often linked to a higher risk of hypoglycemia and is more taxing on the body than stable high readings. It helps identify if a patient's insulin or lifestyle is causing "rollercoaster" glucose.

## 4. Dawn Phenomenon Detection
The "Dawn Phenomenon" is a natural rise in blood sugar that occurs in the early morning (usually between 2 AM and 8 AM) due to hormonal changes.

- **Calculation:** `abs(Average_7AM - Average_2AM)`
- **Severity Flags:**
    - `< 15 mg/dL`: None
    - `15–30 mg/dL`: Mild
    - `30–50 mg/dL`: Moderate
    - `> 50 mg/dL`: Severe
- **Why we need it:** Detecting this helps users and doctors decide if overnight basal (long-acting) insulin needs adjustment. If glucose is stable at 2 AM but high at 7 AM, it's likely Dawn Phenomenon.

## 5. Bolus Timing Suggestion
Insulin takes time to work (onset). Eating too soon after a bolus can cause a "spike," while waiting too long can cause a "dip."

- **Base Logic:**
    - `< 90 mg/dL`: 0 mins (Eat immediately)
    - `90–120 mg/dL`: 12 mins
    - `120–150 mg/dL`: 17 mins
    - `150–180 mg/dL`: 22 mins
    - `> 180 mg/dL`: Correction required (Warning)
- **GI Modifier:**
    - Low GI: -3 mins
    - High GI: +5 mins
- **Why we need it:** This helps users synchronize their insulin peak with their food absorption peak, significantly reducing post-meal spikes.

## 6. Ambulatory Glucose Profile (AGP)
The AGP aggregates multiple days of data into a single 24-hour "modal day."

- **Calculation:** Percentiles (5th, 25th, 50th, 75th, 95th) for every hour of the day.
- **Why we need it:** It visualizes trends. If the 75th percentile is consistently above 180 at 2 PM, it indicates a recurring pattern of high glucose after lunch, making it easier to pinpoint specific times of day that need attention.

## 7. Body Mass Index (BMI)
- **Formula:** `Weight (kg) / Height (m^2)`
- **Why we need it:** In the context of diabetes, BMI is often correlated with insulin resistance. It provides baseline health context for the user's metabolic profile.
