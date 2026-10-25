// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Wardkeep';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionReset => 'Reset';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionNext => 'Next';

  @override
  String get actionImport => 'Import';

  @override
  String get actionDownload => 'Download';

  @override
  String get actionCopyAll => 'Copy all';

  @override
  String get actionClear => 'Clear';

  @override
  String get tooltipMore => 'More';

  @override
  String get tooltipShow => 'Show';

  @override
  String get tooltipHide => 'Hide';

  @override
  String get searchHint => 'Search';

  @override
  String get tooltipLogs => 'Logs';

  @override
  String get tooltipSettings => 'Settings';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusConnecting => 'Connecting…';

  @override
  String get statusDisconnecting => 'Disconnecting…';

  @override
  String get statusError => 'Connection failed';

  @override
  String get statusNoInternet => 'No internet connection';

  @override
  String get statusDisconnected => 'Not connected';

  @override
  String get stagePermission => 'Waiting for VPN permission';

  @override
  String get stageNetworkCheck => 'Checking internet connection';

  @override
  String get stagePrepare => 'Preparing configuration';

  @override
  String get stageEngineStart => 'Starting engine';

  @override
  String get stageTunnelUp => 'Opening tunnel';

  @override
  String get stageHandshake => 'Contacting server';

  @override
  String get stageConnected => 'Connected';

  @override
  String get buttonConnect => 'Connect';

  @override
  String get buttonDisconnect => 'Disconnect';

  @override
  String get buttonCancel => 'Cancel';

  @override
  String get locationLabel => 'Location';

  @override
  String get noServers => 'No servers';

  @override
  String get noServersHint => 'Add one to get started';

  @override
  String get automatic => 'Automatic';

  @override
  String get automaticHint => 'Fastest server, switches on failure';

  @override
  String get anyServerInCountry => 'Any server in this country';

  @override
  String get torNetwork => 'Tor network';

  @override
  String get torHopBridge => 'Bridge';

  @override
  String get torHopEntry => 'Entry';

  @override
  String get torHopRelay => 'Relay';

  @override
  String get torHopExit => 'Exit';

  @override
  String get torHopHidden => 'Hidden';

  @override
  String get torHopUnknown => 'Unknown';

  @override
  String get hopYou => 'You';

  @override
  String get hopYouNote =>
      'This is where you really are. Your traffic starts here.';

  @override
  String get hopServer => 'Server';

  @override
  String get hopServerNote =>
      'Your traffic travels encrypted to this server and comes out here, so websites see its address instead of yours.';

  @override
  String get hopBridgeNote =>
      'Your first hop. A bridge hides from your network that you use Tor. It knows who you are, but not where you go.';

  @override
  String get hopEntryNote =>
      'The first relay. It knows your address, but not what you visit.';

  @override
  String get hopRelayNote =>
      'The middle relay. It knows neither who you are nor what you visit; it only passes traffic along.';

  @override
  String get hopExitNote =>
      'The last relay. It sees where you go, but not who you are, and websites see its address.';

  @override
  String get hopHiddenNote =>
      'The bridge\'s location is hidden by its transport, so it cannot be shown on the map.';

  @override
  String get hopTransport => 'Transport';

  @override
  String get hopProtocol => 'Protocol';

  @override
  String get hopAddress => 'Address';

  @override
  String get hopLatency => 'Latency';

  @override
  String get hopExitAddress => 'Exit address';

  @override
  String get menuNewGroup => 'New group';

  @override
  String get groupNameHint => 'Group name';

  @override
  String get groupCreate => 'Create';

  @override
  String get menuMoveToGroup => 'Move to group';

  @override
  String get groupMoveTitle => 'Move to';

  @override
  String get menuRenameGroup => 'Rename';

  @override
  String get menuDeleteGroup => 'Delete group';

  @override
  String get groupDeleteTitle => 'Delete this group?';

  @override
  String groupDeleteBody(String name) {
    return 'Its servers are not deleted. They move back to $name.';
  }

  @override
  String get groupEmptyHint =>
      'No servers yet. Open a server\'s menu and choose Move to group.';

  @override
  String get menuShareGroupFile => 'Save as text file';

  @override
  String get menuCopyGroupLinks => 'Copy links';

  @override
  String groupSavedToast(String servers) {
    return 'Saved: $servers';
  }

  @override
  String groupCopiedToast(String servers) {
    return 'Copied: $servers';
  }

  @override
  String get groupNothingToShare => 'None of these servers has a share link.';

  @override
  String groupSkipped(String servers) {
    return 'Left out, no share link: $servers';
  }

  @override
  String get emptyTitle => 'No profiles yet';

  @override
  String get emptyHint => 'Import a config, link or subscription.';

  @override
  String get importConfig => 'Import config';

  @override
  String failoverToast(String to, String from) {
    return 'Switched to $to — $from stopped responding';
  }

  @override
  String get unknownLocation => 'Unknown location';

  @override
  String errorFailed(String stage, String reason) {
    return '$stage failed: $reason';
  }

  @override
  String get errTimeout => 'the server did not answer in time';

  @override
  String get errRefused => 'the server refused the connection';

  @override
  String get errReset => 'the connection was reset by the network';

  @override
  String get errNoRoute => 'the server cannot be reached from this network';

  @override
  String get errNetworkUnreachable => 'the network is unreachable';

  @override
  String get errDns => 'the server name could not be resolved';

  @override
  String get errTls => 'the server\'s security certificate was rejected';

  @override
  String get errAuth => 'the username or password was rejected';

  @override
  String get errClosed => 'the server closed the connection';

  @override
  String get errCertDate =>
      'the server\'s certificate has expired or is not valid yet (also check this phone\'s date and time)';

  @override
  String get errCertUntrusted =>
      'the server\'s certificate is not signed by a trusted authority';

  @override
  String get errCertName =>
      'the server\'s certificate is for a different name than the one you connect to';

  @override
  String get errTlsKeys =>
      'the shared key (tls-auth or tls-crypt) does not match the server\'s';

  @override
  String get errReality =>
      'the server rejected the Reality handshake (check the public key, short ID and server name)';

  @override
  String get errNoHandshake =>
      'the server did not answer the handshake (check the keys, the endpoint and that its UDP port is open)';

  @override
  String get errUdpBlocked =>
      'the server did not answer over UDP; this network may block it, try a TCP-based server';

  @override
  String get errPortInUse => 'the local port is already used by another app';

  @override
  String get errTorTimeout =>
      'Tor did not finish connecting in time. This network may block Tor; use a bridge (Snowflake or obfs4)';

  @override
  String get errTorBridgeTimeout =>
      'Tor did not finish connecting in time. The bridge may be blocked or overloaded; try another bridge type (Snowflake or obfs4)';

  @override
  String get errTorBadBridge =>
      'a Tor bridge line is not valid (it needs a transport, address and fingerprint)';

  @override
  String get errTorMissing => 'this build does not include the Tor client';

  @override
  String get errPermission => 'VPN permission was not granted';

  @override
  String get errCoreLost => 'Lost connection to the core service';

  @override
  String get selectLocation => 'Select location';

  @override
  String get testSpeedTooltip => 'Test speed of all servers';

  @override
  String get addServersTooltip => 'Add servers';

  @override
  String get menuImport => 'Import a config, link or QR';

  @override
  String get menuNewServer => 'Add a server by hand';

  @override
  String get menuSubscription => 'Add a subscription';

  @override
  String get menuManage => 'Manage servers and subscriptions';

  @override
  String get menuSetDefault => 'Make default';

  @override
  String get badgeDefault => 'Default';

  @override
  String get menuDeleteAll => 'Delete all servers';

  @override
  String get deleteAllTitle => 'Delete all servers?';

  @override
  String get deleteAllBody =>
      'Every server and subscription you added is removed. The built-in Tor connection stays, and the app goes back to it.';

  @override
  String get menuRestoreTor => 'Restore Tor defaults';

  @override
  String get deletedAllToast => 'All servers deleted';

  @override
  String defaultSetToast(String name) {
    return '$name is the default now';
  }

  @override
  String serversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers',
      one: '1 server',
    );
    return '$_temp0';
  }

  @override
  String get otherGroup => 'Other';

  @override
  String get torGroup => 'Tor';

  @override
  String get noServersYet => 'No servers yet';

  @override
  String get importHintShort => 'Import a config file, link or subscription.';

  @override
  String get showServers => 'Show servers';

  @override
  String get hideServers => 'Hide servers';

  @override
  String get menuEditServer => 'Edit';

  @override
  String get menuBridgeSettings => 'Bridge settings';

  @override
  String get menuShare => 'Share link or QR';

  @override
  String get menuSetCountry => 'Set country';

  @override
  String get menuCredentials => 'Username and password';

  @override
  String needsSignIn(String address) {
    return '$address · needs sign-in';
  }

  @override
  String get countryOfServer => 'Country of this server';

  @override
  String get guessFromName => 'Work it out from the name';

  @override
  String get latencyNotTested => 'Not tested';

  @override
  String get latencyUnreachable => 'Unreachable';

  @override
  String get latencyTimeout => 'timeout';

  @override
  String latencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String get unknownCountry => 'Unknown country';

  @override
  String get addServerTitle => 'Add a server';

  @override
  String get addServerIntro =>
      'Pick a protocol. A link or QR is quicker: use Import.';

  @override
  String newServerTitle(String label) {
    return 'New $label server';
  }

  @override
  String get editServerTitle => 'Edit server';

  @override
  String get torBridgesTitle => 'Tor bridges';

  @override
  String get subscriptionEditNote =>
      'This server comes from a subscription: your changes are replaced when it refreshes.';

  @override
  String get moreOptions => 'More options';

  @override
  String get countryRow => 'Country';

  @override
  String get countryAuto => 'Worked out from the name and address';

  @override
  String get alreadyInList => 'This server is already in the list';

  @override
  String get choiceDefault => 'Default';

  @override
  String get torBridgesNone => 'None (direct, or the lines below)';

  @override
  String get torBridgesSnowflake => 'Snowflake';

  @override
  String get torBridgesObfs4 => 'obfs4 (built-in bridges)';

  @override
  String get listHelper => 'Separate values with commas';

  @override
  String get fillPaste => 'Paste';

  @override
  String get fillFile => 'File';

  @override
  String get fillScanQr => 'Scan QR';

  @override
  String get openTextFile => 'Open a text file';

  @override
  String couldNotReadFile(String error) {
    return 'Could not read the file: $error';
  }

  @override
  String fieldRequired(String label) {
    return '$label *';
  }

  @override
  String formNoEditor(String protocol) {
    return 'No editor for $protocol';
  }

  @override
  String get shareScanHint => 'Scan with Wardkeep, or copy the link.';

  @override
  String get shareCopy => 'Copy link';

  @override
  String get shareCopied => 'Link copied';

  @override
  String get shareWarning =>
      'Contains the server\'s password or key. Share with care.';

  @override
  String shareFailed(String reason) {
    return 'This server cannot be shared as a link: $reason';
  }

  @override
  String get shareTooLong => 'Too long for a QR code: copy the link';

  @override
  String get obTitle1 => 'Private and simple';

  @override
  String get obText1 =>
      'One calm screen for VPN, proxy and Tor. Pick a place, press Connect.';

  @override
  String get obTitle2 => 'Add your servers';

  @override
  String get obText2 =>
      'Import a link, QR code, config file or subscription. Or add a server by hand.';

  @override
  String get obTitle3Android => 'Android will ask once';

  @override
  String get obText3Android =>
      'Android will ask to allow a VPN connection. Accept it to be protected.';

  @override
  String get obTitle3Desktop => 'Ready when you are';

  @override
  String get obText3Desktop =>
      'Starts in proxy mode, no special rights. Turn on VPN mode in Settings to capture all traffic.';

  @override
  String get obAddFirst => 'Add my first server';

  @override
  String get bypassTitle => 'Bypass lists';

  @override
  String get bypassAddTooltip => 'Add a list';

  @override
  String get bypassFromClipboard => 'Paste from the clipboard';

  @override
  String get bypassFromFile => 'Open a .txt file';

  @override
  String get bypassFromUrl => 'Download from a link';

  @override
  String get bypassType => 'Type it';

  @override
  String get bypassClipboardEmpty => 'The clipboard is empty';

  @override
  String get bypassPickFile => 'Open a bypass list (.txt)';

  @override
  String bypassDownloadFailed(String error) {
    return 'Could not download the list: $error';
  }

  @override
  String get bypassIntro =>
      'Sites and addresses that skip the VPN. One per line: example.com, full:www.example.com, keyword:bank, regexp:…, 203.0.113.7 or 10.0.0.0/8. Lines starting with # are ignored.';

  @override
  String get bypassNoLists => 'No lists yet.';

  @override
  String get bypassTypeList => 'Type a list';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get bypassOnlyTitle => 'Only listed use the VPN';

  @override
  String get bypassOnlyOn => 'Everything else goes direct.';

  @override
  String get bypassOnlyOff => 'Listed go direct; the rest uses the VPN.';

  @override
  String get bypassNothing => 'No list is on.';

  @override
  String bypassInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries in use',
      one: '1 entry in use',
    );
    return '$_temp0. Applies on next connect.';
  }

  @override
  String get bypassHttpLink => 'Enter an http(s) link';

  @override
  String bypassServerAnswered(int code) {
    return 'the server answered $code';
  }

  @override
  String get bypassTooLarge => 'the list is larger than 5 MB';

  @override
  String get bypassDownloadTitle => 'Download a list';

  @override
  String get bypassNewList => 'New list';

  @override
  String get bypassEditList => 'Edit list';

  @override
  String get bypassName => 'Name';

  @override
  String get bypassEntriesLabel => 'Entries, one per line';

  @override
  String get bypassNoUsable => 'No usable entries yet.';

  @override
  String bypassSummary(String entries, String names, String ranges) {
    return '$entries · $names, $ranges.';
  }

  @override
  String bypassNames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count names',
      one: '1 name',
    );
    return '$_temp0';
  }

  @override
  String bypassRanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count addresses or ranges',
      one: '1 address or range',
    );
    return '$_temp0';
  }

  @override
  String bypassIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines will be ignored:',
      one: '1 line will be ignored:',
    );
    return '$_temp0';
  }

  @override
  String bypassMoreIssues(int count) {
    return '… and $count more';
  }

  @override
  String get bypassReconnect => 'Reconnect to use the new list';

  @override
  String get bypassDefaultName => 'My list';

  @override
  String get bypassPastedName => 'Pasted list';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsServers => 'Servers';

  @override
  String get manageServers => 'Manage servers';

  @override
  String get manageServersHint => 'Servers and subscriptions';

  @override
  String get settingsConnection => 'Connection';

  @override
  String get vpnMode => 'VPN mode (all traffic)';

  @override
  String get vpnModeHint => 'Off: proxy only, no VPN permission';

  @override
  String get systemProxy => 'Set system proxy';

  @override
  String get systemProxyHint => 'Set the system proxy while connected';

  @override
  String get autoSwitch => 'Auto-switch on failure';

  @override
  String get autoSwitchHint => 'Try the next server if one fails';

  @override
  String get bypassLan => 'Bypass local network';

  @override
  String get bypassLanHint =>
      'Reach local devices directly (192.168.x.x, 10.x.x.x)';

  @override
  String get bypassListsHint => 'Websites and addresses that skip the VPN';

  @override
  String bypassListsInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries in use',
      one: '1 entry in use',
    );
    return '$_temp0';
  }

  @override
  String get alwaysOnTitle => 'Always-on VPN and kill switch';

  @override
  String get alwaysOnHint =>
      'Reconnect at boot and block leaks. Set in Android\'s VPN settings.';

  @override
  String get openVpnSettingsFallback =>
      'Settings → Network → VPN → gear next to Wardkeep';

  @override
  String get splitTunneling => 'Split tunneling';

  @override
  String splitSummaryOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Only $count selected apps use the VPN',
      one: 'Only 1 selected app uses the VPN',
    );
    return '$_temp0';
  }

  @override
  String splitSummaryBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps bypass the VPN',
      one: '1 app bypasses the VPN',
    );
    return '$_temp0';
  }

  @override
  String get splitSummaryOff => 'All apps use the VPN';

  @override
  String get remoteDns => 'Remote DNS';

  @override
  String get remoteDnsHelp =>
      'DNS used through the tunnel, e.g. https://1.1.1.1/dns-query or tls://1.1.1.1';

  @override
  String get settingsApp => 'App';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'Follow the system';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get stopOnClose => 'Stop VPN when app is closed';

  @override
  String aboutLine(String engine) {
    return 'MIT License · engine: $engine';
  }

  @override
  String get splitTitle => 'Split tunneling';

  @override
  String get splitAll => 'All apps';

  @override
  String get splitOnlySelected => 'Only selected';

  @override
  String get splitBypassSelected => 'Bypass selected';

  @override
  String get splitHelpOffMode => 'Every app uses the VPN.';

  @override
  String get splitHelpOnlyNone => 'No apps picked: all use the VPN.';

  @override
  String splitHelpOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Only $count apps use the VPN.',
      one: 'Only 1 app uses the VPN.',
    );
    return '$_temp0';
  }

  @override
  String splitHelpBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps go direct.',
      one: '1 app goes direct.',
    );
    return '$_temp0';
  }

  @override
  String get searchApps => 'Search apps';

  @override
  String get showSystemApps => 'Show system apps';

  @override
  String couldNotListApps(String error) {
    return 'Could not list apps: $error';
  }

  @override
  String get scanTitle => 'Scan QR code';

  @override
  String get scanTorch => 'Torch';

  @override
  String scanCameraUnavailable(String code) {
    return 'Camera unavailable: $code';
  }

  @override
  String get scanPoint => 'Point the camera at a config QR code';

  @override
  String get credTitle => 'Sign in';

  @override
  String credNeeds(String name) {
    return '$name needs a username and password.';
  }

  @override
  String get credUsername => 'Username';

  @override
  String get credPassword => 'Password';

  @override
  String get logsEmpty => 'No log entries yet.';

  @override
  String get profilesTitle => 'Manage servers';

  @override
  String get addSubscriptionTooltip => 'Add subscription';

  @override
  String get testLatencyTooltip => 'Test latency';

  @override
  String get profilesEmptyHint => 'No profiles. Tap Import to add one.';

  @override
  String get profilesDragHint =>
      'Hold and drag to reorder. Failover follows this order.';

  @override
  String get myProfiles => 'My profiles';

  @override
  String subRefreshed(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profiles',
      one: '1 profile',
    );
    return '$name: $_temp0';
  }

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get subDeleteWithProfiles => 'Delete subscription and its profiles';

  @override
  String subUsageOf(String used, String total) {
    return '$used of $total';
  }

  @override
  String subUsed(String used) {
    return '$used used';
  }

  @override
  String get subExpired => 'expired';

  @override
  String get subExpiresToday => 'expires today';

  @override
  String subExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'expires in $days days',
      one: 'expires in 1 day',
    );
    return '$_temp0';
  }

  @override
  String subUpdated(String ago) {
    return 'updated $ago';
  }

  @override
  String get agoJustNow => 'just now';

  @override
  String agoMinutes(int count) {
    return '$count min ago';
  }

  @override
  String agoHours(int count) {
    return '$count h ago';
  }

  @override
  String agoDays(int count) {
    return '$count d ago';
  }

  @override
  String subRefreshFailed(String error) {
    return 'Last refresh failed: $error';
  }

  @override
  String get importTitle => 'Import config';

  @override
  String get importDescription =>
      'Paste a link, config or subscription — or open a file or scan a QR code.';

  @override
  String get importScanQr => 'Scan QR';

  @override
  String get importOpenFile => 'Open file';

  @override
  String get importPaste => 'Paste';

  @override
  String get importSubscription => 'Subscription';

  @override
  String get importTor => 'Tor';

  @override
  String get importAddTor => 'Add Tor';

  @override
  String get importTorDirect => 'Tor (direct)';

  @override
  String get importTorSnowflake => 'Tor + Snowflake bridge';

  @override
  String get importTorObfs4 => 'Tor + obfs4 bridges';

  @override
  String importedProfiles(int added, int dupes) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Imported $added profiles',
      one: 'Imported 1 profile',
    );
    String _temp1 = intl.Intl.pluralLogic(
      dupes,
      locale: localeName,
      other: ', $dupes already present',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String importNothing(String reason) {
    return 'Nothing imported: $reason';
  }

  @override
  String importPartial(int added, int failed) {
    return 'Imported $added, failed $failed';
  }

  @override
  String get subAddTitle => 'Add subscription';

  @override
  String get subEditTitle => 'Edit subscription';

  @override
  String get subUrlLabel => 'Subscription URL';

  @override
  String get subUrlHint =>
      'https://provider.example/sub/… or nordvpn://<token>';

  @override
  String get subNameLabel => 'Name (optional)';

  @override
  String get subNameHelp =>
      'Defaults to the provider\'s title or the host name';

  @override
  String get subAuthLabel => 'Authentication';

  @override
  String get authNone => 'None';

  @override
  String get authBasic => 'Username & password (Basic)';

  @override
  String get authBearer => 'Bearer token';

  @override
  String get authHeader => 'Custom header';

  @override
  String get authQuery => 'Token in URL';

  @override
  String get subUsername => 'Username';

  @override
  String get subPassword => 'Password';

  @override
  String get subHeaderName => 'Header name';

  @override
  String get subHeaderValue => 'Header value';

  @override
  String get subParamName => 'Parameter name';

  @override
  String get subToken => 'Token';

  @override
  String get subDownloadLabel => 'Download';

  @override
  String get subDownloadHelp => 'Provider blocked? The VPN can still fetch it';

  @override
  String get subViaDirect => 'Directly';

  @override
  String get subViaAuto => 'Direct, or via the VPN if blocked';

  @override
  String get subViaTunnel => 'Always through the VPN (connect first)';

  @override
  String get subErrUrl =>
      'Enter an http(s) subscription URL (or nordvpn://<access token>)';

  @override
  String get subErrHeader => 'Enter the header name';

  @override
  String get subErrToken => 'Enter the token';

  @override
  String get subAddAndDownload => 'Add and download';

  @override
  String get subSaveAndRefresh => 'Save and refresh';

  @override
  String subUpdatedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profiles',
      one: '1 profile',
    );
    return 'Subscription updated: $_temp0';
  }

  @override
  String get flName => 'Name';

  @override
  String get flServer => 'Server';

  @override
  String get flPort => 'Port';

  @override
  String get flPassword => 'Password';

  @override
  String get flUsername => 'Username';

  @override
  String get flUuid => 'UUID';

  @override
  String get flSecurity => 'Security';

  @override
  String get flFlow => 'Flow';

  @override
  String get flCipher => 'Cipher';

  @override
  String get flEncryption => 'Encryption';

  @override
  String get flAlterId => 'Alter id';

  @override
  String get flTlsServerName => 'TLS server name (SNI)';

  @override
  String get flTlsFingerprint => 'TLS fingerprint';

  @override
  String get flAlpn => 'ALPN';

  @override
  String get flSkipCertCheck => 'Skip certificate check';

  @override
  String get flPinnedCert => 'Pinned certificate (PEM)';

  @override
  String get flRealityPublicKey => 'Reality public key';

  @override
  String get flRealityShortId => 'Reality short id';

  @override
  String get flTransport => 'Transport';

  @override
  String get flHostHeader => 'Host header';

  @override
  String get flPath => 'Path';

  @override
  String get flGrpcService => 'gRPC service name';

  @override
  String get flPlugin => 'Plugin';

  @override
  String get flPluginOptions => 'Plugin options';

  @override
  String get flObfuscation => 'Obfuscation';

  @override
  String get flObfsPassword => 'Obfuscation password';

  @override
  String get flUploadMbps => 'Upload (Mbps)';

  @override
  String get flDownloadMbps => 'Download (Mbps)';

  @override
  String get flCongestion => 'Congestion control';

  @override
  String get flUdpRelay => 'UDP relay mode';

  @override
  String get flUseQuic => 'Use HTTP/3 (QUIC)';

  @override
  String get flTunnelAddress => 'Your tunnel address';

  @override
  String get flRoutedNetworks => 'Routed networks';

  @override
  String get flDnsServers => 'DNS servers';

  @override
  String get flMtu => 'MTU';

  @override
  String get flKeepalive => 'Keepalive (seconds)';

  @override
  String get flPrivateKey => 'Private key';

  @override
  String get flServerPublicKey => 'Server public key';

  @override
  String get flPresharedKey => 'Pre-shared key';

  @override
  String get flReservedBytes => 'Reserved bytes';

  @override
  String get flAuthentication => 'Authentication';

  @override
  String get flAuthDigest => 'Auth digest';

  @override
  String get flCaCert => 'CA certificate (PEM)';

  @override
  String get flClientCert => 'Client certificate (PEM)';

  @override
  String get flClientKey => 'Client key (PEM)';

  @override
  String get flControlWrap => 'Control channel protection';

  @override
  String get flControlWrapKey => 'Control channel key';

  @override
  String get flKeyDirection => 'Key direction';

  @override
  String get flRemoteCertType => 'Remote certificate type';

  @override
  String get flVerifyServerName => 'Verify server name';

  @override
  String get flYourIdentity => 'Your identity';

  @override
  String get flServerIdentity => 'Server identity';

  @override
  String get flServerCertTrust => 'Server certificate to trust (PEM)';

  @override
  String get flUseSystemIke => 'Use the phone\'s own IKEv2 client';

  @override
  String get flUseTcp => 'Use TCP';

  @override
  String get flHostKeys => 'Host keys';

  @override
  String get flPrivateKeyPem => 'Private key (PEM)';

  @override
  String get flKeyPassphrase => 'Key passphrase';

  @override
  String get flBridges => 'Bridges';

  @override
  String get flBridgeLines => 'Bridge lines';

  @override
  String get flJc => 'Jc (junk packet count)';

  @override
  String get flSignaturePacket => 'I1 (signature packet)';

  @override
  String get hpAuthorizedKeys =>
      'authorized_keys format; empty accepts any key';

  @override
  String get hpIkeTcp =>
      'Carry IKE and ESP over TCP for networks that block UDP';

  @override
  String get hpDefaultsToServer => 'Defaults to the server address';

  @override
  String get hpTorBridges =>
      'Empty connects to Tor directly, or uses the bridge lines below';

  @override
  String get hpExampleAddress => 'For example 10.8.0.2/32';

  @override
  String get hpExamplePlugin => 'For example shadow-tls or v2ray-plugin';

  @override
  String get hpHostOrIp => 'Host name or IP address';

  @override
  String get hpNeededReality => 'Needed when Security is reality';

  @override
  String get hpOnlySelfSigned =>
      'Only for servers with a self-signed certificate you cannot pin';

  @override
  String get hpSafeSstp =>
      'Safe for SSTP: the password exchange proves the server';

  @override
  String get hpHysteriaObfs =>
      'salamander for Hysteria 2; the obfuscation password for Hysteria 1';

  @override
  String get hpTrustCert =>
      'Trust this certificate instead of the system\'s authorities';

  @override
  String get hpWhichBrowser => 'Which browser\'s TLS handshake to imitate';

  @override
  String get hpWarpReserved =>
      'Three numbers, as WARP configurations list them';

  @override
  String get hpOneBridgePerLine =>
      'One bridge per line, as in a torrc without \"Bridge \"';

  @override
  String get exitTitle => 'Show exit address and country';

  @override
  String get exitHint =>
      'Ask api.country.is for your IP and country, also when not connected.';

  @override
  String exitIpLabel(String ip) {
    return 'IP $ip';
  }

  @override
  String connectedTo(String place) {
    return 'Connected to $place';
  }

  @override
  String get noticesTitle => 'Open-source licenses';

  @override
  String get noticesIntro =>
      'Wardkeep is MIT licensed. It includes the software below, each under its own license.';

  @override
  String noticesMore(int count) {
    return '+$count more';
  }

  @override
  String noticesPackages(int count) {
    return '$count packages';
  }

  @override
  String get noticesLoadFailed => 'The license list could not be read.';

  @override
  String formRequired(String label) {
    return '$label is required';
  }

  @override
  String formNotNumber(String label) {
    return '$label must be a whole number';
  }

  @override
  String formNotBool(String label) {
    return '$label must be on or off';
  }

  @override
  String formBadChoice(String label, String value, String choices) {
    return '$label: $value is not one of $choices';
  }

  @override
  String get formRealityOnlyVless => 'Reality is only available for VLESS';

  @override
  String formUnknownSecurity(String value) {
    return 'Unknown security: $value';
  }

  @override
  String get formReservedBytes =>
      'Reserved bytes must be numbers from 0 to 255';

  @override
  String get formRealityKeyRequired =>
      'The Reality public key is required when Security is Reality';

  @override
  String get importUnsupported =>
      'This is not a server link, subscription or config that Wardkeep can read';

  @override
  String importUnsupportedScheme(String scheme) {
    return 'Links that start with $scheme:// are not supported';
  }

  @override
  String get importXrayServer =>
      'This is an Xray server config. Import it on the server (omnitun-server import xray), not as a client profile';

  @override
  String get subAuthFailed =>
      'The subscription rejected the sign-in. Check the username, password or token';

  @override
  String subHttp(String status) {
    return 'The subscription server answered HTTP $status';
  }

  @override
  String get subTooLarge => 'The subscription is larger than 10 MB';

  @override
  String get subBadUrl => 'That is not a valid subscription address';

  @override
  String get bypassIssueEmptyExpression => 'empty expression';

  @override
  String get bypassIssueBadExpression => 'not a valid expression';

  @override
  String get bypassIssueBadName => 'not a valid name';

  @override
  String get bypassIssueGeo =>
      'geo lists are not supported; list the domains or ranges';

  @override
  String get bypassIssueBadEntry => 'not a domain, address or range';

  @override
  String bypassIssueTooMany(int limit) {
    return 'more than $limit entries: the rest is ignored';
  }

  @override
  String get torStarting => 'Starting Tor';

  @override
  String torBootstrap(int percent) {
    return 'Connecting to Tor $percent%';
  }

  @override
  String get torCircuit => 'Building a Tor circuit';

  @override
  String torRetry(int attempt, int attempts) {
    return 'Retrying Tor ($attempt/$attempts)';
  }

  @override
  String get importNoServer => 'No valid server was found in this text';

  @override
  String importJsonSyntax(String found, int line, int column) {
    return 'This is not valid JSON: unexpected $found at line $line, column $column.';
  }

  @override
  String importJsonEnd(int line, int column) {
    return 'This is not valid JSON: the text ends too early, at line $line, column $column. A closing bracket, brace or quote may be missing.';
  }

  @override
  String get importJsonNoServer =>
      'This JSON is valid, but it has no proxy server in it. Use a client config with a VLESS, VMess, Trojan, Shadowsocks or similar outbound.';

  @override
  String importJsonNoServerFound(String found) {
    return 'This JSON is valid, but it has no proxy server in it (it holds $found). Use a client config with a VLESS, VMess, Trojan, Shadowsocks or similar outbound.';
  }

  @override
  String importTooLarge(int limit) {
    return 'This is too large to import (the limit is $limit MB).';
  }

  @override
  String get importFileEmpty => 'The file is empty.';

  @override
  String get importFileNotText =>
      'The file is not text that Wardkeep can read (it looks binary, or it is in an unknown encoding). Use a UTF-8 or UTF-16 text file.';

  @override
  String get importFileNoPermission =>
      'Wardkeep is not allowed to read this file.';

  @override
  String get importFileMissing =>
      'The file was not found. It may have been moved or deleted.';

  @override
  String get importDetails => 'Details';

  @override
  String get importJsonNote =>
      'A JSON config (Xray, sing-box, SIP008) or a list of them also works, as text or as a file.';

  @override
  String get ipdbTitle => 'Offline country database';

  @override
  String get ipdbIntro =>
      'Download a database once, and Wardkeep finds the country of a server or an address by itself, without asking a website.';

  @override
  String ipdbSizeNote(String size) {
    return 'About $size · free data (public domain)';
  }

  @override
  String get ipdbDownload => 'Download';

  @override
  String get ipdbContinue => 'Continue';

  @override
  String get ipdbPause => 'Pause';

  @override
  String get ipdbUpdate => 'Update';

  @override
  String get ipdbDelete => 'Delete';

  @override
  String get ipdbDeleteTitle => 'Delete the database?';

  @override
  String get ipdbUse => 'Use the database';

  @override
  String get ipdbStepV4 => 'IPv4';

  @override
  String get ipdbStepV6 => 'IPv6';

  @override
  String get ipdbStepPrepare => 'Prepare';

  @override
  String get ipdbPreparing => 'Preparing…';

  @override
  String get ipdbReady => 'Ready';

  @override
  String ipdbStoppedAt(int percent) {
    return 'Stopped at $percent%. Continue picks up right there.';
  }

  @override
  String ipdbFailed(String reason) {
    return 'Download failed: $reason';
  }

  @override
  String ipdbReadyLine(String ranges, String size) {
    return '$ranges ranges · $size';
  }

  @override
  String ipdbVersion(String version, String date) {
    return 'Version $version · $date';
  }

  @override
  String ipdbLeft(String time) {
    return '$time left';
  }

  @override
  String get ipdbSource =>
      'Data: regional internet registries and ASN announcements (CC0), from the ip-location-db project.';

  @override
  String get ipdbSubNone => 'Find countries without asking a website';

  @override
  String ipdbSubReady(String size) {
    return 'On · $size';
  }

  @override
  String ipdbSubOff(String size) {
    return 'Off · $size';
  }

  @override
  String ipdbSubDownloading(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String ipdbSubStopped(int percent) {
    return 'Stopped at $percent%';
  }

  @override
  String get ipdbErrNetwork => 'no connection to the data servers';

  @override
  String get ipdbErrMirrors => 'the data servers did not send the right file';

  @override
  String get bypassCountriesTitle => 'Countries';

  @override
  String get bypassCountriesNone => 'No country chosen';

  @override
  String bypassCountriesMore(String names, int count) {
    return '$names +$count';
  }

  @override
  String get bypassCountriesIntro =>
      'Traffic to the chosen countries goes straight to the internet, around the VPN. Their address ranges come from the offline country database.';

  @override
  String get bypassCountriesGetDb => 'Get the country database';

  @override
  String get bypassCountriesSearch => 'Search countries';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowRestore => 'Restore';

  @override
  String get windowClose => 'Close';

  @override
  String get windowFullScreen => 'Full screen';

  @override
  String get windowExitFullScreen => 'Exit full screen';

  @override
  String get globeRecenter => 'Centre the Earth';

  @override
  String get bypassCountriesZoneIntro =>
      'Each country you tick downloads its address ranges (a few kilobytes). The full offline database is more exact and needs no download.';

  @override
  String get bypassCountriesDownloading => 'Downloading…';

  @override
  String get bypassCountriesFailed => 'Could not download. Tap to try again.';

  @override
  String get bypassCountriesYourServer =>
      'Your selected server is here: its traffic would skip the VPN too.';

  @override
  String get ipv6Title => 'IPv6';

  @override
  String get ipv6Hint =>
      'Off: only IPv4 is used; IPv6 connections are refused, not sent around the VPN.';

  @override
  String get mtuTitle => 'MTU';

  @override
  String get mtuAuto => 'Default';

  @override
  String get mtuHelp =>
      'The packet size of the tunnel (VPN mode only). Try 1280 to 1420 if some sites hang on a mobile network. Empty is the default.';

  @override
  String mtuInvalid(int min, int max) {
    return 'Enter a number from $min to $max.';
  }

  @override
  String get trayOpen => 'Open Wardkeep';

  @override
  String get trayQuit => 'Quit';

  @override
  String get traySwitchServer => 'Switch server';

  @override
  String get keepInTray => 'Keep running in the tray';

  @override
  String get keepInTrayHint =>
      'Closing the window only hides it. Use Quit in the tray menu to end the app and the VPN.';

  @override
  String usageUsed(String size) {
    return '$size used';
  }

  @override
  String get menuResetUsage => 'Reset data usage';

  @override
  String get dnsPickerHelp =>
      'Website names are looked up through the VPN by the resolver you choose. DNSCrypt also proves that the answer came from that resolver.';

  @override
  String get dnsDefault => 'Default';

  @override
  String get dnsSectionDnscrypt => 'DNSCrypt · DNSSEC, no logs, no filtering';

  @override
  String get dnsCustom => 'Custom';

  @override
  String get dnsCustomLabel => 'Address or DNS stamp';

  @override
  String get dnsAnonymized => 'Anonymized DNSCrypt';

  @override
  String get dnsAnonymizedHint =>
      'Queries go through a relay, so the resolver never sees where they come from';

  @override
  String get dnsAnonymizedNeedsDnscrypt =>
      'Choose a DNSCrypt resolver to use this';

  @override
  String get dnsRelay => 'Relay';

  @override
  String get dnsRelayChoose => 'Choose a relay';

  @override
  String get dnsRelayAutomatic => 'Automatic (another operator)';

  @override
  String get dnsErrAddress =>
      'Use an address that starts with https://, tls://, tcp:// or udp://, or an sdns:// stamp';

  @override
  String get dnsErrDamaged =>
      'This stamp is damaged or cut short. Copy it again.';

  @override
  String get dnsErrUnsupported => 'This kind of stamp is not supported';

  @override
  String get dnsErrRelayStamp => 'This is a relay stamp, not a resolver';

  @override
  String dnsLine(String resolver) {
    return 'DNS: $resolver';
  }

  @override
  String get dnsLimits =>
      'This protects the names you look up. It does not hide which sites you then connect to.';

  @override
  String get dnsAnonymizedShort => 'anonymized';

  @override
  String get flAuthKey => 'Auth key';

  @override
  String get flControlServer => 'Control server';

  @override
  String get flDeviceName => 'Device name';

  @override
  String get flExitDevice => 'Exit device';

  @override
  String get flUseSubnets => 'Use subnets of other devices';

  @override
  String get flTempDevice => 'Temporary device';

  @override
  String get hpAuthKey =>
      'A pre-authorized key from the Tailscale admin page, or made by headscale preauthkeys create';

  @override
  String get hpControlServer =>
      'Empty uses Tailscale; for Headscale, its address such as https://hs.example.com';

  @override
  String get hpDeviceName =>
      'The name this device has in the network; empty uses the device\'s own';

  @override
  String get hpExitDevice =>
      'Name or address of a device whose internet connection to use; empty reaches only your devices';

  @override
  String get hpTempDevice => 'Removed from the network when it goes offline';

  @override
  String get devicesTitle => 'My devices';

  @override
  String get devicesNotConnected =>
      'Connect a Tailscale or Headscale profile to see your devices.';

  @override
  String get devicesJoining => 'Joining the network…';

  @override
  String get devicesLoginNeeded =>
      'The network did not accept this device\'s key. Make a new key and edit the profile.';

  @override
  String get devicesEmpty => 'No other devices in this network yet.';

  @override
  String get devicesThisDevice => 'This device';

  @override
  String get deviceOnline => 'Online';

  @override
  String get deviceOffline => 'Offline';

  @override
  String deviceLastSeen(String when) {
    return 'Last seen $when';
  }

  @override
  String get deviceUseAsExit => 'Use as exit';

  @override
  String get deviceStopExit => 'Stop using as exit';

  @override
  String get deviceIsExit => 'Exit in use';

  @override
  String get devicesExitHint =>
      'Use one of your devices as the exit: all your traffic leaves from its connection.';

  @override
  String get deviceCopyName => 'Copy name';

  @override
  String get deviceCopyAddress => 'Copy address';

  @override
  String get deviceCopied => 'Copied';

  @override
  String get errMeshExit =>
      'That device cannot be used as the exit right now. It must be online and offer its connection.';

  @override
  String get wnTlsInsecure =>
      'The server\'s certificate is not checked. Anyone on the path can read or change your traffic.';

  @override
  String get wnNoTls =>
      'Traffic is not wrapped in TLS. It is easy to recognise and may be read on the way.';

  @override
  String get wnVmessLegacy =>
      'VMess is an older protocol and is easy to recognise. VLESS with Reality is a better choice.';

  @override
  String get wnSsPlain =>
      'Without a plugin such as shadow-tls the traffic looks like random bytes, and some networks block that pattern.';

  @override
  String get wnHysteria1 =>
      'Hysteria 1 is deprecated. Use Hysteria 2 when the server supports it.';

  @override
  String get wnDpiVisible =>
      'This protocol is easy to identify and is often blocked on strict networks.';

  @override
  String get wnSshVisible => 'SSH tunnels are easy to identify.';

  @override
  String get wnDnsttSlow =>
      'Slow (usually well under 1 Mbit/s) and TCP only. It sends many DNS queries that the network can see. Use it when nothing else works.';

  @override
  String get wnDnsttOpen =>
      'No username or password: anyone with this link can use the server.';

  @override
  String get wnMuxLossy =>
      'Multiplexing puts many connections on one. A bad link can slow all of them.';

  @override
  String get wnFragmentSide =>
      'Fragmenting the handshake helps against some filters, may break on others, and adds delay.';

  @override
  String get wnEchServer =>
      'Needs a server that supports ECH. Otherwise the connection fails.';

  @override
  String get wnWgChain =>
      'WireGuard inside a proxy: if the proxy is slow, the tunnel can stall. The proxy must carry UDP.';

  @override
  String get wnSubUnsigned =>
      'This list is not signed, so a changed list cannot be detected.';
}
