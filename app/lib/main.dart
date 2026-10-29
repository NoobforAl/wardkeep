import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'engine/engine.dart';
import 'l10n/errors.dart';
import 'l10n/l10n.dart';
import 'state/incoming.dart';
import 'state/log_alerts.dart';
import 'state/providers.dart';
import 'state/store.dart';
import 'state/subscriptions.dart';
import 'state/window_bounds.dart';
import 'ui/incoming_import.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/logs_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/profiles_screen.dart';
import 'ui/theme.dart';
import 'ui/system_notifications.dart';
import 'ui/tray.dart';
import 'ui/widgets/notice.dart';
import 'ui/widgets/splash.dart';
import 'ui/widgets/window_frame.dart';
import 'ui/layout.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  startInBackground = args.contains('--background');
  final store = await AppStore.open();
  await _setUpWindow(store);
  // On a computer, opening a link or config file with Wardkeep starts it with that as an argument.
  final startup = await IncomingShare.fromArguments(args);
  runApp(ProviderScope(
    overrides: [storeProvider.overrideWithValue(store), startupSharesProvider.overrideWithValue(startup)],
    child: const OmnitunApp(),
  ));
}

/// On a computer (Windows, macOS, Linux) the system's title bar (its own minimize, maximize and close buttons,
/// in the system's colours) is replaced by the app's own, drawn by [WindowFrame] with that system's buttons, and the window is sized from the
/// monitor instead of a fixed size, can be resized by every edge, and opens where it was left. If the
/// window cannot be set up the system's bar and size stay, so the app is never left without them.
Future<void> _setUpWindow(AppStore store) async {
  if (kIsWeb || !(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
  try {
    await windowManager.ensureInitialized();
    final bounds = openingBounds(
      displays: await _usableDisplays(),
      saved: boundsFromJson(store.read<Object>('window')),
    );
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        title: 'Wardkeep',
        minimumSize: minWindowSize,
      ),
      () async {
        await windowManager.setBounds(bounds);
        // Started by Windows at sign-in: stays in the tray until it is opened.
        if (startInBackground) return;
        await windowManager.show();
        await windowManager.focus();
      },
    );
    windowManager.addListener(_WindowMemory(store));
    customTitleBar = true;
  } catch (_) {}
}

/// The usable area (without the task bar) of every monitor, in logical pixels, the primary one first.
Future<List<Rect>> _usableDisplays() async {
  final primary = await screenRetriever.getPrimaryDisplay();
  final all = await screenRetriever.getAllDisplays();
  Rect usable(Display d) {
    final size = d.visibleSize ?? d.size;
    final at = d.visiblePosition ?? Offset.zero;
    return Rect.fromLTWH(at.dx, at.dy, size.width, size.height);
  }

  return [usable(primary), for (final d in all) if (d.id != primary.id) usable(d)];
}

/// Remembers where the user left the window (size and place) for the next start, and fits it to the
/// monitor it is moved to: a window sized for a big monitor would hang off a smaller one.
class _WindowMemory with WindowListener {
  _WindowMemory(this._store);

  final AppStore _store;
  Timer? _later;

  void _remember() {
    _later?.cancel();
    _later = Timer(const Duration(milliseconds: 400), () async {
      // A maximized, minimized or full screen window has no size of its own to remember.
      if (await windowManager.isMaximized() || await windowManager.isMinimized() || await windowManager.isFullScreen()) {
        return;
      }
      _store.write('window', boundsToJson(await windowManager.getBounds()));
    });
  }

  @override
  void onWindowResized() => _remember();

  @override
  void onWindowMoved() {
    _fit();
    _remember();
  }

  Future<void> _fit() async {
    try {
      if (await windowManager.isMaximized() || await windowManager.isMinimized() || await windowManager.isFullScreen()) {
        return;
      }
      final now = await windowManager.getBounds();
      final fit = openingBounds(displays: await _usableDisplays(), saved: now);
      final same = (fit.left - now.left).abs() < 1 &&
          (fit.top - now.top).abs() < 1 &&
          (fit.width - now.width).abs() < 1 &&
          (fit.height - now.height).abs() < 1;
      if (!same) await windowManager.setBounds(fit);
    } catch (_) {}
  }
}

class OmnitunApp extends ConsumerStatefulWidget {
  const OmnitunApp({super.key});

  @override
  ConsumerState<OmnitunApp> createState() => _OmnitunAppState();
}

class _OmnitunAppState extends ConsumerState<OmnitunApp> {
  final _navigator = GlobalKey<NavigatorState>();

  /// The app's own messenger: a failure is told on whichever page is open.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // The tray icon (Windows), when the window has been set up (the icon is what brings it back).
      if (customTitleBar) {
        unawaited(ref.read(trayProvider).start());
      } else if (startInBackground) {
        unawaited(windowManager.show()); // no window set-up, so no tray either: nothing else would bring it back
      }
      // A tap on a system notification of a failure opens the log of that connection.
      unawaited(ref.read(systemNotificationsProvider).start(_openLogs));
      // Update subscriptions whose refresh interval has passed.
      ref.read(subscriptionsProvider.notifier).refreshDue();
      // A link or file sent by another app comes first; the introduction steps aside for it.
      final shared = await IncomingShare.start(
        (text) => importShared(_navigator, ref, text),
        startup: ref.read(startupSharesProvider),
        onProblem: (code) => importSharedProblem(_navigator, code),
      );
      // The app's own default configuration (Tor) is there from the first start.
      await ref.read(defaultProfileIdProvider.notifier).ensureTorDefaults();
      if (!shared) _introduction();
    });
  }

  /// The first start, with no servers yet, begins with a short introduction.
  Future<void> _introduction() async {
    if (ref.read(onboardedProvider)) return;
    // An existing user needs no introduction. The Tor defaults are the app's, not theirs: a list
    // that is only those, on an install the app seeded itself, is still a new user's.
    final profiles = ref.read(profilesProvider);
    final fresh = ref.read(storeProvider).read<bool>(DefaultProfileController.freshInstall) == true;
    if (profiles.any((p) => p.protocol != 'tor') || (profiles.isNotEmpty && !fresh)) return;
    final navigator = _navigator.currentState;
    if (navigator == null) return;
    final addServer = await navigator.push<bool>(
      AppRoute(fullscreenDialog: true, builder: (_) => const OnboardingScreen()),
    );
    final overlay = _navigator.currentState?.overlay;
    if (addServer == true && overlay != null && overlay.mounted) showImportSheet(overlay.context, ref);
  }

  /// The log page, narrowed to one connect attempt when [conn] is given.
  void _openLogs(String conn) =>
      _navigator.currentState?.push(AppRoute<void>(builder: (_) => LogsScreen(conn: conn)));

  /// Tells the user of a failure nothing handled (docs/logging.md §5): a red notice on the open page and,
  /// when the app is not in front (or has no notice to show), a notification of the system.
  void _tell(LogRecord record) {
    final context = _navigator.currentContext;
    if (context == null) return;
    final l = context.l10n;
    final settings = ref.read(settingsProvider);
    final text = logRecordText(l, record);
    final messenger = _messenger.currentState;
    final popup = settings.notifyPopup && messenger != null;
    if (popup) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(noticeSnackBar(Theme.of(context), text, actionLabel: l.logsView, onAction: () => _openLogs(record.conn)));
    }
    final inFront = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (settings.notifyOs && !(popup && inFront)) {
      final notifications = ref.read(systemNotificationsProvider);
      unawaited(notifications.show(
        title: l.appName,
        body: text,
        conn: record.conn,
        connection: SystemNotifications.isConnectionFailure(record),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Collect core logs from startup, not only once the Logs tab is opened.
    ref.listen(logsProvider, (_, _) {});
    ref.listen(logAlertsProvider, (_, record) {
      if (record != null) _tell(record);
    });
    ref.watch(exitProvider); // looks up the exit address after each connection, when switched on
    final theme = ref.watch(settingsProvider.select((s) => s.theme));
    final language = ref.watch(settingsProvider.select((s) => s.language));
    return MaterialApp(
      navigatorKey: _navigator,
      scaffoldMessengerKey: _messenger,
      title: 'Wardkeep',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeModeOf(theme),
      locale: language.isEmpty ? null : Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      onGenerateTitle: (context) => context.l10n.appName,
      builder: (context, child) {
        final framed = customTitleBar ? WindowFrame(child: child!) : child!;
        // The phone opens on the loading screen with the whole shield; a computer shows its window ready.
        return Platform.isAndroid ? SplashCover(child: framed) : framed;
      },
      home: const HomeScreen(),
    );
  }
}
