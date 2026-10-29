// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'Wardkeep';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionEdit => 'تعديل';

  @override
  String get actionReset => 'إعادة ضبط';

  @override
  String get actionSkip => 'تخطي';

  @override
  String get actionNext => 'التالي';

  @override
  String get actionImport => 'استيراد';

  @override
  String get actionDownload => 'تنزيل';

  @override
  String get actionCopyAll => 'نسخ الكل';

  @override
  String get actionClear => 'مسح';

  @override
  String get tooltipMore => 'المزيد';

  @override
  String get tooltipShow => 'إظهار';

  @override
  String get tooltipHide => 'إخفاء';

  @override
  String get searchHint => 'بحث';

  @override
  String get tooltipLogs => 'السجلات';

  @override
  String get tooltipSettings => 'الإعدادات';

  @override
  String get statusConnected => 'متصل';

  @override
  String get statusConnecting => 'جارٍ الاتصال…';

  @override
  String get statusDisconnecting => 'جارٍ قطع الاتصال…';

  @override
  String get statusError => 'فشل الاتصال';

  @override
  String get statusNoInternet => 'لا يوجد اتصال بالإنترنت';

  @override
  String get statusDisconnected => 'غير متصل';

  @override
  String get stagePermission => 'في انتظار إذن VPN';

  @override
  String get stageNetworkCheck => 'التحقق من اتصال الإنترنت';

  @override
  String get stagePrepare => 'تجهيز الإعدادات';

  @override
  String get stageEngineStart => 'تشغيل المحرك';

  @override
  String get stageTunnelUp => 'فتح النفق';

  @override
  String get stageHandshake => 'الاتصال بالخادم';

  @override
  String get stageConnected => 'متصل';

  @override
  String get buttonConnect => 'اتصال';

  @override
  String get buttonDisconnect => 'قطع الاتصال';

  @override
  String get buttonCancel => 'إلغاء';

  @override
  String get locationLabel => 'الموقع';

  @override
  String get noServers => 'لا توجد خوادم';

  @override
  String get noServersHint => 'أضف خادمًا للبدء';

  @override
  String get automatic => 'تلقائي';

  @override
  String get automaticHint => 'أسرع خادم، ويتبدّل عند العطل';

  @override
  String get anyServerInCountry => 'أي خادم في هذا البلد';

  @override
  String get torNetwork => 'شبكة Tor';

  @override
  String get torHopBridge => 'جسر';

  @override
  String get torHopEntry => 'دخول';

  @override
  String get torHopRelay => 'مرحّل';

  @override
  String get torHopExit => 'خروج';

  @override
  String get torHopHidden => 'مخفي';

  @override
  String get torHopUnknown => 'غير معروف';

  @override
  String get hopYou => 'أنت';

  @override
  String get hopYouNote => 'هذا هو مكانك الحقيقي. تبدأ حركة بياناتك من هنا.';

  @override
  String get hopServer => 'الخادم';

  @override
  String get hopServerNote =>
      'تنتقل بياناتك مشفّرة إلى هذا الخادم وتخرج منه، لذلك ترى المواقع عنوانه بدلاً من عنوانك.';

  @override
  String get hopBridgeNote =>
      'نقطتك الأولى. يخفي الجسر عن شبكتك أنك تستخدم Tor. يعرف من أنت لكنه لا يعرف إلى أين تذهب.';

  @override
  String get hopEntryNote => 'أول مرحّل. يعرف عنوانك لكنه لا يعرف ما تزوره.';

  @override
  String get hopRelayNote =>
      'المرحّل الأوسط. لا يعرف من أنت ولا ما تزوره؛ فهو يمرّر الحركة فقط.';

  @override
  String get hopExitNote =>
      'آخر مرحّل. يرى إلى أين تذهب لكنه لا يعرف من أنت، وترى المواقع عنوانه.';

  @override
  String get hopHiddenNote =>
      'موقع الجسر مخفي بواسطة وسيلة النقل، لذا لا يمكن عرضه على الخريطة.';

  @override
  String get hopTransport => 'وسيلة النقل';

  @override
  String get hopProtocol => 'البروتوكول';

  @override
  String get hopAddress => 'العنوان';

  @override
  String get hopLatency => 'زمن الاستجابة';

  @override
  String get hopExitAddress => 'عنوان الخروج';

  @override
  String get menuNewGroup => 'مجموعة جديدة';

  @override
  String get groupNameHint => 'اسم المجموعة';

  @override
  String get groupCreate => 'إنشاء';

  @override
  String get menuMoveToGroup => 'نقل إلى مجموعة';

  @override
  String get groupMoveTitle => 'نقل إلى';

  @override
  String get menuRenameGroup => 'إعادة تسمية';

  @override
  String get menuDeleteGroup => 'حذف المجموعة';

  @override
  String get groupDeleteTitle => 'حذف هذه المجموعة؟';

  @override
  String groupDeleteBody(String name) {
    return 'لن تُحذف خوادمها. ستعود إلى $name.';
  }

  @override
  String get groupEmptyHint =>
      'لا توجد خوادم بعد. افتح قائمة أي خادم واختر «نقل إلى مجموعة».';

  @override
  String get menuShareGroupFile => 'حفظ كملف نصي';

  @override
  String get menuCopyGroupLinks => 'نسخ الروابط';

  @override
  String groupSavedToast(String servers) {
    return 'تم الحفظ: $servers';
  }

  @override
  String groupCopiedToast(String servers) {
    return 'تم النسخ: $servers';
  }

  @override
  String get groupNothingToShare => 'لا يوجد رابط مشاركة لأي من هذه الخوادم.';

  @override
  String groupSkipped(String servers) {
    return 'تم استبعادها لعدم وجود رابط مشاركة: $servers';
  }

  @override
  String get emptyTitle => 'لا توجد ملفات تعريف بعد';

  @override
  String get emptyHint => 'استورد إعدادًا أو رابطًا أو اشتراكًا.';

  @override
  String get importConfig => 'استيراد الإعدادات';

  @override
  String failoverToast(String to, String from) {
    return 'تم التبديل إلى $to — توقف $from عن الاستجابة';
  }

  @override
  String get unknownLocation => 'موقع غير معروف';

  @override
  String errorFailed(String stage, String reason) {
    return 'فشل $stage: $reason';
  }

  @override
  String get errTimeout => 'لم يستجب الخادم في الوقت المناسب';

  @override
  String get errRefused => 'رفض الخادم الاتصال';

  @override
  String get errReset => 'أعادت الشبكة ضبط الاتصال';

  @override
  String get errNoRoute => 'لا يمكن الوصول إلى الخادم من هذه الشبكة';

  @override
  String get errNetworkUnreachable => 'الشبكة غير قابلة للوصول';

  @override
  String get errDns => 'تعذّر تحديد عنوان الخادم من اسمه';

  @override
  String get errTls => 'تم رفض شهادة أمان الخادم';

  @override
  String get errAuth => 'تم رفض اسم المستخدم أو كلمة المرور';

  @override
  String get errClosed => 'أغلق الخادم الاتصال';

  @override
  String get errCertDate =>
      'شهادة الخادم منتهية أو غير سارية بعد (تحقق أيضًا من تاريخ الهاتف ووقته)';

  @override
  String get errCertUntrusted => 'شهادة الخادم غير موقّعة من جهة موثوقة';

  @override
  String get errCertName => 'شهادة الخادم صادرة لاسم مختلف عن الذي تتصل به';

  @override
  String get errTlsKeys =>
      'المفتاح المشترك (tls-auth أو tls-crypt) لا يطابق مفتاح الخادم';

  @override
  String get errReality =>
      'رفض الخادم مصافحة Reality (تحقق من المفتاح العام وshort ID واسم الخادم)';

  @override
  String get errNoHandshake =>
      'لم يردّ الخادم على المصافحة (تحقق من المفاتيح والعنوان وأن منفذ UDP مفتوح)';

  @override
  String get errUdpBlocked =>
      'لم يردّ الخادم عبر UDP؛ قد تحجبه هذه الشبكة، جرّب خادمًا يعمل عبر TCP';

  @override
  String get errPortInUse => 'المنفذ المحلي مستخدم من تطبيق آخر';

  @override
  String get errTorTimeout =>
      'لم يكتمل اتصال Tor في الوقت المناسب. قد تحجب هذه الشبكة Tor؛ استخدم جسرًا (Snowflake أو obfs4)';

  @override
  String get errTorBridgeTimeout =>
      'لم يكتمل اتصال Tor في الوقت المناسب. قد يكون الجسر محجوبًا أو مزدحمًا؛ جرّب نوعًا آخر من الجسور (Snowflake أو obfs4)';

  @override
  String get errTorBadBridge =>
      'سطر جسر Tor غير صالح (يلزمه نوع النقل والعنوان والبصمة)';

  @override
  String get errTorMissing => 'لا يتضمن هذا الإصدار عميل Tor';

  @override
  String get errPermission => 'لم يتم منح إذن VPN';

  @override
  String get errCoreLost => 'انقطع الاتصال بخدمة النواة';

  @override
  String get selectLocation => 'اختيار الموقع';

  @override
  String get testSpeedTooltip => 'اختبار سرعة جميع الخوادم';

  @override
  String get addServersTooltip => 'إضافة خوادم';

  @override
  String get menuImport => 'استيراد إعدادات أو رابط أو رمز QR';

  @override
  String get menuNewServer => 'إضافة خادم يدويًا';

  @override
  String get menuSubscription => 'إضافة اشتراك';

  @override
  String get menuManage => 'إدارة الخوادم والاشتراكات';

  @override
  String get menuSetDefault => 'اجعله الافتراضي';

  @override
  String get badgeDefault => 'افتراضي';

  @override
  String get menuDeleteAll => 'حذف كل الخوادم';

  @override
  String get deleteAllTitle => 'حذف كل الخوادم؟';

  @override
  String get deleteAllBody =>
      'ستُحذف كل الخوادم والاشتراكات التي أضفتها. يبقى اتصال Tor المدمج ويعود التطبيق إليه.';

  @override
  String get menuRestoreTor => 'استعادة Tor الافتراضي';

  @override
  String get deletedAllToast => 'حُذفت كل الخوادم';

  @override
  String defaultSetToast(String name) {
    return '$name هو الافتراضي الآن';
  }

  @override
  String serversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خادم',
      many: '$count خادمًا',
      few: '$count خوادم',
      two: 'خادمان',
      one: 'خادم واحد',
      zero: 'لا خوادم',
    );
    return '$_temp0';
  }

  @override
  String get otherGroup => 'أخرى';

  @override
  String get torGroup => 'Tor';

  @override
  String get noServersYet => 'لا توجد خوادم بعد';

  @override
  String get importHintShort => 'استورد ملف إعدادات أو رابطًا أو اشتراكًا.';

  @override
  String get showServers => 'إظهار الخوادم';

  @override
  String get hideServers => 'إخفاء الخوادم';

  @override
  String get menuEditServer => 'تعديل';

  @override
  String get menuBridgeSettings => 'إعدادات الجسور';

  @override
  String get menuShare => 'مشاركة الرابط أو رمز QR';

  @override
  String get menuSetCountry => 'تحديد البلد';

  @override
  String get menuCredentials => 'اسم المستخدم وكلمة المرور';

  @override
  String needsSignIn(String address) {
    return '$address · يتطلب تسجيل الدخول';
  }

  @override
  String get countryOfServer => 'بلد هذا الخادم';

  @override
  String get guessFromName => 'استنتاجه من الاسم';

  @override
  String get latencyNotTested => 'لم يُختبر';

  @override
  String get latencyUnreachable => 'غير قابل للوصول';

  @override
  String get latencyTimeout => 'انتهت المهلة';

  @override
  String latencyMs(int ms) {
    return '$ms مللي ثانية';
  }

  @override
  String get unknownCountry => 'بلد غير معروف';

  @override
  String get addServerTitle => 'إضافة خادم';

  @override
  String get addServerIntro =>
      'اختر البروتوكول. الرابط أو QR أسرع: استخدم استيراد.';

  @override
  String newServerTitle(String label) {
    return 'خادم $label جديد';
  }

  @override
  String get editServerTitle => 'تعديل الخادم';

  @override
  String get torBridgesTitle => 'جسور Tor';

  @override
  String get subscriptionEditNote =>
      'هذا الخادم من اشتراك: ستُستبدل تغييراتك عند تحديث الاشتراك.';

  @override
  String get moreOptions => 'خيارات إضافية';

  @override
  String get countryRow => 'البلد';

  @override
  String get countryAuto => 'يُستنتج من الاسم والعنوان';

  @override
  String get alreadyInList => 'هذا الخادم موجود بالفعل في القائمة';

  @override
  String get choiceDefault => 'افتراضي';

  @override
  String get torBridgesNone => 'بلا (اتصال مباشر، أو الأسطر أدناه)';

  @override
  String get torBridgesSnowflake => 'Snowflake';

  @override
  String get torBridgesObfs4 => 'obfs4 (جسور مدمجة)';

  @override
  String get listHelper => 'افصل القيم بفواصل';

  @override
  String get fillPaste => 'لصق';

  @override
  String get fillFile => 'ملف';

  @override
  String get fillScanQr => 'مسح QR';

  @override
  String get openTextFile => 'فتح ملف نصي';

  @override
  String couldNotReadFile(String error) {
    return 'تعذّرت قراءة الملف: $error';
  }

  @override
  String fieldRequired(String label) {
    return '$label *';
  }

  @override
  String formNoEditor(String protocol) {
    return 'لا يوجد محرر لـ $protocol';
  }

  @override
  String get shareScanHint => 'امسحه بـ Wardkeep أو انسخ الرابط.';

  @override
  String get shareCopy => 'نسخ الرابط';

  @override
  String get shareCopied => 'تم نسخ الرابط';

  @override
  String get shareWarning =>
      'يحتوي على كلمة مرور الخادم أو مفتاحه. شاركه بحذر.';

  @override
  String shareFailed(String reason) {
    return 'لا يمكن مشاركة هذا الخادم كرابط: $reason';
  }

  @override
  String get shareTooLong => 'أطول من أن يُحوَّل إلى رمز QR: انسخ الرابط';

  @override
  String get obTitle1 => 'خصوصية وبساطة';

  @override
  String get obText1 =>
      'شاشة هادئة واحدة لـ VPN والوكيل وTor. اختر مكانًا واضغط اتصال.';

  @override
  String get obTitle2 => 'أضف خوادمك';

  @override
  String get obText2 =>
      'استورد رابطًا أو رمز QR أو ملف إعداد أو اشتراكًا، أو أضف خادمًا يدويًا.';

  @override
  String get obTitle3Android => 'سيسألك أندرويد مرة واحدة';

  @override
  String get obText3Android =>
      'سيطلب أندرويد السماح باتصال VPN. اقبل ليبدأ الحماية.';

  @override
  String get obTitle3Desktop => 'جاهز متى شئت';

  @override
  String get obText3Desktop =>
      'يبدأ بوضع الوكيل دون صلاحيات خاصة. فعّل وضع VPN من الإعدادات لالتقاط كل الحركة.';

  @override
  String get obAddFirst => 'إضافة أول خادم';

  @override
  String get bypassTitle => 'قوائم التجاوز';

  @override
  String get bypassAddTooltip => 'إضافة قائمة';

  @override
  String get bypassFromClipboard => 'لصق من الحافظة';

  @override
  String get bypassFromFile => 'فتح ملف .txt';

  @override
  String get bypassFromUrl => 'تنزيل من رابط';

  @override
  String get bypassType => 'كتابتها';

  @override
  String get bypassClipboardEmpty => 'الحافظة فارغة';

  @override
  String get bypassPickFile => 'فتح قائمة تجاوز (.txt)';

  @override
  String bypassDownloadFailed(String error) {
    return 'تعذّر تنزيل القائمة: $error';
  }

  @override
  String get bypassIntro =>
      'مواقع وعناوين تتجاوز VPN. إدخال في كل سطر: ‎example.com‎، ‎full:www.example.com‎، ‎keyword:bank‎، ‎regexp:…‎، ‎203.0.113.7‎ أو ‎10.0.0.0/8‎. تُتجاهل الأسطر التي تبدأ بـ #.';

  @override
  String get bypassNoLists => 'لا توجد قوائم بعد.';

  @override
  String get bypassTypeList => 'اكتب قائمة';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إدخال',
      many: '$count إدخالًا',
      few: '$count إدخالات',
      two: 'إدخالان',
      one: 'إدخال واحد',
      zero: 'لا إدخالات',
    );
    return '$_temp0';
  }

  @override
  String get bypassOnlyTitle => 'المدرجة فقط تستخدم VPN';

  @override
  String get bypassOnlyOn => 'البقية مباشرة.';

  @override
  String get bypassOnlyOff => 'المدرجة مباشرة والبقية عبر VPN.';

  @override
  String get bypassNothing => 'لا توجد قائمة مفعّلة.';

  @override
  String bypassInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إدخال قيد الاستخدام',
      many: '$count إدخالًا قيد الاستخدام',
      few: '$count إدخالات قيد الاستخدام',
      two: 'إدخالان قيد الاستخدام',
      one: 'إدخال واحد قيد الاستخدام',
      zero: 'لا إدخالات قيد الاستخدام',
    );
    return '$_temp0. يُطبَّق عند الاتصال التالي.';
  }

  @override
  String get bypassHttpLink => 'أدخل رابط http(s)';

  @override
  String bypassServerAnswered(int code) {
    return 'ردّ الخادم بالرمز $code';
  }

  @override
  String get bypassTooLarge => 'القائمة أكبر من 5 ميغابايت';

  @override
  String get bypassDownloadTitle => 'تنزيل قائمة';

  @override
  String get bypassNewList => 'قائمة جديدة';

  @override
  String get bypassEditList => 'تعديل القائمة';

  @override
  String get bypassName => 'الاسم';

  @override
  String get bypassEntriesLabel => 'الإدخالات، واحد في كل سطر';

  @override
  String get bypassNoUsable => 'لا توجد إدخالات صالحة بعد.';

  @override
  String bypassSummary(String entries, String names, String ranges) {
    return '$entries · $names، $ranges.';
  }

  @override
  String bypassNames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اسم',
      many: '$count اسمًا',
      few: '$count أسماء',
      two: 'اسمان',
      one: 'اسم واحد',
      zero: 'لا أسماء',
    );
    return '$_temp0';
  }

  @override
  String bypassRanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنوان أو نطاق',
      many: '$count عنوانًا أو نطاقًا',
      few: '$count عناوين أو نطاقات',
      two: 'عنوانان أو نطاقان',
      one: 'عنوان أو نطاق واحد',
      zero: 'لا عناوين',
    );
    return '$_temp0';
  }

  @override
  String bypassIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سيُتجاهل $count سطر:',
      many: 'سيُتجاهل $count سطرًا:',
      few: 'ستُتجاهل $count أسطر:',
      two: 'سيُتجاهل سطران:',
      one: 'سيُتجاهل سطر واحد:',
    );
    return '$_temp0';
  }

  @override
  String bypassMoreIssues(int count) {
    return '… و$count أخرى';
  }

  @override
  String get bypassReconnect => 'أعد الاتصال لاستخدام القائمة الجديدة';

  @override
  String get bypassDefaultName => 'قائمتي';

  @override
  String get bypassPastedName => 'قائمة ملصوقة';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsServers => 'الخوادم';

  @override
  String get manageServers => 'إدارة الخوادم';

  @override
  String get manageServersHint => 'الخوادم والاشتراكات';

  @override
  String get settingsConnection => 'الاتصال';

  @override
  String get vpnMode => 'وضع VPN (كل حركة البيانات)';

  @override
  String get vpnModeHint => 'متوقف: وكيل فقط، دون إذن VPN';

  @override
  String get systemProxy => 'ضبط وكيل النظام';

  @override
  String get systemProxyHint => 'ضبط وكيل النظام أثناء الاتصال';

  @override
  String get autoSwitch => 'التبديل التلقائي عند الفشل';

  @override
  String get autoSwitchHint => 'جرّب الخادم التالي عند تعطل الحالي';

  @override
  String get bypassLan => 'تجاوز الشبكة المحلية';

  @override
  String get bypassLanHint =>
      'الوصول إلى الأجهزة المحلية مباشرة (‎192.168.x.x‎، ‎10.x.x.x‎)';

  @override
  String get bypassListsHint => 'مواقع وعناوين تتجاوز VPN';

  @override
  String bypassListsInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إدخال قيد الاستخدام',
      many: '$count إدخالًا قيد الاستخدام',
      few: '$count إدخالات قيد الاستخدام',
      two: 'إدخالان قيد الاستخدام',
      one: 'إدخال واحد قيد الاستخدام',
      zero: 'لا إدخالات قيد الاستخدام',
    );
    return '$_temp0';
  }

  @override
  String get alwaysOnTitle => 'VPN دائم التشغيل وقاطع الاتصال';

  @override
  String get alwaysOnHint =>
      'إعادة الاتصال عند التشغيل وحظر الحركة إذا انقطع VPN. فعّله من إعدادات VPN في أندرويد (الترس بجوار Wardkeep).';

  @override
  String get openVpnSettingsFallback =>
      'الإعدادات ← الشبكة ← VPN ← الترس بجوار Wardkeep';

  @override
  String get splitTunneling => 'النفق المقسَّم';

  @override
  String splitSummaryOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تطبيق محدد فقط يستخدم VPN',
      many: '$count تطبيقًا محددًا فقط يستخدم VPN',
      few: '$count تطبيقات محددة فقط تستخدم VPN',
      two: 'تطبيقان محددان فقط يستخدمان VPN',
      one: 'تطبيق واحد محدد فقط يستخدم VPN',
    );
    return '$_temp0';
  }

  @override
  String splitSummaryBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تطبيق يتجاوز VPN',
      many: '$count تطبيقًا يتجاوز VPN',
      few: '$count تطبيقات تتجاوز VPN',
      two: 'تطبيقان يتجاوزان VPN',
      one: 'تطبيق واحد يتجاوز VPN',
    );
    return '$_temp0';
  }

  @override
  String get splitSummaryOff => 'جميع التطبيقات تستخدم VPN';

  @override
  String get remoteDns => 'DNS البعيد';

  @override
  String get remoteDnsHelp =>
      'DNS المستخدم عبر النفق، مثل ‎https://1.1.1.1/dns-query‎ أو ‎tls://1.1.1.1‎';

  @override
  String get settingsApp => 'التطبيق';

  @override
  String get appearance => 'المظهر';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeSystem => 'حسب النظام';

  @override
  String get language => 'اللغة';

  @override
  String get languageSystem => 'افتراضي النظام';

  @override
  String get stopOnClose => 'إيقاف VPN عند إغلاق التطبيق';

  @override
  String aboutLine(String engine) {
    return 'رخصة MIT · المحرك: $engine';
  }

  @override
  String get splitTitle => 'النفق المقسَّم';

  @override
  String get splitAll => 'كل التطبيقات';

  @override
  String get splitOnlySelected => 'المحددة فقط';

  @override
  String get splitBypassSelected => 'تجاوز المحددة';

  @override
  String get splitHelpOffMode => 'كل التطبيقات تستخدم VPN.';

  @override
  String get splitHelpOnlyNone => 'لم تُحدَّد تطبيقات: الكل يستخدم VPN.';

  @override
  String splitHelpOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تطبيق فقط تستخدم VPN.',
      many: '$count تطبيقًا فقط تستخدم VPN.',
      few: '$count تطبيقات فقط تستخدم VPN.',
      two: 'تطبيقان فقط يستخدمان VPN.',
      one: 'تطبيق واحد فقط يستخدم VPN.',
    );
    return '$_temp0';
  }

  @override
  String splitHelpBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تطبيق يتصل مباشرة.',
      many: '$count تطبيقًا يتصل مباشرة.',
      few: '$count تطبيقات تتصل مباشرة.',
      two: 'تطبيقان يتصلان مباشرة.',
      one: 'تطبيق واحد يتصل مباشرة.',
    );
    return '$_temp0';
  }

  @override
  String get searchApps => 'بحث في التطبيقات';

  @override
  String get showSystemApps => 'إظهار تطبيقات النظام';

  @override
  String couldNotListApps(String error) {
    return 'تعذّر عرض التطبيقات: $error';
  }

  @override
  String get scanTitle => 'مسح رمز QR';

  @override
  String get scanTorch => 'المصباح';

  @override
  String scanCameraUnavailable(String code) {
    return 'الكاميرا غير متاحة: $code';
  }

  @override
  String get scanPoint => 'وجّه الكاميرا إلى رمز QR الخاص بالإعدادات';

  @override
  String get credTitle => 'تسجيل الدخول';

  @override
  String credNeeds(String name) {
    return 'يحتاج $name إلى اسم مستخدم وكلمة مرور.';
  }

  @override
  String get credUsername => 'اسم المستخدم';

  @override
  String get credPassword => 'كلمة المرور';

  @override
  String get logsEmpty => 'لا توجد سجلات بعد.';

  @override
  String get profilesTitle => 'إدارة الخوادم';

  @override
  String get addSubscriptionTooltip => 'إضافة اشتراك';

  @override
  String get testLatencyTooltip => 'اختبار زمن الاستجابة';

  @override
  String get profilesEmptyHint =>
      'لا توجد ملفات تعريف. اضغط «استيراد» لإضافة واحد.';

  @override
  String get profilesDragHint =>
      'اضغط مطولًا واسحب لإعادة الترتيب. التبديل التلقائي يتبع هذا الترتيب.';

  @override
  String get myProfiles => 'ملفاتي';

  @override
  String subRefreshed(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف تعريف',
      many: '$count ملف تعريف',
      few: '$count ملفات تعريف',
      two: 'ملفا تعريف',
      one: 'ملف تعريف واحد',
      zero: 'لا ملفات تعريف',
    );
    return '$name: $_temp0';
  }

  @override
  String get refreshTooltip => 'تحديث';

  @override
  String get subDeleteWithProfiles => 'حذف الاشتراك وملفات تعريفه';

  @override
  String subUsageOf(String used, String total) {
    return '$used من $total';
  }

  @override
  String subUsed(String used) {
    return 'المستخدم $used';
  }

  @override
  String get subExpired => 'منتهي';

  @override
  String get subExpiresToday => 'ينتهي اليوم';

  @override
  String subExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'ينتهي خلال $days يوم',
      many: 'ينتهي خلال $days يومًا',
      few: 'ينتهي خلال $days أيام',
      two: 'ينتهي خلال يومين',
      one: 'ينتهي خلال يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String subUpdated(String ago) {
    return 'حُدّث $ago';
  }

  @override
  String get agoJustNow => 'الآن';

  @override
  String agoMinutes(int count) {
    return 'منذ $count دقيقة';
  }

  @override
  String agoHours(int count) {
    return 'منذ $count ساعة';
  }

  @override
  String agoDays(int count) {
    return 'منذ $count يوم';
  }

  @override
  String subRefreshFailed(String error) {
    return 'فشل آخر تحديث: $error';
  }

  @override
  String get importTitle => 'استيراد الإعدادات';

  @override
  String get importDescription =>
      'الصق رابطًا أو إعدادًا أو اشتراكًا، أو افتح ملفًا أو امسح رمز QR.';

  @override
  String get importScanQr => 'مسح QR';

  @override
  String get importOpenFile => 'فتح ملف';

  @override
  String get importPaste => 'لصق';

  @override
  String get importSubscription => 'اشتراك';

  @override
  String get importTor => 'Tor';

  @override
  String get importAddTor => 'إضافة Tor';

  @override
  String get importTorDirect => 'Tor (مباشر)';

  @override
  String get importTorSnowflake => 'Tor + جسر Snowflake';

  @override
  String get importTorObfs4 => 'Tor + جسور obfs4';

  @override
  String importedProfiles(int added, int dupes) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'تم استيراد $added ملف تعريف',
      many: 'تم استيراد $added ملف تعريف',
      few: 'تم استيراد $added ملفات تعريف',
      two: 'تم استيراد ملفي تعريف',
      one: 'تم استيراد ملف تعريف واحد',
      zero: 'لم يُستورد شيء',
    );
    String _temp1 = intl.Intl.pluralLogic(
      dupes,
      locale: localeName,
      other: '، منها $dupes موجود مسبقًا',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String importNothing(String reason) {
    return 'لم يُستورد شيء: $reason';
  }

  @override
  String importPartial(int added, int failed) {
    return 'تم استيراد $added، وفشل $failed';
  }

  @override
  String get subAddTitle => 'إضافة اشتراك';

  @override
  String get subEditTitle => 'تعديل الاشتراك';

  @override
  String get subUrlLabel => 'رابط الاشتراك';

  @override
  String get subUrlHint =>
      'https://provider.example/sub/… أو nordvpn://<الرمز>';

  @override
  String get subNameLabel => 'الاسم (اختياري)';

  @override
  String get subNameHelp => 'الافتراضي هو عنوان المزوّد أو اسم المضيف';

  @override
  String get subAuthLabel => 'المصادقة';

  @override
  String get authNone => 'بلا';

  @override
  String get authBasic => 'اسم المستخدم وكلمة المرور (Basic)';

  @override
  String get authBearer => 'رمز Bearer';

  @override
  String get authHeader => 'ترويسة مخصصة';

  @override
  String get authQuery => 'رمز في الرابط';

  @override
  String get subUsername => 'اسم المستخدم';

  @override
  String get subPassword => 'كلمة المرور';

  @override
  String get subHeaderName => 'اسم الترويسة';

  @override
  String get subHeaderValue => 'قيمة الترويسة';

  @override
  String get subParamName => 'اسم المعامل';

  @override
  String get subToken => 'الرمز';

  @override
  String get subDownloadLabel => 'التنزيل';

  @override
  String get subDownloadHelp => 'المزوّد محجوب؟ يستطيع VPN جلبه';

  @override
  String get subViaDirect => 'مباشرة';

  @override
  String get subViaAuto => 'مباشرة، أو عبر VPN إن كان محجوبًا';

  @override
  String get subViaTunnel => 'دائمًا عبر VPN (اتصل أولًا)';

  @override
  String get subErrUrl =>
      'أدخل رابط اشتراك http(s) (أو nordvpn://<رمز الوصول>)';

  @override
  String get subErrHeader => 'أدخل اسم الترويسة';

  @override
  String get subErrToken => 'أدخل الرمز';

  @override
  String get subAddAndDownload => 'إضافة وتنزيل';

  @override
  String get subSaveAndRefresh => 'حفظ وتحديث';

  @override
  String subUpdatedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف تعريف',
      many: '$count ملف تعريف',
      few: '$count ملفات تعريف',
      two: 'ملفا تعريف',
      one: 'ملف تعريف واحد',
      zero: 'لا ملفات تعريف',
    );
    return 'تم تحديث الاشتراك: $_temp0';
  }

  @override
  String get flName => 'الاسم';

  @override
  String get flServer => 'الخادم';

  @override
  String get flPort => 'المنفذ';

  @override
  String get flPassword => 'كلمة المرور';

  @override
  String get flUsername => 'اسم المستخدم';

  @override
  String get flUuid => 'UUID';

  @override
  String get flSecurity => 'الأمان';

  @override
  String get flFlow => 'Flow';

  @override
  String get flCipher => 'الشيفرة';

  @override
  String get flEncryption => 'التشفير';

  @override
  String get flAlterId => 'Alter id';

  @override
  String get flTlsServerName => 'اسم خادم TLS ‏(SNI)';

  @override
  String get flTlsFingerprint => 'بصمة TLS';

  @override
  String get flAlpn => 'ALPN';

  @override
  String get flSkipCertCheck => 'تخطي فحص الشهادة';

  @override
  String get flPinnedCert => 'الشهادة المثبّتة (PEM)';

  @override
  String get flRealityPublicKey => 'المفتاح العام لـ Reality';

  @override
  String get flRealityShortId => 'المعرّف القصير لـ Reality';

  @override
  String get flTransport => 'النقل';

  @override
  String get flHostHeader => 'ترويسة Host';

  @override
  String get flPath => 'المسار';

  @override
  String get flGrpcService => 'اسم خدمة gRPC';

  @override
  String get flPlugin => 'الإضافة';

  @override
  String get flPluginOptions => 'خيارات الإضافة';

  @override
  String get flObfuscation => 'التمويه';

  @override
  String get flObfsPassword => 'كلمة مرور التمويه';

  @override
  String get flUploadMbps => 'الرفع (ميغابت/ث)';

  @override
  String get flDownloadMbps => 'التنزيل (ميغابت/ث)';

  @override
  String get flCongestion => 'التحكم بالازدحام';

  @override
  String get flUdpRelay => 'وضع ترحيل UDP';

  @override
  String get flUseQuic => 'استخدام HTTP/3 ‏(QUIC)';

  @override
  String get flTunnelAddress => 'عنوانك في النفق';

  @override
  String get flRoutedNetworks => 'الشبكات الموجَّهة';

  @override
  String get flDnsServers => 'خوادم DNS';

  @override
  String get flMtu => 'MTU';

  @override
  String get flKeepalive => 'Keepalive (ثوانٍ)';

  @override
  String get flPrivateKey => 'المفتاح الخاص';

  @override
  String get flServerPublicKey => 'المفتاح العام للخادم';

  @override
  String get flPresharedKey => 'المفتاح المشترك مسبقًا';

  @override
  String get flReservedBytes => 'البايتات المحجوزة';

  @override
  String get flAuthDigest => 'ملخّص المصادقة';

  @override
  String get flCaCert => 'شهادة CA ‏(PEM)';

  @override
  String get flClientCert => 'شهادة العميل (PEM)';

  @override
  String get flClientKey => 'مفتاح العميل (PEM)';

  @override
  String get flControlWrap => 'حماية قناة التحكم';

  @override
  String get flControlWrapKey => 'مفتاح قناة التحكم';

  @override
  String get flKeyDirection => 'اتجاه المفتاح';

  @override
  String get flRemoteCertType => 'نوع شهادة الخادم';

  @override
  String get flVerifyServerName => 'التحقق من اسم الخادم';

  @override
  String get flHostKeys => 'مفاتيح المضيف';

  @override
  String get flPrivateKeyPem => 'المفتاح الخاص (PEM)';

  @override
  String get flKeyPassphrase => 'عبارة مرور المفتاح';

  @override
  String get flBridges => 'الجسور';

  @override
  String get flBridgeLines => 'أسطر الجسور';

  @override
  String get flJc => 'Jc (عدد الحزم العشوائية)';

  @override
  String get flSignaturePacket => 'I1 (حزمة التوقيع)';

  @override
  String get hpAuthorizedKeys => 'بصيغة authorized_keys؛ الفارغ يقبل أي مفتاح';

  @override
  String get hpDefaultsToServer => 'الافتراضي هو عنوان الخادم';

  @override
  String get hpTorBridges =>
      'الفارغ يتصل بـ Tor مباشرة، أو يستخدم أسطر الجسور أدناه';

  @override
  String get hpExampleAddress => 'مثلًا 10.8.0.2/32';

  @override
  String get hpExamplePlugin => 'مثلًا shadow-tls أو v2ray-plugin';

  @override
  String get hpHostOrIp => 'اسم المضيف أو عنوان IP';

  @override
  String get hpNeededReality => 'مطلوب عندما يكون الأمان reality';

  @override
  String get hpOnlySelfSigned =>
      'فقط للخوادم ذات الشهادة الموقّعة ذاتيًا التي لا يمكنك تثبيتها';

  @override
  String get hpHysteriaObfs =>
      'salamander لـ Hysteria 2؛ وكلمة مرور التمويه لـ Hysteria 1';

  @override
  String get hpTrustCert => 'الوثوق بهذه الشهادة بدلًا من جهات النظام';

  @override
  String get hpWhichBrowser => 'مصافحة TLS لأي متصفح تُحاكى';

  @override
  String get hpWarpReserved => 'ثلاثة أرقام كما تُدرج في إعدادات WARP';

  @override
  String get hpOneBridgePerLine =>
      'جسر واحد في كل سطر كما في torrc لكن بدون «Bridge »';

  @override
  String get exitTitle => 'إظهار عنوان الخروج والبلد';

  @override
  String get exitHint =>
      'يسأل Cloudflare (1.1.1.1) / api.country.is عن عنوانك وبلدك، حتى عند عدم الاتصال.';

  @override
  String exitIpLabel(String ip) {
    return 'IP‎ $ip';
  }

  @override
  String connectedTo(String place) {
    return 'متصل بـ $place';
  }

  @override
  String get noticesTitle => 'تراخيص المصدر المفتوح';

  @override
  String get noticesIntro =>
      'يُوزَّع Wardkeep بترخيص MIT. ويتضمن البرامج التالية، كلٌّ بترخيصه الخاص.';

  @override
  String noticesMore(int count) {
    return '+$count أخرى';
  }

  @override
  String noticesPackages(int count) {
    return '$count حزمة';
  }

  @override
  String get noticesLoadFailed => 'تعذّرت قراءة قائمة التراخيص.';

  @override
  String formRequired(String label) {
    return '$label مطلوب';
  }

  @override
  String formNotNumber(String label) {
    return 'يجب أن يكون $label عددًا صحيحًا';
  }

  @override
  String formNotBool(String label) {
    return 'يجب أن يكون $label مفعّلًا أو متوقفًا';
  }

  @override
  String formBadChoice(String label, String value, String choices) {
    return '$label: ‎$value‎ ليس من بين $choices';
  }

  @override
  String get formRealityOnlyVless => 'Reality‎ متاح فقط مع VLESS';

  @override
  String formUnknownSecurity(String value) {
    return 'حماية غير معروفة: ‎$value';
  }

  @override
  String get formReservedBytes =>
      'يجب أن تكون البايتات المحجوزة أعدادًا من 0 إلى 255';

  @override
  String get formRealityKeyRequired =>
      'المفتاح العام لـ Reality‎ مطلوب عندما تكون الحماية Reality';

  @override
  String get importUnsupported =>
      'هذا ليس رابط خادم أو اشتراكًا أو إعدادًا يستطيع Wardkeep‎ قراءته';

  @override
  String importUnsupportedScheme(String scheme) {
    return 'الروابط التي تبدأ بـ ‎$scheme://‎ غير مدعومة';
  }

  @override
  String get importXrayServer =>
      'هذا إعداد خادم Xray‎. استورده على الخادم (‎omnitun-server import xray‎) لا كملف تعريف عميل';

  @override
  String get subAuthFailed =>
      'رفض الاشتراك تسجيل الدخول. تحقق من اسم المستخدم أو كلمة المرور أو الرمز';

  @override
  String subHttp(String status) {
    return 'ردّ خادم الاشتراك بـ ‎HTTP $status';
  }

  @override
  String get subTooLarge => 'حجم الاشتراك أكبر من 10 ميغابايت';

  @override
  String get subBadUrl => 'هذا ليس عنوان اشتراك صالحًا';

  @override
  String get bypassIssueEmptyExpression => 'تعبير فارغ';

  @override
  String get bypassIssueBadExpression => 'تعبير غير صالح';

  @override
  String get bypassIssueBadName => 'اسم غير صالح';

  @override
  String get bypassIssueGeo =>
      'القوائم الجغرافية غير مدعومة؛ اذكر النطاقات أو المدى';

  @override
  String get bypassIssueBadEntry => 'ليس نطاقًا ولا عنوانًا ولا مدى';

  @override
  String bypassIssueTooMany(int limit) {
    return 'أكثر من $limit إدخالًا: يُتجاهل الباقي';
  }

  @override
  String get torStarting => 'جارٍ تشغيل ‎Tor';

  @override
  String torBootstrap(int percent) {
    return 'جارٍ الاتصال بـ ‎Tor‎ $percent%';
  }

  @override
  String get torCircuit => 'جارٍ إنشاء مسار ‎Tor';

  @override
  String torRetry(int attempt, int attempts) {
    return 'إعادة محاولة ‎Tor‎ ($attempt/$attempts)';
  }

  @override
  String get importNoServer => 'لم يُعثر على أي خادم صالح في هذا النص';

  @override
  String importJsonSyntax(String found, int line, int column) {
    return 'هذا ليس JSON صالحًا: حرف غير متوقع $found في السطر $line، العمود $column.';
  }

  @override
  String importJsonEnd(int line, int column) {
    return 'هذا ليس JSON صالحًا: ينتهي النص مبكرًا جدًا عند السطر $line، العمود $column. ربما ينقص قوس إغلاق أو أقواس معقوفة أو علامة اقتباس.';
  }

  @override
  String get importJsonNoServer =>
      'ملف JSON هذا صالح، لكنه لا يحتوي على أي خادم وكيل. استخدم إعداد عميل يتضمن مخرجًا من نوع VLESS أو VMess أو Trojan أو Shadowsocks أو ما شابه.';

  @override
  String importJsonNoServerFound(String found) {
    return 'ملف JSON هذا صالح، لكنه لا يحتوي على أي خادم وكيل (يحتوي على $found). استخدم إعداد عميل يتضمن مخرجًا من نوع VLESS أو VMess أو Trojan أو Shadowsocks أو ما شابه.';
  }

  @override
  String importTooLarge(int limit) {
    return 'هذا كبير جدًا للاستيراد (الحد الأقصى $limit ميغابايت).';
  }

  @override
  String get importFileEmpty => 'الملف فارغ.';

  @override
  String get importFileNotText =>
      'الملف ليس نصًا يستطيع Wardkeep قراءته (يبدو ثنائيًا أو بترميز غير معروف). استخدم ملفًا نصيًا بترميز UTF-8 أو UTF-16.';

  @override
  String get importFileNoPermission =>
      'لا يملك Wardkeep إذنًا لقراءة هذا الملف.';

  @override
  String get importFileMissing => 'لم يتم العثور على الملف. ربما نُقل أو حُذف.';

  @override
  String get importDetails => 'التفاصيل';

  @override
  String get importJsonNote =>
      'يمكن أيضًا استخدام إعداد JSON (Xray أو sing-box أو SIP008) أو قائمة منها، نصًا أو ملفًا.';

  @override
  String get ipdbTitle => 'قاعدة بيانات الدول (دون اتصال)';

  @override
  String get ipdbIntro =>
      'نزّل قاعدة البيانات مرة واحدة، وسيعرف Wardkeep بلد الخادم أو العنوان بنفسه دون سؤال أي موقع.';

  @override
  String ipdbSizeNote(String size) {
    return 'نحو $size · بيانات مجانية (ملكية عامة)';
  }

  @override
  String get ipdbDownload => 'تنزيل';

  @override
  String get ipdbContinue => 'متابعة';

  @override
  String get ipdbPause => 'إيقاف مؤقت';

  @override
  String get ipdbUpdate => 'تحديث';

  @override
  String get ipdbDelete => 'حذف';

  @override
  String get ipdbDeleteTitle => 'حذف قاعدة البيانات؟';

  @override
  String get ipdbUse => 'استخدام قاعدة البيانات';

  @override
  String get ipdbStepV4 => 'IPv4';

  @override
  String get ipdbStepV6 => 'IPv6';

  @override
  String get ipdbStepPrepare => 'تجهيز';

  @override
  String get ipdbPreparing => 'جارٍ التجهيز…';

  @override
  String get ipdbReady => 'جاهزة';

  @override
  String ipdbStoppedAt(int percent) {
    return 'توقف عند $percent%. «متابعة» تكمل من النقطة نفسها.';
  }

  @override
  String ipdbFailed(String reason) {
    return 'فشل التنزيل: $reason';
  }

  @override
  String ipdbReadyLine(String ranges, String size) {
    return '$ranges نطاق · $size';
  }

  @override
  String ipdbVersion(String version, String date) {
    return 'الإصدار $version · $date';
  }

  @override
  String ipdbLeft(String time) {
    return 'المتبقي $time';
  }

  @override
  String get ipdbSource =>
      'البيانات: سجلات الإنترنت الإقليمية وإعلانات ASN (CC0)، من مشروع ip-location-db.';

  @override
  String get ipdbSubNone => 'معرفة البلد دون سؤال أي موقع';

  @override
  String ipdbSubReady(String size) {
    return 'مفعّلة · $size';
  }

  @override
  String ipdbSubOff(String size) {
    return 'متوقفة · $size';
  }

  @override
  String ipdbSubDownloading(int percent) {
    return 'جارٍ التنزيل $percent%';
  }

  @override
  String ipdbSubStopped(int percent) {
    return 'توقف عند $percent%';
  }

  @override
  String get ipdbErrNetwork => 'تعذّر الاتصال بخوادم البيانات';

  @override
  String get ipdbErrMirrors => 'لم ترسل خوادم البيانات الملف الصحيح';

  @override
  String get bypassCountriesTitle => 'الدول';

  @override
  String get bypassCountriesNone => 'لم تُختر أي دولة';

  @override
  String bypassCountriesMore(String names, int count) {
    return '$names +$count';
  }

  @override
  String get bypassCountriesIntro =>
      'تذهب الحركة إلى الدول المختارة مباشرة إلى الإنترنت دون المرور عبر VPN. تأتي نطاقات عناوينها من قاعدة بيانات الدول دون اتصال.';

  @override
  String get bypassCountriesGetDb => 'الحصول على قاعدة بيانات الدول';

  @override
  String get bypassCountriesSearch => 'ابحث عن الدول';

  @override
  String get windowMinimize => 'تصغير';

  @override
  String get windowMaximize => 'تكبير';

  @override
  String get windowRestore => 'استعادة';

  @override
  String get windowClose => 'إغلاق';

  @override
  String get windowFullScreen => 'ملء الشاشة';

  @override
  String get windowExitFullScreen => 'الخروج من ملء الشاشة';

  @override
  String get globeRecenter => 'إرجاع الأرض';

  @override
  String get bypassCountriesZoneIntro =>
      'ينزّل كل بلد تختاره نطاقات عناوينه (بضعة كيلوبايت). قاعدة البيانات الكاملة دون اتصال أدق ولا تحتاج إلى تنزيل.';

  @override
  String get bypassCountriesDownloading => 'جارٍ التنزيل…';

  @override
  String get bypassCountriesFailed => 'تعذّر التنزيل. اضغط للمحاولة مجددًا.';

  @override
  String get bypassCountriesYourServer =>
      'الخادم الذي اخترته هنا: ستتجاوز حركته VPN أيضًا.';

  @override
  String get ipv6Title => 'IPv6';

  @override
  String get ipv6Hint =>
      'متوقف: يُستخدم IPv4 فقط؛ تُرفض اتصالات IPv6 ولا تُرسل خارج VPN.';

  @override
  String get mtuTitle => 'MTU';

  @override
  String get mtuAuto => 'الافتراضي';

  @override
  String get mtuHelp =>
      'حجم الحزمة في النفق (وضع VPN فقط). جرّب من 1280 إلى 1420 إذا تعلّقت بعض المواقع على شبكة الجوال. الفراغ يعني الافتراضي.';

  @override
  String mtuInvalid(int min, int max) {
    return 'أدخل رقمًا من $min إلى $max.';
  }

  @override
  String get trayOpen => 'فتح Wardkeep';

  @override
  String get trayQuit => 'إنهاء';

  @override
  String get traySwitchServer => 'تبديل الخادم';

  @override
  String get keepInTray => 'المتابعة في منطقة الإشعارات';

  @override
  String get keepInTrayHint =>
      'إغلاق النافذة يخفيها فقط. استخدم «إنهاء» من قائمة الأيقونة لإيقاف التطبيق وVPN.';

  @override
  String usageUsed(String size) {
    return 'المستخدم $size';
  }

  @override
  String get menuResetUsage => 'تصفير استهلاك البيانات';

  @override
  String get dnsPickerHelp =>
      'تُحَلّ أسماء المواقع عبر الـ VPN بواسطة المحلِّل الذي تختاره. كما يُثبت DNSCrypt أن الرد جاء من هذا المحلِّل نفسه.';

  @override
  String get dnsDefault => 'الافتراضي';

  @override
  String get dnsSectionDnscrypt => 'DNSCrypt · DNSSEC، بلا سجلات، بلا تصفية';

  @override
  String get dnsCustom => 'مخصص';

  @override
  String get dnsCustomLabel => 'عنوان أو DNS stamp';

  @override
  String get dnsAnonymized => 'DNSCrypt المجهول';

  @override
  String get dnsAnonymizedHint =>
      'تمر الاستعلامات عبر مرحِّل، فلا يرى المحلِّل مصدرها أبدًا';

  @override
  String get dnsAnonymizedNeedsDnscrypt =>
      'اختر محلِّل DNSCrypt لاستخدام هذا الخيار';

  @override
  String get dnsRelay => 'المرحِّل';

  @override
  String get dnsRelayChoose => 'اختر مرحِّلًا';

  @override
  String get dnsRelayAutomatic => 'تلقائي (مشغِّل آخر)';

  @override
  String get dnsErrAddress =>
      'استخدم عنوانًا يبدأ بـ https:// أو tls:// أو tcp:// أو udp://، أو stamp من نوع sdns://';

  @override
  String get dnsErrDamaged => 'هذا الـ stamp تالف أو مقطوع. انسخه مرة أخرى.';

  @override
  String get dnsErrUnsupported => 'هذا النوع من الـ stamp غير مدعوم';

  @override
  String get dnsErrRelayStamp => 'هذا stamp مرحِّل وليس محلِّلًا';

  @override
  String dnsLine(String resolver) {
    return 'DNS: $resolver';
  }

  @override
  String get dnsLimits =>
      'يحمي هذا الأسماء التي تبحث عنها، لكنه لا يُخفي المواقع التي تتصل بها بعد ذلك.';

  @override
  String get dnsAnonymizedShort => 'مجهول';

  @override
  String get flAuthKey => 'مفتاح المصادقة';

  @override
  String get flControlServer => 'خادم التحكم';

  @override
  String get flDeviceName => 'اسم الجهاز';

  @override
  String get flExitDevice => 'جهاز الخروج';

  @override
  String get flUseSubnets => 'استخدام الشبكات الفرعية للأجهزة الأخرى';

  @override
  String get flTempDevice => 'جهاز مؤقت';

  @override
  String get hpAuthKey =>
      'مفتاح مصرّح به مسبقًا من صفحة إدارة Tailscale، أو أنشأه الأمر headscale preauthkeys create';

  @override
  String get hpControlServer =>
      'الفارغ يعني Tailscale؛ وفي Headscale أدخل عنوانه مثل https://hs.example.com';

  @override
  String get hpDeviceName =>
      'الاسم الذي يحمله هذا الجهاز في الشبكة؛ الفارغ يستخدم اسم الجهاز نفسه';

  @override
  String get hpExitDevice =>
      'اسم أو عنوان الجهاز الذي سيُستخدم اتصاله بالإنترنت؛ الفارغ يصل إلى أجهزتك فقط';

  @override
  String get hpTempDevice => 'تتم إزالته من الشبكة عند انقطاعه';

  @override
  String get devicesTitle => 'أجهزتي';

  @override
  String get devicesNotConnected =>
      'اتصل بملف Tailscale أو Headscale لرؤية أجهزتك.';

  @override
  String get devicesJoining => 'جارٍ الانضمام إلى الشبكة…';

  @override
  String get devicesLoginNeeded =>
      'لم تقبل الشبكة مفتاح هذا الجهاز. أنشئ مفتاحًا جديدًا وعدّل الملف.';

  @override
  String get devicesEmpty => 'لا توجد أجهزة أخرى في هذه الشبكة بعد.';

  @override
  String get devicesThisDevice => 'هذا الجهاز';

  @override
  String get deviceOnline => 'متصل';

  @override
  String get deviceOffline => 'غير متصل';

  @override
  String deviceLastSeen(String when) {
    return 'آخر ظهور $when';
  }

  @override
  String get deviceUseAsExit => 'استخدام كمخرج';

  @override
  String get deviceStopExit => 'إيقاف الاستخدام كمخرج';

  @override
  String get deviceIsExit => 'مخرج قيد الاستخدام';

  @override
  String get devicesExitHint =>
      'استخدم أحد أجهزتك كمخرج: تخرج كل حركة بياناتك من اتصاله.';

  @override
  String get deviceCopyName => 'نسخ الاسم';

  @override
  String get deviceCopyAddress => 'نسخ العنوان';

  @override
  String get deviceCopied => 'تم النسخ';

  @override
  String get errMeshExit =>
      'لا يمكن استخدام هذا الجهاز كمخرج الآن. يجب أن يكون متصلًا ويتيح اتصاله.';

  @override
  String get wnTlsInsecure =>
      'لا يتم فحص شهادة الخادم. يمكن لأي شخص على المسار قراءة حركة بياناتك أو تغييرها.';

  @override
  String get wnNoTls =>
      'حركة البيانات غير مغلّفة بـ TLS. يسهل التعرف عليها وقد تُقرأ في الطريق.';

  @override
  String get wnVmessLegacy =>
      'VMess بروتوكول قديم ويسهل التعرف عليه. VLESS مع Reality خيار أفضل.';

  @override
  String get wnSsPlain =>
      'من دون إضافة مثل shadow-tls تبدو حركة البيانات كبايتات عشوائية، وبعض الشبكات تحظر هذا النمط.';

  @override
  String get wnHysteria1 =>
      'Hysteria 1 متقادم. استخدم Hysteria 2 إذا كان الخادم يدعمه.';

  @override
  String get wnDpiVisible =>
      'يسهل التعرف على هذا البروتوكول وغالبًا ما يُحظر في الشبكات المتشددة.';

  @override
  String get wnSshVisible => 'يسهل التعرف على أنفاق SSH.';

  @override
  String get wnDnsttSlow =>
      'بطيء (عادةً أقل بكثير من 1 ميغابت/ث) ويعمل عبر TCP فقط. يرسل استعلامات DNS كثيرة يمكن للشبكة رؤيتها. استخدمه عندما لا ينجح غيره.';

  @override
  String get wnDnsttOpen =>
      'بلا اسم مستخدم أو كلمة مرور: يمكن لأي شخص يملك هذا الرابط استخدام الخادم.';

  @override
  String get wnMuxLossy =>
      'تعدد الإرسال يجمع اتصالات كثيرة في اتصال واحد. قد يبطئ الخط السيئ جميعها.';

  @override
  String get wnFragmentSide =>
      'تجزئة المصافحة تفيد ضد بعض المرشحات، وقد تتعطل على غيرها، وتضيف تأخيرًا.';

  @override
  String get wnEchServer => 'يحتاج إلى خادم يدعم ECH، وإلا فشل الاتصال.';

  @override
  String get wnWgChain =>
      'WireGuard داخل وكيل: إذا كان الوكيل بطيئًا فقد يتعثر النفق. يجب أن ينقل الوكيل UDP.';

  @override
  String get wnSubUnsigned =>
      'هذه القائمة غير موقّعة، لذا لا يمكن اكتشاف تغييرها.';

  @override
  String get choiceOff => 'إيقاف';

  @override
  String get flMultiplexing => 'تعدد الإرسال';

  @override
  String get flMuxPadding => 'حشو تعدد الإرسال';

  @override
  String get flMuxMaxConnections => 'أقصى عدد اتصالات';

  @override
  String get flMuxMinStreams => 'أقل عدد تدفقات لكل اتصال';

  @override
  String get flMuxMaxStreams => 'أكثر عدد تدفقات لكل اتصال';

  @override
  String get hpMultiplexing =>
      'اتصالات كثيرة عبر اتصال واحد؛ يجب أن يسمح الخادم بذلك. لا يعمل مع flow في VLESS';

  @override
  String get hpMuxMaxStreams => 'بدلًا من الخيارين أعلاه';

  @override
  String get flTlsFragment => 'تجزئة مصافحة TLS';

  @override
  String get flTlsRecordFragment => 'تجزئة سجلات TLS';

  @override
  String get flEch => 'Client Hello المشفّر (ECH)';

  @override
  String get flEchConfig => 'إعداد ECH (PEM)';

  @override
  String get flEchQueryName => 'اسم البحث عن ECH';

  @override
  String get hpTlsFragment =>
      'يقسم الحزمة الأولى حتى لا يستطيع المرشح قراءة اسم الخادم';

  @override
  String get hpTlsRecordFragment => 'يقسم السجلات بدل الحزم';

  @override
  String get hpEch => 'يخفي اسم الخادم؛ يحتاج إلى خادم يدعمه';

  @override
  String get hpEchConfig => 'إذا ترك فارغًا يُبحث عنه في DNS';

  @override
  String get hpEchQueryName => 'الافتراضي هو اسم الخادم';

  @override
  String get flWgVia => 'عبر وكيل (رابط المشاركة)';

  @override
  String get hpWgVia =>
      'ينقل WireGuard داخل هذا الوكيل للشبكات التي تحجب UDP. يجب أن ينقل الوكيل UDP';

  @override
  String get subSigned => 'موقّع';

  @override
  String get subKeyLabel => 'مفتاح التوقيع (اختياري)';

  @override
  String get subKeyHelp =>
      'المفتاح العام للمزوّد. يُرفض أي رد بلا توقيع صالح بهذا المفتاح';

  @override
  String get subBackupLabel => 'عناوين احتياطية (اختياري)';

  @override
  String get subBackupHelp =>
      'واحد في كل سطر. تُجرَّب بالترتيب إذا تعذّر الوصول إلى الأول';

  @override
  String get subErrKey => 'مفتاح التوقيع ليس مفتاحًا عامًا صالحًا';

  @override
  String get subUnsigned =>
      'الاشتراك غير موقّع بينما مفتاح التوقيع مُعيَّن، لذا رُفض';

  @override
  String get subBadSignature =>
      'توقيع الاشتراك خاطئ: ربما تغيّر في الطريق أو أن المفتاح قديم';

  @override
  String get subStale =>
      'هذا الرد أقدم من آخر رد مقبول، لذا رُفض. إذا استعاد المزوّد نسخة احتياطية قديمة فعدّل الاشتراك واحفظه من جديد.';

  @override
  String get flTunnelDomain => 'نطاق النفق';

  @override
  String get flServerKey => 'مفتاح الخادم';

  @override
  String get flResolvers => 'محللات DNS';

  @override
  String get hpTunnelDomain =>
      'المنطقة التي فوّضتها إلى خادم النفق، مثل t.example.com';

  @override
  String get hpServerKey => '64 رقمًا سداسي عشري؛ يطبعه الخادم';

  @override
  String get hpResolvers =>
      'تُجرَّب بالترتيب: udp://IP:port أو tls://host:port أو https://host/path';

  @override
  String get hpTunnelLogin =>
      'بيانات دخول SOCKS5 لدى الخادم؛ اتركها فارغة إن لم يكن هناك';

  @override
  String get scanFind => 'ابحث عن المحللات العاملة';

  @override
  String get scanBusy => 'جارٍ تجربة المحللات…';

  @override
  String scanFound(int count) {
    return 'المحللات العاملة التي وُجدت: $count';
  }

  @override
  String get scanNone =>
      'لم ينجح أي محلل. تحقّق من النطاق والمفتاح ومن أن الخادم يعمل.';

  @override
  String get scanConnected =>
      'افصل الاتصال أولًا: يجب أن يستخدم الفحص الشبكة مباشرةً لا عبر VPN.';

  @override
  String get scanNeedsFields => 'املأ نطاق النفق ومفتاح الخادم أولًا.';

  @override
  String get settingsLogging => 'السجلات والأخطاء';

  @override
  String get debugLogging => 'سجل التصحيح';

  @override
  String get debugLoggingOff => 'متوقف';

  @override
  String debugLoggingUntil(String level, String time) {
    return '$level حتى $time';
  }

  @override
  String debugLoggingCore(String level, String mode) {
    return 'مستوى سجل النواة: $level (إصدار $mode)';
  }

  @override
  String get debugLoggingWarning =>
      'سجل التصحيح يبطئ الاتصالات ويستهلك بطارية أكثر ويحتفظ بتفاصيل أكثر في السجل. يتوقف تلقائيًا بعد 24 ساعة.';

  @override
  String get logLevelInfo => 'معلومات';

  @override
  String get logLevelDebug => 'تصحيح';

  @override
  String get logLevelTrace => 'تتبع (كل شيء)';

  @override
  String get notifyPopup => 'أخبرني بالأخطاء';

  @override
  String get notifyPopupHint =>
      'تنبيه أحمر في التطبيق عندما يفشل شيء لم يستطع التطبيق إصلاحه';

  @override
  String get notifyOs => 'إشعارات النظام للأخطاء';

  @override
  String get notifyOsHint =>
      'إشعار من النظام، حتى عندما يكون التطبيق في الخلفية';

  @override
  String get logsView => 'عرض السجلات';

  @override
  String get logsExport => 'حفظ بتنسيق JSON Lines';

  @override
  String get logsSaved => 'تم حفظ السجل';

  @override
  String get logsLevel => 'المستوى';

  @override
  String get logsLevelAll => 'كل المستويات';

  @override
  String logsConnection(String conn) {
    return 'الاتصال $conn';
  }

  @override
  String get logsNoMatch => 'لا توجد سجلات تطابق عامل التصفية.';

  @override
  String get errTorExited =>
      'توقف Tor بشكل غير متوقع. اتصل مرة أخرى؛ وإذا تكرر ذلك فراجع السجلات.';

  @override
  String get errDnsttExited =>
      'توقف نفق DNS بشكل غير متوقع. اتصل مرة أخرى؛ وإذا تكرر ذلك فراجع السجلات.';

  @override
  String get errEngineFatal =>
      'توقف محرك الاتصال بسبب خطأ. اتصل مرة أخرى؛ وإذا تكرر ذلك فراجع السجلات.';

  @override
  String get errPanic =>
      'حدث خطأ داخل Wardkeep وتم إيقاف الاتصال. التفاصيل في السجلات.';

  @override
  String get errTorStreamFailed =>
      'لم يتمكن Tor من فتح اتصال بهذا الموقع عبر شبكة Tor.';
}
