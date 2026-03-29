"""
Systolic Blood Pressure Predictor — FastAPI
"""

import os
import io
import joblib
import numpy as np
import pandas as pd

from fastapi import FastAPI, HTTPException, UploadFile, File, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


# App Setup

app = FastAPI(
    title="Systolic Blood Pressure Predictor",
    description=(
        "Predicts systolic blood pressure (mmHg) from demographic and clinical indicators. "
        "Trained on CDC NHANES 2013-2014 real survey data from 7,172 US civilians. "
        "Use POST /predict to get a prediction and clinical risk category."
    ),
    version="1.0.0",
)


# CORS Middleware

# NOT using wildcard (*) — origins are explicitly listed for security.
# allow_origins: only the app ports and deployed domain.
# allow_methods: only the HTTP methods the app uses.
# allow_headers: only headers the app sends.
# allow_credentials: True, needed for future token-based auth.

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:8080",
        "http://localhost:3000",
        "https://<your-render-url>.onrender.com",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Content-Type", "Authorization", "Accept"],
)


# Load Model Artifacts

BASE_DIR    = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH  = os.path.join(BASE_DIR, "best_model.pkl")
SCALER_PATH = os.path.join(BASE_DIR, "scaler.pkl")
FEAT_PATH   = os.path.join(BASE_DIR, "feature_names.pkl")

try:
    model         = joblib.load(MODEL_PATH)
    scaler        = joblib.load(SCALER_PATH)
    feature_names = joblib.load(FEAT_PATH)
    print(f"Model loaded: {type(model).__name__}")
    print(f"Features: {feature_names}")
except FileNotFoundError as e:
    raise RuntimeError(
        f"Model files not found: {e}. "
        "Run multivariate.ipynb first to generate best_model.pkl, scaler.pkl, feature_names.pkl."
    )


# Input Schema — Pydantic with enforced types and ranges

class BloodPressureInput(BaseModel):
    age: int = Field(
        ..., ge=1, le=80,
        description="Age in years (1–80)",
        example=45
    )
    gender: int = Field(
        ..., ge=1, le=2,
        description="Gender: 1 = Male, 2 = Female",
        example=1
    )
    race: int = Field(
        ..., ge=1, le=7,
        description=(
            "Race/Ethnicity code: 1=Mexican American, 2=Other Hispanic, "
            "3=Non-Hispanic White, 4=Non-Hispanic Black, 6=Non-Hispanic Asian, 7=Other"
        ),
        example=3
    )
    income_poverty_ratio: float = Field(
        ..., ge=0.0, le=5.0,
        description="Income-to-poverty ratio (0.0 = at poverty line, 5.0 = 5x above)",
        example=2.5
    )
    diastolic_bp: float = Field(
        ..., ge=20.0, le=130.0,
        description="Diastolic blood pressure in mmHg (20–130)",
        example=80.0
    )
    pulse_rate: float = Field(
        ..., ge=30.0, le=150.0,
        description="Resting pulse rate in beats per minute (30–150)",
        example=72.0
    )
    bmi: float = Field(
        ..., ge=10.0, le=70.0,
        description="Body Mass Index in kg/m² (10–70)",
        example=26.5
    )
    waist_cm: float = Field(
        ..., ge=40.0, le=200.0,
        description="Waist circumference in centimetres (40–200)",
        example=90.0
    )

    class Config:
        json_schema_extra = {
            "example": {
                "age": 45,
                "gender": 1,
                "race": 3,
                "income_poverty_ratio": 2.5,
                "diastolic_bp": 80.0,
                "pulse_rate": 72.0,
                "bmi": 26.5,
                "waist_cm": 90.0
            }
        }


# Output Schema

class PredictionOutput(BaseModel):
    predicted_systolic_bp: float
    risk_category: str
    model_used: str
    unit: str = "mmHg"


# Helper: Classify BP risk

def classify_bp(systolic: float) -> str:
    if systolic < 120:
        return "Normal (< 120 mmHg)"
    elif systolic < 130:
        return "Elevated (120–129 mmHg)"
    elif systolic < 140:
        return "High Stage 1 (130–139 mmHg)"
    else:
        return "High Stage 2 (≥ 140 mmHg)"


# Helper: Background retraining task

def retrain_model_task(new_data: pd.DataFrame):
    """
    Retrains the model on newly uploaded data and saves updated pkl files.
    Runs in the background so the API stays responsive.
    """
    try:
        X_new = new_data[feature_names]
        y_new = new_data["Systolic_BP"]
        X_scaled = scaler.transform(X_new)
        model.fit(X_scaled, y_new)
        joblib.dump(model,  MODEL_PATH)
        joblib.dump(scaler, SCALER_PATH)
        print(f"Model retrained on {len(new_data)} new rows and saved.")
    except Exception as e:
        print(f"Retraining failed: {e}")


# Routes


@app.get("/", tags=["Health"])
def root():
    """Health check — confirms the API is running."""
    return {
        "status": "running",
        "message": "Systolic Blood Pressure Predictor API",
        "docs": "/docs"
    }

@app.get("/health", tags=["Health"])
def health_check():
    """Returns model type and expected feature list."""
    return {
        "status": "healthy",
        "model_type": type(model).__name__,
        "features": feature_names,
        "n_features": len(feature_names)
    }

@app.post("/predict", response_model=PredictionOutput, tags=["Prediction"])
def predict(data: BloodPressureInput):
    """
    Predict systolic blood pressure from clinical and demographic inputs.

    Returns the predicted value in mmHg and a clinical risk category.
    Raises HTTP 422 automatically if any value is missing or out of range.
    """
    try:
        # Build input in the exact feature order used during training
        input_dict = {
            "Gender":               data.gender,
            "Age":                  data.age,
            "Race":                 data.race,
            "Income_Poverty_Ratio": data.income_poverty_ratio,
            "Diastolic_BP":         data.diastolic_bp,
            "Pulse_Rate":           data.pulse_rate,
            "BMI":                  data.bmi,
            "Waist_cm":             data.waist_cm,
        }
        input_array  = np.array([[input_dict[f] for f in feature_names]])
        input_scaled = scaler.transform(input_array)
        prediction   = round(float(model.predict(input_scaled)[0]), 1)

        return PredictionOutput(
            predicted_systolic_bp=prediction,
            risk_category=classify_bp(prediction),
            model_used=type(model).__name__,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


@app.post("/retrain", tags=["Model Update"])
async def retrain(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...)
):
    """
    Upload a CSV file to trigger model retraining in the background.

    Required CSV columns:
        Gender, Age, Race, Income_Poverty_Ratio,
        Diastolic_BP, Pulse_Rate, BMI, Waist_cm, Systolic_BP

    The API responds immediately and retrains in the background.
    Updated model files are saved automatically when retraining completes.
    """
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only CSV files are accepted.")

    contents = await file.read()
    try:
        new_data = pd.read_csv(io.StringIO(contents.decode("utf-8")))
    except Exception:
        raise HTTPException(status_code=400, detail="Could not parse the CSV file.")

    required_cols = feature_names + ["Systolic_BP"]
    missing_cols  = [c for c in required_cols if c not in new_data.columns]
    if missing_cols:
        raise HTTPException(
            status_code=400,
            detail=f"CSV is missing required columns: {missing_cols}"
        )

    background_tasks.add_task(retrain_model_task, new_data)
    return {
        "status": "accepted",
        "message": f"Retraining started in background on {len(new_data)} new rows.",
        "rows_received": len(new_data)
    }
