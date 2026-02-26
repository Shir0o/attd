import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/event.dart';
import '../data/event_repository.dart';
import '../application/setup_service.dart';

class ShareSetupDialog extends StatefulWidget {
  const ShareSetupDialog({
    super.key,
    required this.eventRepository,
    required this.setupService,
  });

  final EventRepository eventRepository;
  final SetupService setupService;

  @override
  State<ShareSetupDialog> createState() => _ShareSetupDialogState();
}

class _ShareSetupDialogState extends State<ShareSetupDialog> {
  final Set<String> _selectedIds = {};
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share Setup'),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<List<Event>>(
          stream: widget.eventRepository.streamEvents(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final events = snapshot.data!;

            if (events.isEmpty) {
              return const Text('No events to share.');
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select events and their associated members to share.'),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return CheckboxListTile(
                        title: Text(event.title),
                        value: _selectedIds.contains(event.id),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(event.id);
                            } else {
                              _selectedIds.remove(event.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedIds.isEmpty || _isLoading
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  try {
                    final bundle = await widget.setupService.createBundle(_selectedIds.toList());
                    await Share.share(
                      bundle,
                      subject: 'Attendance Setup Configuration',
                    );
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Share Setup'),
        ),
      ],
    );
  }
}
