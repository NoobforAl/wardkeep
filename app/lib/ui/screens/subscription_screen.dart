import 'package:flutter/material.dart';
import '../motion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine.dart';
import '../../l10n/errors.dart';
import '../../l10n/l10n.dart';
import '../../state/subscriptions.dart';
import '../insets.dart';
import '../widgets/warning_list.dart';

/// Adds a subscription (or edits one when [existing] is given).
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key, this.initialUrl = '', this.existing});

  final String initialUrl;
  final Subscription? existing;

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  static Map<String, String> _viaChoices(AppLocalizations l) => {
    'direct': l.subViaDirect,
    'auto': l.subViaAuto,
    'tunnel': l.subViaTunnel,
  };

  static Map<String, String> _authTypes(AppLocalizations l) => {
    'none': l.authNone,
    'basic': l.authBasic,
    'bearer': l.authBearer,
    'header': l.authHeader,
    'query': l.authQuery,
  };

  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _url = TextEditingController(text: widget.existing?.url ?? widget.initialUrl);
  late final _username = TextEditingController(text: widget.existing?.auth.username ?? '');
  late final _password = TextEditingController(text: widget.existing?.auth.password ?? '');
  late final _token = TextEditingController(text: widget.existing?.auth.token ?? '');
  late final _header = TextEditingController(text: widget.existing?.auth.header ?? '');
  late final _queryKey = TextEditingController(text: widget.existing?.auth.queryKey ?? 'token');
  late final _key = TextEditingController(text: widget.existing?.publicKey ?? '');
  late final _backups = TextEditingController(text: (widget.existing?.fallbackUrls ?? const <String>[]).join('\n'));
  late String _authType = widget.existing?.auth.type ?? 'none';
  late String _via = widget.existing?.via ?? Subscription.defaultVia;
  bool _busy = false;
  bool _showSecret = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _url, _username, _password, _token, _header, _queryKey, _key, _backups]) {
      c.dispose();
    }
    super.dispose();
  }

  SubscriptionAuth get _auth => SubscriptionAuth(
        type: _authType,
        username: _authType == 'basic' ? _username.text.trim() : '',
        password: _authType == 'basic' ? _password.text : '',
        token: const ['bearer', 'header', 'query'].contains(_authType) ? _token.text.trim() : '',
        header: _authType == 'header' ? _header.text.trim() : '',
        queryKey: _authType == 'query' ? _queryKey.text.trim() : '',
      );

  List<String> get _backupUrls => [
        for (final line in _backups.text.split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ];

  static bool _isAddress(String s) {
    final uri = Uri.tryParse(s);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https') || uri.isScheme('nordvpn')) && uri.host.isNotEmpty;
  }

  String? _validate(AppLocalizations l) {
    final (link, linkKey) = Subscription.splitKey(_url.text.trim());
    if (_key.text.trim().isNotEmpty && !Subscription.isValidKey(_key.text)) return l.subErrKey;
    if (_key.text.trim().isEmpty && linkKey.isNotEmpty && !Subscription.isValidKey(linkKey)) return l.subErrKey;
    if (_backupUrls.any((u) => !_isAddress(u))) return l.subErrUrl;
    final uri = Uri.tryParse(link);
    // nordvpn://<access token>?country=DE gives NordLynx (WireGuard) servers.
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https') || uri.isScheme('nordvpn')) || uri.host.isEmpty) {
      return l.subErrUrl;
    }
    if (_authType == 'header' && _header.text.trim().isEmpty) return l.subErrHeader;
    if (const ['bearer', 'header', 'query'].contains(_authType) && _token.text.trim().isEmpty) {
      return l.subErrToken;
    }
    return null;
  }

  Future<void> _save() async {
    final l = context.l10n;
    final problem = _validate(l);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ctrl = ref.read(subscriptionsProvider.notifier);
    try {
      final int count;
      final existing = widget.existing;
      if (existing == null) {
        count = await ctrl.add(
          url: _url.text,
          name: _name.text.trim(),
          auth: _auth,
          via: _via,
          fallbackUrls: _backupUrls,
          publicKey: _key.text,
        );
      } else {
        final (link, linkKey) = Subscription.splitKey(_url.text.trim());
        final key = _key.text.trim().isNotEmpty ? _key.text.trim() : linkKey;
        ctrl.update(existing.copyWith(
          name: _name.text.trim(),
          url: link,
          auth: _auth,
          via: _via,
          fallbackUrls: _backupUrls,
          publicKey: key,
        ));
        // A new key, or a save after "older than the last one accepted", starts the replay check over.
        if (key != existing.publicKey || existing.lastErrorCode == 'SUB_STALE') ctrl.forgetSignature(existing.id);
        count = await ctrl.refresh(existing.id);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.subUpdatedToast(count))));
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(l, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final secret = _showSecret ? null : '•';
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? l.subAddTitle : l.subEditTitle)),
      // The button is part of the body, not a Scaffold footer: the body shrinks above the
      // keyboard, a footer would stay behind it.
      body: Column(children: [
        Expanded(
          child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autofocus: widget.existing == null && widget.initialUrl.isEmpty,
            decoration: InputDecoration(
              labelText: l.subUrlLabel,
              hintText: l.subUrlHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l.subNameLabel,
              helperText: l.subNameHelp,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _authType,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.subAuthLabel, border: const OutlineInputBorder()),
            items: [
              for (final e in _authTypes(l).entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _authType = v ?? 'none'),
          ),
          const SizedBox(height: 12),
          SoftAppear(
            show: _authType == 'basic',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            TextField(
              controller: _username,
              decoration: InputDecoration(labelText: l.subUsername, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: !_showSecret,
              obscuringCharacter: secret ?? '•',
              decoration: InputDecoration(
                labelText: l.subPassword,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showSecret = !_showSecret),
                  icon: Icon(_showSecret ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
            ]),
          ),
          SoftAppear(
            show: _authType == 'header',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            TextField(
              controller: _header,
              decoration: InputDecoration(
                labelText: l.subHeaderName,
                hintText: 'X-Api-Key',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ]),
          ),
          SoftAppear(
            show: _authType == 'query',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            TextField(
              controller: _queryKey,
              decoration: InputDecoration(labelText: l.subParamName, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            ]),
          ),
          SoftAppear(
            show: const ['bearer', 'header', 'query'].contains(_authType),
            child: TextField(
              controller: _token,
              obscureText: !_showSecret,
              decoration: InputDecoration(
                labelText: _authType == 'header' ? l.subHeaderValue : l.subToken,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showSecret = !_showSecret),
                  icon: Icon(_showSecret ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _via,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.subDownloadLabel,
              helperText: l.subDownloadHelp,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final e in _viaChoices(l).entries)
                DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _via = v ?? Subscription.defaultVia),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _key,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l.subKeyLabel,
              helperText: l.subKeyHelp,
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          ListenableBuilder(
            listenable: _key,
            builder: (context, _) => _key.text.trim().isEmpty && !_url.text.contains('#pk=')
                ? const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: WarningList([WarningSpec(code: 'SUB_UNSIGNED', text: 'This list is not signed.', risk: false)]),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _backups,
            keyboardType: TextInputType.multiline,
            minLines: 2,
            maxLines: 5,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l.subBackupLabel,
              helperText: l.subBackupHelp,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
          ),
          SoftAppear(
            show: _error != null,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error ?? '', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ),
        ],
          ),
        ),
        PinnedAction(
          child: FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_download_outlined),
            label: Text(widget.existing == null ? l.subAddAndDownload : l.subSaveAndRefresh),
          ),
        ),
      ]),
    );
  }
}
