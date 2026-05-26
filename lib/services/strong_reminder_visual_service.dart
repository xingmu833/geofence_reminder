import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StrongReminderVisualSelection {
  const StrongReminderVisualSelection({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
}

class StrongReminderVisualService {
  const StrongReminderVisualService();

  static const _imageKey = 'strong_reminder_visual.image_base64';
  static const _nameKey = 'strong_reminder_visual.name';

  Future<StrongReminderVisualSelection?> loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final base64Image = prefs.getString(_imageKey) ?? '';
    if (base64Image.isEmpty) {
      return null;
    }
    try {
      return StrongReminderVisualSelection(
        name: prefs.getString(_nameKey) ?? '自定义图片',
        bytes: base64Decode(base64Image),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSelection(StrongReminderVisualSelection selection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_imageKey, base64Encode(selection.bytes));
    await prefs.setString(_nameKey, selection.name);
  }

  Future<void> clearSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_imageKey);
    await prefs.remove(_nameKey);
  }

  Future<StrongReminderVisualSelection?> pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (image == null) {
      return null;
    }
    final bytes = await image.readAsBytes();
    return StrongReminderVisualSelection(
      name: image.name.isEmpty ? '自定义图片' : image.name,
      bytes: bytes,
    );
  }
}
