import 'dart:io';

import 'package:capcut_clone/features/editor/presentation/video_editor_screen.dart';
import 'package:capcut_clone/features/home/presentation/video_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> savedProjects = [];

  @override
  void initState() {
    _loadSavedProjects();
    super.initState();
  }

  Future<void> _loadSavedProjects() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> savedData = prefs.getStringList("saved_projects") ?? [];

    setState(() {
      savedProjects = savedData.map((entry) {
        List<String> split = entry.split("|");
        return {
          "video": split[0],
          "thumbnail": split.length > 1 ? split[1] : "",
        };
      }).toList();
    });
  }

  Future<void> _deleteProject(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      File(savedProjects[index]['video']!).deleteSync();
      File(savedProjects[index]['thumbnail']!).deleteSync();
      savedProjects.removeAt(index);
      prefs.setStringList(
        'saved_projects',
        savedProjects
            .map((proj) => '${proj['video']}|${proj['thumbnail']}')
            .toList(),
      );
    });
  }

  void _showProjectNameDialog() {
    TextEditingController _projectNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Name your project"),
          content: TextField(
            controller: _projectNameController,
            decoration: InputDecoration(hintText: "Enter project name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                String projectName = _projectNameController.text.trim();
                if (projectName.isNotEmpty) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoEditorScreen(projectName: projectName),
                    ),
                  ).then((_) => _loadSavedProjects());
                }
              },
              child: Text("Create"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Capcut"), backgroundColor: Colors.black),
      body: Center(
        child: Container(
          color: Colors.black,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                onPressed: () {
                  _showProjectNameDialog();
                },
                child: Text('New Project'),
              ),
              SizedBox(height: 30),
              savedProjects.isEmpty
                  ? Text(
                      "Your projects will appear here",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    )
                  : Expanded(
                      child: ListView.builder(
                        itemCount: savedProjects.length,
                        itemBuilder: (context, index) {
                          return Card(
                            color: Colors.grey[900],
                            child: ListTile(
                              leading:
                                  savedProjects[index]['thumbnail']!.isNotEmpty
                                  ? Image.file(
                                      File(savedProjects[index]['thumbnail']!),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.video_library,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                              title: Text(
                                "Project ${index + 1}",
                                style: TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                savedProjects[index]['video']!,
                                style: TextStyle(color: Colors.white),
                              ),
                              trailing: IconButton(
                                onPressed: () => _deleteProject(index),
                                icon: Icon(Icons.delete, color: Colors.red),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VideoPreviewScreen(
                                      videoPath: savedProjects[index]['video']!,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
