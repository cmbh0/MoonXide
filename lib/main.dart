import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/bootstrap.dart';
import 'app/moonxide_app.dart';
import 'core/services/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MoonXideBootstrap(child: MoonXideApp()));
}
