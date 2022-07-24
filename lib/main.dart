import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

late List<CameraDescription> _cameras;

class Throttler {
  Throttler({required this.milliSeconds});

  final int milliSeconds;

  int? lastActionTime;

  void run(VoidCallback action) {
    if (lastActionTime == null) {
      action();
      lastActionTime = DateTime.now().millisecondsSinceEpoch;
    } else {
      if (DateTime.now().millisecondsSinceEpoch - lastActionTime! >
          (milliSeconds)) {
        action();
        lastActionTime = DateTime.now().millisecondsSinceEpoch;
      }
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraController controller;
  late Throttler throttler;
  late StreamSubscription<int> timer;

  @override
  void initState() {
    super.initState();
    throttler = Throttler(milliSeconds: 500);

    final cameraDescription = _cameras
        .where(
          (element) => element.lensDirection == CameraLensDirection.front,
        )
        .first;

    controller = CameraController(cameraDescription, ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420);

    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      Future.delayed(const Duration(milliseconds: 500));

      // Only open and close camera in iOS for low-tier device
      if (Platform.isIOS) {
        timer = Stream.periodic(const Duration(milliseconds: 500), (v) => v)
            .listen((count) async {
          throttler.run(() async {
            controller.startImageStream((image) async {
              if (Platform.isIOS) {
                try {
                  await const MethodChannel('com.benamorn.liveness')
                      .invokeMethod<Uint8List>("checkLiveness", {
                    'platforms': image.planes.first.bytes,
                    'height': image.height,
                    'width': image.width,
                    "bytesPerRow": image.planes.first.bytesPerRow
                  });
                } on PlatformException catch (e) {
                  debugPrint(
                      "==== checkLiveness Method is not implemented ${e.message}");
                }
              }
            });

            Future.delayed(const Duration(milliseconds: 50), () async {
              await controller.stopImageStream();
            });
          });
        });
      } else {
        // For Android, we can open it all the time
        controller.startImageStream((image) async {
          throttler.run(() async {
            try {
              // Prepare data for Android
              List<int> strides = Int32List(image.planes.length * 2);
              int index = 0;
              final bytes = image.planes.map((plane) {
                strides[index] = (plane.bytesPerRow);
                index++;
                strides[index] = (plane.bytesPerPixel)!;
                index++;
                return plane.bytes;
              }).toList();

              await const MethodChannel('com.benamorn.liveness')
                  .invokeMethod<Uint8List>("checkLiveness", {
                'platforms': bytes,
                'height': image.height,
                'width': image.width,
                'strides': strides
              });
            } on PlatformException catch (e) {
              debugPrint(
                  "==== checkLiveness Method is not implemented ${e.message}");
            }
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return MaterialApp(
      home: CameraPreview(controller),
    );
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }
}
