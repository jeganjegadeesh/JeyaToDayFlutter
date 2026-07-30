import 'package:flutter/material.dart';

/// Attached to [MaterialApp] in main.dart. Lets code outside the widget
/// tree (e.g. [PushNotificationService] handling a notification tap) push
/// new routes without needing a local [BuildContext].
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
