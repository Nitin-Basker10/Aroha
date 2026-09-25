/// App-wide constants for Indian Antarctic Program (AROHA / NCPOR)
class AppConstants {
  AppConstants._();

  static const String appName = 'AROHA';
  static const String appSubtitle =
      'Integrated Polar Expedition Logistics & Command';
  static const String missionVersion = 'OPS-v4.2 // NCPOR';

  // Station Identifiers
  static const String maitriId = 'maitri';
  static const String bharatiId = 'bharati';
  static const String himadriId = 'himadri';

  // Category Constants
  static const List<String> inventoryCategories = [
    'All',
    'fuel',
    'food',
    'medical',
    'spare-parts',
    'equipment',
  ];

  // Personnel Roles
  static const List<String> personnelRoles = [
    'All',
    'station-lead',
    'researcher',
    'crew',
    'medical',
    'logistics',
  ];

  // Comms Priorities
  static const String priorityRoutine = 'routine';
  static const String priorityUrgent = 'urgent';
  static const String priorityEmergency = 'emergency';
}
