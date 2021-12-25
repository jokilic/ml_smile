import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'confetti.dart';
import 'main_controller.dart';

class MainScreen extends StatelessWidget {
  static const routeName = '/main_screen';

  final mainController = Get.find<MainController>();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: mainController.obx(
          (cameraController) => Obx(
            () => Stack(
              alignment: Alignment.center,
              children: [
                CameraPreview(
                  cameraController!,
                ),
                Align(
                  alignment: const Alignment(0, 0.8),
                  child: Text(
                    mainController.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (mainController.smiling)
                  Align(
                    alignment: const Alignment(0, -0.5),
                    child: Confetti(),
                  ),
              ],
            ),
          ),
          onError: (error) => Align(
            alignment: const Alignment(0, 0.8),
            child: Text(
              error ?? 'No error',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
