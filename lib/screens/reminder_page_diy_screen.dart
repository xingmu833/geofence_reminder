import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/strong_reminder_visual_service.dart';
import '../widgets/strong_reminder_visual_frame.dart';

class ReminderPageDiyScreen extends StatefulWidget {
  const ReminderPageDiyScreen({super.key});

  @override
  State<ReminderPageDiyScreen> createState() => _ReminderPageDiyScreenState();
}

class _ReminderPageDiyScreenState extends State<ReminderPageDiyScreen> {
  final StrongReminderVisualService _service =
      const StrongReminderVisualService();

  StrongReminderVisualSelection? _selection;
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final selection = await _service.loadSelection();
    if (!mounted) {
      return;
    }
    setState(() {
      _selection = selection;
      _bytes = selection?.bytes;
      _loading = false;
    });
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _service.pickImage();
      if (picked == null) {
        return;
      }
      await _service.saveSelection(picked);
      if (!mounted) {
        return;
      }
      setState(() {
        _selection = picked;
        _bytes = picked.bytes;
      });
      _showMessage('已应用到强提醒页面');
    } on MissingPluginException {
      _showMessage('图片选择器尚未完成重启，请重新启动应用后再试');
    } catch (_) {
      _showMessage('图片选择失败');
    }
  }

  Future<void> _resetImage() async {
    await _service.clearSelection();
    if (!mounted) {
      return;
    }
    setState(() {
      _selection = null;
      _bytes = null;
    });
    _showMessage('已恢复默认图片');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          foregroundColor: const Color(0xFF10203F),
          title: const Text('提醒页面DIY'),
          centerTitle: false,
        ),
        body: Stack(
          children: [
            const _Backdrop(),
            const Positioned(
              top: 70,
              right: -40,
              child: _Orb(color: Color(0x33C9E5FF), size: 170),
            ),
            const Positioned(
              bottom: 100,
              left: -34,
              child: _Orb(color: Color(0x33DDEDD7), size: 190),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final frameWidth = width.clamp(280.0, 420.0).toDouble();
                  final frameHeight = frameWidth * 0.78;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '自定义全屏强提醒页的卡通人物',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF10203F),
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '上传后会同步到强提醒页面预览和真机触发页，图片会自动适配卡片尺寸。',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: const Color(0xFF60708F),
                                          height: 1.35,
                                        ),
                                  ),
                                  const SizedBox(height: 18),
                                  Center(
                                    child: StrongReminderVisualFrame(
                                      width: frameWidth,
                                      height: frameHeight,
                                      imageBytes: _bytes,
                                      angle: -0.03,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.preview_outlined,
                                        size: 18,
                                        color: Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selection == null
                                              ? '当前使用默认图片'
                                              : '当前图片：${_selection!.name}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF344863),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FilledButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.upload_outlined),
                                    label: const Text('选择图片'),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed:
                                        _selection == null ? null : _resetImage,
                                    icon: const Icon(Icons.restore_outlined),
                                    label: const Text('恢复默认'),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _loading
                                        ? '正在加载预览...'
                                        : '支持在手机本地选择图片，建议使用清晰的 PNG / JPG。',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF60708F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.84)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7FAFF), Color(0xFFF4F8F6), Color(0xFFFFFBF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
