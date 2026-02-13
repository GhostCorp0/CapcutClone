import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_editor/video_editor.dart';
import 'package:video_player/video_player.dart';

class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  final ImagePicker _picker = ImagePicker();
  VideoEditorController? _videoEditorController;
  VideoPlayerController? _videoPlayerController;
  bool canShowEditor = false;
  List<String> trimmedVideos = [];
  bool isSeeking = false;

  Future<void> _pickVideo() async {
    final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      _videoEditorController = VideoEditorController.file(
        File(file.path),
        minDuration: Duration(seconds: 1),
        maxDuration: Duration(seconds: 53),
      );

      _videoPlayerController = VideoPlayerController.file(File(file.path));

      try {
        await Future.wait([
          _videoEditorController!.initialize(),
          _videoPlayerController!.initialize(),
        ]);

        _videoPlayerController!.addListener(() {
          if (_videoPlayerController!.value.position >=
              _videoEditorController!.endTrim) {
            _videoPlayerController!.pause();
          }
        });

        setState(() {
          canShowEditor = true;
        });
      } catch (e) {
        print("Initialization error : $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Column(
          children: [
            if (canShowEditor &&
                _videoPlayerController!.value.isInitialized &&
                _videoEditorController!.initialized) ...[
              //Video preview area
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio:
                                _videoPlayerController!.value.aspectRatio,
                            child: VideoPlayer(_videoPlayerController!),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (_videoPlayerController!.value.isPlaying) {
                                  _videoPlayerController!.pause();
                                } else {
                                  if (!isSeeking) {
                                    int startTrimDuration =
                                        _videoEditorController!
                                            .startTrim
                                            .inSeconds;
                                    _videoPlayerController!.seekTo(
                                      Duration(seconds: startTrimDuration),
                                    );
                                  }
                                  _videoPlayerController!.play();
                                }
                              });
                            },
                            icon: Icon(
                              _videoPlayerController!.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Slider(
                      max: _videoPlayerController!.value.duration.inMilliseconds
                          .toDouble(),
                      value: _videoPlayerController!
                          .value
                          .position
                          .inMilliseconds
                          .toDouble(),
                      onChangeStart: (value) {
                        isSeeking = true;
                      },
                      onChanged: (double value) {
                        _videoPlayerController!.seekTo(
                          Duration(milliseconds: value.toInt()),
                        );
                        setState(() {});
                      },
                      onChangeEnd: (value) {
                        isSeeking = false;
                        _videoPlayerController!.play();
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: Text(
                    "Select a video to start editing",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 25),
                child: ElevatedButton(
                  onPressed: _pickVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: Text(
                    'Import video',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
