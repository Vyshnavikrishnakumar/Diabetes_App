import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:twilio_flutter/twilio_flutter.dart';
import 'dart:convert';
import 'package:phase_1_app/utils/config.dart';
import 'secret.dart';

class FastCheckPage extends StatefulWidget {
  const FastCheckPage({Key? key}) : super(key: key);

  @override
  _FastCheckPageState createState() => _FastCheckPageState();
}

class _FastCheckPageState extends State<FastCheckPage> {
  final _formKey = GlobalKey<FormState>();
  String predictionResult = "Awaiting prediction...";
  Color predictionColor = Colors.black;
  late TwilioFlutter twilioFlutter;

  double? predictionScore;

  final List<TextEditingController> controllers =
      List.generate(7, (index) => TextEditingController());

  final TextEditingController emergencyContactController =
      TextEditingController();
  String? savedEmergencyContact;

  final Map<int, String?> errorMessages = {};
  String sweating = '0';
  String shivering = '0';

  @override
  void initState() {
    super.initState();
    _loadEmergencyContact();

    twilioFlutter = TwilioFlutter(
      accountSid: Secrets.accountSid,
      authToken: Secrets.authToken,
      twilioNumber: Secrets.twilioNumber,
    );
  }

  Future<void> _loadEmergencyContact() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      savedEmergencyContact = prefs.getString("emergencyContact") ?? "";
      emergencyContactController.text = savedEmergencyContact ?? "";
    });
  }

  Future<void> _saveEmergencyContact() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("emergencyContact", emergencyContactController.text);
    setState(() {
      savedEmergencyContact = emergencyContactController.text;
    });
    _showAlert("Emergency contact saved!");
  }

  void _sendEmergencyMessage(double prediction) {
    String contact = savedEmergencyContact ?? emergencyContactController.text;
    if (contact.isNotEmpty) {
      String message;

      if (prediction < 0.5) {
        message =
            "✅ Health Update: No signs of diabetes detected. Stay healthy!";
      } else if (prediction < 0.8) {
        message =
            "⚠️ Warning: Possible signs of diabetes. Please consult a doctor soon.";
      } else {
        message =
            "🚨 Emergency Alert! High risk of diabetes detected. Immediate medical attention is required!";
      }

      twilioFlutter.sendSMS(
        toNumber: contact,
        messageBody: message,
      );

      _showAlert("Message sent: $message");
    } else {
      _showAlert("No emergency contact set!");
    }
  }

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

  Future<void> _predict() async {
    for (int i = 0; i < controllers.length; i++) {
      _validateField(i, 0, 200, "Field");
    }

    if (errorMessages.values.any((error) => error != null)) {
      _showAlert("Please fix the errors before submitting.");
      return;
    }

    try {
      List<double> inputValues = controllers.map((c) {
        return c.text.isEmpty ? 0.0 : double.parse(c.text);
      }).toList();

      inputValues.add(double.parse(sweating));
      inputValues.add(double.parse(shivering));

      var url = 'http://192.168.184.186:5001/predict';

      var response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode({'input': inputValues}),
      );

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body)['prediction'];

        setState(() {
          predictionScore = result;
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
        // Automatically send an emergency SMS if the score is high
if (predictionScore != null && predictionScore! >= 0.8) {
  _sendEmergencyMessage(predictionScore!);
}
      } else {
        _showAlert('Server error: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      _showAlert('Error: ${e.toString()}');
    }
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("EMERGENCY "),
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
                _buildTableRow("Age", 0, 1, 120),
                _buildTableRow("BGL", 1, 20, 500),
                _buildTableRow("DBP", 2, 40, 200),
                _buildTableRow("SBP", 3, 70, 200),
                _buildTableRow("Heart Rate", 4, 60, 100),
                _buildTableRow("Temperature (°F)", 5, 94, 110),
                _buildTableRow("SPO2", 6, 94, 100),
                _buildDropdown("Sweating", sweating, (val) {
                  setState(() => sweating = val!);
                }),
                _buildDropdown("Shivering", shivering, (val) {
                  setState(() => shivering = val!);
                }),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emergencyContactController,
                  decoration: const InputDecoration(
                    labelText: "Emergency Contact",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveEmergencyContact,
                  child: const Text("Save Emergency Contact"),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (predictionScore != null) {
                      _sendEmergencyMessage(
                          predictionScore!); // Pass the stored score ✅
                    } else {
                      _showAlert(
                          "Please predict first before sending an alert.");
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text(
                    'Send Emergency Alert',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
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

  Widget _buildDropdown(
      String label, String selectedValue, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        value: selectedValue,
        items: ['0', '1']
            .map((val) => DropdownMenuItem(value: val, child: Text(val)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTableRow(String label, int index, double min, double max) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controllers[index],
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          errorText: errorMessages[index],
        ),
        keyboardType: TextInputType.number,
        onChanged: (value) => _validateField(index, min, max, label),
      ),
    );
  }

  Widget _buildPredictionBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        predictionResult,
        style: TextStyle(
            fontSize: 20, color: predictionColor, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}
