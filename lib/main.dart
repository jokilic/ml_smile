import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'main_binding.dart';
import 'main_screen.dart';

void main() => runApp(MLSmileApp());

class MLSmileApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GetMaterialApp(
        title: 'ML Smile App',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
        ),
        initialRoute: MainScreen.routeName,
        getPages: [
          GetPage(
            name: MainScreen.routeName,
            page: MainScreen.new,
            binding: MainBinding(),
          ),
        ],
      );
}
