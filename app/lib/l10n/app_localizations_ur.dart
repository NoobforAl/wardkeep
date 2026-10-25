// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appName => 'Wardkeep';

  @override
  String get actionSave => 'محفوظ کریں';

  @override
  String get actionCancel => 'منسوخ کریں';

  @override
  String get actionDelete => 'حذف کریں';

  @override
  String get actionEdit => 'ترمیم';

  @override
  String get actionReset => 'ری سیٹ';

  @override
  String get actionSkip => 'چھوڑیں';

  @override
  String get actionNext => 'اگلا';

  @override
  String get actionImport => 'درآمد کریں';

  @override
  String get actionDownload => 'ڈاؤن لوڈ';

  @override
  String get actionCopyAll => 'سب کاپی کریں';

  @override
  String get actionClear => 'صاف کریں';

  @override
  String get tooltipMore => 'مزید';

  @override
  String get tooltipShow => 'دکھائیں';

  @override
  String get tooltipHide => 'چھپائیں';

  @override
  String get searchHint => 'تلاش';

  @override
  String get tooltipLogs => 'لاگز';

  @override
  String get tooltipSettings => 'ترتیبات';

  @override
  String get statusConnected => 'منسلک';

  @override
  String get statusConnecting => 'منسلک ہو رہا ہے…';

  @override
  String get statusDisconnecting => 'منقطع ہو رہا ہے…';

  @override
  String get statusError => 'کنکشن ناکام رہا';

  @override
  String get statusNoInternet => 'انٹرنیٹ کنکشن نہیں ہے';

  @override
  String get statusDisconnected => 'منسلک نہیں';

  @override
  String get stagePermission => 'VPN کی اجازت کا انتظار';

  @override
  String get stageNetworkCheck => 'انٹرنیٹ کنکشن کی جانچ';

  @override
  String get stagePrepare => 'کنفیگریشن تیار ہو رہی ہے';

  @override
  String get stageEngineStart => 'انجن شروع ہو رہا ہے';

  @override
  String get stageTunnelUp => 'ٹنل کھل رہی ہے';

  @override
  String get stageHandshake => 'سرور سے رابطہ ہو رہا ہے';

  @override
  String get stageConnected => 'منسلک';

  @override
  String get buttonConnect => 'منسلک ہوں';

  @override
  String get buttonDisconnect => 'منقطع کریں';

  @override
  String get buttonCancel => 'منسوخ کریں';

  @override
  String get locationLabel => 'مقام';

  @override
  String get noServers => 'کوئی سرور نہیں';

  @override
  String get noServersHint => 'شروع کرنے کے لیے ایک شامل کریں';

  @override
  String get automatic => 'خودکار';

  @override
  String get automaticHint => 'تیز ترین سرور، ناکامی پر بدل جاتا ہے';

  @override
  String get anyServerInCountry => 'اس ملک کا کوئی بھی سرور';

  @override
  String get torNetwork => 'Tor نیٹ ورک';

  @override
  String get torHopBridge => 'پل';

  @override
  String get torHopEntry => 'داخلہ';

  @override
  String get torHopRelay => 'ریلے';

  @override
  String get torHopExit => 'اخراج';

  @override
  String get torHopHidden => 'پوشیدہ';

  @override
  String get torHopUnknown => 'نامعلوم';

  @override
  String get hopYou => 'آپ';

  @override
  String get hopYouNote =>
      'آپ حقیقت میں یہاں ہیں۔ آپ کی ٹریفک یہیں سے شروع ہوتی ہے۔';

  @override
  String get hopServer => 'سرور';

  @override
  String get hopServerNote =>
      'آپ کی ٹریفک انکرپٹ ہو کر اس سرور تک جاتی ہے اور یہیں سے نکلتی ہے، اس لیے ویب سائٹس آپ کا نہیں بلکہ اس کا پتہ دیکھتی ہیں۔';

  @override
  String get hopBridgeNote =>
      'آپ کا پہلا پڑاؤ۔ برج آپ کے نیٹ ورک سے چھپاتا ہے کہ آپ Tor استعمال کر رہے ہیں۔ وہ جانتا ہے کہ آپ کون ہیں، لیکن یہ نہیں کہ آپ کہاں جا رہے ہیں۔';

  @override
  String get hopEntryNote =>
      'پہلا ریلے۔ وہ آپ کا پتہ جانتا ہے، لیکن یہ نہیں کہ آپ کیا دیکھتے ہیں۔';

  @override
  String get hopRelayNote =>
      'درمیانی ریلے۔ وہ نہ یہ جانتا ہے کہ آپ کون ہیں اور نہ یہ کہ آپ کیا دیکھتے ہیں؛ وہ صرف ٹریفک آگے بڑھاتا ہے۔';

  @override
  String get hopExitNote =>
      'آخری ریلے۔ وہ دیکھتا ہے کہ آپ کہاں جا رہے ہیں، لیکن یہ نہیں کہ آپ کون ہیں، اور ویب سائٹس اس کا پتہ دیکھتی ہیں۔';

  @override
  String get hopHiddenNote =>
      'برج کی جگہ اس کے ٹرانسپورٹ نے چھپا رکھی ہے، اس لیے اسے نقشے پر نہیں دکھایا جا سکتا۔';

  @override
  String get hopTransport => 'ٹرانسپورٹ';

  @override
  String get hopProtocol => 'پروٹوکول';

  @override
  String get hopAddress => 'پتہ';

  @override
  String get hopLatency => 'تاخیر';

  @override
  String get hopExitAddress => 'اخراج کا پتہ';

  @override
  String get menuNewGroup => 'نیا گروپ';

  @override
  String get groupNameHint => 'گروپ کا نام';

  @override
  String get groupCreate => 'بنائیں';

  @override
  String get menuMoveToGroup => 'گروپ میں منتقل کریں';

  @override
  String get groupMoveTitle => 'یہاں منتقل کریں';

  @override
  String get menuRenameGroup => 'نام بدلیں';

  @override
  String get menuDeleteGroup => 'گروپ حذف کریں';

  @override
  String get groupDeleteTitle => 'یہ گروپ حذف کریں؟';

  @override
  String groupDeleteBody(String name) {
    return 'اس کے سرور حذف نہیں ہوں گے۔ وہ $name میں واپس چلے جائیں گے۔';
  }

  @override
  String get groupEmptyHint =>
      'ابھی کوئی سرور نہیں۔ کسی سرور کا مینو کھولیں اور «گروپ میں منتقل کریں» چنیں۔';

  @override
  String get menuShareGroupFile => 'ٹیکسٹ فائل کے طور پر محفوظ کریں';

  @override
  String get menuCopyGroupLinks => 'لنک کاپی کریں';

  @override
  String groupSavedToast(String servers) {
    return 'محفوظ ہو گیا: $servers';
  }

  @override
  String groupCopiedToast(String servers) {
    return 'کاپی ہو گیا: $servers';
  }

  @override
  String get groupNothingToShare => 'ان میں سے کسی سرور کا شیئر لنک نہیں ہے۔';

  @override
  String groupSkipped(String servers) {
    return 'شیئر لنک نہ ہونے کی وجہ سے چھوڑے گئے: $servers';
  }

  @override
  String get emptyTitle => 'ابھی کوئی پروفائل نہیں';

  @override
  String get emptyHint => 'کنفیگ، لنک یا سبسکرپشن درآمد کریں۔';

  @override
  String get importConfig => 'کنفیگ درآمد کریں';

  @override
  String failoverToast(String to, String from) {
    return '$to پر منتقل ہو گئے — $from نے جواب دینا بند کر دیا';
  }

  @override
  String get unknownLocation => 'نامعلوم مقام';

  @override
  String errorFailed(String stage, String reason) {
    return '$stage ناکام: $reason';
  }

  @override
  String get errTimeout => 'سرور نے وقت پر جواب نہیں دیا';

  @override
  String get errRefused => 'سرور نے کنکشن مسترد کر دیا';

  @override
  String get errReset => 'نیٹ ورک نے کنکشن ری سیٹ کر دیا';

  @override
  String get errNoRoute => 'اس نیٹ ورک سے سرور تک رسائی ممکن نہیں';

  @override
  String get errNetworkUnreachable => 'نیٹ ورک دستیاب نہیں ہے';

  @override
  String get errDns => 'سرور کا نام حل نہیں ہو سکا';

  @override
  String get errTls => 'سرور کا سیکیورٹی سرٹیفکیٹ مسترد کر دیا گیا';

  @override
  String get errAuth => 'صارف نام یا پاس ورڈ مسترد کر دیا گیا';

  @override
  String get errClosed => 'سرور نے کنکشن بند کر دیا';

  @override
  String get errCertDate =>
      'سرور کا سرٹیفکیٹ ختم ہو چکا ہے یا ابھی درست نہیں ہوا (اس فون کی تاریخ اور وقت بھی جانچیں)';

  @override
  String get errCertUntrusted =>
      'سرور کے سرٹیفکیٹ پر کسی قابلِ اعتماد ادارے کے دستخط نہیں ہیں';

  @override
  String get errCertName =>
      'سرور کا سرٹیفکیٹ اس نام کے لیے نہیں ہے جس سے آپ منسلک ہو رہے ہیں';

  @override
  String get errTlsKeys =>
      'مشترکہ کلید (tls-auth یا tls-crypt) سرور کی کلید سے میل نہیں کھاتی';

  @override
  String get errReality =>
      'سرور نے Reality ہینڈشیک مسترد کر دیا (پبلک کلید، شارٹ ID اور سرور کا نام جانچیں)';

  @override
  String get errNoHandshake =>
      'سرور نے ہینڈشیک کا جواب نہیں دیا (کلیدیں اور اینڈ پوائنٹ جانچیں اور دیکھیں کہ اس کا UDP پورٹ کھلا ہے)';

  @override
  String get errUdpBlocked =>
      'سرور نے UDP پر جواب نہیں دیا؛ یہ نیٹ ورک اسے روک سکتا ہے، TCP پر مبنی سرور آزمائیں';

  @override
  String get errPortInUse =>
      'مقامی پورٹ پہلے سے کسی دوسری ایپ میں استعمال ہو رہا ہے';

  @override
  String get errTorTimeout =>
      'Tor وقت پر منسلک نہیں ہو سکا۔ یہ نیٹ ورک Tor کو روک سکتا ہے؛ برج (Snowflake یا obfs4) استعمال کریں';

  @override
  String get errTorBridgeTimeout =>
      'Tor وقت پر منسلک نہیں ہو سکا۔ برج بلاک یا حد سے زیادہ مصروف ہو سکتا ہے؛ کسی دوسری قسم کا برج (Snowflake یا obfs4) آزمائیں';

  @override
  String get errTorBadBridge =>
      'Tor برج لائن درست نہیں (اس میں ٹرانسپورٹ، پتہ اور فنگر پرنٹ درکار ہے)';

  @override
  String get errTorMissing => 'اس بلڈ میں Tor کلائنٹ شامل نہیں ہے';

  @override
  String get errPermission => 'VPN کی اجازت نہیں دی گئی';

  @override
  String get errCoreLost => 'کور سروس سے کنکشن ٹوٹ گیا';

  @override
  String get selectLocation => 'مقام منتخب کریں';

  @override
  String get testSpeedTooltip => 'تمام سرورز کی رفتار جانچیں';

  @override
  String get addServersTooltip => 'سرورز شامل کریں';

  @override
  String get menuImport => 'کنفیگ، لنک یا QR درآمد کریں';

  @override
  String get menuNewServer => 'ہاتھ سے سرور شامل کریں';

  @override
  String get menuSubscription => 'سبسکرپشن شامل کریں';

  @override
  String get menuManage => 'سرورز اور سبسکرپشنز کا نظم کریں';

  @override
  String get menuSetDefault => 'ڈیفالٹ بنائیں';

  @override
  String get badgeDefault => 'ڈیفالٹ';

  @override
  String get menuDeleteAll => 'تمام سرورز حذف کریں';

  @override
  String get deleteAllTitle => 'تمام سرورز حذف کریں؟';

  @override
  String get deleteAllBody =>
      'آپ کے شامل کردہ تمام سرورز اور سبسکرپشنز ہٹا دیے جائیں گے۔ بلٹ اِن Tor کنکشن برقرار رہے گا اور ایپ اسی پر واپس آ جائے گی۔';

  @override
  String get menuRestoreTor => 'Tor ڈیفالٹ بحال کریں';

  @override
  String get deletedAllToast => 'تمام سرورز حذف کر دیے گئے';

  @override
  String defaultSetToast(String name) {
    return '$name اب ڈیفالٹ ہے';
  }

  @override
  String serversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سرورز',
      one: '$count سرور',
    );
    return '$_temp0';
  }

  @override
  String get otherGroup => 'دیگر';

  @override
  String get torGroup => 'Tor';

  @override
  String get noServersYet => 'ابھی کوئی سرور نہیں';

  @override
  String get importHintShort => 'کنفیگ فائل، لنک یا سبسکرپشن درآمد کریں۔';

  @override
  String get showServers => 'سرورز دکھائیں';

  @override
  String get hideServers => 'سرورز چھپائیں';

  @override
  String get menuEditServer => 'ترمیم';

  @override
  String get menuBridgeSettings => 'برج کی ترتیبات';

  @override
  String get menuShare => 'لنک یا QR شیئر کریں';

  @override
  String get menuSetCountry => 'ملک مقرر کریں';

  @override
  String get menuCredentials => 'صارف نام اور پاس ورڈ';

  @override
  String needsSignIn(String address) {
    return '$address — سائن اِن درکار ہے';
  }

  @override
  String get countryOfServer => 'اس سرور کا ملک';

  @override
  String get guessFromName => 'نام سے معلوم کریں';

  @override
  String get latencyNotTested => 'جانچا نہیں گیا';

  @override
  String get latencyUnreachable => 'پہنچ سے باہر';

  @override
  String get latencyTimeout => 'ٹائم آؤٹ';

  @override
  String latencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String get unknownCountry => 'نامعلوم ملک';

  @override
  String get addServerTitle => 'سرور شامل کریں';

  @override
  String get addServerIntro =>
      'پروٹوکول منتخب کریں۔ لنک یا QR زیادہ تیز ہے: درآمد استعمال کریں۔';

  @override
  String newServerTitle(String label) {
    return 'نیا $label سرور';
  }

  @override
  String get editServerTitle => 'سرور میں ترمیم کریں';

  @override
  String get torBridgesTitle => 'Tor برجز';

  @override
  String get subscriptionEditNote =>
      'یہ سرور ایک سبسکرپشن سے آتا ہے: ریفریش ہونے پر آپ کی تبدیلیاں بدل دی جائیں گی۔';

  @override
  String get moreOptions => 'مزید اختیارات';

  @override
  String get countryRow => 'ملک';

  @override
  String get countryAuto => 'نام اور پتے سے معلوم کیا گیا';

  @override
  String get alreadyInList => 'یہ سرور پہلے سے فہرست میں ہے';

  @override
  String get choiceDefault => 'ڈیفالٹ';

  @override
  String get torBridgesNone => 'کوئی نہیں (براہِ راست، یا نیچے دی گئی لائنیں)';

  @override
  String get torBridgesSnowflake => 'Snowflake';

  @override
  String get torBridgesObfs4 => 'obfs4 (بلٹ اِن برجز)';

  @override
  String get listHelper => 'قدروں کو کومے سے الگ کریں';

  @override
  String get fillPaste => 'پیسٹ کریں';

  @override
  String get fillFile => 'فائل';

  @override
  String get fillScanQr => 'QR اسکین کریں';

  @override
  String get openTextFile => 'ٹیکسٹ فائل کھولیں';

  @override
  String couldNotReadFile(String error) {
    return 'فائل پڑھی نہیں جا سکی: $error';
  }

  @override
  String fieldRequired(String label) {
    return '$label *';
  }

  @override
  String formNoEditor(String protocol) {
    return '$protocol کے لیے کوئی ایڈیٹر نہیں';
  }

  @override
  String get shareScanHint => 'Wardkeep سے اسکین کریں، یا لنک کاپی کریں۔';

  @override
  String get shareCopy => 'لنک کاپی کریں';

  @override
  String get shareCopied => 'لنک کاپی ہو گیا';

  @override
  String get shareWarning =>
      'اس میں سرور کا پاس ورڈ یا کلید شامل ہے۔ احتیاط سے شیئر کریں۔';

  @override
  String shareFailed(String reason) {
    return 'اس سرور کو لنک کے طور پر شیئر نہیں کیا جا سکتا: $reason';
  }

  @override
  String get shareTooLong => 'QR کوڈ کے لیے بہت لمبا: لنک کاپی کریں';

  @override
  String get obTitle1 => 'نجی اور آسان';

  @override
  String get obText1 =>
      'VPN، پراکسی اور Tor کے لیے ایک پرسکون اسکرین۔ مقام چنیں، منسلک ہوں دبائیں۔';

  @override
  String get obTitle2 => 'اپنے سرورز شامل کریں';

  @override
  String get obText2 =>
      'لنک، QR کوڈ، کنفیگ فائل یا سبسکرپشن درآمد کریں۔ یا ہاتھ سے سرور شامل کریں۔';

  @override
  String get obTitle3Android => 'Android ایک بار پوچھے گا';

  @override
  String get obText3Android =>
      'Android VPN کنکشن کی اجازت مانگے گا۔ محفوظ رہنے کے لیے قبول کریں۔';

  @override
  String get obTitle3Desktop => 'جب آپ چاہیں، تیار';

  @override
  String get obText3Desktop =>
      'پراکسی موڈ میں شروع ہوتا ہے، کسی خاص اختیار کی ضرورت نہیں۔ تمام ٹریفک کیپچر کرنے کے لیے ترتیبات میں VPN موڈ آن کریں۔';

  @override
  String get obAddFirst => 'میرا پہلا سرور شامل کریں';

  @override
  String get bypassTitle => 'بائی پاس فہرستیں';

  @override
  String get bypassAddTooltip => 'فہرست شامل کریں';

  @override
  String get bypassFromClipboard => 'کلپ بورڈ سے پیسٹ کریں';

  @override
  String get bypassFromFile => '.txt فائل کھولیں';

  @override
  String get bypassFromUrl => 'لنک سے ڈاؤن لوڈ کریں';

  @override
  String get bypassType => 'خود لکھیں';

  @override
  String get bypassClipboardEmpty => 'کلپ بورڈ خالی ہے';

  @override
  String get bypassPickFile => 'بائی پاس فہرست کھولیں (.txt)';

  @override
  String bypassDownloadFailed(String error) {
    return 'فہرست ڈاؤن لوڈ نہیں ہو سکی: $error';
  }

  @override
  String get bypassIntro =>
      'وہ سائٹس اور پتے جو VPN کو چھوڑ دیتے ہیں۔ ہر سطر میں ایک: example.com، full:www.example.com، keyword:bank، regexp:…، 203.0.113.7 یا 10.0.0.0/8۔ # سے شروع ہونے والی سطریں نظر انداز کی جاتی ہیں۔';

  @override
  String get bypassNoLists => 'ابھی کوئی فہرست نہیں۔';

  @override
  String get bypassTypeList => 'فہرست لکھیں';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اندراجات',
      one: '$count اندراج',
    );
    return '$_temp0';
  }

  @override
  String get bypassOnlyTitle => 'صرف درج شدہ VPN استعمال کریں';

  @override
  String get bypassOnlyOn => 'باقی سب براہِ راست جاتا ہے۔';

  @override
  String get bypassOnlyOff =>
      'درج شدہ براہِ راست جاتے ہیں؛ باقی VPN سے جاتے ہیں۔';

  @override
  String get bypassNothing => 'کوئی فہرست آن نہیں ہے۔';

  @override
  String bypassInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اندراجات استعمال میں',
      one: '$count اندراج استعمال میں',
    );
    return '$_temp0۔ اگلی بار منسلک ہونے پر لاگو ہوگا۔';
  }

  @override
  String get bypassHttpLink => 'http(s) لنک درج کریں';

  @override
  String bypassServerAnswered(int code) {
    return 'سرور نے $code جواب دیا';
  }

  @override
  String get bypassTooLarge => 'فہرست 5 MB سے بڑی ہے';

  @override
  String get bypassDownloadTitle => 'فہرست ڈاؤن لوڈ کریں';

  @override
  String get bypassNewList => 'نئی فہرست';

  @override
  String get bypassEditList => 'فہرست میں ترمیم کریں';

  @override
  String get bypassName => 'نام';

  @override
  String get bypassEntriesLabel => 'اندراجات، ہر سطر میں ایک';

  @override
  String get bypassNoUsable => 'ابھی کوئی قابلِ استعمال اندراج نہیں۔';

  @override
  String bypassSummary(String entries, String names, String ranges) {
    return '$entries · $names، $ranges۔';
  }

  @override
  String bypassNames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نام',
      one: '$count نام',
    );
    return '$_temp0';
  }

  @override
  String bypassRanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count پتے یا رینجز',
      one: '$count پتہ یا رینج',
    );
    return '$_temp0';
  }

  @override
  String bypassIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سطریں نظر انداز کی جائیں گی:',
      one: '$count سطر نظر انداز کی جائے گی:',
    );
    return '$_temp0';
  }

  @override
  String bypassMoreIssues(int count) {
    return '… اور $count مزید';
  }

  @override
  String get bypassReconnect =>
      'نئی فہرست استعمال کرنے کے لیے دوبارہ منسلک ہوں';

  @override
  String get bypassDefaultName => 'میری فہرست';

  @override
  String get bypassPastedName => 'پیسٹ کی گئی فہرست';

  @override
  String get settingsTitle => 'ترتیبات';

  @override
  String get settingsServers => 'سرورز';

  @override
  String get manageServers => 'سرورز کا نظم کریں';

  @override
  String get manageServersHint => 'سرورز اور سبسکرپشنز';

  @override
  String get settingsConnection => 'کنکشن';

  @override
  String get vpnMode => 'VPN موڈ (تمام ٹریفک)';

  @override
  String get vpnModeHint => 'آف: صرف پراکسی، VPN اجازت نہیں';

  @override
  String get systemProxy => 'سسٹم پراکسی سیٹ کریں';

  @override
  String get systemProxyHint => 'منسلک رہنے کے دوران سسٹم پراکسی سیٹ کریں';

  @override
  String get autoSwitch => 'ناکامی پر خودکار تبدیلی';

  @override
  String get autoSwitchHint => 'ایک ناکام ہو تو اگلا سرور آزمائیں';

  @override
  String get bypassLan => 'مقامی نیٹ ورک بائی پاس کریں';

  @override
  String get bypassLanHint =>
      'مقامی ڈیوائسز تک براہِ راست رسائی (192.168.x.x, 10.x.x.x)';

  @override
  String get bypassListsHint => 'ویب سائٹس اور پتے جو VPN کو چھوڑ دیتے ہیں';

  @override
  String bypassListsInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اندراجات استعمال میں',
      one: '$count اندراج استعمال میں',
    );
    return '$_temp0';
  }

  @override
  String get alwaysOnTitle => 'ہمیشہ آن VPN اور کِل سوئچ';

  @override
  String get alwaysOnHint =>
      'بوٹ پر دوبارہ منسلک ہوں اور لیک روکیں۔ Android کی VPN ترتیبات میں سیٹ کریں۔';

  @override
  String get openVpnSettingsFallback =>
      'ترتیبات ← نیٹ ورک ← VPN ← Wardkeep کے ساتھ گیئر';

  @override
  String get splitTunneling => 'اسپلٹ ٹنلنگ';

  @override
  String splitSummaryOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'صرف منتخب $count ایپس VPN استعمال کرتی ہیں',
      one: 'صرف منتخب $count ایپ VPN استعمال کرتی ہے',
    );
    return '$_temp0';
  }

  @override
  String splitSummaryBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ایپس VPN کو بائی پاس کرتی ہیں',
      one: '$count ایپ VPN کو بائی پاس کرتی ہے',
    );
    return '$_temp0';
  }

  @override
  String get splitSummaryOff => 'تمام ایپس VPN استعمال کرتی ہیں';

  @override
  String get remoteDns => 'ریموٹ DNS';

  @override
  String get remoteDnsHelp =>
      'ٹنل کے ذریعے استعمال ہونے والا DNS، جیسے https://1.1.1.1/dns-query یا tls://1.1.1.1';

  @override
  String get settingsApp => 'ایپ';

  @override
  String get appearance => 'ظاہری شکل';

  @override
  String get themeDark => 'ڈارک';

  @override
  String get themeLight => 'لائٹ';

  @override
  String get themeSystem => 'سسٹم کے مطابق';

  @override
  String get language => 'زبان';

  @override
  String get languageSystem => 'سسٹم ڈیفالٹ';

  @override
  String get stopOnClose => 'ایپ بند ہونے پر VPN روکیں';

  @override
  String aboutLine(String engine) {
    return 'MIT لائسنس · انجن: $engine';
  }

  @override
  String get splitTitle => 'اسپلٹ ٹنلنگ';

  @override
  String get splitAll => 'تمام ایپس';

  @override
  String get splitOnlySelected => 'صرف منتخب';

  @override
  String get splitBypassSelected => 'منتخب کو بائی پاس کریں';

  @override
  String get splitHelpOffMode => 'ہر ایپ VPN استعمال کرتی ہے۔';

  @override
  String get splitHelpOnlyNone =>
      'کوئی ایپ منتخب نہیں: سب VPN استعمال کرتی ہیں۔';

  @override
  String splitHelpOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'صرف $count ایپس VPN استعمال کرتی ہیں۔',
      one: 'صرف $count ایپ VPN استعمال کرتی ہے۔',
    );
    return '$_temp0';
  }

  @override
  String splitHelpBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ایپس براہِ راست جاتی ہیں۔',
      one: '$count ایپ براہِ راست جاتی ہے۔',
    );
    return '$_temp0';
  }

  @override
  String get searchApps => 'ایپس تلاش کریں';

  @override
  String get showSystemApps => 'سسٹم ایپس دکھائیں';

  @override
  String couldNotListApps(String error) {
    return 'ایپس کی فہرست نہیں بن سکی: $error';
  }

  @override
  String get scanTitle => 'QR کوڈ اسکین کریں';

  @override
  String get scanTorch => 'ٹارچ';

  @override
  String scanCameraUnavailable(String code) {
    return 'کیمرا دستیاب نہیں: $code';
  }

  @override
  String get scanPoint => 'کیمرا کنفیگ QR کوڈ کی طرف رکھیں';

  @override
  String get credTitle => 'سائن اِن کریں';

  @override
  String credNeeds(String name) {
    return '$name کو صارف نام اور پاس ورڈ درکار ہے۔';
  }

  @override
  String get credUsername => 'صارف نام';

  @override
  String get credPassword => 'پاس ورڈ';

  @override
  String get logsEmpty => 'ابھی کوئی لاگ اندراج نہیں۔';

  @override
  String get profilesTitle => 'سرورز کا نظم کریں';

  @override
  String get addSubscriptionTooltip => 'سبسکرپشن شامل کریں';

  @override
  String get testLatencyTooltip => 'لیٹنسی جانچیں';

  @override
  String get profilesEmptyHint =>
      'کوئی پروفائل نہیں۔ شامل کرنے کے لیے درآمد دبائیں۔';

  @override
  String get profilesDragHint =>
      'ترتیب بدلنے کے لیے دبا کر گھسیٹیں۔ فیل اوور اسی ترتیب سے چلتا ہے۔';

  @override
  String get myProfiles => 'میری پروفائلز';

  @override
  String subRefreshed(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count پروفائلز',
      one: '$count پروفائل',
    );
    return '$name: $_temp0';
  }

  @override
  String get refreshTooltip => 'ریفریش';

  @override
  String get subDeleteWithProfiles => 'سبسکرپشن اور اس کی پروفائلز حذف کریں';

  @override
  String subUsageOf(String used, String total) {
    return '$total میں سے $used';
  }

  @override
  String subUsed(String used) {
    return '$used استعمال ہوا';
  }

  @override
  String get subExpired => 'ختم ہو گیا';

  @override
  String get subExpiresToday => 'آج ختم ہوگا';

  @override
  String subExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days دن میں ختم ہوگا',
      one: '$days دن میں ختم ہوگا',
    );
    return '$_temp0';
  }

  @override
  String subUpdated(String ago) {
    return '$ago اپ ڈیٹ ہوا';
  }

  @override
  String get agoJustNow => 'ابھی ابھی';

  @override
  String agoMinutes(int count) {
    return '$count منٹ پہلے';
  }

  @override
  String agoHours(int count) {
    return '$count گھنٹے پہلے';
  }

  @override
  String agoDays(int count) {
    return '$count دن پہلے';
  }

  @override
  String subRefreshFailed(String error) {
    return 'پچھلا ریفریش ناکام رہا: $error';
  }

  @override
  String get importTitle => 'کنفیگ درآمد کریں';

  @override
  String get importDescription =>
      'لنک، کنفیگ یا سبسکرپشن پیسٹ کریں — یا فائل کھولیں یا QR کوڈ اسکین کریں۔';

  @override
  String get importScanQr => 'QR اسکین کریں';

  @override
  String get importOpenFile => 'فائل کھولیں';

  @override
  String get importPaste => 'پیسٹ کریں';

  @override
  String get importSubscription => 'سبسکرپشن';

  @override
  String get importTor => 'Tor';

  @override
  String get importAddTor => 'Tor شامل کریں';

  @override
  String get importTorDirect => 'Tor (براہِ راست)';

  @override
  String get importTorSnowflake => 'Tor + Snowflake برج';

  @override
  String get importTorObfs4 => 'Tor + obfs4 برجز';

  @override
  String importedProfiles(int added, int dupes) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added پروفائلز درآمد ہوئیں',
      one: '$added پروفائل درآمد ہوئی',
    );
    String _temp1 = intl.Intl.pluralLogic(
      dupes,
      locale: localeName,
      other: '، $dupes پہلے سے موجود',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String importNothing(String reason) {
    return 'کچھ درآمد نہیں ہوا: $reason';
  }

  @override
  String importPartial(int added, int failed) {
    return '$added درآمد ہوئے، $failed ناکام';
  }

  @override
  String get subAddTitle => 'سبسکرپشن شامل کریں';

  @override
  String get subEditTitle => 'سبسکرپشن میں ترمیم کریں';

  @override
  String get subUrlLabel => 'سبسکرپشن URL';

  @override
  String get subUrlHint =>
      'https://provider.example/sub/… یا nordvpn://<token>';

  @override
  String get subNameLabel => 'نام (اختیاری)';

  @override
  String get subNameHelp => 'بطور ڈیفالٹ فراہم کنندہ کا عنوان یا ہوسٹ کا نام';

  @override
  String get subAuthLabel => 'توثیق';

  @override
  String get authNone => 'کوئی نہیں';

  @override
  String get authBasic => 'صارف نام اور پاس ورڈ (Basic)';

  @override
  String get authBearer => 'Bearer ٹوکن';

  @override
  String get authHeader => 'حسبِ ضرورت ہیڈر';

  @override
  String get authQuery => 'URL میں ٹوکن';

  @override
  String get subUsername => 'صارف نام';

  @override
  String get subPassword => 'پاس ورڈ';

  @override
  String get subHeaderName => 'ہیڈر کا نام';

  @override
  String get subHeaderValue => 'ہیڈر کی قدر';

  @override
  String get subParamName => 'پیرامیٹر کا نام';

  @override
  String get subToken => 'ٹوکن';

  @override
  String get subDownloadLabel => 'ڈاؤن لوڈ';

  @override
  String get subDownloadHelp =>
      'فراہم کنندہ بلاک ہے؟ VPN پھر بھی اسے حاصل کر سکتا ہے';

  @override
  String get subViaDirect => 'براہِ راست';

  @override
  String get subViaAuto => 'براہِ راست، یا بلاک ہونے پر VPN سے';

  @override
  String get subViaTunnel => 'ہمیشہ VPN سے (پہلے منسلک ہوں)';

  @override
  String get subErrUrl =>
      'http(s) سبسکرپشن URL درج کریں (یا nordvpn://<access token>)';

  @override
  String get subErrHeader => 'ہیڈر کا نام درج کریں';

  @override
  String get subErrToken => 'ٹوکن درج کریں';

  @override
  String get subAddAndDownload => 'شامل کریں اور ڈاؤن لوڈ کریں';

  @override
  String get subSaveAndRefresh => 'محفوظ کریں اور ریفریش کریں';

  @override
  String subUpdatedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count پروفائلز',
      one: '$count پروفائل',
    );
    return 'سبسکرپشن اپ ڈیٹ ہو گیا: $_temp0';
  }

  @override
  String get flName => 'نام';

  @override
  String get flServer => 'سرور';

  @override
  String get flPort => 'پورٹ';

  @override
  String get flPassword => 'پاس ورڈ';

  @override
  String get flUsername => 'صارف نام';

  @override
  String get flUuid => 'UUID';

  @override
  String get flSecurity => 'سیکیورٹی';

  @override
  String get flFlow => 'Flow';

  @override
  String get flCipher => 'سائفر';

  @override
  String get flEncryption => 'انکرپشن';

  @override
  String get flAlterId => 'Alter id';

  @override
  String get flTlsServerName => 'TLS سرور کا نام (SNI)';

  @override
  String get flTlsFingerprint => 'TLS فنگر پرنٹ';

  @override
  String get flAlpn => 'ALPN';

  @override
  String get flSkipCertCheck => 'سرٹیفکیٹ کی جانچ چھوڑیں';

  @override
  String get flPinnedCert => 'پن کیا ہوا سرٹیفکیٹ (PEM)';

  @override
  String get flRealityPublicKey => 'Reality پبلک کلید';

  @override
  String get flRealityShortId => 'Reality شارٹ ID';

  @override
  String get flTransport => 'ٹرانسپورٹ';

  @override
  String get flHostHeader => 'ہوسٹ ہیڈر';

  @override
  String get flPath => 'پاتھ';

  @override
  String get flGrpcService => 'gRPC سروس کا نام';

  @override
  String get flPlugin => 'پلگ اِن';

  @override
  String get flPluginOptions => 'پلگ اِن کے اختیارات';

  @override
  String get flObfuscation => 'اوبفسکیشن';

  @override
  String get flObfsPassword => 'اوبفسکیشن پاس ورڈ';

  @override
  String get flUploadMbps => 'اپ لوڈ (Mbps)';

  @override
  String get flDownloadMbps => 'ڈاؤن لوڈ (Mbps)';

  @override
  String get flCongestion => 'کنجیشن کنٹرول';

  @override
  String get flUdpRelay => 'UDP ریلے موڈ';

  @override
  String get flUseQuic => 'HTTP/3 (QUIC) استعمال کریں';

  @override
  String get flTunnelAddress => 'آپ کا ٹنل ایڈریس';

  @override
  String get flRoutedNetworks => 'روٹ کیے گئے نیٹ ورکس';

  @override
  String get flDnsServers => 'DNS سرورز';

  @override
  String get flMtu => 'MTU';

  @override
  String get flKeepalive => 'Keepalive (سیکنڈ)';

  @override
  String get flPrivateKey => 'پرائیویٹ کلید';

  @override
  String get flServerPublicKey => 'سرور پبلک کلید';

  @override
  String get flPresharedKey => 'پری شیئرڈ کلید';

  @override
  String get flReservedBytes => 'ریزروڈ بائٹس';

  @override
  String get flAuthentication => 'توثیق';

  @override
  String get flAuthDigest => 'Auth ڈائجسٹ';

  @override
  String get flCaCert => 'CA سرٹیفکیٹ (PEM)';

  @override
  String get flClientCert => 'کلائنٹ سرٹیفکیٹ (PEM)';

  @override
  String get flClientKey => 'کلائنٹ کلید (PEM)';

  @override
  String get flControlWrap => 'کنٹرول چینل کا تحفظ';

  @override
  String get flControlWrapKey => 'کنٹرول چینل کلید';

  @override
  String get flKeyDirection => 'کلید کی سمت';

  @override
  String get flRemoteCertType => 'ریموٹ سرٹیفکیٹ کی قسم';

  @override
  String get flVerifyServerName => 'سرور کا نام تصدیق کریں';

  @override
  String get flYourIdentity => 'آپ کی شناخت';

  @override
  String get flServerIdentity => 'سرور کی شناخت';

  @override
  String get flServerCertTrust => 'قابلِ اعتماد سرور سرٹیفکیٹ (PEM)';

  @override
  String get flUseSystemIke => 'فون کا اپنا IKEv2 کلائنٹ استعمال کریں';

  @override
  String get flUseTcp => 'TCP استعمال کریں';

  @override
  String get flHostKeys => 'ہوسٹ کلیدیں';

  @override
  String get flPrivateKeyPem => 'پرائیویٹ کلید (PEM)';

  @override
  String get flKeyPassphrase => 'کلید کا پاس فریز';

  @override
  String get flBridges => 'برجز';

  @override
  String get flBridgeLines => 'برج لائنیں';

  @override
  String get flJc => 'Jc (جنک پیکٹ کی تعداد)';

  @override
  String get flSignaturePacket => 'I1 (سگنیچر پیکٹ)';

  @override
  String get hpAuthorizedKeys =>
      'authorized_keys فارمیٹ؛ خالی ہو تو کوئی بھی کلید قبول';

  @override
  String get hpIkeTcp =>
      'UDP روکنے والے نیٹ ورکس کے لیے IKE اور ESP کو TCP پر چلائیں';

  @override
  String get hpDefaultsToServer => 'بطور ڈیفالٹ سرور کا پتہ';

  @override
  String get hpTorBridges =>
      'خالی ہو تو Tor براہِ راست منسلک ہوتا ہے، یا نیچے کی برج لائنیں استعمال کرتا ہے';

  @override
  String get hpExampleAddress => 'مثال: 10.8.0.2/32';

  @override
  String get hpExamplePlugin => 'مثال: shadow-tls یا v2ray-plugin';

  @override
  String get hpHostOrIp => 'ہوسٹ کا نام یا IP ایڈریس';

  @override
  String get hpNeededReality => 'سیکیورٹی reality ہونے پر درکار';

  @override
  String get hpOnlySelfSigned =>
      'صرف ان سرورز کے لیے جن کا سیلف سائنڈ سرٹیفکیٹ آپ پن نہیں کر سکتے';

  @override
  String get hpSafeSstp =>
      'SSTP کے لیے محفوظ: پاس ورڈ کا تبادلہ سرور کی تصدیق کر دیتا ہے';

  @override
  String get hpHysteriaObfs =>
      'Hysteria 2 کے لیے salamander؛ Hysteria 1 کے لیے اوبفسکیشن پاس ورڈ';

  @override
  String get hpTrustCert =>
      'سسٹم کے اداروں کی بجائے اس سرٹیفکیٹ پر بھروسا کریں';

  @override
  String get hpWhichBrowser => 'کس براؤزر کے TLS ہینڈشیک کی نقل کرنی ہے';

  @override
  String get hpWarpReserved =>
      'تین نمبر، جیسا WARP کنفیگریشنز میں دیے جاتے ہیں';

  @override
  String get hpOneBridgePerLine =>
      'ہر سطر میں ایک برج، torrc کی طرح لیکن \"Bridge \" کے بغیر';

  @override
  String get exitTitle => 'ایگزٹ ایڈریس اور ملک دکھائیں';

  @override
  String get exitHint =>
      'api.country.is سے آپ کا IP اور ملک پوچھیں، منسلک نہ ہونے پر بھی۔';

  @override
  String exitIpLabel(String ip) {
    return 'IP $ip';
  }

  @override
  String connectedTo(String place) {
    return '$place سے منسلک';
  }

  @override
  String get noticesTitle => 'اوپن سورس لائسنس';

  @override
  String get noticesIntro =>
      'Wardkeep MIT لائسنس کے تحت ہے۔ اس میں نیچے دیا گیا سافٹ ویئر شامل ہے، ہر ایک اپنے لائسنس کے تحت۔';

  @override
  String noticesMore(int count) {
    return '+$count مزید';
  }

  @override
  String noticesPackages(int count) {
    return '$count پیکجز';
  }

  @override
  String get noticesLoadFailed => 'لائسنس کی فہرست پڑھی نہیں جا سکی۔';

  @override
  String formRequired(String label) {
    return '$label درکار ہے';
  }

  @override
  String formNotNumber(String label) {
    return '$label پورا عدد ہونا چاہیے';
  }

  @override
  String formNotBool(String label) {
    return '$label آن یا آف ہونا چاہیے';
  }

  @override
  String formBadChoice(String label, String value, String choices) {
    return '$label: $value، $choices میں سے نہیں ہے';
  }

  @override
  String get formRealityOnlyVless => 'Reality صرف VLESS کے لیے دستیاب ہے';

  @override
  String formUnknownSecurity(String value) {
    return 'نامعلوم سیکیورٹی: $value';
  }

  @override
  String get formReservedBytes =>
      'ریزروڈ بائٹس 0 سے 255 تک کے نمبر ہونے چاہییں';

  @override
  String get formRealityKeyRequired =>
      'سیکیورٹی Reality ہونے پر Reality پبلک کلید درکار ہے';

  @override
  String get importUnsupported =>
      'یہ سرور لنک، سبسکرپشن یا کنفیگ نہیں ہے جسے Wardkeep پڑھ سکے';

  @override
  String importUnsupportedScheme(String scheme) {
    return '$scheme:// سے شروع ہونے والے لنک معاون نہیں ہیں';
  }

  @override
  String get importXrayServer =>
      'یہ Xray سرور کنفیگ ہے۔ اسے سرور پر درآمد کریں (omnitun-server import xray)، کلائنٹ پروفائل کے طور پر نہیں';

  @override
  String get subAuthFailed =>
      'سبسکرپشن نے سائن اِن مسترد کر دیا۔ صارف نام، پاس ورڈ یا ٹوکن جانچیں';

  @override
  String subHttp(String status) {
    return 'سبسکرپشن سرور نے HTTP $status جواب دیا';
  }

  @override
  String get subTooLarge => 'سبسکرپشن 10 MB سے بڑا ہے';

  @override
  String get subBadUrl => 'یہ درست سبسکرپشن پتہ نہیں ہے';

  @override
  String get bypassIssueEmptyExpression => 'خالی ایکسپریشن';

  @override
  String get bypassIssueBadExpression => 'درست ایکسپریشن نہیں';

  @override
  String get bypassIssueBadName => 'درست نام نہیں';

  @override
  String get bypassIssueGeo =>
      'geo فہرستیں معاون نہیں ہیں؛ ڈومینز یا رینجز لکھیں';

  @override
  String get bypassIssueBadEntry => 'ڈومین، پتہ یا رینج نہیں';

  @override
  String bypassIssueTooMany(int limit) {
    return '$limit سے زیادہ اندراجات: باقی نظر انداز کیے جائیں گے';
  }

  @override
  String get torStarting => 'Tor شروع ہو رہا ہے';

  @override
  String torBootstrap(int percent) {
    return 'Tor سے منسلک ہو رہا ہے $percent%';
  }

  @override
  String get torCircuit => 'Tor سرکٹ بن رہا ہے';

  @override
  String torRetry(int attempt, int attempts) {
    return 'Tor دوبارہ آزمایا جا رہا ہے ($attempt/$attempts)';
  }

  @override
  String get importNoServer => 'اس متن میں کوئی درست سرور نہیں ملا';

  @override
  String importJsonSyntax(String found, int line, int column) {
    return 'یہ درست JSON نہیں ہے: سطر $line، کالم $column پر غیر متوقع حرف $found۔';
  }

  @override
  String importJsonEnd(int line, int column) {
    return 'یہ درست JSON نہیں ہے: متن بہت جلد ختم ہو جاتا ہے (سطر $line، کالم $column)۔ ممکن ہے کوئی بند کرنے والا بریکٹ، بریس یا اقتباس کا نشان رہ گیا ہو۔';
  }

  @override
  String get importJsonNoServer =>
      'یہ JSON درست ہے، لیکن اس میں کوئی پراکسی سرور نہیں ہے۔ ایسی کلائنٹ کنفیگریشن استعمال کریں جس میں VLESS، VMess، Trojan، Shadowsocks یا اسی طرح کا آؤٹ باؤنڈ ہو۔';

  @override
  String importJsonNoServerFound(String found) {
    return 'یہ JSON درست ہے، لیکن اس میں کوئی پراکسی سرور نہیں ہے (اس میں $found ہے)۔ ایسی کلائنٹ کنفیگریشن استعمال کریں جس میں VLESS، VMess، Trojan، Shadowsocks یا اسی طرح کا آؤٹ باؤنڈ ہو۔';
  }

  @override
  String importTooLarge(int limit) {
    return 'درآمد کرنے کے لیے یہ بہت بڑا ہے (حد $limit MB ہے)۔';
  }

  @override
  String get importFileEmpty => 'فائل خالی ہے۔';

  @override
  String get importFileNotText =>
      'یہ فائل ایسا متن نہیں ہے جسے Wardkeep پڑھ سکے (یہ بائنری لگتی ہے یا نامعلوم انکوڈنگ میں ہے)۔ UTF-8 یا UTF-16 متنی فائل استعمال کریں۔';

  @override
  String get importFileNoPermission =>
      'Wardkeep کو یہ فائل پڑھنے کی اجازت نہیں ہے۔';

  @override
  String get importFileMissing =>
      'فائل نہیں ملی۔ ممکن ہے اسے منتقل یا حذف کر دیا گیا ہو۔';

  @override
  String get importDetails => 'تفصیلات';

  @override
  String get importJsonNote =>
      'JSON کنفیگریشن (Xray، sing-box، SIP008) یا ان کی فہرست بھی، متن یا فائل کی صورت میں، چلتی ہے۔';

  @override
  String get ipdbTitle => 'آف لائن ملکی ڈیٹابیس';

  @override
  String get ipdbIntro =>
      'ایک بار ڈیٹابیس ڈاؤن لوڈ کریں، اور Wardkeep کسی ویب سائٹ سے پوچھے بغیر خود سرور یا پتے کا ملک معلوم کر لے گا۔';

  @override
  String ipdbSizeNote(String size) {
    return 'تقریباً $size · مفت ڈیٹا (پبلک ڈومین)';
  }

  @override
  String get ipdbDownload => 'ڈاؤن لوڈ کریں';

  @override
  String get ipdbContinue => 'جاری رکھیں';

  @override
  String get ipdbPause => 'روکیں';

  @override
  String get ipdbUpdate => 'اپ ڈیٹ کریں';

  @override
  String get ipdbDelete => 'حذف کریں';

  @override
  String get ipdbDeleteTitle => 'ڈیٹابیس حذف کریں؟';

  @override
  String get ipdbUse => 'ڈیٹابیس استعمال کریں';

  @override
  String get ipdbStepV4 => 'IPv4';

  @override
  String get ipdbStepV6 => 'IPv6';

  @override
  String get ipdbStepPrepare => 'تیاری';

  @override
  String get ipdbPreparing => 'تیار ہو رہا ہے…';

  @override
  String get ipdbReady => 'تیار';

  @override
  String ipdbStoppedAt(int percent) {
    return '$percent% پر رک گیا۔ جاری رکھیں دبانے پر وہیں سے شروع ہوگا۔';
  }

  @override
  String ipdbFailed(String reason) {
    return 'ڈاؤن لوڈ ناکام: $reason';
  }

  @override
  String ipdbReadyLine(String ranges, String size) {
    return '$ranges رینجز · $size';
  }

  @override
  String ipdbVersion(String version, String date) {
    return 'ورژن $version · $date';
  }

  @override
  String ipdbLeft(String time) {
    return '$time باقی';
  }

  @override
  String get ipdbSource =>
      'ڈیٹا: علاقائی انٹرنیٹ رجسٹریاں اور ASN اعلانات (CC0)، ip-location-db پروجیکٹ سے۔';

  @override
  String get ipdbSubNone => 'ویب سائٹ سے پوچھے بغیر ممالک معلوم کریں';

  @override
  String ipdbSubReady(String size) {
    return 'آن · $size';
  }

  @override
  String ipdbSubOff(String size) {
    return 'آف · $size';
  }

  @override
  String ipdbSubDownloading(int percent) {
    return 'ڈاؤن لوڈ ہو رہا ہے $percent%';
  }

  @override
  String ipdbSubStopped(int percent) {
    return '$percent% پر رک گیا';
  }

  @override
  String get ipdbErrNetwork => 'ڈیٹا سرورز سے کنکشن نہیں ہے';

  @override
  String get ipdbErrMirrors => 'ڈیٹا سرورز نے درست فائل نہیں بھیجی';

  @override
  String get bypassCountriesTitle => 'ممالک';

  @override
  String get bypassCountriesNone => 'کوئی ملک منتخب نہیں';

  @override
  String bypassCountriesMore(String names, int count) {
    return '$names +$count';
  }

  @override
  String get bypassCountriesIntro =>
      'منتخب ممالک کی ٹریفک VPN کو چھوڑ کر براہِ راست انٹرنیٹ پر جاتی ہے۔ ان کی ایڈریس رینجز آف لائن ملکی ڈیٹابیس سے آتی ہیں۔';

  @override
  String get bypassCountriesGetDb => 'ملکی ڈیٹابیس حاصل کریں';

  @override
  String get bypassCountriesSearch => 'ممالک تلاش کریں';

  @override
  String get windowMinimize => 'چھوٹا کریں';

  @override
  String get windowMaximize => 'بڑا کریں';

  @override
  String get windowRestore => 'بحال کریں';

  @override
  String get windowClose => 'بند کریں';

  @override
  String get windowFullScreen => 'مکمل اسکرین';

  @override
  String get windowExitFullScreen => 'مکمل اسکرین سے باہر نکلیں';

  @override
  String get globeRecenter => 'زمین کو مرکز میں لائیں';

  @override
  String get bypassCountriesZoneIntro =>
      'آپ جس ملک پر ٹک کرتے ہیں اس کی ایڈریس رینجز ڈاؤن لوڈ ہوتی ہیں (چند کلوبائٹس)۔ مکمل آف لائن ڈیٹابیس زیادہ درست ہے اور اس کے لیے ڈاؤن لوڈ کی ضرورت نہیں۔';

  @override
  String get bypassCountriesDownloading => 'ڈاؤن لوڈ ہو رہا ہے…';

  @override
  String get bypassCountriesFailed =>
      'ڈاؤن لوڈ نہیں ہو سکا۔ دوبارہ کوشش کے لیے ٹیپ کریں۔';

  @override
  String get bypassCountriesYourServer =>
      'آپ کا منتخب سرور یہاں ہے: اس کی ٹریفک بھی VPN کو چھوڑ دے گی۔';

  @override
  String get ipv6Title => 'IPv6';

  @override
  String get ipv6Hint =>
      'بند: صرف IPv4 استعمال ہوتا ہے؛ IPv6 کنکشن مسترد ہوتے ہیں، VPN سے باہر نہیں جاتے۔';

  @override
  String get mtuTitle => 'MTU';

  @override
  String get mtuAuto => 'طے شدہ';

  @override
  String get mtuHelp =>
      'ٹنل میں پیکٹ کا سائز (صرف VPN موڈ)۔ موبائل نیٹ ورک پر کچھ سائٹیں اٹک جائیں تو 1280 سے 1420 آزمائیں۔ خالی کا مطلب طے شدہ۔';

  @override
  String mtuInvalid(int min, int max) {
    return '$min سے $max تک کوئی عدد درج کریں۔';
  }

  @override
  String get trayOpen => 'Wardkeep کھولیں';

  @override
  String get trayQuit => 'باہر نکلیں';

  @override
  String get traySwitchServer => 'سرور تبدیل کریں';

  @override
  String get keepInTray => 'ٹرے میں چلتا رہے';

  @override
  String get keepInTrayHint =>
      'ونڈو بند کرنے سے وہ صرف چھپ جاتی ہے۔ ایپ اور VPN بند کرنے کے لیے ٹرے مینو میں «باہر نکلیں» چنیں۔';

  @override
  String usageUsed(String size) {
    return '$size استعمال ہوا';
  }

  @override
  String get menuResetUsage => 'ڈیٹا کا استعمال صفر کریں';

  @override
  String get dnsPickerHelp =>
      'ویب سائٹس کے نام VPN کے ذریعے آپ کے منتخب کردہ ریزولور سے تلاش ہوتے ہیں۔ DNSCrypt یہ بھی ثابت کرتا ہے کہ جواب اسی ریزولور سے آیا ہے۔';

  @override
  String get dnsDefault => 'ڈیفالٹ';

  @override
  String get dnsSectionDnscrypt => 'DNSCrypt · DNSSEC، بغیر لاگ، بغیر فلٹر';

  @override
  String get dnsCustom => 'حسبِ ضرورت';

  @override
  String get dnsCustomLabel => 'پتہ یا DNS stamp';

  @override
  String get dnsAnonymized => 'گمنام DNSCrypt';

  @override
  String get dnsAnonymizedHint =>
      'کوئریز ایک ریلے سے گزرتی ہیں، اس لیے ریزولور کبھی نہیں دیکھتا کہ وہ کہاں سے آئیں';

  @override
  String get dnsAnonymizedNeedsDnscrypt =>
      'اس کے لیے کوئی DNSCrypt ریزولور منتخب کریں';

  @override
  String get dnsRelay => 'ریلے';

  @override
  String get dnsRelayChoose => 'ریلے منتخب کریں';

  @override
  String get dnsRelayAutomatic => 'خودکار (دوسرا آپریٹر)';

  @override
  String get dnsErrAddress =>
      'https://، tls://، tcp:// یا udp:// سے شروع ہونے والا پتہ، یا sdns:// stamp درج کریں';

  @override
  String get dnsErrDamaged =>
      'یہ stamp خراب یا ادھورا ہے۔ اسے دوبارہ کاپی کریں۔';

  @override
  String get dnsErrUnsupported => 'اس قسم کا stamp معاون نہیں ہے';

  @override
  String get dnsErrRelayStamp => 'یہ ریلے کا stamp ہے، ریزولور کا نہیں';

  @override
  String dnsLine(String resolver) {
    return 'DNS: $resolver';
  }

  @override
  String get dnsLimits =>
      'یہ آپ کے تلاش کیے گئے ناموں کی حفاظت کرتا ہے۔ یہ نہیں چھپاتا کہ آپ بعد میں کن سائٹس سے جڑتے ہیں۔';

  @override
  String get dnsAnonymizedShort => 'گمنام';

  @override
  String get flAuthKey => 'تصدیقی کلید';

  @override
  String get flControlServer => 'کنٹرول سرور';

  @override
  String get flDeviceName => 'ڈیوائس کا نام';

  @override
  String get flExitDevice => 'ایگزٹ ڈیوائس';

  @override
  String get flUseSubnets => 'دوسری ڈیوائسز کے سب نیٹ استعمال کریں';

  @override
  String get flTempDevice => 'عارضی ڈیوائس';

  @override
  String get hpAuthKey =>
      'Tailscale ایڈمن صفحے سے پیشگی منظور شدہ کلید، یا headscale preauthkeys create سے بنائی گئی';

  @override
  String get hpControlServer =>
      'خالی ہو تو Tailscale؛ Headscale کے لیے اس کا پتہ، جیسے https://hs.example.com';

  @override
  String get hpDeviceName =>
      'نیٹ ورک میں اس ڈیوائس کا نام؛ خالی ہو تو ڈیوائس کا اپنا نام';

  @override
  String get hpExitDevice =>
      'اس ڈیوائس کا نام یا پتہ جس کا انٹرنیٹ کنکشن استعمال کرنا ہے؛ خالی ہو تو صرف آپ کی ڈیوائسز تک رسائی';

  @override
  String get hpTempDevice => 'آف لائن ہونے پر نیٹ ورک سے ہٹا دی جاتی ہے';

  @override
  String get devicesTitle => 'میری ڈیوائسز';

  @override
  String get devicesNotConnected =>
      'اپنی ڈیوائسز دیکھنے کے لیے Tailscale یا Headscale پروفائل سے جڑیں۔';

  @override
  String get devicesJoining => 'نیٹ ورک میں شامل ہو رہے ہیں…';

  @override
  String get devicesLoginNeeded =>
      'نیٹ ورک نے اس ڈیوائس کی کلید قبول نہیں کی۔ نئی کلید بنائیں اور پروفائل میں ترمیم کریں۔';

  @override
  String get devicesEmpty => 'اس نیٹ ورک میں ابھی کوئی اور ڈیوائس نہیں ہے۔';

  @override
  String get devicesThisDevice => 'یہ ڈیوائس';

  @override
  String get deviceOnline => 'آن لائن';

  @override
  String get deviceOffline => 'آف لائن';

  @override
  String deviceLastSeen(String when) {
    return 'آخری بار $when کو دیکھا گیا';
  }

  @override
  String get deviceUseAsExit => 'ایگزٹ کے طور پر استعمال کریں';

  @override
  String get deviceStopExit => 'ایگزٹ کے طور پر استعمال بند کریں';

  @override
  String get deviceIsExit => 'ایگزٹ زیر استعمال';

  @override
  String get devicesExitHint =>
      'اپنی کسی ڈیوائس کو ایگزٹ بنائیں: آپ کا سارا ٹریفک اس کے کنکشن سے نکلے گا۔';

  @override
  String get deviceCopyName => 'نام کاپی کریں';

  @override
  String get deviceCopyAddress => 'پتہ کاپی کریں';

  @override
  String get deviceCopied => 'کاپی ہو گیا';

  @override
  String get errMeshExit =>
      'اس ڈیوائس کو ابھی ایگزٹ کے طور پر استعمال نہیں کیا جا سکتا۔ اسے آن لائن ہونا اور اپنا کنکشن پیش کرنا ہوگا۔';

  @override
  String get wnTlsInsecure =>
      'سرور کا سرٹیفکیٹ نہیں جانچا جاتا۔ راستے میں کوئی بھی آپ کا ٹریفک پڑھ یا بدل سکتا ہے۔';

  @override
  String get wnNoTls =>
      'ٹریفک TLS میں لپٹا ہوا نہیں ہے۔ اسے پہچاننا آسان ہے اور راستے میں پڑھا جا سکتا ہے۔';

  @override
  String get wnVmessLegacy =>
      'VMess پرانا پروٹوکول ہے اور اسے پہچاننا آسان ہے۔ Reality کے ساتھ VLESS بہتر انتخاب ہے۔';

  @override
  String get wnSsPlain =>
      'shadow-tls جیسے پلگ اِن کے بغیر ٹریفک بے ترتیب بائٹس جیسا لگتا ہے، اور کچھ نیٹ ورک اس نمونے کو روک دیتے ہیں۔';

  @override
  String get wnHysteria1 =>
      'Hysteria 1 متروک ہو چکا ہے۔ سرور سپورٹ کرے تو Hysteria 2 استعمال کریں۔';

  @override
  String get wnDpiVisible =>
      'اس پروٹوکول کو پہچاننا آسان ہے اور سخت نیٹ ورکس پر اکثر بند کر دیا جاتا ہے۔';

  @override
  String get wnSshVisible => 'SSH ٹنل کو پہچاننا آسان ہے۔';

  @override
  String get wnDnsttSlow =>
      'سست (عموماً 1 Mbit/s سے بہت کم) اور صرف TCP۔ یہ بہت سی DNS کوئریز بھیجتا ہے جنہیں نیٹ ورک دیکھ سکتا ہے۔ صرف تب استعمال کریں جب کچھ اور نہ چلے۔';

  @override
  String get wnDnsttOpen =>
      'صارف نام اور پاس ورڈ نہیں: اس لنک والا کوئی بھی سرور استعمال کر سکتا ہے۔';

  @override
  String get wnMuxLossy =>
      'ملٹی پلیکسنگ کئی کنکشن ایک میں رکھتی ہے۔ خراب لائن سب کو سست کر سکتی ہے۔';

  @override
  String get wnFragmentSide =>
      'ہینڈ شیک کو ٹکڑوں میں بانٹنا کچھ فلٹرز کے خلاف مدد دیتا ہے، کچھ پر خراب ہو سکتا ہے اور تاخیر بڑھاتا ہے۔';

  @override
  String get wnEchServer =>
      'ایسا سرور چاہیے جو ECH سپورٹ کرے، ورنہ کنکشن ناکام ہوگا۔';

  @override
  String get wnWgChain =>
      'پراکسی کے اندر WireGuard: پراکسی سست ہو تو ٹنل رک سکتی ہے۔ پراکسی کو UDP گزارنا ہوگا۔';

  @override
  String get wnSubUnsigned =>
      'یہ فہرست دستخط شدہ نہیں ہے، اس لیے تبدیلی کا پتا نہیں چل سکتا۔';

  @override
  String get choiceOff => 'بند';

  @override
  String get flMultiplexing => 'ملٹی پلیکسنگ';

  @override
  String get flMuxPadding => 'ملٹی پلیکسنگ پیڈنگ';

  @override
  String get flMuxMaxConnections => 'زیادہ سے زیادہ کنکشن';

  @override
  String get flMuxMinStreams => 'فی کنکشن کم از کم اسٹریمز';

  @override
  String get flMuxMaxStreams => 'فی کنکشن زیادہ سے زیادہ اسٹریمز';

  @override
  String get hpMultiplexing =>
      'کئی کنکشن ایک میں؛ سرور کو اجازت دینی ہوگی۔ VLESS flow کے ساتھ نہیں';

  @override
  String get hpMuxMaxStreams => 'اوپر کے دونوں کی جگہ';
}
