import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const BPPredictorApp());
}

class BPPredictorApp extends StatelessWidget {
  const BPPredictorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BP Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      home: const PredictionPage(),
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  static const String _apiUrl =
      'https://linear-regression-model-elhm.onrender.com/predict';

  // One controller per text input field
  final _ageCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _raceCtrl = TextEditingController();
  final _diasCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _bmiCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();

  // Values map to CDC income-to-poverty ratio numeric values used by the model
  double _incomePovertyRatio = 2.5; // default: Middle income

  final _formKey = GlobalKey<FormState>();
  String _result = '';
  Color _resultColor = Colors.black87;
  bool _isLoading = false;

  // API call
  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _result = '';
    });

    final body = jsonEncode({
      "age": int.parse(_ageCtrl.text.trim()),
      "gender": int.parse(_genderCtrl.text.trim()),
      "race": int.parse(_raceCtrl.text.trim()),
      "income_poverty_ratio": _incomePovertyRatio,
      "diastolic_bp": double.parse(_diasCtrl.text.trim()),
      "pulse_rate": double.parse(_pulseCtrl.text.trim()),
      "bmi": double.parse(_bmiCtrl.text.trim()),
      "waist_cm": double.parse(_waistCtrl.text.trim()),
    });

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bp = data['predicted_systolic_bp'];
        final risk = data['risk_category'] as String;

        Color c = Colors.green.shade700;
        if (risk.contains('Elevated')) c = Colors.orange.shade700;
        if (risk.contains('Stage 1')) c = Colors.deepOrange.shade700;
        if (risk.contains('Stage 2')) c = Colors.red.shade700;

        setState(() {
          _result = '🩺 Predicted Systolic BP: $bp mmHg\n📊 Risk: $risk';
          _resultColor = c;
        });
      } else {
        final err = jsonDecode(response.body);
        setState(() {
          _result = '⚠️ Error ${response.statusCode}: ${err["detail"]}';
          _resultColor = Colors.red.shade700;
        });
      }
    } catch (e) {
      setState(() {
        _result = '❌ Network error: $e';
        _resultColor = Colors.red.shade700;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Reusable text field builder
  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: false),
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: validator,
      ),
    );
  }

  String? _notEmpty(String? v, String name) {
    if (v == null || v.trim().isEmpty) return '$name is required';
    if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
    return null;
  }

  @override
  void dispose() {
    for (final c in [
      _ageCtrl,
      _genderCtrl,
      _raceCtrl,
      _diasCtrl,
      _pulseCtrl,
      _bmiCtrl,
      _waistCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Blood Pressure Predictor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: const Color(0xFFE3F2FD),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Enter your clinical details to predict systolic blood '
                      'pressure using an AI model trained on CDC NHANES data.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF0D47A1)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Demographics',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),

                _field(
                  ctrl: _ageCtrl,
                  label: 'Age (years)',
                  hint: 'e.g. 45  [1–80]',
                  validator: (v) {
                    final e = _notEmpty(v, 'Age');
                    if (e != null) return e;
                    final n = int.tryParse(v!.trim());
                    if (n == null || n < 1 || n > 80) return 'Enter 1–80';
                    return null;
                  },
                ),
                _field(
                  ctrl: _genderCtrl,
                  label: 'Gender  (1=Male, 2=Female)',
                  hint: '1 or 2',
                  validator: (v) {
                    final e = _notEmpty(v, 'Gender');
                    if (e != null) return e;
                    final n = int.tryParse(v!.trim());
                    if (n == null || n < 1 || n > 2) return 'Enter 1 or 2';
                    return null;
                  },
                ),
                _field(
                  ctrl: _raceCtrl,
                  label: 'Race code  (1–7)',
                  hint: '3=White, 4=Black …',
                  validator: (v) {
                    final e = _notEmpty(v, 'Race');
                    if (e != null) return e;
                    final n = int.tryParse(v!.trim());
                    if (n == null || n < 1 || n > 7) return 'Enter 1–7';
                    return null;
                  },
                ),

                // Income Level Dropdown
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: DropdownButtonFormField<double>(
                    value: _incomePovertyRatio,
                    decoration: InputDecoration(
                      labelText: 'Income Level',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 0.5, child: Text('Below poverty line')),
                      DropdownMenuItem(value: 1.5, child: Text('Low income')),
                      DropdownMenuItem(
                          value: 2.5, child: Text('Middle income')),
                      DropdownMenuItem(
                          value: 4.0, child: Text('Above average')),
                      DropdownMenuItem(value: 5.0, child: Text('High income')),
                    ],
                    onChanged: (val) {
                      if (val != null)
                        setState(() => _incomePovertyRatio = val);
                    },
                  ),
                ),

                const SizedBox(height: 10),
                const Text('Clinical Measurements',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),

                _field(
                  ctrl: _diasCtrl,
                  label: 'Diastolic BP (mmHg)',
                  hint: 'e.g. 80  [20–130]',
                  validator: (v) {
                    final e = _notEmpty(v, 'Diastolic BP');
                    if (e != null) return e;
                    final n = double.tryParse(v!.trim());
                    if (n == null || n < 20 || n > 130) return 'Enter 20–130';
                    return null;
                  },
                ),
                _field(
                  ctrl: _pulseCtrl,
                  label: 'Pulse Rate (bpm)',
                  hint: 'e.g. 72  [30–150]',
                  validator: (v) {
                    final e = _notEmpty(v, 'Pulse rate');
                    if (e != null) return e;
                    final n = double.tryParse(v!.trim());
                    if (n == null || n < 30 || n > 150) return 'Enter 30–150';
                    return null;
                  },
                ),
                _field(
                  ctrl: _bmiCtrl,
                  label: 'BMI (kg/m²)',
                  hint: 'e.g. 26.5  [10–70]',
                  validator: (v) {
                    final e = _notEmpty(v, 'BMI');
                    if (e != null) return e;
                    final n = double.tryParse(v!.trim());
                    if (n == null || n < 10 || n > 70) return 'Enter 10–70';
                    return null;
                  },
                ),
                _field(
                  ctrl: _waistCtrl,
                  label: 'Waist Circumference (cm)',
                  hint: 'e.g. 90  [40–200]',
                  validator: (v) {
                    final e = _notEmpty(v, 'Waist');
                    if (e != null) return e;
                    final n = double.tryParse(v!.trim());
                    if (n == null || n < 40 || n > 200) return 'Enter 40–200';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isLoading ? null : _predict,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('Predict'),
                  ),
                ),

                const SizedBox(height: 20),

                if (_result.isNotEmpty)
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        _result,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _resultColor,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
