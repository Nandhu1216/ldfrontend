import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? selectedZone;
  String? selectedSupervisor;
  String? selectedCategory;
  String? selectedWard;
  DateTime? selectedDate;
  List<File> selectedImages = [];

  List<String> zones = [];
  List<String> supervisorsList = [];
  List<String> categoryList = [];
  List<String> wardList = [];

  bool _isUploading = false; // ✅ Upload flag

  @override
  void initState() {
    super.initState();
    fetchZones();
    fetchCategories();
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

  Future<void> fetchCategories() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Categories')
          .doc('categories')
          .get();

      if (doc.exists && doc.data() != null) {
        final List<dynamic> types = doc.data()!['type'];
        setState(() {
          categoryList = types.cast<String>().toList();
        });
      } else {
        print("⚠️ 'categories' document not found");
      }
    } catch (e) {
      print("❌ Error loading categories: $e");
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

  Future<void> pickImages() async {
    final pickedImages = await ImagePicker().pickMultiImage();
    if (pickedImages != null) {
      setState(() {
        selectedImages = pickedImages.map((xfile) => File(xfile.path)).toList();
      });
    }
  }

  Future<void> uploadImages() async {
    if (_isUploading) return;

    if (selectedZone == null ||
        selectedSupervisor == null ||
        selectedCategory == null ||
        selectedWard == null ||
        selectedDate == null ||
        selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final uri = Uri.parse('https://ldbackend.onrender.com/upload');
    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate!);

    try {
      final uploadTasks = selectedImages.map((image) async {
        final request = http.MultipartRequest('POST', uri);
        request.fields['zone'] = selectedZone!;
        request.fields['supervisor'] = selectedSupervisor!;
        request.fields['category'] = selectedCategory!;
        request.fields['ward'] = selectedWard!;
        request.fields['date'] = formattedDate;
        request.files.add(
          await http.MultipartFile.fromPath('image', image.path),
        );
        final response = await request.send();
        return response.statusCode == 200;
      }).toList();

      final results = await Future.wait(uploadTasks);

      if (results.every((success) => success)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploaded successfully')));
        setState(() {
          selectedImages.clear();
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Some uploads failed')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Work Images"),
        centerTitle: true,
        backgroundColor: Colors.teal,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
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

                  /// Zone Dropdown
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

                  /// Supervisor Dropdown
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

                  /// Category Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Select Category",
                      border: OutlineInputBorder(),
                    ),
                    value: selectedCategory,
                    items: categoryList
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                    onChanged: (cat) {
                      setState(() {
                        selectedCategory = cat;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  /// Ward Dropdown
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

                  /// Date Picker
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

                  selectedImages.isNotEmpty
                      ? SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedImages.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  selectedImages[index],
                                  height: 180,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const Text("No images selected"),

                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: pickImages,
                    icon: const Icon(Icons.image),
                    label: const Text("Pick Images"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// ✅ Upload Button
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : uploadImages,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(
                      _isUploading ? 'Uploading...' : 'Upload to Cloudinary',
                    ),
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
