class AppConfig {
  static const String apiBaseUrl = 'https://elderease.uslsbsit.com/api';
  static const String adminWebUrl = 'https://elderease.uslsbsit.com/admin.html';

  // PHP endpoint names can be changed here when your backend files are finalized.
  static const String registerPath = 'register.php';
  static const String loginPath = 'login.php';
  static const String getProfilePath = 'get_profile.php';
  static const String updateProfilePath = 'update_profile.php';
  static const String createRequestPath = 'create_request.php';
  static const String listRequestsPath = 'list_requests.php';
  static const String listVolunteerRequestsPath = 'list_volunteer_requests.php';
  static const String acceptRequestPath = 'accept_request.php';
  static const String updateRequestStatusPath = 'update_request_status.php';
  static const String updateVolunteerLocationPath = 'update_volunteer_location.php';
}
