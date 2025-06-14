import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? selectedZone;
  String? selectedSupervisor;
  String? selectedWard;
  DateTime? selectedDate;
  File? selectedImage;

  List<String> zones = [];
  List<String> supervisorsList = [];
  List<String> wardList = [];

  @override
  void initState() {
    super.initState();
    fetchZones();
  }

  Future<void> fetchZones() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Zones')
          .get();
      final zoneList = snapshot.docs.map((doc) => doc.id).toList();
      setState(() {
        zones = zoneList;
      });
    } catch (e) {
      print('Error loading zones: $e');
    }
  }

  Future<void> fetchSupervisors(String zone) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Zones')
          .doc(zone)
          .collection('Supervisors')
          .get();

      final supervisors = snapshot.docs.map((doc) => doc.id).toList();

      setState(() {
        supervisorsList = supervisors;
        selectedSupervisor = null;
        wardList = [];
        selectedWard = null;
      });
    } catch (e) {
      print("Error loading supervisors: $e");
    }
  }

  Future<void> fetchWards(String zone, String supervisorName) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('Zones')
          .doc(zone)
          .collection('Supervisors')
          .doc(supervisorName)
          .get();

      if (docSnapshot.exists) {
        final wards = List<String>.from(docSnapshot['wards']);
        setState(() {
          wardList = wards;
          selectedWard = null;
        });
      }
    } catch (e) {
      print("Error loading wards: $e");
    }
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2023),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        selectedImage = File(picked.path);
      });
    }
  }

  Future<void> uploadImage() async {
    if (selectedZone == null ||
        selectedSupervisor == null ||
        selectedWard == null ||
        selectedDate == null ||
        selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    final uri = Uri.parse(
      'BACKEND_URL', // Replace with your backend URL
    ); // 🔁 Update your backend URL here
    final request = http.MultipartRequest('POST', uri);

    request.fields['zone'] = selectedZone!;
    request.fields['supervisor'] = selectedSupervisor!;
    request.fields['ward'] = selectedWard!;
    request.fields['date'] = DateFormat('yyyy-MM-dd').format(selectedDate!);
    request.files.add(
      await http.MultipartFile.fromPath('image', selectedImage!.path),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload successful')));
      setState(() {
        selectedImage = null;
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Work Image"),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text(
                    "Work Image Upload",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 30, thickness: 1.5),

                  // Zone Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Select Zone",
                      border: OutlineInputBorder(),
                    ),
                    value: selectedZone,
                    items: zones
                        .map(
                          (zone) =>
                              DropdownMenuItem(value: zone, child: Text(zone)),
                        )
                        .toList(),
                    onChanged: (zone) {
                      setState(() {
                        selectedZone = zone;
                        selectedSupervisor = null;
                        selectedWard = null;
                        supervisorsList = [];
                        wardList = [];
                      });
                      fetchSupervisors(zone!);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Supervisor Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Select Supervisor",
                      border: OutlineInputBorder(),
                    ),
                    value: selectedSupervisor,
                    items: supervisorsList
                        .map(
                          (sup) =>
                              DropdownMenuItem(value: sup, child: Text(sup)),
                        )
                        .toList(),
                    onChanged: (sup) {
                      setState(() {
                        selectedSupervisor = sup;
                        selectedWard = null;
                        wardList = [];
                      });
                      fetchWards(selectedZone!, sup!);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Ward Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Select Ward",
                      border: OutlineInputBorder(),
                    ),
                    value: selectedWard,
                    items: wardList
                        .map(
                          (ward) =>
                              DropdownMenuItem(value: ward, child: Text(ward)),
                        )
                        .toList(),
                    onChanged: (ward) {
                      setState(() {
                        selectedWard = ward;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Date Picker
                  InkWell(
                    onTap: pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Select Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate == null
                                ? 'No date selected'
                                : DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(selectedDate!),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Image Preview
                  selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(selectedImage!, height: 180),
                        )
                      : const Text("No image selected"),

                  const SizedBox(height: 8),

                  ElevatedButton.icon(
                    onPressed: pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text("Pick Image"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Upload Button
                  ElevatedButton.icon(
                    onPressed: uploadImage,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text("Upload to Cloudinary"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.teal,
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
