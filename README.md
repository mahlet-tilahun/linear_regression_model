# Systolic Blood Pressure Predictor

## Mission & Problem

---

My mission is to apply technology to advance healthcare by building impactful tools that support stronger health systems and improve patient outcomes.
Hypertension affects 1 in 3 adults globally and is the leading preventable cause of heart disease and stroke, making timely intervention and preventive care essential.

This project predicts systolic blood pressure from demographic and clinical indicators, enabling early hypertension screening.

**Dataset**

- **Source**: [National Health and Nutrition Examination Survey](https://www.kaggle.com/datasets/cdc/national-health-and-nutrition-examination-survey) -Kaggle
- **Origin**: Clinical measurements from 9,813 US civilians
- **Files**: demographic.csv + examination.csv merged on participant ID
- **Target**: Systolic Blood Pressure (mmHg) — continuous numeric, regression task

**Live API** : https://linear-regression-model-elhm.onrender.com/
Sawgger UI link: https://linear-regression-model-elhm.onrender.com/docs

**Video Demo**

## How to Run the Flutter App

1. Install Flutter SDK: https://flutter.dev/docs/get-started/install
2. Open a terminal and navigate to the Flutter app folder:
   ```
   cd linear_regression_model/summative/FlutterApp
   ```
3. Install dependencies:
   ```
   flutter pub get
   ```
4. Connect a physical Android or iOS device, or start an emulator
5. Run the app:
   ```
   flutter run
   ```



