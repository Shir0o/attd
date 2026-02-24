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

  // Colors from design
  static const primaryColor = Color(0xFF6750A4);
  static const onPrimaryColor = Color(0xFFFFFFFF);
  static const onSurfaceColor = Color(0xFF1D1B20);
  static const onSurfaceVariantColor = Color(0xFF49454F);
  static const surfaceContainerColor = Color(0xFFF3EDF7);
  static const tertiaryContainerColor = Color(0xFFFFD8E4);

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
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: surfaceContainerColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
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
                color: onSurfaceVariantColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            const Text(
              'Add Guest',
              style: TextStyle(
                fontSize: 22,
                color: onSurfaceColor,
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
                    decoration: const BoxDecoration(
                      color: tertiaryContainerColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Guest Name',
                        labelStyle: TextStyle(color: onSurfaceVariantColor),
                        contentPadding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: onSurfaceVariantColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                      style: const TextStyle(color: onSurfaceColor),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mark as Present',
                        style: TextStyle(fontSize: 16, color: onSurfaceColor),
                      ),
                      Switch(
                        value: _isPresent,
                        onChanged: (value) =>
                            setState(() => _isPresent = value),
                        thumbColor:
                            WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return primaryColor;
                              }
                              return null;
                            }),
                        trackColor:
                            WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return primaryColor.withValues(alpha: 0.5);
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
                        backgroundColor: primaryColor,
                        foregroundColor: onPrimaryColor,
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
