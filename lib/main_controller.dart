import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path_provider/path_provider.dart';

class MainController extends GetxController with StateMixin<CameraController> {
  /// ------------------------
  /// VARIABLES
  /// ------------------------

  final RxString _message = ''.obs;
  final RxBool _isProcessingImage = false.obs;
  final RxBool _smiling = false.obs;
  final RxBool _takingPhoto = false.obs;
  final RxBool _confetti = false.obs;

  /// Related to ML Kit - Face detection
  late FaceDetector _faceDetector;

  /// Related to Camera
  final RxList<CameraDescription> _cameras = <CameraDescription>[].obs;
  late CameraController? _cameraController;
  final RxInt _cameraIndex = 0.obs;

  /// ------------------------
  /// GETTERS
  /// ------------------------

  String get message => _message.value;
  bool get isProcessingImage => _isProcessingImage.value;
  bool get smiling => _smiling.value;
  bool get takingPhoto => _takingPhoto.value;
  bool get confetti => _confetti.value;

  FaceDetector get faceDetector => _faceDetector;

  List<CameraDescription> get cameras => _cameras;
  CameraController? get cameraController => _cameraController;
  int get cameraIndex => _cameraIndex.value;

  /// ------------------------
  /// SETTERS
  /// ------------------------

  set message(String value) => _message.value = value;
  set isProcessingImage(bool value) => _isProcessingImage.value = value;
  set smiling(bool value) => _smiling.value = value;
  set takingPhoto(bool value) => _takingPhoto.value = value;
  set confetti(bool value) => _confetti.value = value;

  set faceDetector(FaceDetector value) => _faceDetector = value;

  set cameras(List<CameraDescription> value) => _cameras.assignAll(value);
  set cameraController(CameraController? value) => _cameraController = value;
  set cameraIndex(int value) => _cameraIndex.value = value;

  /// ------------------------
  /// INIT
  /// ------------------------

  @override
  Future<void> onInit() async {
    super.onInit();

    /// Initialize everything
    initializeFaceDetector();
    await initializeCamera();
    change(cameraController, status: RxStatus.success());
  }

  /// ------------------------
  /// DISPOSE
  /// ------------------------

  @override
  Future<void> onClose() async {
    /// Dispose everything
    await faceDetector.close();
    await cameraController?.stopImageStream();

    super.onClose();
  }

  /// ------------------------
  /// METHODS
  /// ------------------------

  /// Called to initialize face detector
  void initializeFaceDetector() {
    try {
      faceDetector = GoogleMlKit.vision.faceDetector(
        const FaceDetectorOptions(
          enableContours: true,
          enableClassification: true,
        ),
      );
    } catch (e) {
      final error = 'InitializeFaceDetector error: $e';
      log(error);
      change(null, status: RxStatus.error(error));
    }
  }

  /// Called to initialize front camera
  Future<void> initializeCamera() async {
    try {
      /// Get available cameras
      cameras = await availableCameras();

      /// Store all available cameras in a list
      for (var i = 0; i < cameras.length; i++) {
        if (cameras[i].lensDirection == CameraLensDirection.front) {
          cameraIndex = i;
        }
      }

      /// Start camera feed on screen
      await startLiveFeed();
    } on CameraException catch (e) {
      final error = 'InitializeCamera CameraException error: $e';
      log(error);
      change(null, status: RxStatus.error(error));
    } catch (e) {
      final error = 'InitializeCamera error: $e';
      log(error);
      change(null, status: RxStatus.error(error));
    }
  }

  /// Initializes CameraController and starts live feed
  Future<void> startLiveFeed() async {
    try {
      final camera = cameras[cameraIndex];

      /// Instantiate a CameraController
      cameraController = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await cameraController?.initialize();

      /// Start the stream and pass in a method that handles what the camera sees
      await cameraController?.startImageStream(processCameraImage);
    } catch (e) {
      final error = 'StartLiveFeed error: $e';
      log(error);
      change(null, status: RxStatus.error(error));
    }
  }

  /// Called when processing camera image
  /// Gets called continuously
  Future<void> processCameraImage(CameraImage image) async {
    try {
      /// Process current camera feed and store in an InputImage variable
      final allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      final camera = cameras[cameraIndex];
      final imageRotation = InputImageRotationMethods.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.Rotation_0deg;

      final inputImageFormat = InputImageFormatMethods.fromRawValue(image.format.raw) ?? InputImageFormat.NV21;

      final planeData = image.planes
          .map(
            (plane) => InputImagePlaneMetadata(
              bytesPerRow: plane.bytesPerRow,
              height: plane.height,
              width: plane.width,
            ),
          )
          .toList();

      final inputImageData = InputImageData(
        size: imageSize,
        imageRotation: imageRotation,
        inputImageFormat: inputImageFormat,
        planeData: planeData,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

      /// Process current image with Google ML Kit
      await processMLKitImage(inputImage);
    } catch (e) {
      final error = 'ProcessCameraImage error: $e';
      log(error);
      change(null, status: RxStatus.error(error));
    }
  }

  /// Called when the MLKit is processing current image
  /// Gets called continuously
  Future<void> processMLKitImage(InputImage inputImage) async {
    try {
      if (isProcessingImage) {
        return;
      }
      isProcessingImage = true;

      /// Find faces on the screen and store them in a list
      final faces = await faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        /// Found some faces, check if first face is smiling
        checkSmiling(faces.first);
      } else {
        smiling = false;

        if (!takingPhoto) {
          message = 'Show your face 🌝';
        }
      }

      isProcessingImage = false;
    } catch (e) {
      final error = 'ProcessMLKitImage error: $e';
      log(error);
      change(null, status: RxStatus.error(error));
    }
  }

  /// Checks if face is smiling
  /// Gets called continuously
  void checkSmiling(Face face) {
    try {
      final smilingProbability = face.smilingProbability ?? 0;

      if (smilingProbability < 0.75) {
        /// Face is not smiling
        smiling = false;

        if (!takingPhoto) {
          message = 'Smile 😁';
        }
      } else {
        /// Face is smiling
        smiling = true;

        if (!takingPhoto) {
          takePicture();
        }
      }
    } catch (e) {
      final error = 'CheckSmiling error: $e';
      log(error);
      change(null, status: RxStatus.error(error));
    }
  }

  /// Called when photo needs to be taken
  Future<void> takePicture() async {
    /// Used because this method would be called continuously
    takingPhoto = true;

    /// Waiting 3 seconds before taking photo to make sure the user is smiling
    message = 'Keep smiling... 😁';
    await Future.delayed(const Duration(milliseconds: 1600));

    /// Face is not smiling, don't take picture
    if (!smiling) {
      takingPhoto = false;
      return;
    }

    /// Face is smiling, try to take picture
    try {
      /// Camera controller isn't initialized, don't take picture
      if (cameraController == null || !cameraController!.value.isInitialized) {
        takingPhoto = false;
        log("CameraController isn't initialized");
        return;
      }

      /// Camera is already taking a picture, don't take another picture
      if (cameraController!.value.isTakingPicture) {
        takingPhoto = false;
        log('Camera is already capturing a picture');
        return;
      }

      /// Take a picture
      try {
        message = 'Taking photo... 📷';

        /// Need to stop image stream before taking photo because of errors
        await cameraController?.stopImageStream();

        /// Take the picture
        final picture = await cameraController?.takePicture();

        /// Start stream again after taking photo
        await cameraController?.startImageStream(processCameraImage);

        log('Picture taken: ${picture?.path}');

        /// Store the picture in the application directory
        final file = File(picture?.path ?? '');
        final picturePath = await storePictureInApplicationDirectory(file);

        /// Show snackbar informing the user of success, proper message, confetti and exit app
        await pictureSuccess(picturePath ?? '');
      } on CameraException catch (e) {
        takingPhoto = false;
        final error = 'TakePicture CameraException error: $e';
        log(error);
        change(null, status: RxStatus.error(error));
      } catch (e) {
        takingPhoto = false;
        final error = 'TakePicture error: $e';
        log(error);
        change(null, status: RxStatus.error(error));
      }
    } catch (e) {
      takingPhoto = false;
      final error = 'TakePicture error (last catch block): $e';
      log(error);
      change(null, status: RxStatus.error(error));
    }
  }

  /// Get application directory
  Future<String?> getApplicationDirectory() async {
    try {
      /// External storage directory
      final applicationDirectory = await getExternalStorageDirectory();
      final applicationDirectoryPath = applicationDirectory?.path;
      log('ExternalStorageDirectoryPath: $applicationDirectoryPath');

      return applicationDirectoryPath;
    } catch (e) {
      final error = 'GetApplicationDirectory error: $e';
      log(error);
      change(null, status: RxStatus.error(error));
      return null;
    }
  }

  /// Store the picture in the application directory
  Future<String?> storePictureInApplicationDirectory(File file) async {
    try {
      final appDirectoryPath = await getApplicationDirectory();
      final fullPath = '$appDirectoryPath/ml_smile.jpg';

      await file.copy(fullPath);

      log('Picture stored: $fullPath');

      return fullPath;
    } catch (e) {
      final error = 'StorePictureInApplicationDirectory error: $e';
      log(error);
      change(null, status: RxStatus.error(error));
      return null;
    }
  }

  /// 1. Show snackbar informing the user of success
  /// 2. Show proper message
  /// 3. Show confetti
  /// 4. Exit app
  Future<void> pictureSuccess(String path) async {
    /// Show snackbar
    Get.snackbar(
      'Picture taken',
      'Check it somewhere on the device',
      icon: const Icon(
        Icons.mood,
        color: Colors.white,
        size: 32,
      ),
      backgroundColor: Colors.transparent,
      colorText: Colors.white,
      borderColor: Colors.white,
      borderWidth: 2,
      shouldIconPulse: false,
      forwardAnimationCurve: Curves.easeIn,
      reverseAnimationCurve: Curves.easeOut,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 6),
    );

    /// Show message and confetti
    message = 'Wohoo 🎉';
    confetti = true;

    /// Exit app
    await Future.delayed(const Duration(seconds: 6));
    message = 'Goodbye 👋';
    await Future.delayed(const Duration(seconds: 2));
    await SystemNavigator.pop();
  }
}
