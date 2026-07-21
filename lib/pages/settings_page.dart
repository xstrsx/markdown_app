import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/webdav_service.dart';

class SettingsPage extends StatefulWidget {
  final ValueListenable<AppSettings> settingsListenable;
  final ValueChanged<AppSettings> onChanged;
  final WebDavService Function(WebDavConfig config)? serviceFactory;

  const SettingsPage({
    super.key,
    required this.settingsListenable,
    required this.onChanged,
    this.serviceFactory,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _minutesController;
  late final FocusNode _minutesFocusNode;
  late final TextEditingController _webDavUrlController;
  late final TextEditingController _webDavUsernameController;
  late final TextEditingController _webDavPasswordController;
  late final TextEditingController _webDavRootController;
  late bool _webDavEnabled;
  bool _testingWebDav = false;

  @override
  void initState() {
    super.initState();
    _minutesController = TextEditingController(
      text: widget.settingsListenable.value.autoSaveMinutes.toString(),
    );
    _minutesFocusNode = FocusNode()..addListener(_onMinutesFocusChanged);
    final webDav = widget.settingsListenable.value.webDav;
    _webDavEnabled = webDav.enabled;
    _webDavUrlController = TextEditingController(text: webDav.serverUrl);
    _webDavUsernameController = TextEditingController(text: webDav.username);
    _webDavPasswordController = TextEditingController(text: webDav.password);
    _webDavRootController = TextEditingController(text: webDav.rootPath);
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

  WebDavConfig _draftWebDav() {
    return WebDavConfig(
      enabled: _webDavEnabled,
      serverUrl: _webDavUrlController.text.trim(),
      username: _webDavUsernameController.text.trim(),
      rootPath: _webDavRootController.text.trim(),
      password: _webDavPasswordController.text,
    );
  }

  void _saveWebDavSettings(AppSettings settings) {
    final config = _draftWebDav();
    if (_webDavEnabled && !config.isComplete) {
      _showWebDavMessage('请填写有效的 WebDAV 地址和远程根目录');
      return;
    }
    widget.onChanged(settings.copyWith(webDav: config));
    _showWebDavMessage('WebDAV 配置已保存');
  }

  Future<void> _testWebDav() async {
    final config = _draftWebDav();
    if (!config.isComplete) {
      _showWebDavMessage('请先启用 WebDAV 并填写有效配置');
      return;
    }
    setState(() => _testingWebDav = true);
    try {
      final service =
          widget.serviceFactory?.call(config) ?? WebDavService(config);
      await service.testConnection();
      if (mounted) _showWebDavMessage('WebDAV 连接成功');
    } catch (_) {
      if (mounted) _showWebDavMessage('WebDAV 连接失败，请检查配置和网络');
    } finally {
      if (mounted) setState(() => _testingWebDav = false);
    }
  }

  void _showWebDavMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _minutesFocusNode.dispose();
    _minutesController.dispose();
    _webDavUrlController.dispose();
    _webDavUsernameController.dispose();
    _webDavPasswordController.dispose();
    _webDavRootController.dispose();
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
              const SizedBox(height: 16),
              _buildSectionTitle(context, 'WebDAV 云同步'),
              SwitchListTile(
                title: const Text('启用 WebDAV'),
                value: _webDavEnabled,
                onChanged: (enabled) {
                  setState(() => _webDavEnabled = enabled);
                },
              ),
              TextField(
                controller: _webDavUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '服务器地址',
                  hintText: 'https://dav.example.com',
                ),
              ),
              TextField(
                controller: _webDavUsernameController,
                decoration: const InputDecoration(labelText: '用户名（可选）'),
              ),
              TextField(
                controller: _webDavPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码（可选）'),
              ),
              TextField(
                controller: _webDavRootController,
                decoration: const InputDecoration(
                  labelText: '远程根目录',
                  hintText: '/notes',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _testingWebDav ? null : _testWebDav,
                      child: _testingWebDav
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('测试连接'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _saveWebDavSettings(settings),
                      child: const Text('保存配置'),
                    ),
                  ),
                ],
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
