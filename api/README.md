# api-cgm

`api-cgm` is a professional FastAPI-based backend service designed to process and analyze Continuous Glucose Monitor (CGM) data. It integrates with **Nightscout** to fetch raw glucose entries and provides advanced clinical insights, including glucose variability, Time-in-Range (TIR) metrics, and bolus timing recommendations.

---

## 🚀 Key Features

- **Nightscout Integration:** Securely fetches historical and real-time CGM data via API.
- **Advanced Clinical Reports:**
  - **GMI Calculation:** Real-time estimation of laboratory A1c.
  - **Ambulatory Glucose Profile (AGP):** Visualizes 24-hour glucose patterns using percentiles.
  - **Dawn Phenomenon Detection:** Identifies early morning hormonal surges.
  - **Glucose Variability Analysis:** Computes Standard Deviation and Coefficient of Variation (CV).
- **Smart Bolus Timing:** Provides insulin-to-meal interval suggestions based on current glucose and glycemic index (GI) modifiers.
- **Robust Schema Validation:** Powered by Pydantic for high-performance data parsing and safety.

---

## 🛠 Tech Stack

- **Framework:** [FastAPI](https://fastapi.tiangolo.com)
- **Data Processing:** [Pandas](https://pandas.pydata.org) & [NumPy](https://numpy.org)
- **Validation:** [Pydantic v2](https://docs.pydantic.dev)
- **Settings Management:** [Pydantic Settings](https://docs.pydantic.dev/latest/usage/pydantic_settings/)
- **Package Manager:** [uv](https://github.com/astral-sh/uv)

---

## ⚙️ Configuration & Setup

### 1. Prerequisites
Ensure you have [uv](https://github.com/astral-sh/uv) installed.

### 2. Environment Variables
Create a `.env` file from the provided example:
```bash
cp .env.example .env
```
Configure the following keys:
- `NIGHTSCOUT_URL`: Your Nightscout instance URL (e.g., `https://your-site.herokuapp.com`).
- `NIGHTSCOUT_SECRET`: Your hashed Nightscout API secret.
- `APP_VERSION`: Current version of the API.

### 3. Installation
Install dependencies and set up the virtual environment:
```bash
uv sync
```

### 4. Running the Application
Start the development server with hot-reload:
```bash
uv run fastapi dev
```
The API will be available at `http://localhost:8000`. You can access the interactive Swagger documentation at `http://localhost:8000/docs`.

---

## 📊 Clinical Calculations & Logic

This service implements standard clinical formulas for diabetes management.

| Metric | Purpose | Threshold/Target |
| :--- | :--- | :--- |
| **GMI** | Estimated A1c | Based on 14+ days of data |
| **TIR** | Time In Range (70-180 mg/dL) | Target: > 70% |
| **CV** | Glucose Variability | Target: ≤ 36% (Stable) |
| **Dawn Phenom.** | Morning Glucose Rise | Delta between 2 AM and 7 AM |

For a deep dive into the mathematical formulas and clinical rationale, please refer to **[CALCULATIONS.md](./CALCULATIONS.md)**.

---

## 📁 Project Structure

```text
api-cgm/
├── core/         # Configuration, dependencies, and logging
├── models/       # Database and data representation models
├── routers/      # API endpoints (glucose, bolus, health)
├── schemas/      # Pydantic models for request/response validation
├── services/     # Core business logic and Nightscout interaction
├── utils/        # Shared helper functions
└── main.py       # Application entry point
```

---

## 📄 License
This project is private and intended for personal diabetes management analysis.
