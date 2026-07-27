class ApiConfig {
  // Point this at your Laravel backend.
  // Android emulator -> 10.0.2.2, iOS simulator/desktop/web -> localhost
  static const String baseUrl = 'https://jeganjegadeesh.in/JeyaToDayBackEnd/api';
  // static const String baseUrl = 'http://192.168.1.8:8000/api';

  static const String imageBaseUrl = 'https://jeganjegadeesh.in/JeyaToDayBackEnd/storage';
  // static const String imageBaseUrl = 'http://192.168.1.8:8000/storage';


  static const String tokenKey = 'aj_auth_token';
  static const String userKey = 'aj_auth_user';
}
