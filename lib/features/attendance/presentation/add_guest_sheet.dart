import 'package:flutter/material.dart';
import '../models/member.dart';

class AddMemberSheet extends StatefulWidget {
  const AddMemberSheet({
    super.key,
    required this.onAdd,
    this.availableMembers = const [],
  });

  final void Function(
    String name,
    bool isPresent,
    bool isGuest,
    Member? existingMember,
  ) onAdd;
  final List<Member> availableMembers;

  @override
  State<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<AddMemberSheet> {
  final _nameController = TextEditingController();
  bool _isPresent = true;
  bool _isGuest = false;
  Member? _selectedExistingMember;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty || _selectedExistingMember != null) {
      widget.onAdd(
        _selectedExistingMember?.displayName ?? name,
        _isPresent,
        _selectedExistingMember != null ? false : _isGuest,
        _selectedExistingMember,
      );
      Navigator.of(context).pop();
    }
  }

  void _selectMember(Member member) {
    setState(() {
      _selectedExistingMember = member;
      _nameController.text = member.displayName;
      _isGuest = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final query = _nameController.text.toLowerCase().trim();
    final suggestions = query.isEmpty
        ? <Member>[]
        : widget.availableMembers
            .where((m) =>
                m.displayName.toLowerCase().contains(query) &&
                m.id != _selectedExistingMember?.id)
            .take(3)
            .toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
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
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              'Add Person',
              style: TextStyle(
                fontSize: 22,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Name Input
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 18),
                    onChanged: (val) {
                      if (_selectedExistingMember != null &&
                          val != _selectedExistingMember!.displayName) {
                        setState(() {
                          _selectedExistingMember = null;
                        });
                      } else {
                        setState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'Enter name',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHigh,
                      suffixIcon: _selectedExistingMember != null
                          ? Icon(Icons.check_circle, color: colorScheme.primary)
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),

                  // Suggestions
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: suggestions.map((member) {
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(
                                member.displayName[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(member.displayName),
                            subtitle: const Text('Existing Member'),
                            onTap: () => _selectMember(member),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Guest Switch - Hide if existing member selected
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _selectedExistingMember == null
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Add as Guest',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                Switch(
                                  value: _isGuest,
                                  onChanged: (value) =>
                                      setState(() => _isGuest = value),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Present Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mark as Present',
                        style: TextStyle(
                          fontSize: 18,
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w400,
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
                    height: 56,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _selectedExistingMember != null
                            ? 'Add Existing'
                            : 'Add & Continue',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
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
