import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateAlertPage extends StatefulWidget {
  final DocumentSnapshot? editDoc;

  const CreateAlertPage({Key? key, this.editDoc}) : super(key: key);

  @override
  _CreateAlertPageState createState() => _CreateAlertPageState();
}

class _CreateAlertPageState extends State<CreateAlertPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController titleController;
  late TextEditingController descriptionController;
  late TextEditingController locationController;

  String alertType = "Flood";
  String severity = "Medium";
  bool isActive = true; // New feature: Status toggle
  bool isLoading = false;

  final List<String> alertTypes = [
    "Flood",
    "Earthquake",
    "Fire",
    "Storm",
    "Accident",
  ];
  final List<String> severityLevels = ["Low", "Medium", "High", "Critical"];

  bool get isEditMode => widget.editDoc != null;

  @override
  void initState() {
    super.initState();
    final data = widget.editDoc?.data() as Map<String, dynamic>?;

    titleController = TextEditingController(text: data?['title'] ?? '');
    descriptionController = TextEditingController(
      text: data?['description'] ?? '',
    );
    locationController = TextEditingController(text: data?['location'] ?? '');
    alertType = data?['type'] ?? "Flood";
    severity = data?['severity'] ?? "Medium";
    isActive = data?['isActive'] ?? true;
  }

  Color _getSeverityColor(String level) {
    switch (level) {
      case "Low":
        return Colors.green;
      case "Medium":
        return Colors.orange;
      case "High":
        return Colors.red;
      case "Critical":
        return Colors.purple;
      default:
        return Colors.blueAccent;
    }
  }

  Future<void> saveAlert() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final alertData = {
      "title": titleController.text.trim(),
      "description": descriptionController.text.trim(),
      "location": locationController.text.trim(),
      "type": alertType,
      "severity": severity,
      "isActive": isActive,
      "updatedAt": FieldValue.serverTimestamp(),
    };

    try {
      if (isEditMode) {
        await FirebaseFirestore.instance
            .collection('alerts')
            .doc(widget.editDoc!.id)
            .update(alertData);
      } else {
        alertData["createdAt"] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('alerts').add(alertData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? "Alert updated successfully"
                : "Alert broadcasted successfully",
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: Text(
          isEditMode ? "Edit Alert" : "Create New Alert",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                label: "Alert Title",
                controller: titleController,
                icon: Icons.title,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: "Detailed Description",
                controller: descriptionController,
                icon: Icons.description,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: "Location",
                controller: locationController,
                icon: Icons.location_on,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      "Type",
                      alertType,
                      alertTypes,
                      (val) => setState(() => alertType = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      "Severity",
                      severity,
                      severityLevels,
                      (val) => setState(() => severity = val!),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Status Toggle Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: SwitchListTile(
                  title: const Text(
                    "Active Status",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isActive ? "Visible to public" : "Hidden from public",
                  ),
                  value: isActive,
                  activeColor: Colors.green,
                  onChanged: (val) => setState(() => isActive = val),
                  secondary: Icon(
                    isActive ? Icons.visibility : Icons.visibility_off,
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double
                    .infinity, // Ensures the button is full-width for better touch target
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : saveAlert,
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : Icon(
                          isEditMode
                              ? Icons.check_circle_outline
                              : Icons.send_rounded,
                          size: 22,
                        ),
                  label: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          isEditMode ? "UPDATE INFORMATION" : "BROADCAST ALERT",
                          style: const TextStyle(
                            fontWeight: FontWeight
                                .w800, // Extra bold for professional look
                            fontSize: 16,
                            letterSpacing:
                                1.1, // Improved readability for all-caps text
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getSeverityColor(severity),
                    foregroundColor: Colors
                        .white, // ✅ Forces text and icon to be white for high contrast
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 4, // Adds subtle depth
                    shadowColor: _getSeverityColor(
                      severity,
                    ).withOpacity(0.4), // Colored shadow
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        16,
                      ), // Slightly smoother corners
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: (v) => v!.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
