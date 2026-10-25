import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('fa'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('ur'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Wardkeep'**
  String get appName;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get actionReset;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get actionImport;

  /// No description provided for @actionDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get actionDownload;

  /// No description provided for @actionCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get actionCopyAll;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @tooltipMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tooltipMore;

  /// No description provided for @tooltipShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get tooltipShow;

  /// No description provided for @tooltipHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get tooltipHide;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @tooltipLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get tooltipLogs;

  /// No description provided for @tooltipSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tooltipSettings;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get statusConnecting;

  /// No description provided for @statusDisconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting…'**
  String get statusDisconnecting;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get statusError;

  /// No description provided for @statusNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get statusNoInternet;

  /// No description provided for @statusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get statusDisconnected;

  /// No description provided for @stagePermission.
  ///
  /// In en, this message translates to:
  /// **'Waiting for VPN permission'**
  String get stagePermission;

  /// No description provided for @stageNetworkCheck.
  ///
  /// In en, this message translates to:
  /// **'Checking internet connection'**
  String get stageNetworkCheck;

  /// No description provided for @stagePrepare.
  ///
  /// In en, this message translates to:
  /// **'Preparing configuration'**
  String get stagePrepare;

  /// No description provided for @stageEngineStart.
  ///
  /// In en, this message translates to:
  /// **'Starting engine'**
  String get stageEngineStart;

  /// No description provided for @stageTunnelUp.
  ///
  /// In en, this message translates to:
  /// **'Opening tunnel'**
  String get stageTunnelUp;

  /// No description provided for @stageHandshake.
  ///
  /// In en, this message translates to:
  /// **'Contacting server'**
  String get stageHandshake;

  /// No description provided for @stageConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get stageConnected;

  /// No description provided for @buttonConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get buttonConnect;

  /// No description provided for @buttonDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get buttonDisconnect;

  /// No description provided for @buttonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get buttonCancel;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @noServers.
  ///
  /// In en, this message translates to:
  /// **'No servers'**
  String get noServers;

  /// No description provided for @noServersHint.
  ///
  /// In en, this message translates to:
  /// **'Add one to get started'**
  String get noServersHint;

  /// No description provided for @automatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automatic;

  /// No description provided for @automaticHint.
  ///
  /// In en, this message translates to:
  /// **'Fastest server, switches on failure'**
  String get automaticHint;

  /// No description provided for @anyServerInCountry.
  ///
  /// In en, this message translates to:
  /// **'Any server in this country'**
  String get anyServerInCountry;

  /// No description provided for @torNetwork.
  ///
  /// In en, this message translates to:
  /// **'Tor network'**
  String get torNetwork;

  /// No description provided for @torHopBridge.
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get torHopBridge;

  /// No description provided for @torHopEntry.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get torHopEntry;

  /// No description provided for @torHopRelay.
  ///
  /// In en, this message translates to:
  /// **'Relay'**
  String get torHopRelay;

  /// No description provided for @torHopExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get torHopExit;

  /// No description provided for @torHopHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get torHopHidden;

  /// No description provided for @torHopUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get torHopUnknown;

  /// No description provided for @hopYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get hopYou;

  /// No description provided for @hopYouNote.
  ///
  /// In en, this message translates to:
  /// **'This is where you really are. Your traffic starts here.'**
  String get hopYouNote;

  /// No description provided for @hopServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get hopServer;

  /// No description provided for @hopServerNote.
  ///
  /// In en, this message translates to:
  /// **'Your traffic travels encrypted to this server and comes out here, so websites see its address instead of yours.'**
  String get hopServerNote;

  /// No description provided for @hopBridgeNote.
  ///
  /// In en, this message translates to:
  /// **'Your first hop. A bridge hides from your network that you use Tor. It knows who you are, but not where you go.'**
  String get hopBridgeNote;

  /// No description provided for @hopEntryNote.
  ///
  /// In en, this message translates to:
  /// **'The first relay. It knows your address, but not what you visit.'**
  String get hopEntryNote;

  /// No description provided for @hopRelayNote.
  ///
  /// In en, this message translates to:
  /// **'The middle relay. It knows neither who you are nor what you visit; it only passes traffic along.'**
  String get hopRelayNote;

  /// No description provided for @hopExitNote.
  ///
  /// In en, this message translates to:
  /// **'The last relay. It sees where you go, but not who you are, and websites see its address.'**
  String get hopExitNote;

  /// No description provided for @hopHiddenNote.
  ///
  /// In en, this message translates to:
  /// **'The bridge\'s location is hidden by its transport, so it cannot be shown on the map.'**
  String get hopHiddenNote;

  /// No description provided for @hopTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get hopTransport;

  /// No description provided for @hopProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get hopProtocol;

  /// No description provided for @hopAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get hopAddress;

  /// No description provided for @hopLatency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get hopLatency;

  /// No description provided for @hopExitAddress.
  ///
  /// In en, this message translates to:
  /// **'Exit address'**
  String get hopExitAddress;

  /// No description provided for @menuNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get menuNewGroup;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameHint;

  /// No description provided for @groupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get groupCreate;

  /// No description provided for @menuMoveToGroup.
  ///
  /// In en, this message translates to:
  /// **'Move to group'**
  String get menuMoveToGroup;

  /// No description provided for @groupMoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get groupMoveTitle;

  /// No description provided for @menuRenameGroup.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get menuRenameGroup;

  /// No description provided for @menuDeleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get menuDeleteGroup;

  /// No description provided for @groupDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this group?'**
  String get groupDeleteTitle;

  /// No description provided for @groupDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its servers are not deleted. They move back to {name}.'**
  String groupDeleteBody(String name);

  /// No description provided for @groupEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No servers yet. Open a server\'s menu and choose Move to group.'**
  String get groupEmptyHint;

  /// No description provided for @menuShareGroupFile.
  ///
  /// In en, this message translates to:
  /// **'Save as text file'**
  String get menuShareGroupFile;

  /// No description provided for @menuCopyGroupLinks.
  ///
  /// In en, this message translates to:
  /// **'Copy links'**
  String get menuCopyGroupLinks;

  /// No description provided for @groupSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Saved: {servers}'**
  String groupSavedToast(String servers);

  /// No description provided for @groupCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Copied: {servers}'**
  String groupCopiedToast(String servers);

  /// No description provided for @groupNothingToShare.
  ///
  /// In en, this message translates to:
  /// **'None of these servers has a share link.'**
  String get groupNothingToShare;

  /// No description provided for @groupSkipped.
  ///
  /// In en, this message translates to:
  /// **'Left out, no share link: {servers}'**
  String groupSkipped(String servers);

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No profiles yet'**
  String get emptyTitle;

  /// No description provided for @emptyHint.
  ///
  /// In en, this message translates to:
  /// **'Import a config, link or subscription.'**
  String get emptyHint;

  /// No description provided for @importConfig.
  ///
  /// In en, this message translates to:
  /// **'Import config'**
  String get importConfig;

  /// No description provided for @failoverToast.
  ///
  /// In en, this message translates to:
  /// **'Switched to {to} — {from} stopped responding'**
  String failoverToast(String to, String from);

  /// No description provided for @unknownLocation.
  ///
  /// In en, this message translates to:
  /// **'Unknown location'**
  String get unknownLocation;

  /// No description provided for @errorFailed.
  ///
  /// In en, this message translates to:
  /// **'{stage} failed: {reason}'**
  String errorFailed(String stage, String reason);

  /// No description provided for @errTimeout.
  ///
  /// In en, this message translates to:
  /// **'the server did not answer in time'**
  String get errTimeout;

  /// No description provided for @errRefused.
  ///
  /// In en, this message translates to:
  /// **'the server refused the connection'**
  String get errRefused;

  /// No description provided for @errReset.
  ///
  /// In en, this message translates to:
  /// **'the connection was reset by the network'**
  String get errReset;

  /// No description provided for @errNoRoute.
  ///
  /// In en, this message translates to:
  /// **'the server cannot be reached from this network'**
  String get errNoRoute;

  /// No description provided for @errNetworkUnreachable.
  ///
  /// In en, this message translates to:
  /// **'the network is unreachable'**
  String get errNetworkUnreachable;

  /// No description provided for @errDns.
  ///
  /// In en, this message translates to:
  /// **'the server name could not be resolved'**
  String get errDns;

  /// No description provided for @errTls.
  ///
  /// In en, this message translates to:
  /// **'the server\'s security certificate was rejected'**
  String get errTls;

  /// No description provided for @errAuth.
  ///
  /// In en, this message translates to:
  /// **'the username or password was rejected'**
  String get errAuth;

  /// No description provided for @errClosed.
  ///
  /// In en, this message translates to:
  /// **'the server closed the connection'**
  String get errClosed;

  /// No description provided for @errCertDate.
  ///
  /// In en, this message translates to:
  /// **'the server\'s certificate has expired or is not valid yet (also check this phone\'s date and time)'**
  String get errCertDate;

  /// No description provided for @errCertUntrusted.
  ///
  /// In en, this message translates to:
  /// **'the server\'s certificate is not signed by a trusted authority'**
  String get errCertUntrusted;

  /// No description provided for @errCertName.
  ///
  /// In en, this message translates to:
  /// **'the server\'s certificate is for a different name than the one you connect to'**
  String get errCertName;

  /// No description provided for @errTlsKeys.
  ///
  /// In en, this message translates to:
  /// **'the shared key (tls-auth or tls-crypt) does not match the server\'s'**
  String get errTlsKeys;

  /// No description provided for @errReality.
  ///
  /// In en, this message translates to:
  /// **'the server rejected the Reality handshake (check the public key, short ID and server name)'**
  String get errReality;

  /// No description provided for @errNoHandshake.
  ///
  /// In en, this message translates to:
  /// **'the server did not answer the handshake (check the keys, the endpoint and that its UDP port is open)'**
  String get errNoHandshake;

  /// No description provided for @errUdpBlocked.
  ///
  /// In en, this message translates to:
  /// **'the server did not answer over UDP; this network may block it, try a TCP-based server'**
  String get errUdpBlocked;

  /// No description provided for @errPortInUse.
  ///
  /// In en, this message translates to:
  /// **'the local port is already used by another app'**
  String get errPortInUse;

  /// No description provided for @errTorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Tor did not finish connecting in time. This network may block Tor; use a bridge (Snowflake or obfs4)'**
  String get errTorTimeout;

  /// No description provided for @errTorBridgeTimeout.
  ///
  /// In en, this message translates to:
  /// **'Tor did not finish connecting in time. The bridge may be blocked or overloaded; try another bridge type (Snowflake or obfs4)'**
  String get errTorBridgeTimeout;

  /// No description provided for @errTorBadBridge.
  ///
  /// In en, this message translates to:
  /// **'a Tor bridge line is not valid (it needs a transport, address and fingerprint)'**
  String get errTorBadBridge;

  /// No description provided for @errTorMissing.
  ///
  /// In en, this message translates to:
  /// **'this build does not include the Tor client'**
  String get errTorMissing;

  /// No description provided for @errPermission.
  ///
  /// In en, this message translates to:
  /// **'VPN permission was not granted'**
  String get errPermission;

  /// No description provided for @errCoreLost.
  ///
  /// In en, this message translates to:
  /// **'Lost connection to the core service'**
  String get errCoreLost;

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select location'**
  String get selectLocation;

  /// No description provided for @testSpeedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Test speed of all servers'**
  String get testSpeedTooltip;

  /// No description provided for @addServersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add servers'**
  String get addServersTooltip;

  /// No description provided for @menuImport.
  ///
  /// In en, this message translates to:
  /// **'Import a config, link or QR'**
  String get menuImport;

  /// No description provided for @menuNewServer.
  ///
  /// In en, this message translates to:
  /// **'Add a server by hand'**
  String get menuNewServer;

  /// No description provided for @menuSubscription.
  ///
  /// In en, this message translates to:
  /// **'Add a subscription'**
  String get menuSubscription;

  /// No description provided for @menuManage.
  ///
  /// In en, this message translates to:
  /// **'Manage servers and subscriptions'**
  String get menuManage;

  /// No description provided for @menuSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Make default'**
  String get menuSetDefault;

  /// No description provided for @badgeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get badgeDefault;

  /// No description provided for @menuDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all servers'**
  String get menuDeleteAll;

  /// No description provided for @deleteAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all servers?'**
  String get deleteAllTitle;

  /// No description provided for @deleteAllBody.
  ///
  /// In en, this message translates to:
  /// **'Every server and subscription you added is removed. The built-in Tor connection stays, and the app goes back to it.'**
  String get deleteAllBody;

  /// No description provided for @menuRestoreTor.
  ///
  /// In en, this message translates to:
  /// **'Restore Tor defaults'**
  String get menuRestoreTor;

  /// No description provided for @deletedAllToast.
  ///
  /// In en, this message translates to:
  /// **'All servers deleted'**
  String get deletedAllToast;

  /// No description provided for @defaultSetToast.
  ///
  /// In en, this message translates to:
  /// **'{name} is the default now'**
  String defaultSetToast(String name);

  /// No description provided for @serversCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 server} other{{count} servers}}'**
  String serversCount(int count);

  /// No description provided for @otherGroup.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherGroup;

  /// No description provided for @torGroup.
  ///
  /// In en, this message translates to:
  /// **'Tor'**
  String get torGroup;

  /// No description provided for @noServersYet.
  ///
  /// In en, this message translates to:
  /// **'No servers yet'**
  String get noServersYet;

  /// No description provided for @importHintShort.
  ///
  /// In en, this message translates to:
  /// **'Import a config file, link or subscription.'**
  String get importHintShort;

  /// No description provided for @showServers.
  ///
  /// In en, this message translates to:
  /// **'Show servers'**
  String get showServers;

  /// No description provided for @hideServers.
  ///
  /// In en, this message translates to:
  /// **'Hide servers'**
  String get hideServers;

  /// No description provided for @menuEditServer.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEditServer;

  /// No description provided for @menuBridgeSettings.
  ///
  /// In en, this message translates to:
  /// **'Bridge settings'**
  String get menuBridgeSettings;

  /// No description provided for @menuShare.
  ///
  /// In en, this message translates to:
  /// **'Share link or QR'**
  String get menuShare;

  /// No description provided for @menuSetCountry.
  ///
  /// In en, this message translates to:
  /// **'Set country'**
  String get menuSetCountry;

  /// No description provided for @menuCredentials.
  ///
  /// In en, this message translates to:
  /// **'Username and password'**
  String get menuCredentials;

  /// No description provided for @needsSignIn.
  ///
  /// In en, this message translates to:
  /// **'{address} · needs sign-in'**
  String needsSignIn(String address);

  /// No description provided for @countryOfServer.
  ///
  /// In en, this message translates to:
  /// **'Country of this server'**
  String get countryOfServer;

  /// No description provided for @guessFromName.
  ///
  /// In en, this message translates to:
  /// **'Work it out from the name'**
  String get guessFromName;

  /// No description provided for @latencyNotTested.
  ///
  /// In en, this message translates to:
  /// **'Not tested'**
  String get latencyNotTested;

  /// No description provided for @latencyUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get latencyUnreachable;

  /// No description provided for @latencyTimeout.
  ///
  /// In en, this message translates to:
  /// **'timeout'**
  String get latencyTimeout;

  /// No description provided for @latencyMs.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String latencyMs(int ms);

  /// No description provided for @unknownCountry.
  ///
  /// In en, this message translates to:
  /// **'Unknown country'**
  String get unknownCountry;

  /// No description provided for @addServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a server'**
  String get addServerTitle;

  /// No description provided for @addServerIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick a protocol. A link or QR is quicker: use Import.'**
  String get addServerIntro;

  /// No description provided for @newServerTitle.
  ///
  /// In en, this message translates to:
  /// **'New {label} server'**
  String newServerTitle(String label);

  /// No description provided for @editServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit server'**
  String get editServerTitle;

  /// No description provided for @torBridgesTitle.
  ///
  /// In en, this message translates to:
  /// **'Tor bridges'**
  String get torBridgesTitle;

  /// No description provided for @subscriptionEditNote.
  ///
  /// In en, this message translates to:
  /// **'This server comes from a subscription: your changes are replaced when it refreshes.'**
  String get subscriptionEditNote;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @countryRow.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryRow;

  /// No description provided for @countryAuto.
  ///
  /// In en, this message translates to:
  /// **'Worked out from the name and address'**
  String get countryAuto;

  /// No description provided for @alreadyInList.
  ///
  /// In en, this message translates to:
  /// **'This server is already in the list'**
  String get alreadyInList;

  /// No description provided for @choiceDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get choiceDefault;

  /// No description provided for @torBridgesNone.
  ///
  /// In en, this message translates to:
  /// **'None (direct, or the lines below)'**
  String get torBridgesNone;

  /// No description provided for @torBridgesSnowflake.
  ///
  /// In en, this message translates to:
  /// **'Snowflake'**
  String get torBridgesSnowflake;

  /// No description provided for @torBridgesObfs4.
  ///
  /// In en, this message translates to:
  /// **'obfs4 (built-in bridges)'**
  String get torBridgesObfs4;

  /// No description provided for @listHelper.
  ///
  /// In en, this message translates to:
  /// **'Separate values with commas'**
  String get listHelper;

  /// No description provided for @fillPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get fillPaste;

  /// No description provided for @fillFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get fillFile;

  /// No description provided for @fillScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get fillScanQr;

  /// No description provided for @openTextFile.
  ///
  /// In en, this message translates to:
  /// **'Open a text file'**
  String get openTextFile;

  /// No description provided for @couldNotReadFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read the file: {error}'**
  String couldNotReadFile(String error);

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'{label} *'**
  String fieldRequired(String label);

  /// No description provided for @formNoEditor.
  ///
  /// In en, this message translates to:
  /// **'No editor for {protocol}'**
  String formNoEditor(String protocol);

  /// No description provided for @shareScanHint.
  ///
  /// In en, this message translates to:
  /// **'Scan with Wardkeep, or copy the link.'**
  String get shareScanHint;

  /// No description provided for @shareCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get shareCopy;

  /// No description provided for @shareCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get shareCopied;

  /// No description provided for @shareWarning.
  ///
  /// In en, this message translates to:
  /// **'Contains the server\'s password or key. Share with care.'**
  String get shareWarning;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'This server cannot be shared as a link: {reason}'**
  String shareFailed(String reason);

  /// No description provided for @shareTooLong.
  ///
  /// In en, this message translates to:
  /// **'Too long for a QR code: copy the link'**
  String get shareTooLong;

  /// No description provided for @obTitle1.
  ///
  /// In en, this message translates to:
  /// **'Private and simple'**
  String get obTitle1;

  /// No description provided for @obText1.
  ///
  /// In en, this message translates to:
  /// **'One calm screen for VPN, proxy and Tor. Pick a place, press Connect.'**
  String get obText1;

  /// No description provided for @obTitle2.
  ///
  /// In en, this message translates to:
  /// **'Add your servers'**
  String get obTitle2;

  /// No description provided for @obText2.
  ///
  /// In en, this message translates to:
  /// **'Import a link, QR code, config file or subscription. Or add a server by hand.'**
  String get obText2;

  /// No description provided for @obTitle3Android.
  ///
  /// In en, this message translates to:
  /// **'Android will ask once'**
  String get obTitle3Android;

  /// No description provided for @obText3Android.
  ///
  /// In en, this message translates to:
  /// **'Android will ask to allow a VPN connection. Accept it to be protected.'**
  String get obText3Android;

  /// No description provided for @obTitle3Desktop.
  ///
  /// In en, this message translates to:
  /// **'Ready when you are'**
  String get obTitle3Desktop;

  /// No description provided for @obText3Desktop.
  ///
  /// In en, this message translates to:
  /// **'Starts in proxy mode, no special rights. Turn on VPN mode in Settings to capture all traffic.'**
  String get obText3Desktop;

  /// No description provided for @obAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add my first server'**
  String get obAddFirst;

  /// No description provided for @bypassTitle.
  ///
  /// In en, this message translates to:
  /// **'Bypass lists'**
  String get bypassTitle;

  /// No description provided for @bypassAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a list'**
  String get bypassAddTooltip;

  /// No description provided for @bypassFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from the clipboard'**
  String get bypassFromClipboard;

  /// No description provided for @bypassFromFile.
  ///
  /// In en, this message translates to:
  /// **'Open a .txt file'**
  String get bypassFromFile;

  /// No description provided for @bypassFromUrl.
  ///
  /// In en, this message translates to:
  /// **'Download from a link'**
  String get bypassFromUrl;

  /// No description provided for @bypassType.
  ///
  /// In en, this message translates to:
  /// **'Type it'**
  String get bypassType;

  /// No description provided for @bypassClipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'The clipboard is empty'**
  String get bypassClipboardEmpty;

  /// No description provided for @bypassPickFile.
  ///
  /// In en, this message translates to:
  /// **'Open a bypass list (.txt)'**
  String get bypassPickFile;

  /// No description provided for @bypassDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download the list: {error}'**
  String bypassDownloadFailed(String error);

  /// No description provided for @bypassIntro.
  ///
  /// In en, this message translates to:
  /// **'Sites and addresses that skip the VPN. One per line: example.com, full:www.example.com, keyword:bank, regexp:…, 203.0.113.7 or 10.0.0.0/8. Lines starting with # are ignored.'**
  String get bypassIntro;

  /// No description provided for @bypassNoLists.
  ///
  /// In en, this message translates to:
  /// **'No lists yet.'**
  String get bypassNoLists;

  /// No description provided for @bypassTypeList.
  ///
  /// In en, this message translates to:
  /// **'Type a list'**
  String get bypassTypeList;

  /// No description provided for @entriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String entriesCount(int count);

  /// No description provided for @bypassOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Only listed use the VPN'**
  String get bypassOnlyTitle;

  /// No description provided for @bypassOnlyOn.
  ///
  /// In en, this message translates to:
  /// **'Everything else goes direct.'**
  String get bypassOnlyOn;

  /// No description provided for @bypassOnlyOff.
  ///
  /// In en, this message translates to:
  /// **'Listed go direct; the rest uses the VPN.'**
  String get bypassOnlyOff;

  /// No description provided for @bypassNothing.
  ///
  /// In en, this message translates to:
  /// **'No list is on.'**
  String get bypassNothing;

  /// No description provided for @bypassInUse.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry in use} other{{count} entries in use}}. Applies on next connect.'**
  String bypassInUse(int count);

  /// No description provided for @bypassHttpLink.
  ///
  /// In en, this message translates to:
  /// **'Enter an http(s) link'**
  String get bypassHttpLink;

  /// No description provided for @bypassServerAnswered.
  ///
  /// In en, this message translates to:
  /// **'the server answered {code}'**
  String bypassServerAnswered(int code);

  /// No description provided for @bypassTooLarge.
  ///
  /// In en, this message translates to:
  /// **'the list is larger than 5 MB'**
  String get bypassTooLarge;

  /// No description provided for @bypassDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download a list'**
  String get bypassDownloadTitle;

  /// No description provided for @bypassNewList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get bypassNewList;

  /// No description provided for @bypassEditList.
  ///
  /// In en, this message translates to:
  /// **'Edit list'**
  String get bypassEditList;

  /// No description provided for @bypassName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get bypassName;

  /// No description provided for @bypassEntriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Entries, one per line'**
  String get bypassEntriesLabel;

  /// No description provided for @bypassNoUsable.
  ///
  /// In en, this message translates to:
  /// **'No usable entries yet.'**
  String get bypassNoUsable;

  /// No description provided for @bypassSummary.
  ///
  /// In en, this message translates to:
  /// **'{entries} · {names}, {ranges}.'**
  String bypassSummary(String entries, String names, String ranges);

  /// No description provided for @bypassNames.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 name} other{{count} names}}'**
  String bypassNames(int count);

  /// No description provided for @bypassRanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 address or range} other{{count} addresses or ranges}}'**
  String bypassRanges(int count);

  /// No description provided for @bypassIgnored.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line will be ignored:} other{{count} lines will be ignored:}}'**
  String bypassIgnored(int count);

  /// No description provided for @bypassMoreIssues.
  ///
  /// In en, this message translates to:
  /// **'… and {count} more'**
  String bypassMoreIssues(int count);

  /// No description provided for @bypassReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to use the new list'**
  String get bypassReconnect;

  /// No description provided for @bypassDefaultName.
  ///
  /// In en, this message translates to:
  /// **'My list'**
  String get bypassDefaultName;

  /// No description provided for @bypassPastedName.
  ///
  /// In en, this message translates to:
  /// **'Pasted list'**
  String get bypassPastedName;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsServers.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get settingsServers;

  /// No description provided for @manageServers.
  ///
  /// In en, this message translates to:
  /// **'Manage servers'**
  String get manageServers;

  /// No description provided for @manageServersHint.
  ///
  /// In en, this message translates to:
  /// **'Servers and subscriptions'**
  String get manageServersHint;

  /// No description provided for @settingsConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get settingsConnection;

  /// No description provided for @vpnMode.
  ///
  /// In en, this message translates to:
  /// **'VPN mode (all traffic)'**
  String get vpnMode;

  /// No description provided for @vpnModeHint.
  ///
  /// In en, this message translates to:
  /// **'Off: proxy only, no VPN permission'**
  String get vpnModeHint;

  /// No description provided for @systemProxy.
  ///
  /// In en, this message translates to:
  /// **'Set system proxy'**
  String get systemProxy;

  /// No description provided for @systemProxyHint.
  ///
  /// In en, this message translates to:
  /// **'Set the system proxy while connected'**
  String get systemProxyHint;

  /// No description provided for @autoSwitch.
  ///
  /// In en, this message translates to:
  /// **'Auto-switch on failure'**
  String get autoSwitch;

  /// No description provided for @autoSwitchHint.
  ///
  /// In en, this message translates to:
  /// **'Try the next server if one fails'**
  String get autoSwitchHint;

  /// No description provided for @bypassLan.
  ///
  /// In en, this message translates to:
  /// **'Bypass local network'**
  String get bypassLan;

  /// No description provided for @bypassLanHint.
  ///
  /// In en, this message translates to:
  /// **'Reach local devices directly (192.168.x.x, 10.x.x.x)'**
  String get bypassLanHint;

  /// No description provided for @bypassListsHint.
  ///
  /// In en, this message translates to:
  /// **'Websites and addresses that skip the VPN'**
  String get bypassListsHint;

  /// No description provided for @bypassListsInUse.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry in use} other{{count} entries in use}}'**
  String bypassListsInUse(int count);

  /// No description provided for @alwaysOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Always-on VPN and kill switch'**
  String get alwaysOnTitle;

  /// No description provided for @alwaysOnHint.
  ///
  /// In en, this message translates to:
  /// **'Reconnect at boot and block leaks. Set in Android\'s VPN settings.'**
  String get alwaysOnHint;

  /// No description provided for @openVpnSettingsFallback.
  ///
  /// In en, this message translates to:
  /// **'Settings → Network → VPN → gear next to Wardkeep'**
  String get openVpnSettingsFallback;

  /// No description provided for @splitTunneling.
  ///
  /// In en, this message translates to:
  /// **'Split tunneling'**
  String get splitTunneling;

  /// No description provided for @splitSummaryOnly.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Only 1 selected app uses the VPN} other{Only {count} selected apps use the VPN}}'**
  String splitSummaryOnly(int count);

  /// No description provided for @splitSummaryBypass.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 app bypasses the VPN} other{{count} apps bypass the VPN}}'**
  String splitSummaryBypass(int count);

  /// No description provided for @splitSummaryOff.
  ///
  /// In en, this message translates to:
  /// **'All apps use the VPN'**
  String get splitSummaryOff;

  /// No description provided for @remoteDns.
  ///
  /// In en, this message translates to:
  /// **'Remote DNS'**
  String get remoteDns;

  /// No description provided for @remoteDnsHelp.
  ///
  /// In en, this message translates to:
  /// **'DNS used through the tunnel, e.g. https://1.1.1.1/dns-query or tls://1.1.1.1'**
  String get remoteDnsHelp;

  /// No description provided for @settingsApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsApp;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow the system'**
  String get themeSystem;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @stopOnClose.
  ///
  /// In en, this message translates to:
  /// **'Stop VPN when app is closed'**
  String get stopOnClose;

  /// No description provided for @aboutLine.
  ///
  /// In en, this message translates to:
  /// **'MIT License · engine: {engine}'**
  String aboutLine(String engine);

  /// No description provided for @splitTitle.
  ///
  /// In en, this message translates to:
  /// **'Split tunneling'**
  String get splitTitle;

  /// No description provided for @splitAll.
  ///
  /// In en, this message translates to:
  /// **'All apps'**
  String get splitAll;

  /// No description provided for @splitOnlySelected.
  ///
  /// In en, this message translates to:
  /// **'Only selected'**
  String get splitOnlySelected;

  /// No description provided for @splitBypassSelected.
  ///
  /// In en, this message translates to:
  /// **'Bypass selected'**
  String get splitBypassSelected;

  /// No description provided for @splitHelpOffMode.
  ///
  /// In en, this message translates to:
  /// **'Every app uses the VPN.'**
  String get splitHelpOffMode;

  /// No description provided for @splitHelpOnlyNone.
  ///
  /// In en, this message translates to:
  /// **'No apps picked: all use the VPN.'**
  String get splitHelpOnlyNone;

  /// No description provided for @splitHelpOnly.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Only 1 app uses the VPN.} other{Only {count} apps use the VPN.}}'**
  String splitHelpOnly(int count);

  /// No description provided for @splitHelpBypass.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 app goes direct.} other{{count} apps go direct.}}'**
  String splitHelpBypass(int count);

  /// No description provided for @searchApps.
  ///
  /// In en, this message translates to:
  /// **'Search apps'**
  String get searchApps;

  /// No description provided for @showSystemApps.
  ///
  /// In en, this message translates to:
  /// **'Show system apps'**
  String get showSystemApps;

  /// No description provided for @couldNotListApps.
  ///
  /// In en, this message translates to:
  /// **'Could not list apps: {error}'**
  String couldNotListApps(String error);

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanTitle;

  /// No description provided for @scanTorch.
  ///
  /// In en, this message translates to:
  /// **'Torch'**
  String get scanTorch;

  /// No description provided for @scanCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable: {code}'**
  String scanCameraUnavailable(String code);

  /// No description provided for @scanPoint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a config QR code'**
  String get scanPoint;

  /// No description provided for @credTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get credTitle;

  /// No description provided for @credNeeds.
  ///
  /// In en, this message translates to:
  /// **'{name} needs a username and password.'**
  String credNeeds(String name);

  /// No description provided for @credUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get credUsername;

  /// No description provided for @credPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get credPassword;

  /// No description provided for @logsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No log entries yet.'**
  String get logsEmpty;

  /// No description provided for @profilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage servers'**
  String get profilesTitle;

  /// No description provided for @addSubscriptionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add subscription'**
  String get addSubscriptionTooltip;

  /// No description provided for @testLatencyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Test latency'**
  String get testLatencyTooltip;

  /// No description provided for @profilesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No profiles. Tap Import to add one.'**
  String get profilesEmptyHint;

  /// No description provided for @profilesDragHint.
  ///
  /// In en, this message translates to:
  /// **'Hold and drag to reorder. Failover follows this order.'**
  String get profilesDragHint;

  /// No description provided for @myProfiles.
  ///
  /// In en, this message translates to:
  /// **'My profiles'**
  String get myProfiles;

  /// No description provided for @subRefreshed.
  ///
  /// In en, this message translates to:
  /// **'{name}: {count, plural, =1{1 profile} other{{count} profiles}}'**
  String subRefreshed(String name, int count);

  /// No description provided for @refreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshTooltip;

  /// No description provided for @subDeleteWithProfiles.
  ///
  /// In en, this message translates to:
  /// **'Delete subscription and its profiles'**
  String get subDeleteWithProfiles;

  /// No description provided for @subUsageOf.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total}'**
  String subUsageOf(String used, String total);

  /// No description provided for @subUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} used'**
  String subUsed(String used);

  /// No description provided for @subExpired.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get subExpired;

  /// No description provided for @subExpiresToday.
  ///
  /// In en, this message translates to:
  /// **'expires today'**
  String get subExpiresToday;

  /// No description provided for @subExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{expires in 1 day} other{expires in {days} days}}'**
  String subExpiresIn(int days);

  /// No description provided for @subUpdated.
  ///
  /// In en, this message translates to:
  /// **'updated {ago}'**
  String subUpdated(String ago);

  /// No description provided for @agoJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get agoJustNow;

  /// No description provided for @agoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String agoMinutes(int count);

  /// No description provided for @agoHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String agoHours(int count);

  /// No description provided for @agoDays.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String agoDays(int count);

  /// No description provided for @subRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Last refresh failed: {error}'**
  String subRefreshFailed(String error);

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import config'**
  String get importTitle;

  /// No description provided for @importDescription.
  ///
  /// In en, this message translates to:
  /// **'Paste a link, config or subscription — or open a file or scan a QR code.'**
  String get importDescription;

  /// No description provided for @importScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get importScanQr;

  /// No description provided for @importOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get importOpenFile;

  /// No description provided for @importPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get importPaste;

  /// No description provided for @importSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get importSubscription;

  /// No description provided for @importTor.
  ///
  /// In en, this message translates to:
  /// **'Tor'**
  String get importTor;

  /// No description provided for @importAddTor.
  ///
  /// In en, this message translates to:
  /// **'Add Tor'**
  String get importAddTor;

  /// No description provided for @importTorDirect.
  ///
  /// In en, this message translates to:
  /// **'Tor (direct)'**
  String get importTorDirect;

  /// No description provided for @importTorSnowflake.
  ///
  /// In en, this message translates to:
  /// **'Tor + Snowflake bridge'**
  String get importTorSnowflake;

  /// No description provided for @importTorObfs4.
  ///
  /// In en, this message translates to:
  /// **'Tor + obfs4 bridges'**
  String get importTorObfs4;

  /// No description provided for @importedProfiles.
  ///
  /// In en, this message translates to:
  /// **'{added, plural, =1{Imported 1 profile} other{Imported {added} profiles}}{dupes, plural, =0{} other{, {dupes} already present}}'**
  String importedProfiles(int added, int dupes);

  /// No description provided for @importNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing imported: {reason}'**
  String importNothing(String reason);

  /// No description provided for @importPartial.
  ///
  /// In en, this message translates to:
  /// **'Imported {added}, failed {failed}'**
  String importPartial(int added, int failed);

  /// No description provided for @subAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add subscription'**
  String get subAddTitle;

  /// No description provided for @subEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit subscription'**
  String get subEditTitle;

  /// No description provided for @subUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Subscription URL'**
  String get subUrlLabel;

  /// No description provided for @subUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://provider.example/sub/… or nordvpn://<token>'**
  String get subUrlHint;

  /// No description provided for @subNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get subNameLabel;

  /// No description provided for @subNameHelp.
  ///
  /// In en, this message translates to:
  /// **'Defaults to the provider\'s title or the host name'**
  String get subNameHelp;

  /// No description provided for @subAuthLabel.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get subAuthLabel;

  /// No description provided for @authNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get authNone;

  /// No description provided for @authBasic.
  ///
  /// In en, this message translates to:
  /// **'Username & password (Basic)'**
  String get authBasic;

  /// No description provided for @authBearer.
  ///
  /// In en, this message translates to:
  /// **'Bearer token'**
  String get authBearer;

  /// No description provided for @authHeader.
  ///
  /// In en, this message translates to:
  /// **'Custom header'**
  String get authHeader;

  /// No description provided for @authQuery.
  ///
  /// In en, this message translates to:
  /// **'Token in URL'**
  String get authQuery;

  /// No description provided for @subUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get subUsername;

  /// No description provided for @subPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get subPassword;

  /// No description provided for @subHeaderName.
  ///
  /// In en, this message translates to:
  /// **'Header name'**
  String get subHeaderName;

  /// No description provided for @subHeaderValue.
  ///
  /// In en, this message translates to:
  /// **'Header value'**
  String get subHeaderValue;

  /// No description provided for @subParamName.
  ///
  /// In en, this message translates to:
  /// **'Parameter name'**
  String get subParamName;

  /// No description provided for @subToken.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get subToken;

  /// No description provided for @subDownloadLabel.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get subDownloadLabel;

  /// No description provided for @subDownloadHelp.
  ///
  /// In en, this message translates to:
  /// **'Provider blocked? The VPN can still fetch it'**
  String get subDownloadHelp;

  /// No description provided for @subViaDirect.
  ///
  /// In en, this message translates to:
  /// **'Directly'**
  String get subViaDirect;

  /// No description provided for @subViaAuto.
  ///
  /// In en, this message translates to:
  /// **'Direct, or via the VPN if blocked'**
  String get subViaAuto;

  /// No description provided for @subViaTunnel.
  ///
  /// In en, this message translates to:
  /// **'Always through the VPN (connect first)'**
  String get subViaTunnel;

  /// No description provided for @subErrUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter an http(s) subscription URL (or nordvpn://<access token>)'**
  String get subErrUrl;

  /// No description provided for @subErrHeader.
  ///
  /// In en, this message translates to:
  /// **'Enter the header name'**
  String get subErrHeader;

  /// No description provided for @subErrToken.
  ///
  /// In en, this message translates to:
  /// **'Enter the token'**
  String get subErrToken;

  /// No description provided for @subAddAndDownload.
  ///
  /// In en, this message translates to:
  /// **'Add and download'**
  String get subAddAndDownload;

  /// No description provided for @subSaveAndRefresh.
  ///
  /// In en, this message translates to:
  /// **'Save and refresh'**
  String get subSaveAndRefresh;

  /// No description provided for @subUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Subscription updated: {count, plural, =1{1 profile} other{{count} profiles}}'**
  String subUpdatedToast(int count);

  /// No description provided for @flName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get flName;

  /// No description provided for @flServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get flServer;

  /// No description provided for @flPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get flPort;

  /// No description provided for @flPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get flPassword;

  /// No description provided for @flUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get flUsername;

  /// No description provided for @flUuid.
  ///
  /// In en, this message translates to:
  /// **'UUID'**
  String get flUuid;

  /// No description provided for @flSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get flSecurity;

  /// No description provided for @flFlow.
  ///
  /// In en, this message translates to:
  /// **'Flow'**
  String get flFlow;

  /// No description provided for @flCipher.
  ///
  /// In en, this message translates to:
  /// **'Cipher'**
  String get flCipher;

  /// No description provided for @flEncryption.
  ///
  /// In en, this message translates to:
  /// **'Encryption'**
  String get flEncryption;

  /// No description provided for @flAlterId.
  ///
  /// In en, this message translates to:
  /// **'Alter id'**
  String get flAlterId;

  /// No description provided for @flTlsServerName.
  ///
  /// In en, this message translates to:
  /// **'TLS server name (SNI)'**
  String get flTlsServerName;

  /// No description provided for @flTlsFingerprint.
  ///
  /// In en, this message translates to:
  /// **'TLS fingerprint'**
  String get flTlsFingerprint;

  /// No description provided for @flAlpn.
  ///
  /// In en, this message translates to:
  /// **'ALPN'**
  String get flAlpn;

  /// No description provided for @flSkipCertCheck.
  ///
  /// In en, this message translates to:
  /// **'Skip certificate check'**
  String get flSkipCertCheck;

  /// No description provided for @flPinnedCert.
  ///
  /// In en, this message translates to:
  /// **'Pinned certificate (PEM)'**
  String get flPinnedCert;

  /// No description provided for @flRealityPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Reality public key'**
  String get flRealityPublicKey;

  /// No description provided for @flRealityShortId.
  ///
  /// In en, this message translates to:
  /// **'Reality short id'**
  String get flRealityShortId;

  /// No description provided for @flTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get flTransport;

  /// No description provided for @flHostHeader.
  ///
  /// In en, this message translates to:
  /// **'Host header'**
  String get flHostHeader;

  /// No description provided for @flPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get flPath;

  /// No description provided for @flGrpcService.
  ///
  /// In en, this message translates to:
  /// **'gRPC service name'**
  String get flGrpcService;

  /// No description provided for @flPlugin.
  ///
  /// In en, this message translates to:
  /// **'Plugin'**
  String get flPlugin;

  /// No description provided for @flPluginOptions.
  ///
  /// In en, this message translates to:
  /// **'Plugin options'**
  String get flPluginOptions;

  /// No description provided for @flObfuscation.
  ///
  /// In en, this message translates to:
  /// **'Obfuscation'**
  String get flObfuscation;

  /// No description provided for @flObfsPassword.
  ///
  /// In en, this message translates to:
  /// **'Obfuscation password'**
  String get flObfsPassword;

  /// No description provided for @flUploadMbps.
  ///
  /// In en, this message translates to:
  /// **'Upload (Mbps)'**
  String get flUploadMbps;

  /// No description provided for @flDownloadMbps.
  ///
  /// In en, this message translates to:
  /// **'Download (Mbps)'**
  String get flDownloadMbps;

  /// No description provided for @flCongestion.
  ///
  /// In en, this message translates to:
  /// **'Congestion control'**
  String get flCongestion;

  /// No description provided for @flUdpRelay.
  ///
  /// In en, this message translates to:
  /// **'UDP relay mode'**
  String get flUdpRelay;

  /// No description provided for @flUseQuic.
  ///
  /// In en, this message translates to:
  /// **'Use HTTP/3 (QUIC)'**
  String get flUseQuic;

  /// No description provided for @flTunnelAddress.
  ///
  /// In en, this message translates to:
  /// **'Your tunnel address'**
  String get flTunnelAddress;

  /// No description provided for @flRoutedNetworks.
  ///
  /// In en, this message translates to:
  /// **'Routed networks'**
  String get flRoutedNetworks;

  /// No description provided for @flDnsServers.
  ///
  /// In en, this message translates to:
  /// **'DNS servers'**
  String get flDnsServers;

  /// No description provided for @flMtu.
  ///
  /// In en, this message translates to:
  /// **'MTU'**
  String get flMtu;

  /// No description provided for @flKeepalive.
  ///
  /// In en, this message translates to:
  /// **'Keepalive (seconds)'**
  String get flKeepalive;

  /// No description provided for @flPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Private key'**
  String get flPrivateKey;

  /// No description provided for @flServerPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Server public key'**
  String get flServerPublicKey;

  /// No description provided for @flPresharedKey.
  ///
  /// In en, this message translates to:
  /// **'Pre-shared key'**
  String get flPresharedKey;

  /// No description provided for @flReservedBytes.
  ///
  /// In en, this message translates to:
  /// **'Reserved bytes'**
  String get flReservedBytes;

  /// No description provided for @flAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get flAuthentication;

  /// No description provided for @flAuthDigest.
  ///
  /// In en, this message translates to:
  /// **'Auth digest'**
  String get flAuthDigest;

  /// No description provided for @flCaCert.
  ///
  /// In en, this message translates to:
  /// **'CA certificate (PEM)'**
  String get flCaCert;

  /// No description provided for @flClientCert.
  ///
  /// In en, this message translates to:
  /// **'Client certificate (PEM)'**
  String get flClientCert;

  /// No description provided for @flClientKey.
  ///
  /// In en, this message translates to:
  /// **'Client key (PEM)'**
  String get flClientKey;

  /// No description provided for @flControlWrap.
  ///
  /// In en, this message translates to:
  /// **'Control channel protection'**
  String get flControlWrap;

  /// No description provided for @flControlWrapKey.
  ///
  /// In en, this message translates to:
  /// **'Control channel key'**
  String get flControlWrapKey;

  /// No description provided for @flKeyDirection.
  ///
  /// In en, this message translates to:
  /// **'Key direction'**
  String get flKeyDirection;

  /// No description provided for @flRemoteCertType.
  ///
  /// In en, this message translates to:
  /// **'Remote certificate type'**
  String get flRemoteCertType;

  /// No description provided for @flVerifyServerName.
  ///
  /// In en, this message translates to:
  /// **'Verify server name'**
  String get flVerifyServerName;

  /// No description provided for @flYourIdentity.
  ///
  /// In en, this message translates to:
  /// **'Your identity'**
  String get flYourIdentity;

  /// No description provided for @flServerIdentity.
  ///
  /// In en, this message translates to:
  /// **'Server identity'**
  String get flServerIdentity;

  /// No description provided for @flServerCertTrust.
  ///
  /// In en, this message translates to:
  /// **'Server certificate to trust (PEM)'**
  String get flServerCertTrust;

  /// No description provided for @flUseSystemIke.
  ///
  /// In en, this message translates to:
  /// **'Use the phone\'s own IKEv2 client'**
  String get flUseSystemIke;

  /// No description provided for @flUseTcp.
  ///
  /// In en, this message translates to:
  /// **'Use TCP'**
  String get flUseTcp;

  /// No description provided for @flHostKeys.
  ///
  /// In en, this message translates to:
  /// **'Host keys'**
  String get flHostKeys;

  /// No description provided for @flPrivateKeyPem.
  ///
  /// In en, this message translates to:
  /// **'Private key (PEM)'**
  String get flPrivateKeyPem;

  /// No description provided for @flKeyPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Key passphrase'**
  String get flKeyPassphrase;

  /// No description provided for @flBridges.
  ///
  /// In en, this message translates to:
  /// **'Bridges'**
  String get flBridges;

  /// No description provided for @flBridgeLines.
  ///
  /// In en, this message translates to:
  /// **'Bridge lines'**
  String get flBridgeLines;

  /// No description provided for @flJc.
  ///
  /// In en, this message translates to:
  /// **'Jc (junk packet count)'**
  String get flJc;

  /// No description provided for @flSignaturePacket.
  ///
  /// In en, this message translates to:
  /// **'I1 (signature packet)'**
  String get flSignaturePacket;

  /// No description provided for @hpAuthorizedKeys.
  ///
  /// In en, this message translates to:
  /// **'authorized_keys format; empty accepts any key'**
  String get hpAuthorizedKeys;

  /// No description provided for @hpIkeTcp.
  ///
  /// In en, this message translates to:
  /// **'Carry IKE and ESP over TCP for networks that block UDP'**
  String get hpIkeTcp;

  /// No description provided for @hpDefaultsToServer.
  ///
  /// In en, this message translates to:
  /// **'Defaults to the server address'**
  String get hpDefaultsToServer;

  /// No description provided for @hpTorBridges.
  ///
  /// In en, this message translates to:
  /// **'Empty connects to Tor directly, or uses the bridge lines below'**
  String get hpTorBridges;

  /// No description provided for @hpExampleAddress.
  ///
  /// In en, this message translates to:
  /// **'For example 10.8.0.2/32'**
  String get hpExampleAddress;

  /// No description provided for @hpExamplePlugin.
  ///
  /// In en, this message translates to:
  /// **'For example shadow-tls or v2ray-plugin'**
  String get hpExamplePlugin;

  /// No description provided for @hpHostOrIp.
  ///
  /// In en, this message translates to:
  /// **'Host name or IP address'**
  String get hpHostOrIp;

  /// No description provided for @hpNeededReality.
  ///
  /// In en, this message translates to:
  /// **'Needed when Security is reality'**
  String get hpNeededReality;

  /// No description provided for @hpOnlySelfSigned.
  ///
  /// In en, this message translates to:
  /// **'Only for servers with a self-signed certificate you cannot pin'**
  String get hpOnlySelfSigned;

  /// No description provided for @hpSafeSstp.
  ///
  /// In en, this message translates to:
  /// **'Safe for SSTP: the password exchange proves the server'**
  String get hpSafeSstp;

  /// No description provided for @hpHysteriaObfs.
  ///
  /// In en, this message translates to:
  /// **'salamander for Hysteria 2; the obfuscation password for Hysteria 1'**
  String get hpHysteriaObfs;

  /// No description provided for @hpTrustCert.
  ///
  /// In en, this message translates to:
  /// **'Trust this certificate instead of the system\'s authorities'**
  String get hpTrustCert;

  /// No description provided for @hpWhichBrowser.
  ///
  /// In en, this message translates to:
  /// **'Which browser\'s TLS handshake to imitate'**
  String get hpWhichBrowser;

  /// No description provided for @hpWarpReserved.
  ///
  /// In en, this message translates to:
  /// **'Three numbers, as WARP configurations list them'**
  String get hpWarpReserved;

  /// No description provided for @hpOneBridgePerLine.
  ///
  /// In en, this message translates to:
  /// **'One bridge per line, as in a torrc without \"Bridge \"'**
  String get hpOneBridgePerLine;

  /// No description provided for @exitTitle.
  ///
  /// In en, this message translates to:
  /// **'Show exit address and country'**
  String get exitTitle;

  /// No description provided for @exitHint.
  ///
  /// In en, this message translates to:
  /// **'Ask api.country.is for your IP and country, also when not connected.'**
  String get exitHint;

  /// No description provided for @exitIpLabel.
  ///
  /// In en, this message translates to:
  /// **'IP {ip}'**
  String exitIpLabel(String ip);

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to {place}'**
  String connectedTo(String place);

  /// No description provided for @noticesTitle.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get noticesTitle;

  /// No description provided for @noticesIntro.
  ///
  /// In en, this message translates to:
  /// **'Wardkeep is MIT licensed. It includes the software below, each under its own license.'**
  String get noticesIntro;

  /// No description provided for @noticesMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String noticesMore(int count);

  /// No description provided for @noticesPackages.
  ///
  /// In en, this message translates to:
  /// **'{count} packages'**
  String noticesPackages(int count);

  /// No description provided for @noticesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The license list could not be read.'**
  String get noticesLoadFailed;

  /// No description provided for @formRequired.
  ///
  /// In en, this message translates to:
  /// **'{label} is required'**
  String formRequired(String label);

  /// No description provided for @formNotNumber.
  ///
  /// In en, this message translates to:
  /// **'{label} must be a whole number'**
  String formNotNumber(String label);

  /// No description provided for @formNotBool.
  ///
  /// In en, this message translates to:
  /// **'{label} must be on or off'**
  String formNotBool(String label);

  /// No description provided for @formBadChoice.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value} is not one of {choices}'**
  String formBadChoice(String label, String value, String choices);

  /// No description provided for @formRealityOnlyVless.
  ///
  /// In en, this message translates to:
  /// **'Reality is only available for VLESS'**
  String get formRealityOnlyVless;

  /// No description provided for @formUnknownSecurity.
  ///
  /// In en, this message translates to:
  /// **'Unknown security: {value}'**
  String formUnknownSecurity(String value);

  /// No description provided for @formReservedBytes.
  ///
  /// In en, this message translates to:
  /// **'Reserved bytes must be numbers from 0 to 255'**
  String get formReservedBytes;

  /// No description provided for @formRealityKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'The Reality public key is required when Security is Reality'**
  String get formRealityKeyRequired;

  /// No description provided for @importUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This is not a server link, subscription or config that Wardkeep can read'**
  String get importUnsupported;

  /// No description provided for @importUnsupportedScheme.
  ///
  /// In en, this message translates to:
  /// **'Links that start with {scheme}:// are not supported'**
  String importUnsupportedScheme(String scheme);

  /// No description provided for @importXrayServer.
  ///
  /// In en, this message translates to:
  /// **'This is an Xray server config. Import it on the server (omnitun-server import xray), not as a client profile'**
  String get importXrayServer;

  /// No description provided for @subAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'The subscription rejected the sign-in. Check the username, password or token'**
  String get subAuthFailed;

  /// No description provided for @subHttp.
  ///
  /// In en, this message translates to:
  /// **'The subscription server answered HTTP {status}'**
  String subHttp(String status);

  /// No description provided for @subTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The subscription is larger than 10 MB'**
  String get subTooLarge;

  /// No description provided for @subBadUrl.
  ///
  /// In en, this message translates to:
  /// **'That is not a valid subscription address'**
  String get subBadUrl;

  /// No description provided for @bypassIssueEmptyExpression.
  ///
  /// In en, this message translates to:
  /// **'empty expression'**
  String get bypassIssueEmptyExpression;

  /// No description provided for @bypassIssueBadExpression.
  ///
  /// In en, this message translates to:
  /// **'not a valid expression'**
  String get bypassIssueBadExpression;

  /// No description provided for @bypassIssueBadName.
  ///
  /// In en, this message translates to:
  /// **'not a valid name'**
  String get bypassIssueBadName;

  /// No description provided for @bypassIssueGeo.
  ///
  /// In en, this message translates to:
  /// **'geo lists are not supported; list the domains or ranges'**
  String get bypassIssueGeo;

  /// No description provided for @bypassIssueBadEntry.
  ///
  /// In en, this message translates to:
  /// **'not a domain, address or range'**
  String get bypassIssueBadEntry;

  /// No description provided for @bypassIssueTooMany.
  ///
  /// In en, this message translates to:
  /// **'more than {limit} entries: the rest is ignored'**
  String bypassIssueTooMany(int limit);

  /// No description provided for @torStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting Tor'**
  String get torStarting;

  /// No description provided for @torBootstrap.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Tor {percent}%'**
  String torBootstrap(int percent);

  /// No description provided for @torCircuit.
  ///
  /// In en, this message translates to:
  /// **'Building a Tor circuit'**
  String get torCircuit;

  /// No description provided for @torRetry.
  ///
  /// In en, this message translates to:
  /// **'Retrying Tor ({attempt}/{attempts})'**
  String torRetry(int attempt, int attempts);

  /// No description provided for @importNoServer.
  ///
  /// In en, this message translates to:
  /// **'No valid server was found in this text'**
  String get importNoServer;

  /// No description provided for @importJsonSyntax.
  ///
  /// In en, this message translates to:
  /// **'This is not valid JSON: unexpected {found} at line {line}, column {column}.'**
  String importJsonSyntax(String found, int line, int column);

  /// No description provided for @importJsonEnd.
  ///
  /// In en, this message translates to:
  /// **'This is not valid JSON: the text ends too early, at line {line}, column {column}. A closing bracket, brace or quote may be missing.'**
  String importJsonEnd(int line, int column);

  /// No description provided for @importJsonNoServer.
  ///
  /// In en, this message translates to:
  /// **'This JSON is valid, but it has no proxy server in it. Use a client config with a VLESS, VMess, Trojan, Shadowsocks or similar outbound.'**
  String get importJsonNoServer;

  /// No description provided for @importJsonNoServerFound.
  ///
  /// In en, this message translates to:
  /// **'This JSON is valid, but it has no proxy server in it (it holds {found}). Use a client config with a VLESS, VMess, Trojan, Shadowsocks or similar outbound.'**
  String importJsonNoServerFound(String found);

  /// No description provided for @importTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This is too large to import (the limit is {limit} MB).'**
  String importTooLarge(int limit);

  /// No description provided for @importFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'The file is empty.'**
  String get importFileEmpty;

  /// No description provided for @importFileNotText.
  ///
  /// In en, this message translates to:
  /// **'The file is not text that Wardkeep can read (it looks binary, or it is in an unknown encoding). Use a UTF-8 or UTF-16 text file.'**
  String get importFileNotText;

  /// No description provided for @importFileNoPermission.
  ///
  /// In en, this message translates to:
  /// **'Wardkeep is not allowed to read this file.'**
  String get importFileNoPermission;

  /// No description provided for @importFileMissing.
  ///
  /// In en, this message translates to:
  /// **'The file was not found. It may have been moved or deleted.'**
  String get importFileMissing;

  /// No description provided for @importDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get importDetails;

  /// No description provided for @importJsonNote.
  ///
  /// In en, this message translates to:
  /// **'A JSON config (Xray, sing-box, SIP008) or a list of them also works, as text or as a file.'**
  String get importJsonNote;

  /// No description provided for @ipdbTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline country database'**
  String get ipdbTitle;

  /// No description provided for @ipdbIntro.
  ///
  /// In en, this message translates to:
  /// **'Download a database once, and Wardkeep finds the country of a server or an address by itself, without asking a website.'**
  String get ipdbIntro;

  /// No description provided for @ipdbSizeNote.
  ///
  /// In en, this message translates to:
  /// **'About {size} · free data (public domain)'**
  String ipdbSizeNote(String size);

  /// No description provided for @ipdbDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get ipdbDownload;

  /// No description provided for @ipdbContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get ipdbContinue;

  /// No description provided for @ipdbPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get ipdbPause;

  /// No description provided for @ipdbUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get ipdbUpdate;

  /// No description provided for @ipdbDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get ipdbDelete;

  /// No description provided for @ipdbDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the database?'**
  String get ipdbDeleteTitle;

  /// No description provided for @ipdbUse.
  ///
  /// In en, this message translates to:
  /// **'Use the database'**
  String get ipdbUse;

  /// No description provided for @ipdbStepV4.
  ///
  /// In en, this message translates to:
  /// **'IPv4'**
  String get ipdbStepV4;

  /// No description provided for @ipdbStepV6.
  ///
  /// In en, this message translates to:
  /// **'IPv6'**
  String get ipdbStepV6;

  /// No description provided for @ipdbStepPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare'**
  String get ipdbStepPrepare;

  /// No description provided for @ipdbPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get ipdbPreparing;

  /// No description provided for @ipdbReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ipdbReady;

  /// No description provided for @ipdbStoppedAt.
  ///
  /// In en, this message translates to:
  /// **'Stopped at {percent}%. Continue picks up right there.'**
  String ipdbStoppedAt(int percent);

  /// No description provided for @ipdbFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {reason}'**
  String ipdbFailed(String reason);

  /// No description provided for @ipdbReadyLine.
  ///
  /// In en, this message translates to:
  /// **'{ranges} ranges · {size}'**
  String ipdbReadyLine(String ranges, String size);

  /// No description provided for @ipdbVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · {date}'**
  String ipdbVersion(String version, String date);

  /// No description provided for @ipdbLeft.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String ipdbLeft(String time);

  /// No description provided for @ipdbSource.
  ///
  /// In en, this message translates to:
  /// **'Data: regional internet registries and ASN announcements (CC0), from the ip-location-db project.'**
  String get ipdbSource;

  /// No description provided for @ipdbSubNone.
  ///
  /// In en, this message translates to:
  /// **'Find countries without asking a website'**
  String get ipdbSubNone;

  /// No description provided for @ipdbSubReady.
  ///
  /// In en, this message translates to:
  /// **'On · {size}'**
  String ipdbSubReady(String size);

  /// No description provided for @ipdbSubOff.
  ///
  /// In en, this message translates to:
  /// **'Off · {size}'**
  String ipdbSubOff(String size);

  /// No description provided for @ipdbSubDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String ipdbSubDownloading(int percent);

  /// No description provided for @ipdbSubStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped at {percent}%'**
  String ipdbSubStopped(int percent);

  /// No description provided for @ipdbErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'no connection to the data servers'**
  String get ipdbErrNetwork;

  /// No description provided for @ipdbErrMirrors.
  ///
  /// In en, this message translates to:
  /// **'the data servers did not send the right file'**
  String get ipdbErrMirrors;

  /// No description provided for @bypassCountriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Countries'**
  String get bypassCountriesTitle;

  /// No description provided for @bypassCountriesNone.
  ///
  /// In en, this message translates to:
  /// **'No country chosen'**
  String get bypassCountriesNone;

  /// No description provided for @bypassCountriesMore.
  ///
  /// In en, this message translates to:
  /// **'{names} +{count}'**
  String bypassCountriesMore(String names, int count);

  /// No description provided for @bypassCountriesIntro.
  ///
  /// In en, this message translates to:
  /// **'Traffic to the chosen countries goes straight to the internet, around the VPN. Their address ranges come from the offline country database.'**
  String get bypassCountriesIntro;

  /// No description provided for @bypassCountriesGetDb.
  ///
  /// In en, this message translates to:
  /// **'Get the country database'**
  String get bypassCountriesGetDb;

  /// No description provided for @bypassCountriesSearch.
  ///
  /// In en, this message translates to:
  /// **'Search countries'**
  String get bypassCountriesSearch;

  /// No description provided for @windowMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get windowMinimize;

  /// No description provided for @windowMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get windowMaximize;

  /// No description provided for @windowRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get windowRestore;

  /// No description provided for @windowClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get windowClose;

  /// No description provided for @windowFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get windowFullScreen;

  /// No description provided for @windowExitFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get windowExitFullScreen;

  /// No description provided for @globeRecenter.
  ///
  /// In en, this message translates to:
  /// **'Centre the Earth'**
  String get globeRecenter;

  /// No description provided for @bypassCountriesZoneIntro.
  ///
  /// In en, this message translates to:
  /// **'Each country you tick downloads its address ranges (a few kilobytes). The full offline database is more exact and needs no download.'**
  String get bypassCountriesZoneIntro;

  /// No description provided for @bypassCountriesDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get bypassCountriesDownloading;

  /// No description provided for @bypassCountriesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download. Tap to try again.'**
  String get bypassCountriesFailed;

  /// No description provided for @bypassCountriesYourServer.
  ///
  /// In en, this message translates to:
  /// **'Your selected server is here: its traffic would skip the VPN too.'**
  String get bypassCountriesYourServer;

  /// Settings switch: whether IPv6 traffic is allowed through the VPN
  ///
  /// In en, this message translates to:
  /// **'IPv6'**
  String get ipv6Title;

  /// No description provided for @ipv6Hint.
  ///
  /// In en, this message translates to:
  /// **'Off: only IPv4 is used; IPv6 connections are refused, not sent around the VPN.'**
  String get ipv6Hint;

  /// Settings row: the packet size of the VPN tunnel
  ///
  /// In en, this message translates to:
  /// **'MTU'**
  String get mtuTitle;

  /// No description provided for @mtuAuto.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get mtuAuto;

  /// No description provided for @mtuHelp.
  ///
  /// In en, this message translates to:
  /// **'The packet size of the tunnel (VPN mode only). Try 1280 to 1420 if some sites hang on a mobile network. Empty is the default.'**
  String get mtuHelp;

  /// Error under the MTU field
  ///
  /// In en, this message translates to:
  /// **'Enter a number from {min} to {max}.'**
  String mtuInvalid(int min, int max);

  /// Windows tray menu: brings the app window back
  ///
  /// In en, this message translates to:
  /// **'Open Wardkeep'**
  String get trayOpen;

  /// Windows tray menu: ends the app and its core
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// Windows tray menu: submenu listing the servers
  ///
  /// In en, this message translates to:
  /// **'Switch server'**
  String get traySwitchServer;

  /// Windows setting: closing the window hides it to the tray
  ///
  /// In en, this message translates to:
  /// **'Keep running in the tray'**
  String get keepInTray;

  /// Explains the keep-in-tray setting
  ///
  /// In en, this message translates to:
  /// **'Closing the window only hides it. Use Quit in the tray menu to end the app and the VPN.'**
  String get keepInTrayHint;

  /// Under a server: how much data went through it, e.g. 1.2 GB used
  ///
  /// In en, this message translates to:
  /// **'{size} used'**
  String usageUsed(String size);

  /// No description provided for @menuResetUsage.
  ///
  /// In en, this message translates to:
  /// **'Reset data usage'**
  String get menuResetUsage;

  /// Help text at the top of the DNS screen
  ///
  /// In en, this message translates to:
  /// **'Website names are looked up through the VPN by the resolver you choose. DNSCrypt also proves that the answer came from that resolver.'**
  String get dnsPickerHelp;

  /// Title of the default DNS choice
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get dnsDefault;

  /// Header over the list of DNSCrypt resolvers; they all validate DNSSEC, keep no logs and block nothing
  ///
  /// In en, this message translates to:
  /// **'DNSCrypt · DNSSEC, no logs, no filtering'**
  String get dnsSectionDnscrypt;

  /// A DNS resolver the person types in
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get dnsCustom;

  /// Field label: a resolver URL or an sdns:// stamp
  ///
  /// In en, this message translates to:
  /// **'Address or DNS stamp'**
  String get dnsCustomLabel;

  /// Switch: send DNSCrypt queries through a relay
  ///
  /// In en, this message translates to:
  /// **'Anonymized DNSCrypt'**
  String get dnsAnonymized;

  /// Explains Anonymized DNSCrypt
  ///
  /// In en, this message translates to:
  /// **'Queries go through a relay, so the resolver never sees where they come from'**
  String get dnsAnonymizedHint;

  /// Shown under the Anonymized switch while it cannot be used
  ///
  /// In en, this message translates to:
  /// **'Choose a DNSCrypt resolver to use this'**
  String get dnsAnonymizedNeedsDnscrypt;

  /// The relay Anonymized DNSCrypt goes through
  ///
  /// In en, this message translates to:
  /// **'Relay'**
  String get dnsRelay;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Choose a relay'**
  String get dnsRelayChoose;

  /// Relay choice: the app picks one run by someone other than the resolver's operator
  ///
  /// In en, this message translates to:
  /// **'Automatic (another operator)'**
  String get dnsRelayAutomatic;

  /// Error under the custom DNS field
  ///
  /// In en, this message translates to:
  /// **'Use an address that starts with https://, tls://, tcp:// or udp://, or an sdns:// stamp'**
  String get dnsErrAddress;

  /// Error for an invalid DNS stamp
  ///
  /// In en, this message translates to:
  /// **'This stamp is damaged or cut short. Copy it again.'**
  String get dnsErrDamaged;

  /// Error for a DNS stamp of a kind the app does not use
  ///
  /// In en, this message translates to:
  /// **'This kind of stamp is not supported'**
  String get dnsErrUnsupported;

  /// Error when a relay stamp is typed as the resolver
  ///
  /// In en, this message translates to:
  /// **'This is a relay stamp, not a resolver'**
  String get dnsErrRelayStamp;

  /// A line in the connected screen naming the resolver, e.g. DNS: DNSCrypt · quad9.net
  ///
  /// In en, this message translates to:
  /// **'DNS: {resolver}'**
  String dnsLine(String resolver);

  /// Short note at the bottom of the DNS screen
  ///
  /// In en, this message translates to:
  /// **'This protects the names you look up. It does not hide which sites you then connect to.'**
  String get dnsLimits;

  /// Short tag after a DNS resolver name when its queries go through a relay
  ///
  /// In en, this message translates to:
  /// **'anonymized'**
  String get dnsAnonymizedShort;

  /// Field label of the Tailscale/Headscale profile editor (the key that lets this device join the network)
  ///
  /// In en, this message translates to:
  /// **'Auth key'**
  String get flAuthKey;

  /// Field label of the Tailscale/Headscale profile editor (the coordination server)
  ///
  /// In en, this message translates to:
  /// **'Control server'**
  String get flControlServer;

  /// Field label of the Tailscale/Headscale profile editor (this device's name in the network)
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get flDeviceName;

  /// Field label of the Tailscale/Headscale profile editor (the device whose internet connection is used)
  ///
  /// In en, this message translates to:
  /// **'Exit device'**
  String get flExitDevice;

  /// Field label of the Tailscale/Headscale profile editor (accept the routes other devices advertise)
  ///
  /// In en, this message translates to:
  /// **'Use subnets of other devices'**
  String get flUseSubnets;

  /// Field label of the Tailscale/Headscale profile editor (an ephemeral node)
  ///
  /// In en, this message translates to:
  /// **'Temporary device'**
  String get flTempDevice;

  /// Help text under the auth key field of the Tailscale/Headscale profile editor
  ///
  /// In en, this message translates to:
  /// **'A pre-authorized key from the Tailscale admin page, or made by headscale preauthkeys create'**
  String get hpAuthKey;

  /// Help text under the control server field of the Tailscale/Headscale profile editor
  ///
  /// In en, this message translates to:
  /// **'Empty uses Tailscale; for Headscale, its address such as https://hs.example.com'**
  String get hpControlServer;

  /// Help text under the device name field of the Tailscale/Headscale profile editor
  ///
  /// In en, this message translates to:
  /// **'The name this device has in the network; empty uses the device\'s own'**
  String get hpDeviceName;

  /// Help text under the exit device field of the Tailscale/Headscale profile editor
  ///
  /// In en, this message translates to:
  /// **'Name or address of a device whose internet connection to use; empty reaches only your devices'**
  String get hpExitDevice;

  /// Help text under the temporary device switch of the Tailscale/Headscale profile editor
  ///
  /// In en, this message translates to:
  /// **'Removed from the network when it goes offline'**
  String get hpTempDevice;

  /// Title of the screen that lists the devices of the connected Tailscale/Headscale network; also the name of that group in the location list
  ///
  /// In en, this message translates to:
  /// **'My devices'**
  String get devicesTitle;

  /// No description provided for @devicesNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Connect a Tailscale or Headscale profile to see your devices.'**
  String get devicesNotConnected;

  /// No description provided for @devicesJoining.
  ///
  /// In en, this message translates to:
  /// **'Joining the network…'**
  String get devicesJoining;

  /// No description provided for @devicesLoginNeeded.
  ///
  /// In en, this message translates to:
  /// **'The network did not accept this device\'s key. Make a new key and edit the profile.'**
  String get devicesLoginNeeded;

  /// No description provided for @devicesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No other devices in this network yet.'**
  String get devicesEmpty;

  /// No description provided for @devicesThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get devicesThisDevice;

  /// No description provided for @deviceOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get deviceOnline;

  /// No description provided for @deviceOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get deviceOffline;

  /// When an offline device was last online
  ///
  /// In en, this message translates to:
  /// **'Last seen {when}'**
  String deviceLastSeen(String when);

  /// No description provided for @deviceUseAsExit.
  ///
  /// In en, this message translates to:
  /// **'Use as exit'**
  String get deviceUseAsExit;

  /// No description provided for @deviceStopExit.
  ///
  /// In en, this message translates to:
  /// **'Stop using as exit'**
  String get deviceStopExit;

  /// No description provided for @deviceIsExit.
  ///
  /// In en, this message translates to:
  /// **'Exit in use'**
  String get deviceIsExit;

  /// No description provided for @devicesExitHint.
  ///
  /// In en, this message translates to:
  /// **'Use one of your devices as the exit: all your traffic leaves from its connection.'**
  String get devicesExitHint;

  /// No description provided for @deviceCopyName.
  ///
  /// In en, this message translates to:
  /// **'Copy name'**
  String get deviceCopyName;

  /// No description provided for @deviceCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get deviceCopyAddress;

  /// No description provided for @deviceCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get deviceCopied;

  /// No description provided for @errMeshExit.
  ///
  /// In en, this message translates to:
  /// **'That device cannot be used as the exit right now. It must be online and offer its connection.'**
  String get errMeshExit;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'The server\'s certificate is not checked. Anyone on the path can read or change your traffic.'**
  String get wnTlsInsecure;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'Traffic is not wrapped in TLS. It is easy to recognise and may be read on the way.'**
  String get wnNoTls;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'VMess is an older protocol and is easy to recognise. VLESS with Reality is a better choice.'**
  String get wnVmessLegacy;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'Without a plugin such as shadow-tls the traffic looks like random bytes, and some networks block that pattern.'**
  String get wnSsPlain;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'Hysteria 1 is deprecated. Use Hysteria 2 when the server supports it.'**
  String get wnHysteria1;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'This protocol is easy to identify and is often blocked on strict networks.'**
  String get wnDpiVisible;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'SSH tunnels are easy to identify.'**
  String get wnSshVisible;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'Slow (usually well under 1 Mbit/s) and TCP only. It sends many DNS queries that the network can see. Use it when nothing else works.'**
  String get wnDnsttSlow;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'No username or password: anyone with this link can use the server.'**
  String get wnDnsttOpen;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'Multiplexing puts many connections on one. A bad link can slow all of them.'**
  String get wnMuxLossy;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'Fragmenting the handshake helps against some filters, may break on others, and adds delay.'**
  String get wnFragmentSide;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'Needs a server that supports ECH. Otherwise the connection fails.'**
  String get wnEchServer;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'WireGuard inside a proxy: if the proxy is slow, the tunnel can stall. The proxy must carry UDP.'**
  String get wnWgChain;

  /// A warning about a weakness of a protocol or setting (see core/profile/warning.go)
  ///
  /// In en, this message translates to:
  /// **'This list is not signed, so a changed list cannot be detected.'**
  String get wnSubUnsigned;

  /// The empty choice of a setting that can be switched off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get choiceOff;

  /// Editor text for the multiplexing setting
  ///
  /// In en, this message translates to:
  /// **'Multiplexing'**
  String get flMultiplexing;

  /// Editor text for the multiplexing setting
  ///
  /// In en, this message translates to:
  /// **'Multiplexing padding'**
  String get flMuxPadding;

  /// Editor text for the multiplexing setting
  ///
  /// In en, this message translates to:
  /// **'Most connections'**
  String get flMuxMaxConnections;

  /// Editor text for the multiplexing setting
  ///
  /// In en, this message translates to:
  /// **'Fewest streams per connection'**
  String get flMuxMinStreams;

  /// Editor text for the multiplexing setting
  ///
  /// In en, this message translates to:
  /// **'Most streams per connection'**
  String get flMuxMaxStreams;

  /// Editor text for the multiplexing setting
  ///
  /// In en, this message translates to:
  /// **'Many connections over one; the server must allow it. Not with the VLESS flow'**
  String get hpMultiplexing;

  /// Editor text for the multiplexing setting
  ///
  /// In en, this message translates to:
  /// **'Instead of the two above'**
  String get hpMuxMaxStreams;

  /// Editor text for the TLS handshake options (fragmenting, ECH)
  ///
  /// In en, this message translates to:
  /// **'Fragment the TLS handshake'**
  String get flTlsFragment;

  /// Editor text for the TLS handshake options (fragmenting, ECH)
  ///
  /// In en, this message translates to:
  /// **'Fragment the TLS records'**
  String get flTlsRecordFragment;

  /// Editor text for the TLS handshake options (fragmenting, ECH)
  ///
  /// In en, this message translates to:
  /// **'Encrypted Client Hello (ECH)'**
  String get flEch;

  /// Editor text for the TLS handshake options (fragmenting, ECH)
  ///
  /// In en, this message translates to:
  /// **'ECH config (PEM)'**
  String get flEchConfig;

  /// Editor text for the TLS handshake options (fragmenting, ECH)
  ///
  /// In en, this message translates to:
  /// **'ECH lookup name'**
  String get flEchQueryName;

  /// Editor text for the TLS handshake options (fragmenting, ECH)
  ///
  /// In en, this message translates to:
  /// **'Splits the first packet so a filter cannot read the server name'**
  String get hpTlsFragment;

  /// Editor text for the TLS handshake options (fragmenting, ECH)
  ///
  /// In en, this message translates to:
  /// **'Splits the records instead of the packets'**
  String get hpTlsRecordFragment;

  /// Editor text for the TLS handshake options (fragmenting, ECH)
  ///
  /// In en, this message translates to:
  /// **'Hides the server name; needs a server that supports it'**
  String get hpEch;

  /// Editor text for the TLS handshake options (fragmenting, ECH)
  ///
  /// In en, this message translates to:
  /// **'Empty looks it up in DNS'**
  String get hpEchConfig;

  /// Editor text for the TLS handshake options (fragmenting, ECH)
  ///
  /// In en, this message translates to:
  /// **'Defaults to the server name'**
  String get hpEchQueryName;

  /// Editor text for WireGuard through a proxy
  ///
  /// In en, this message translates to:
  /// **'Through a proxy (share link)'**
  String get flWgVia;

  /// Editor text for WireGuard through a proxy
  ///
  /// In en, this message translates to:
  /// **'Carries WireGuard inside this proxy, for networks that block UDP. The proxy must pass UDP'**
  String get hpWgVia;

  /// Signed subscriptions: the signing key, backup addresses and what a failed check says
  ///
  /// In en, this message translates to:
  /// **'Signed'**
  String get subSigned;

  /// Signed subscriptions: the signing key, backup addresses and what a failed check says
  ///
  /// In en, this message translates to:
  /// **'Signing key (optional)'**
  String get subKeyLabel;

  /// Signed subscriptions: the signing key, backup addresses and what a failed check says
  ///
  /// In en, this message translates to:
  /// **'The provider\'s public key. Without a valid signature made with it, an answer is refused'**
  String get subKeyHelp;

  /// Signed subscriptions: the signing key, backup addresses and what a failed check says
  ///
  /// In en, this message translates to:
  /// **'Backup addresses (optional)'**
  String get subBackupLabel;

  /// Signed subscriptions: the signing key, backup addresses and what a failed check says
  ///
  /// In en, this message translates to:
  /// **'One per line. Tried in order when the first cannot be reached'**
  String get subBackupHelp;

  /// Signed subscriptions: the signing key, backup addresses and what a failed check says
  ///
  /// In en, this message translates to:
  /// **'The signing key is not a valid public key'**
  String get subErrKey;

  /// Signed subscriptions: the signing key, backup addresses and what a failed check says
  ///
  /// In en, this message translates to:
  /// **'The subscription is not signed, but a signing key is set, so it was refused'**
  String get subUnsigned;

  /// Signed subscriptions: the signing key, backup addresses and what a failed check says
  ///
  /// In en, this message translates to:
  /// **'The subscription\'s signature is wrong: it may have been changed on the way, or the key is old'**
  String get subBadSignature;

  /// A signed subscription answer older than the last one accepted
  ///
  /// In en, this message translates to:
  /// **'This answer is older than the last one accepted, so it was refused. If the provider restored an old backup, edit the subscription and save it again.'**
  String get subStale;

  /// DNS tunnel editor text (core/profile/dnstt.go) and the resolver scan
  ///
  /// In en, this message translates to:
  /// **'Tunnel domain'**
  String get flTunnelDomain;

  /// DNS tunnel editor text (core/profile/dnstt.go) and the resolver scan
  ///
  /// In en, this message translates to:
  /// **'Server key'**
  String get flServerKey;

  /// DNS tunnel editor text (core/profile/dnstt.go) and the resolver scan
  ///
  /// In en, this message translates to:
  /// **'Resolvers'**
  String get flResolvers;

  /// DNS tunnel editor text (core/profile/dnstt.go) and the resolver scan
  ///
  /// In en, this message translates to:
  /// **'The zone you delegated to the tunnel server, such as t.example.com'**
  String get hpTunnelDomain;

  /// DNS tunnel editor text (core/profile/dnstt.go) and the resolver scan
  ///
  /// In en, this message translates to:
  /// **'64 hexadecimal digits; the server prints it'**
  String get hpServerKey;

  /// DNS tunnel editor text (core/profile/dnstt.go) and the resolver scan
  ///
  /// In en, this message translates to:
  /// **'Tried in order: udp://IP:port, tls://host:port or https://host/path'**
  String get hpResolvers;

  /// DNS tunnel editor text (core/profile/dnstt.go) and the resolver scan
  ///
  /// In en, this message translates to:
  /// **'The login of the server\'s SOCKS5 upstream; empty if it has none'**
  String get hpTunnelLogin;

  /// DNS tunnel editor text (core/profile/dnstt.go) and the resolver scan
  ///
  /// In en, this message translates to:
  /// **'Find working resolvers'**
  String get scanFind;

  /// DNS tunnel editor text (core/profile/dnstt.go) and the resolver scan
  ///
  /// In en, this message translates to:
  /// **'Trying resolvers…'**
  String get scanBusy;

  /// DNS tunnel editor text (core/profile/dnstt.go) and the resolver scan
  ///
  /// In en, this message translates to:
  /// **'Working resolvers found: {count}'**
  String scanFound(int count);

  /// DNS tunnel editor text (core/profile/dnstt.go) and the resolver scan
  ///
  /// In en, this message translates to:
  /// **'No resolver worked. Check the domain and the key, and that the server is running.'**
  String get scanNone;

  /// DNS tunnel editor text (core/profile/dnstt.go) and the resolver scan
  ///
  /// In en, this message translates to:
  /// **'Disconnect first: the scan has to use the network directly, not through the VPN.'**
  String get scanConnected;

  /// DNS tunnel editor text (core/profile/dnstt.go) and the resolver scan
  ///
  /// In en, this message translates to:
  /// **'Fill in the tunnel domain and the server key first.'**
  String get scanNeedsFields;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'en',
    'es',
    'fa',
    'fr',
    'hi',
    'id',
    'pt',
    'ru',
    'tr',
    'ur',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fa':
      return AppLocalizationsFa();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'ur':
      return AppLocalizationsUr();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
