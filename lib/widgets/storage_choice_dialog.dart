import 'package:flutter/material.dart';

enum FileStorageChoice { local, webDav }

Future<FileStorageChoice?> showStorageChoiceDialog(BuildContext context) {
  return showDialog<FileStorageChoice>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('选择存储位置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('本地'),
              onTap: () => Navigator.of(context).pop(FileStorageChoice.local),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('云端'),
              onTap: () => Navigator.of(context).pop(FileStorageChoice.webDav),
            ),
          ],
        ),
      );
    },
  );
}
