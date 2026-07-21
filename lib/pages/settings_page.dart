import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  final ValueListenable<AppSettings> settingsListenable;
  final ValueChanged<AppSettings> onChanged;

  const SettingsPage({
    super.key,
    required this.settingsListenable,
    required this.onChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _minutesController;
  late final FocusNode _minutesFocusNode;

  @override
  void initState() {
    super.initState();
    _minutesController = TextEditingController(
      text: widget.settingsListenable.value.autoSaveMinutes.toString(),
    );
    _minutesFocusNode = FocusNode()..addListener(_onMinutesFocusChanged);
  }

  void _onMinutesFocusChanged() {
    if (!_minutesFocusNode.hasFocus) _commitMinutes();
  }

  void _commitMinutes() {
    final value = int.tryParse(_minutesController.text);
    if (value == null) {
      _minutesController.text =
          widget.settingsListenable.value.autoSaveMinutes.toString();
      return;
    }

    final normalized = SettingsService.normalizeMinutes(value);
    if (_minutesController.text != normalized.toString()) {
      _minutesController.text = normalized.toString();
      _minutesController.selection = TextSelection.collapsed(
        offset: _minutesController.text.length,
      );
    }
    final settings = widget.settingsListenable.value;
    if (settings.autoSaveMinutes != normalized) {
      widget.onChanged(settings.copyWith(autoSaveMinutes: normalized));
    }
  }

  @override
  void dispose() {
    _minutesFocusNode.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: widget.settingsListenable,
      builder: (context, settings, child) {
        final minutes = settings.autoSaveMinutes.toString();
        if (!_minutesFocusNode.hasFocus && _minutesController.text != minutes) {
          _minutesController.text = minutes;
        }

        return Scaffold(
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _buildSectionTitle(context, '外观'),
              RadioGroup<ThemeMode>(
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    widget.onChanged(settings.copyWith(themeMode: value));
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text('浅色模式'),
                      value: ThemeMode.light,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text('深色模式'),
                      value: ThemeMode.dark,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text('跟随系统'),
                      value: ThemeMode.system,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionTitle(context, '编辑'),
              SwitchListTile(
                title: const Text('自动保存'),
                value: settings.autoSaveEnabled,
                onChanged: (enabled) {
                  widget.onChanged(
                    settings.copyWith(autoSaveEnabled: enabled),
                  );
                },
              ),
              if (settings.autoSaveEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '保存间隔（分钟）',
                      suffixText: '分钟',
                    ),
                    onChanged: (text) {
                      if (text.isNotEmpty) _commitMinutes();
                    },
                    onSubmitted: (_) => _commitMinutes(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
