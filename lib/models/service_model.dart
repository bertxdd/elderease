// This class represents one service in the app
class ServiceModel {
  final String id;
  final String name;
  final String description;
  final String category;

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
  });
}

// All available services in ElderEase
// In a real app, this would come from your PHP + MySQL backend
final List<ServiceModel> allServices = [
  ServiceModel(
    id: '1',
    name: 'LPG Gas Tank Replacement',
    description: 'Safe replacement of LPG gas tanks at home.',
    category: 'Home Maintenance & Support',
  ),
  ServiceModel(
    id: '2',
    name: 'Grocery Collection',
    description: 'Pick up and deliver groceries from the market.',
    category: 'Errands and Logistics',
  ),
  ServiceModel(
    id: '3',
    name: 'Garden Maintenance',
    description: 'Trimming, weeding, and general garden care.',
    category: 'Home Maintenance & Support',
  ),
  ServiceModel(
    id: '4',
    name: 'Utility Assistance',
    description: 'Help with utility-related errands and account coordination.',
    category: 'Home Maintenance & Support',
  ),
  ServiceModel(
    id: '5',
    name: 'Water Container Refill',
    description: 'Lift and place heavy water containers.',
    category: 'Home Maintenance & Support',
  ),
  ServiceModel(
    id: '6',
    name: 'Medical Prescription Pickup',
    description: 'Collect medicine from pharmacy.',
    category: 'Errands and Logistics',
  ),
];
