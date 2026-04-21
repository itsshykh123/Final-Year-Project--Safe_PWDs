import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsersListPage extends StatefulWidget {
  const UsersListPage({Key? key}) : super(key: key);

  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  String searchQuery = "";
  String selectedFilter = "All"; // All, Disabled, Guardian, Normal
  String? adminEmail;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  // ✅ Load current admin email to hide it from the list
  Future<void> _loadAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      adminEmail = prefs.getString('userEmail');
    });
  }

  // Helper to build Filter Chips
  Widget _buildFilterChip(String label) {
    bool isSelected = selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: Colors.blueAccent.withOpacity(0.2),
        checkmarkColor: Colors.blueAccent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.blueAccent : Colors.black54,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (bool value) {
          setState(() {
            selectedFilter = label;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "User Directory",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Search Bar Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      setState(() => searchQuery = value.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Search by name or email...",
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.blueAccent,
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => searchQuery = "");
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F3F4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 2. Filter Section
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip("All"),
                      _buildFilterChip("Disabled"),
                      _buildFilterChip("Guardian"),
                      _buildFilterChip("Normal"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. User List Section
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No users found"));
                }

                // Filtering Logic
                var users = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String name = (data['Name'] ?? '').toString().toLowerCase();
                  String email = (data['email'] ?? '').toString().toLowerCase();
                  String disability = (data['disability'] ?? 'Normal');

                  if (email == adminEmail?.toLowerCase()) return false;

                  bool matchesSearch =
                      name.contains(searchQuery) || email.contains(searchQuery);

                  bool matchesFilter = true;
                  if (selectedFilter == "Disabled") {
                    matchesFilter = disability != "Normal";
                  }
                  if (selectedFilter == "Guardian") {
                    matchesFilter = data.containsKey('guardian');
                  }
                  if (selectedFilter == "Normal") {
                    matchesFilter = disability == "Normal";
                  }

                  return matchesSearch && matchesFilter;
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var data = users[index].data() as Map<String, dynamic>;
                    bool isDisability =
                        data['disability'] != null &&
                        data['disability'] != "Normal";

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isDisability
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.blueAccent.withOpacity(0.1),
                          child: Icon(
                            isDisability
                                ? Icons.accessible_forward
                                : Icons.person,
                            color: isDisability
                                ? Colors.orange
                                : Colors.blueAccent,
                          ),
                        ),
                        title: Text(
                          data['Name'] ?? 'No Name',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(data['email'] ?? 'No Email'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDisability
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                data['disability'] ?? 'Normal',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDisability
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        onTap: () {
                          // Add functionality to view user details if needed
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
