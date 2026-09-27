import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../data/cisa_sync_service.dart';

class CisaSyncSettingsPage extends StatefulWidget {
  const CisaSyncSettingsPage({
    super.key,
    this.cisaSyncService,
  });

  final CisaSyncService? cisaSyncService;

  @override
  State<CisaSyncSettingsPage> createState() => _CisaSyncSettingsPageState();
}

class _CisaSyncSettingsPageState extends State<CisaSyncSettingsPage> {
  late final CisaSyncService _syncService;
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isSaving = false;
  bool _obscureToken = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _syncService = widget.cisaSyncService ?? CisaSyncService();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _urlController.text = prefs.getString(CisaSyncService.keyCisaSyncUrl) ?? '';
      _tokenController.text = prefs.getString(CisaSyncService.keyCisaSyncToken) ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    await _syncService.saveConfig(
      cisaSyncUrl: _urlController.text,
      cisaSyncToken: _tokenController.text,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    if (widget.cisaSyncService == null) {
      _syncService.close();
    }
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CISA Campus Tracker'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ConvCardSoft(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: c.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.sync_alt, color: c.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Attendance Sync Integration',
                              style: AppTypography.geist(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Configure your team\'s CISA Campus Work Tracker intake endpoint and secret Sync Token to synchronize gathering attendance records.',
                        style: AppTypography.geist(
                          fontSize: 14,
                          color: c.ink3,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        key: const ValueKey('cisa_sync_url_field'),
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: 'Intake Endpoint URL',
                          hintText: 'https://cisa-tracker.../api/attendance-sync',
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_urlController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  tooltip: 'Clear URL',
                                  onPressed: () {
                                    _urlController.clear();
                                    _saveConfig();
                                  },
                                ),
                              if (_isSaving)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        onChanged: (_) => _saveConfig(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('cisa_sync_token_field'),
                        controller: _tokenController,
                        obscureText: _obscureToken,
                        decoration: InputDecoration(
                          labelText: 'Sync Token',
                          hintText: 'Secret Sync Token',
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _obscureToken ? Icons.visibility_off : Icons.visibility,
                                  size: 20,
                                ),
                                tooltip: _obscureToken ? 'Show Token' : 'Hide Token',
                                onPressed: () {
                                  setState(() {
                                    _obscureToken = !_obscureToken;
                                  });
                                },
                              ),
                              if (_tokenController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  tooltip: 'Clear Token',
                                  onPressed: () {
                                    _tokenController.clear();
                                    _saveConfig();
                                  },
                                ),
                            ],
                          ),
                        ),
                        onChanged: (_) => _saveConfig(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Tokens can be generated from the CISA Web Settings page under Attendance Tracker integration.',
                    style: AppTypography.geist(
                      fontSize: 12,
                      color: c.ink4,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
