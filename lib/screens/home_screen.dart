import 'package:flutter/material.dart';
import '../config/service_image_config.dart';
import '../models/service_model.dart';
import '../widgets/bottom_nav.dart';
import 'category_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'your_service_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final List<ServiceModel>? initialServices;
  const HomeScreen({
    super.key,
    required this.username,
    this.initialServices,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _currentTab = 0;

  // This list holds services the user has added
  late final List<ServiceModel> _myServices;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _myServices = List<ServiceModel>.from(widget.initialServices ?? []);
  }
  // Show popup modal when user taps '+' on a service
  void _showAddServiceModal(ServiceModel service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 100,
              width: 100,
              child: buildMappedImage(
                serviceImagePath(service.name),
                height: 100,
                width: 100,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              service.name,
              style: const TextStyle(
                color: Color(0xFFE8922A),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              service.description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Add to my services if not already added
                  if (!_myServices.any((s) => s.id == service.id)) {
                    setState(() => _myServices.add(service));
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8922A),
                ),
                child: const Text(
                  'Add Service',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final filteredCategories = [
      'Heavy Household\nChores',
      'Home Maintenance\n& Support',
      'Errands and\nLogistics',
    ].where((category) {
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return category.replaceAll('\n', ' ').toLowerCase().contains(normalizedQuery);
    }).toList();

    final filteredServices = allServices.where((service) {
      if (normalizedQuery.isEmpty) {
        return true;
      }

      return service.name.toLowerCase().contains(normalizedQuery) ||
          service.description.toLowerCase().contains(normalizedQuery) ||
          service.category.toLowerCase().contains(normalizedQuery);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFE8F0EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F0EE),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.elderly, color: Color(0xFFE8922A)),
            SizedBox(width: 8),
            Text(
              'ElderEase',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFFFF3E0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Service Categories
            const Text(
              'Service Categories:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filteredCategories
                  .map((category) => SizedBox(
                        width: (MediaQuery.of(context).size.width - 48) / 3,
                        child: _buildCategoryCard(category),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            // Popular Services
            const Text(
              'Popular Services:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (filteredServices.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'No matching services found.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: filteredServices.length,
                itemBuilder: (context, index) {
                  return _buildServiceCard(filteredServices[index]);
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentTab,
        onTap: (i) {
          if (i == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => YourServiceScreen(
                  username: widget.username,
                  services: _myServices,
                ),
              ),
            );
          } else if (i == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationScreen(
                  username: widget.username,
                  services: _myServices,
                ),
              ),
            );
          } else if (i == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  username: widget.username,
                  services: _myServices,
                ),
              ),
            );
          } else {
            setState(() {});
          }
        },
      ),
    );
  }

  // Build a single category card
  Widget _buildCategoryCard(String title) {
    final normalizedTitle = title.replaceAll('\n', ' ');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryScreen(
            category: normalizedTitle,
            services: allServices
                .where((s) => s.category == normalizedTitle)
                .toList(),
            onAdd: (s) {
              if (!_myServices.any((ms) => ms.id == s.id)) {
                setState(() => _myServices.add(s));
              }
            },
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 60,
              width: double.infinity,
              child: buildMappedImage(
                categoryImagePath(normalizedTitle),
                height: 60,
                width: double.infinity,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // Build a single popular service card
  Widget _buildServiceCard(ServiceModel service) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 80,
              width: double.infinity,
              child: buildMappedImage(
                serviceImagePath(service.name),
                height: 80,
                width: double.infinity,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              service.name,
              style: const TextStyle(
                color: Color(0xFFE8922A),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              service.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                onTap: () => _showAddServiceModal(service),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8922A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
