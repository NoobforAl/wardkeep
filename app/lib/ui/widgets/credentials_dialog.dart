import 'package:flutter/material.dart';
import '../motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';

/// Asks for the username and password of [profile] and saves them.
/// Returns true when saved.
Future<bool> askCredentials(BuildContext context, WidgetRef ref, ProfileInfo profile) async {
  final creds = await showDialog<(String, String)>(
    animationStyle: softAnimation,
    context: context,
    builder: (_) => _CredentialsDialog(profile: profile),
  );
  if (creds == null) return false;
  ref.read(profilesProvider.notifier).setCredentials(profile.id, creds.$1, creds.$2);
  return true;
}

/// The dialog owns its text controllers, so they are disposed once it has left the screen.
class _CredentialsDialog extends StatefulWidget {
  const _CredentialsDialog({required this.profile});

  final ProfileInfo profile;

  @override
  State<_CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends State<_CredentialsDialog> {
  late final _user = TextEditingController(text: widget.profile.raw['username'] as String? ?? '');
  late final _pass = TextEditingController(text: widget.profile.raw['password'] as String? ?? '');
  var _obscure = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Scrolls when the keyboard leaves too little room (a small phone).
      scrollable: true,
      title: Text(context.l10n.credTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.credNeeds(widget.profile.name)),
          const SizedBox(height: 12),
          TextField(
            controller: _user,
            autofocus: true,
            autocorrect: false,
            decoration: InputDecoration(labelText: context.l10n.credUsername),
          ),
          TextField(
            controller: _pass,
            obscureText: _obscure,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: context.l10n.credPassword,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.actionCancel)),
        FilledButton(
          onPressed: () {
            if (_user.text.trim().isEmpty || _pass.text.isEmpty) return;
            Navigator.pop(context, (_user.text.trim(), _pass.text));
          },
          child: Text(context.l10n.actionSave),
        ),
      ],
    );
  }
}
