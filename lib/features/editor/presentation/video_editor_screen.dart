import 'dart:io';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_editor/video_editor.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as path;

class VideoEditorScreen extends StatefulWidget {
  final String projectName;
  const VideoEditorScreen({super.key, required this.projectName});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  final ImagePicker _picker = ImagePicker();
  VideoEditorController? _videoEditorController;
  VideoPlayerController? _videoPlayerController;
  bool canShowEditor = false;
  List<Map<String, String>> trimmedVideos = [];
  bool isSeeking = false;
  bool enableTransition = false;
  bool isMuted = false;
  bool isSpeedControlVisible = false;
  double playbackSpeed = 1.0;
  String selectedAspectRatio = "Original";
  final Map<String, List<int>> aspectRatios = {
    "Original": [0, 0, 0, 0],
    "16:9": [1920, 1080, 0, 0],
    "9:16": [1080, 1920, 0, 0],
    "4:3": [1440, 1080, 0, 0],
  };

  String selectFilter = "None";

  final Map<String,String> filterCommands = {
    "None":"",
    "Brightness":"eq=brightness=0.3",
    "Contrast":"eq=contrast=1.5",
    "Saturation":"eq=saturation=1.8",
    "Grayscale":"format=gray",
  };

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          color: Colors.black,
          padding: EdgeInsets.all(16),
          height: 250,
          child: Column(
            children: [
              Text(
                "Select Filter",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children:filterCommands.keys.map((filter){
                  return GestureDetector(
                    onTap: (){
                      setState(() {
                        selectFilter = filter;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: selectFilter == filter? Colors.green:Colors.white10,
                          borderRadius: BorderRadius.circular(10)
                      ),
                      child: Text(filter,style: TextStyle(color: Colors.white),),
                    ),
                  );
                }).toList(),
              )
            ],
          ),
        );
      },
    );
  }

  void _openCropRatioModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          color: Colors.black,
          padding: EdgeInsets.all(16),
          height: 200,
          child: Column(
            children: [
              Text(
                "Select crop ratio",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children:aspectRatios.keys.map((ratio){
                  return GestureDetector(
                    onTap: (){
                      setState(() {
                        selectedAspectRatio = ratio;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: selectedAspectRatio == ratio? Colors.green:Colors.white10,
                        borderRadius: BorderRadius.circular(10)
                      ),
                      child: Text(ratio,style: TextStyle(color: Colors.white),),
                    ),
                  );
                }).toList(),
              )
            ],
          ),
        );
      },
    );
  }

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

  Future<void> _trimVideo() async {
    if (_videoEditorController == null) return;
    final start = _videoEditorController!.startTrim.inMilliseconds / 1000;
    final end = _videoEditorController!.endTrim.inMilliseconds / 1000;
    final Directory tempDir = await getTemporaryDirectory();
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String fileName = 'trimmed_video_$timestamp.mp4';
    print("filename : $fileName");
    final String outputPath = path.join(tempDir.path, fileName);

    final String command =
        '-i ${_videoEditorController!.file.path} -ss $start -to $end -c copy $outputPath';
    await FFmpegKit.execute(command).then((session) async {
      final returnCode = await session.getReturnCode();
      print('Returncode : $returnCode');
      if (ReturnCode.isSuccess(returnCode)) {
        setState(() {
          _generateThumbnail(outputPath, timestamp);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Video exported to: $outputPath")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to exported to : $outputPath")),
        );
      }
    });
  }

  Future<void> _generateThumbnail(String videoPath, String timestamp) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String fileName = 'thumb_$timestamp.jpg';
    final String thumbnailPath = path.join(tempDir.path, fileName);

    final String command =
        '-i $videoPath -ss 00:00:00.500 -vframes 1 $thumbnailPath';

    await FFmpegKit.execute(command).then((session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        setState(() {
          trimmedVideos.add({'video': videoPath, 'thumbnail': thumbnailPath});
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to export video")));
      }
    });
  }

  Future<void> _mergeVideos() async {
    if (trimmedVideos.isEmpty) return;

    final Directory tempDir = await getTemporaryDirectory();
    final String mergedVideosPath = '${tempDir.path}/${widget.projectName}.mp4';
    final String fileListPath = '${tempDir.path}/file_list_txt';
    File fileList = File(fileListPath);

    String fileListContent = trimmedVideos
        .map((clip) => "file '${clip['video']}'")
        .join('\n');
    await fileList.writeAsString(fileListContent);
    print("fileListContent : $fileListContent");

    String command = enableTransition
        ? '-f concat -safe 0 -i "$fileListPath" -vf "fade=in:0:30" -c:v h264_videotoolbox -q:v 70 -c:a copy -movflags +faststart "$mergedVideosPath" -y'
        : '-f concat -safe 0 -i "$fileListPath" -c copy -y "$mergedVideosPath"';

    if (isMuted) {
      command =
          '-f concat -safe 0 -i "$fileListPath" -c copy -an "$mergedVideosPath" -y';
    }

    if (playbackSpeed != 1.0) {
      double setptsValue = 1 / playbackSpeed;
      command =
          '-f concat -safe 0 -i "$fileListPath" -filter_complex "[0:v]setpts=$setptsValue*PTS[v];[0:a]atempo=$playbackSpeed[a]" -map "[v]" -map "[a]" -c:v libx264 -preset medium -crf 23 $mergedVideosPath -y';
    }

    if (selectedAspectRatio != "Original") {
      final videoWidth = _videoPlayerController!.value.size.width;
      final videoHeight = _videoPlayerController!.value.size.height;

      final aspectRatioSettings = aspectRatios[selectedAspectRatio]!;
      int targetWidth = aspectRatioSettings[0];
      int targetHeight = aspectRatioSettings[1];
      int cropX = aspectRatioSettings[2];
      int cropY = aspectRatioSettings[3];

      double videoAspectRatio = videoWidth / videoHeight;
      double targetAspectRatio = targetWidth / targetHeight.toDouble();

      if (videoAspectRatio > targetAspectRatio) {
        targetWidth = (videoHeight * targetAspectRatio).toInt();
        cropX = ((videoWidth - targetWidth) ~/ 2);
        cropY = 0;
        targetHeight = videoHeight.toInt();
      } else {
        targetHeight = (videoWidth / targetAspectRatio).toInt();
        cropY = ((videoHeight - targetHeight) ~/ 2);
        cropX = 0;
        targetWidth = videoWidth.toInt();
      }

      targetWidth = targetWidth - (targetWidth % 2);
      targetHeight = targetHeight - (targetHeight % 2);

      command =
          '-f concat -safe 0 -i $fileListPath -vf crop=$targetWidth:$targetHeight:$cropX:$cropY -c copy $mergedVideosPath -y';
    }

    if(selectFilter != "None"){
      String filter = filterCommands[selectFilter]!;
      command = '-f concat -safe 0 -i $fileListPath -vf "$filter" -c copy $mergedVideosPath -y';
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    await FFmpegKit.execute(command).then((session) async {
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print("Merge video saved to $mergedVideosPath");

        String thumbnailPath = trimmedVideos.first['thumbnail']!;
        List<String> savedProjects = prefs.getStringList("saved_projects") ?? [];
        savedProjects.add('$mergedVideosPath|$thumbnailPath');
        prefs.setStringList('saved_projects',savedProjects);
        print("savedProjects : $savedProjects");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Final video exported to : $mergedVideosPath"),
            ),
          );
        }
      } else {
        final String? failLog = await session.getFailStackTrace();
        final String? output = await session.getOutput();
        print("Merge failed. ReturnCode: $returnCode");
        print("FFmpeg fail: $failLog");
        print("FFmpeg output: $output");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Merge failed. See console for details."),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Video editor"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                enableTransition = !enableTransition;
              });
            },
            icon: Icon(
              enableTransition
                  ? Icons.swap_horizontal_circle
                  : Icons.swap_horizontal_circle_outlined,
            ),
          ),
        ],
      ),
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
                    if (isSpeedControlVisible)
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Text(
                              "Speed : ${playbackSpeed.toStringAsFixed(1)}x",
                              style: TextStyle(color: Colors.white),
                            ),
                            Slider(
                              min: 0.5,
                              max: 3.0,
                              divisions: 6,
                              value: playbackSpeed,
                              onChanged: (value) {
                                setState(() {
                                  playbackSpeed = value;
                                  _videoPlayerController!.setPlaybackSpeed(
                                    playbackSpeed,
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              //Timeline editor
              Expanded(
                flex: 2,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: trimmedVideos.length,
                  itemBuilder: (context, index) {
                    return ReorderableDragStartListener(
                      key: ValueKey(trimmedVideos[index]['video']),
                      index: index,
                      child: Container(
                        width: 100,
                        margin: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            trimmedVideos[index]['thumbnail'] != null
                                ? Image.file(
                                    File(trimmedVideos[index]['thumbnail']!),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  )
                                : Center(child: CircularProgressIndicator()),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    trimmedVideos.removeAt(index);
                                  });
                                },
                                icon: Icon(Icons.delete, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onReorder: (int oldIndex, int newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final Map<String, String> movedClip = trimmedVideos
                        .removeAt(oldIndex);
                    trimmedVideos.insert(newIndex, movedClip);
                  },
                ),
              ),
              //Trim Slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TrimSlider(
                  controller: _videoEditorController!,
                  height: 60,
                  child: TrimTimeline(controller: _videoEditorController!),
                ),
              ),

              //Editing toolbar
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _trimVideo,
                      icon: Icon(Icons.content_cut, color: Colors.white),
                    ),
                    IconButton(
                      onPressed:() => _openCropRatioModal(context),
                      icon: Icon(Icons.crop, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          isSpeedControlVisible = !isSpeedControlVisible;
                        });
                      },
                      icon: Icon(
                        Icons.speed,
                        color: !isSpeedControlVisible
                            ? Colors.white
                            : Colors.green,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          isMuted = !isMuted;
                          _videoPlayerController!.setVolume(isMuted ? 0 : 1);
                        });
                      },
                      icon: Icon(
                        isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showFilterModal(context),
                      icon: Icon(Icons.filter,color: Colors.white),
                    ),
                  ],
                ),
              ),
              //Bottom action buttons
              Padding(
                padding: EdgeInsets.only(bottom: 25),
                child: ElevatedButton(
                  onPressed: _mergeVideos,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: Text(
                    'Merge & Export Final video',
                    style: TextStyle(fontSize: 16),
                  ),
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
