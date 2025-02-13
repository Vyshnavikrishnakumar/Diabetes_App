import 'package:flutter/material.dart';
import 'package:phase_1_app/utils/config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FastCheckPage extends StatefulWidget {
  const FastCheckPage({Key? key}) : super(key: key);

  @override
  _FastCheckPageState createState() => _FastCheckPageState();
}

class _FastCheckPageState extends State<FastCheckPage> {
  final _formKey = GlobalKey<FormState>();
  String predictionResult = "Awaiting prediction...";
  Color predictionColor = Colors.black;

  final List<TextEditingController> controllers =
      List.generate(7, (index) => TextEditingController());

  String sweating = '0';
  String shivering = '0';
  final Map<int, String?> errorMessages = {};

  /// Validates an input field based on min/max range
  void _validateField(int index, double min, double max, String label) {
    String text = controllers[index].text;
    setState(() {
      if (text.isEmpty) {
        errorMessages[index] = "Field cannot be empty";
      } else {
        try {
          double value = double.parse(text);
          if (value < min || value > max) {
            errorMessages[index] = "$label must be between $min and $max";
          } else {
            errorMessages[index] = null;
          }
        } catch (e) {
          errorMessages[index] = "Enter a valid number";
        }
      }
    });
  }

  /// Sends data to the API and updates UI
  Future<void> _predict() async {
    if (errorMessages.values.any((error) => error != null)) {
      return;
    }

    List<double> inputValues =
        controllers.map((c) => double.tryParse(c.text) ?? 0).toList();
    inputValues.add(double.parse(sweating));
    inputValues.add(double.parse(shivering));

    var url = 'http://192.168.29.185:5001/predict';
    try {
      var response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode({'input': inputValues}),
      );

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body)['prediction'];
        setState(() {
          if (result < 0.5) {
            predictionResult = 'Non Diabetic';
            predictionColor = Colors.green;
          } else if (result < 0.8) {
            predictionResult = 'Potentially Diabetic, consult a doctor.';
            predictionColor = Colors.orange;
          } else {
            predictionResult = 'Diabetic, seek medical attention.';
            predictionColor = Colors.red;
          }
        });
      } else {
        _showAlert('Server error: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      _showAlert('Network error: $e');
    }
  }

  /// Displays an alert dialog
  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Warning"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fast Check'),
        backgroundColor: Config.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildTableRow("BGL", 0, 20, 500),
                _buildTableRow("DBP", 1, 40, 200),
                _buildTableRow("SBP", 2, 70, 200),
                _buildTableRow("Temperature (°F)", 3, 94, 110),
                _buildTableRow("SPO2", 4, 94, 100),
                _buildDropdown("Sweating", (val) {
                  if (val != null) setState(() => sweating = val);
                }),
                _buildDropdown("Shivering", (val) {
                  if (val != null) setState(() => shivering = val);
                }),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _predict,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Config.primaryColor),
                  child: const Text('Predict'),
                ),
                const SizedBox(height: 20),
                _buildPredictionBox(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds an input field with validation
  Widget _buildTableRow(String label, int index, double min, double max) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controllers[index],
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              errorText: errorMessages[index],
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) => _validateField(index, min, max, label),
          ),
        ],
      ),
    );
  }

  /// Builds a dropdown for binary choices (Sweating, Shivering)
  Widget _buildDropdown(String label, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        value: '0',
        items: ['0', '1'].map((val) {
          return DropdownMenuItem(value: val, child: Text(val));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  /// Builds a styled container to display the prediction result
  Widget _buildPredictionBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        predictionResult,
        style: TextStyle(fontSize: 20, color: predictionColor, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}
