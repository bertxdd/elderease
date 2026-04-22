import 'package:flutter/material.dart';

const Map<String, String> categoryImageByTitle = {
  'Heavy Household Chores': 'lib/screens/heavy_household_chores.png',
  'Home Maintenance & Support': 'lib/screens/home_maintenance.png',
  'Errands and Logistics': 'lib/screens/errands_and_logistics.png',
};

const Map<String, String> serviceImageByName = {
  'LPG Gas Tank Replacement': 'lib/screens/lpg_gas_tank_replacement.png',
  'Grocery Collection': 'lib/screens/grocery_collection.png',
  'Garden Maintenance': 'lib/screens/garden_maintenance.png',
  'Utility Assistance': 'lib/screens/utility_assistance.png',
  'Water Container Refill': 'lib/screens/water_container_refill.png',
  'Medical Prescription Pickup': 'lib/screens/medical_prescription_pickup.png',
};

String? categoryImagePath(String categoryTitle) {
  return categoryImageByTitle[categoryTitle];
}

String? serviceImagePath(String serviceName) {
  return serviceImageByName[serviceName];
}

Widget buildMappedImage(
  String? assetPath, {
  required double height,
  double? width,
  BoxFit fit = BoxFit.cover,
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(8)),
}) {
  if (assetPath == null || assetPath.isEmpty) {
    return _buildImageFallback(height: height, width: width, borderRadius: borderRadius);
  }

  return SizedBox(
    height: height,
    width: width,
    child: ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        assetPath,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildImageFallback(
            height: height,
            width: width,
            borderRadius: borderRadius,
          );
        },
      ),
    ),
  );
}

Widget _buildImageFallback({
  required double height,
  double? width,
  required BorderRadius borderRadius,
}) {
  return Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: borderRadius,
    ),
    child: const Center(
      child: Icon(Icons.image, color: Colors.grey),
    ),
  );
}
