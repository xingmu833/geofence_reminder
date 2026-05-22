import 'package:flutter/material.dart';

import '../services/alarm_audio_service.dart';
import '../services/app_settings_store.dart';
import '../widgets/app_feedback_dialog.dart';

class AlarmSoundScreen extends StatefulWidget {
  const AlarmSoundScreen({super.key});

  @override
  State<AlarmSoundScreen> createState() => _AlarmSoundScreenState();
}

class _AlarmSoundScreenState extends State<AlarmSoundScreen> {
  final AppSettingsStore _settingsStore = const AppSettingsStore();
  final AlarmAudioService _alarmAudioService = const AlarmAudioService();
  AppSettingsSnapshot? _settings;
  AlarmSoundSetting _selectedSound = AlarmSoundSetting.defaultValue;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _alarmAudioService.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _settingsStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _selectedSound = settings.alarmSound;
      _isLoading = false;
    });
  }

  Future<void> _preview(AlarmSoundSetting sound) async {
    setState(() => _selectedSound = sound);
    await _alarmAudioService.start(sound);
  }

  Future<void> _pickLocalAudio() async {
    try {
      final picked = await _alarmAudioService.pickLocalAudio();
      if (picked == null) {
        return;
      }
      await _preview(
        AlarmSoundSetting(
          source: AlarmSoundSource.localFile,
          id: 'local',
          name: picked.name,
          uri: picked.uri,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await AppFeedbackDialog.show(
        context,
        title: '选择失败',
        message: '$error\n\n如果刚更新过原生代码，请卸载旧应用后重新运行安装。',
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _save() async {
    final current = _settings ?? await _settingsStore.load();
    await _settingsStore.save(current.copyWith(alarmSound: _selectedSound));
    await _alarmAudioService.stop();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  bool _isSelected(AlarmSoundSetting sound) {
    return _selectedSound.source == sound.source &&
        _selectedSound.id == sound.id &&
        _selectedSound.uri == sound.uri;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('闹钟铃声'),
        actions: [
          IconButton(
            tooltip: '确认',
            onPressed: _isLoading ? null : _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                _Section(
                  title: '内置铃声',
                  children: [
                    for (final sound in AlarmSoundSetting.builtInSounds)
                      _SoundTile(
                        icon: Icons.music_note_outlined,
                        title: sound.name,
                        subtitle: '点击试听，右上角确认后生效',
                        selected: _isSelected(sound),
                        onTap: () => _preview(sound),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _Section(
                  title: '本地音频',
                  children: [
                    _SoundTile(
                      icon: Icons.audio_file_outlined,
                      title: _selectedSound.source == AlarmSoundSource.localFile
                          ? _selectedSound.name
                          : '选择本地音频',
                      subtitle: '支持系统文件选择器中可读取的音频',
                      selected:
                          _selectedSound.source == AlarmSoundSource.localFile,
                      onTap: _pickLocalAudio,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _alarmAudioService.stop,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('停止试听'),
                ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Divider(height: 1, indent: 64),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SoundTile extends StatelessWidget {
  const _SoundTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      onTap: onTap,
    );
  }
}
