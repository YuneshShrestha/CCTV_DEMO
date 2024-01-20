import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class LiveCamera extends StatefulWidget {
  const LiveCamera({super.key, required this.cameras});
  final List<CameraDescription> cameras;

  @override
  State<LiveCamera> createState() => _LiveCameraState();
}

class _LiveCameraState extends State<LiveCamera> {
  late CameraController cameraController;
  CameraImage? img;
  XFile? imageFile;
  Timer? timer;

  Future<void> timerFunction() async {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (img != null) {
        timer.cancel();
        imageFile = await takePicture();
        setState(() {});
        if (imageFile != null) {
          await sendImage(imageFile!.name);
        } else {
          await timerFunction();
        }
      }
    });
  }

  @override
  void initState() {
    Timer.periodic(const Duration(seconds: 1), (Timer t) => timerFunction());

    super.initState();
    cameraController =
        CameraController(widget.cameras[0], ResolutionPreset.max);
    cameraController.initialize().then((_) {
      if (!mounted) {
        return;
      }
      cameraController.startImageStream((image) {
        setState(() {
          img = image;
        });
      });
      setState(() {});
    }).catchError((Object error) {
      if (error is CameraException) {
        switch (error.code) {
          case 'CameraAccessDenied':
            break;
          case 'CameraUnavailable':
            break;
          case 'CameraUninitialized':
            break;
          case 'InvalidCameraDescription':
            break;
          case 'NotSupported':
            break;
          default:
            break;
        }
      }
    });
  }

  String prediction = "";

  Future<void> sendImage(String imagePath) async {
    // final directory = await getApplicationDocumentsDirectory();
    // final imagePath =
    //     '${directory.path}/image.jpg'; // Replace with your image path
    // await sendMail();
    final toSendImageFile = File(imageFile!.path);

    final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'http://192.168.18.28:5002/predict')); // Replace with your API endpoint
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        toSendImageFile.path,
      ),
    );

    final response = await request.send();
    final responseString = await response.stream.bytesToString();
    final decodedMap = jsonDecode(responseString);
    print("Response Json: ${decodedMap['prediction']}");

    if (decodedMap['prediction'] != "" &&
        prediction != decodedMap['prediction']) {
      await sendMail(decodedMap['prediction']);
    }
    setState(() {
      prediction = decodedMap['prediction'];
    });
    // print("Response Json: ${decodedMap.toString()}");
    // print("Response: ${response.persistentConnection.toString()}");
    // print("Response: ${response.statusCode.toString()}");
    // print("Response: ${response.contentLength.toString()}");
    // print("Response: ${response.reasonPhrase.toString()}");
    // print("Response: ${response.request.toString()}");
    // print("Response: ${response.stream.toString()}");
    // print("Response: ${response.toString()}");

    if (response.statusCode == 200) {
      print('Image uploaded successfully');
    } else {
      print('Failed to upload image');
    }
  }

  Future<void> sendMail(String mailText) async {
    try {
      final response =
          await http.post(Uri.parse('http://192.168.18.17:3000/api/alert'),
              headers: <String, String>{
                'Content-Type': 'application/json',
              },
              body: jsonEncode(<String, String>{
                "alert": "Alert! \n $mailText was detected.",
              }));
      print("Roshan Response: ${response.statusCode.toString()}");
      print("Roshan Response: ${response.body.toString()}");
    } catch (e) {
      print("Roshan Error: ${e.toString()}");
    }
  }

  Future<XFile?> takePicture() async {
    CameraController? controller = cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: select a camera first.')),
      );
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      final XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  void _showCameraException(CameraException e) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(e.toString()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height / 1.2,
                      width: MediaQuery.of(context).size.width,
                      child: CameraPreview(cameraController),
                    ),
                    // Center(
                    //   child: cameraController.value.isInitialized
                    //       ? AspectRatio(
                    //           aspectRatio: cameraController.value.aspectRatio,
                    //           child: CameraPreview(cameraController),
                    //         )
                    //       : const CircularProgressIndicator(),
                    // ),
                    // Positioned(
                    //   bottom: 10,
                    //   left: 40,
                    //   child: IconButton(
                    //     onPressed: () async {
                    //       imageFile = await takePicture();
                    //     },
                    //     icon: const Icon(Icons.camera),
                    //   ),
                    // ),
                  ],
                ),
                //  Display Image
                // Container(
                //   height: MediaQuery.of(context).size.height / 2,
                //   width: MediaQuery.of(context).size.width,
                //   child: imageFile == null
                //       ? const Text('No Image')
                //       : Image.file(
                //           File(imageFile!.path),
                //           fit: BoxFit.cover,
                //         ),
                // ),
                if (prediction != "") Text("$prediction Detected.")
              ],
            ),
          ),
        ),
      ),
    );
  }
}
