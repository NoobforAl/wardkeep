import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine.dart';
import '../../l10n/errors.dart';
import '../../l10n/l10n.dart';
import '../../state/groups.dart';
import '../../state/providers.dart';
import '../import_file.dart';
import '../insets.dart';
import '../layout.dart';
import '../motion.dart';
import '../widgets/menu_item.dart';
import '../widgets/notice.dart';
import 'qr_scan_screen.dart';
import 'subscription_screen.dart';

/// Opens the page that imports servers: a QR code, the clipboard, a file, a subscription, Tor, or text typed in.
Future<void> showImport(BuildContext context) {
  return Navigator.of(context).push(AppRoute<void>(builder: (_) => const ImportScreen()));
}

/// The link schemes the core reads (listed under "Supported formats"; the core does the reading, this is only
/// what the user is told).
const _schemes = [
  'vless://',
  'vmess://',
  'trojan://',
  'ss://',
  'hysteria2://',
  'hysteria://',
  'tuic://',
  'wireguard://',
  'awg://',
  'anytls://',
  'ssh://',
  'naive+https://',
  'tor://',
  'tailscale://',
  'dnstt://',
  'rvpn://',
];

/// From this width of the page's content the methods and the text field stand side by side.
const _twoColumns = 600.0;

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _controller = TextEditingController();
  final _noticeKey = GlobalKey();
  String? _message;

  /// Why entries failed, one line each (shown under the message), as the core words them.
  List<String> _details = const [];

  /// Whether the message is about an import that worked in part (amber) and not one that failed (red).
  bool _partial = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Shows [message] under the text field and scrolls it into view (on a phone it can be below the fold).
  void _say(String message, {List<String> details = const [], bool partial = false}) {
    setState(() {
      _busy = false;
      _partial = partial;
      _message = message;
      _details = details;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _noticeKey.currentContext;
      if (target != null && target.mounted) {
        unawaited(Scrollable.ensureVisible(target, duration: soft(context, 300), alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd));
      }
    });
  }

  /// Pastes the clipboard into the field and imports it at once.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      _say(context.l10n.importClipboardEmpty, partial: true);
      return;
    }
    _controller.text = text;
    await _import();
  }

  Future<void> _openFile() async {
    try {
      final file = await FilePicker.pickFile(dialogTitle: context.l10n.openTextFile);
      if (file == null) return;
      _controller.text = await readImportFile(file);
    } catch (e) {
      if (!mounted) return;
      _say(describeFileProblem(context.l10n, e));
      return;
    }
    await _import();
  }

  Future<void> _scanQr() async {
    final text = await Navigator.of(context).push<String>(
      AppRoute(builder: (_) => const QrScanScreen()),
    );
    if (text == null || !mounted) return;
    _controller.text = text;
    await _import();
  }

  void _addTor(String kind) {
    _controller.text = 'tor://$kind';
    unawaited(_import());
  }

  /// Opens the subscription form in place of this page, optionally prefilled.
  void _openSubscription([String url = '']) {
    unawaited(Navigator.of(context).pushReplacement<void, void>(
      AppRoute<void>(builder: (_) => SubscriptionScreen(initialUrl: url)),
    ));
  }

  Future<void> _import() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // A single http(s) or nordvpn:// URL is a subscription link, not a config.
    if (!text.contains('\n') && RegExp(r'^(https?|nordvpn)://\S+$').hasMatch(text)) {
      _openSubscription(text);
      return;
    }
    setState(() {
      _busy = true;
      _partial = false;
      _message = null;
      _details = const [];
    });
    final ImportResult result;
    try {
      result = await ref.read(engineProvider).importText(_controller.text);
    } catch (e) {
      // The core could not be asked at all (it is not running, the connection to it broke): say so.
      if (!mounted) return;
      _say(context.l10n.importNothing(describeError(context.l10n, e)));
      return;
    }
    final added = ref.read(profilesProvider.notifier).addAll(ref.read(groupsProvider.notifier).place(_controller.text, result.profiles));
    if (!mounted) return;
    if (result.profiles.isNotEmpty && result.errors.isEmpty) {
      final messenger = ScaffoldMessenger.of(context);
      final words = context.l10n.importedProfiles(added, result.profiles.length - added);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(words)));
      return;
    }
    // What the core says went wrong with each entry: the errors of a partial import, or the reasons that came
    // along with a failure (without any, the failure's own message is already the message above).
    final failure = result.failure;
    final reasons = failure == null
        ? result.errors
        : (failure.args['details'] ?? '').split('\n').where((l) => l.isNotEmpty).toList();
    _say(
      result.profiles.isEmpty && result.errors.isNotEmpty
          ? context.l10n.importNothing(failure != null ? describeError(context.l10n, failure) : result.errors.first)
          : context.l10n.importPartial(added, result.errors.length),
      details: reasons,
      partial: result.profiles.isNotEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.importTitle)),
      // The Import button is part of the body, not a Scaffold footer: the body shrinks above the keyboard,
      // a footer would stay behind it.
      body: Column(children: [
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= _twoColumns;
            final header = Text(
              l.importDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            );
            final methods = _Methods(
              busy: _busy,
              onScanQr: QrScanScreen.supported ? _scanQr : null,
              onPaste: _paste,
              onOpenFile: _openFile,
              onSubscription: _openSubscription,
              onTor: _addTor,
            );
            final form = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(context),
                // A failure is a red notice on the page itself; an import that worked in part is amber.
                if (_message != null)
                  Padding(
                    key: _noticeKey,
                    padding: const EdgeInsets.only(top: 12),
                    child: Notice(
                      message: _message!,
                      details: _details,
                      detailsTitle: l.importDetails,
                      tone: _partial ? NoticeTone.warning : NoticeTone.error,
                      messageKey: const Key('importMessage'),
                      detailsKey: const Key('importDetails'),
                    ),
                  ),
                const SizedBox(height: 8),
                const _Formats(),
              ],
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: wide
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: methods),
                            const SizedBox(width: 20),
                            Expanded(child: form),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [header, const SizedBox(height: 16), methods, const SizedBox(height: 20), form],
                    ),
            );
          }),
        ),
        PinnedAction(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => FilledButton.icon(
              onPressed: _busy || value.text.trim().isEmpty ? null : _import,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded),
              label: Text(l.actionImport),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _field(BuildContext context) {
    final l = context.l10n;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) => TextField(
        key: const Key('importText'),
        controller: _controller,
        enabled: !_busy,
        minLines: 4,
        maxLines: 12,
        keyboardType: TextInputType.multiline,
        autocorrect: false,
        enableSuggestions: false,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          labelText: l.importTextLabel,
          alignLabelWithHint: true,
          hintText: 'vless://…',
          border: const OutlineInputBorder(),
          suffixIcon: value.text.isEmpty
              ? null
              : Align(
                  alignment: AlignmentDirectional.topEnd,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: IconButton(
                    tooltip: l.actionClear,
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => setState(() {
                      _controller.clear();
                      _message = null;
                      _details = const [];
                    }),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The ways to import, as large cards: two to a row where they fit, one under the other where they do not
/// (a narrow column, a large font).
class _Methods extends StatelessWidget {
  const _Methods({
    required this.busy,
    required this.onScanQr,
    required this.onPaste,
    required this.onOpenFile,
    required this.onSubscription,
    required this.onTor,
  });

  final bool busy;

  /// Null where there is no camera scanner.
  final VoidCallback? onScanQr;
  final VoidCallback onPaste, onOpenFile, onSubscription;
  final void Function(String kind) onTor;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return LayoutBuilder(builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final grid = box.maxWidth / scale >= 320;
      _MethodCard card(Key key, IconData icon, String title, String hint, VoidCallback? onTap) =>
          _MethodCard(key: key, icon: icon, title: title, hint: hint, onTap: busy ? null : onTap, stacked: grid);
      final cards = <Widget>[
        if (onScanQr != null) card(const Key('importScanQr'), Icons.qr_code_scanner_rounded, l.importScanQrTitle, l.importScanQrHint, onScanQr),
        card(const Key('importPaste'), Icons.content_paste_rounded, l.importPasteTitle, l.importPasteHint, onPaste),
        card(const Key('importOpenFile'), Icons.file_open_outlined, l.importOpenFile, l.importOpenFileHint, onOpenFile),
        card(const Key('importSubscription'), Icons.add_link_rounded, l.importSubscriptionTitle, l.importSubscriptionHint, onSubscription),
      ];
      final tor = PopupMenuButton<String>(
        key: const Key('importTor'),
        enabled: !busy,
        tooltip: l.importAddTor,
        onSelected: onTor,
        itemBuilder: (_) => [
          iconMenuItem('', Icons.bolt_rounded, l.importTorDirect),
          iconMenuItem('snowflake', Icons.ac_unit_rounded, l.importTorSnowflake),
          iconMenuItem('obfs4', Icons.shield_outlined, l.importTorObfs4),
        ],
        // The menu button handles the tap; the card only shows what it is.
        child: IgnorePointer(
          child: _MethodCard(
            icon: Icons.security_rounded,
            title: l.importTor,
            hint: l.importTorHint,
            onTap: busy ? null : () {},
            stacked: grid && cards.length.isOdd,
          ),
        ),
      );
      cards.add(tor);
      const gap = 12.0;
      if (!grid) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, c) in cards.indexed) ...[if (i > 0) const SizedBox(height: gap), c],
          ],
        );
      }
      // Two to a row, each row as tall as its taller card; an odd one out takes the whole last row.
      final rows = <Widget>[];
      for (var i = 0; i < cards.length; i += 2) {
        if (i > 0) rows.add(const SizedBox(height: gap));
        rows.add(i + 1 < cards.length
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: cards[i]), const SizedBox(width: gap), Expanded(child: cards[i + 1])],
                ),
              )
            : cards[i]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    });
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({super.key, required this.icon, required this.title, required this.hint, required this.onTap, required this.stacked});

  final IconData icon;
  final String title, hint;
  final VoidCallback? onTap;

  /// Icon above the words (a card in a row of two) rather than beside them.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    final badge = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: scheme.primary, size: 22),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [badge, const SizedBox(height: 10), words],
                  )
                : Row(children: [badge, const SizedBox(width: 14), Expanded(child: words)]),
          ),
        ),
      ),
    );
  }
}

/// What the core can read, folded away until asked for.
class _Formats extends StatelessWidget {
  const _Formats();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    Widget item(String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 2, end: 8),
                child: Icon(Icons.check_rounded, size: 16, color: scheme.primary),
              ),
              Expanded(child: Text(text, style: small)),
            ],
          ),
        );
    return ExpansionTile(
      key: const Key('importFormats'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsetsDirectional.only(bottom: 8),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Icons.info_outline_rounded),
      title: Text(l.importFormatsTitle, style: theme.textTheme.titleSmall),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.importFormatsLinks, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        // Scheme names read left to right in every language.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in _schemes)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(6)),
                  child: Text(s, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        item(l.importFormatsSubscriptions),
        item(l.importFormatsConfigs),
        item(l.importFormatsWireGuard),
        item(l.importFormatsOpenVpn),
        item(l.importFormatsTorBridges),
      ],
    );
  }
}
