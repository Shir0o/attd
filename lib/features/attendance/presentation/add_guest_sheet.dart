import 'package:flutter/material.dart';

class AddMemberSheet extends StatefulWidget {
  const AddMemberSheet({super.key, required this.onAdd});

  final void Function(String name, bool isPresent, bool isGuest) onAdd;

  @override
  State<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<AddMemberSheet> {
  final _nameController = TextEditingController();
  bool _isPresent = true;
  bool _isGuest = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      widget.onAdd(name, _isPresent, _isGuest);
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
              'Add Person',
              style: TextStyle(
                fontSize: 24,
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
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Name',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withAlpha(179),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Enter name',
                          ),
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 18),
                          autofocus: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Guest Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add as Guest',
                        style: TextStyle(
                          fontSize: 18,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Switch(
                        value: _isGuest,
                        onChanged: (value) => setState(() => _isGuest = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Present Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mark as Present',
                        style: TextStyle(
                          fontSize: 18,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Switch(
                        value: _isPresent,
                        onChanged: (value) =>
                            setState(() => _isPresent = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Add & Continue',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
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
