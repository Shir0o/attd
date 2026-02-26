import 'package:flutter/material.dart';

class AddGuestSheet extends StatefulWidget {
  const AddGuestSheet({super.key, required this.onAdd});

  final void Function(String name, bool isPresent) onAdd;

  @override
  State<AddGuestSheet> createState() => _AddGuestSheetState();
}

class _AddGuestSheetState extends State<AddGuestSheet> {
  final _nameController = TextEditingController();
  bool _isPresent = true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      widget.onAdd(name, _isPresent);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 16),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              'Add Guest',
              style: TextStyle(
                fontSize: 22,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 24),

            // Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Name Input
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Guest Name',
                        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: colorScheme.onSurfaceVariant),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                        ),
                      ),
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mark as Present',
                        style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
                      ),
                      Switch(
                        value: _isPresent,
                        onChanged: (value) =>
                            setState(() => _isPresent = value),
                        thumbColor:
                            WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return colorScheme.primary;
                              }
                              return null;
                            }),
                        trackColor:
                            WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return colorScheme.primary.withValues(alpha: 0.5);
                              }
                              return null;
                            }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: const Text('Add & Continue'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
