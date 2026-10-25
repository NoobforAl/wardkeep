// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'Wardkeep';

  @override
  String get actionSave => 'सहेजें';

  @override
  String get actionCancel => 'रद्द करें';

  @override
  String get actionDelete => 'हटाएँ';

  @override
  String get actionEdit => 'संपादित करें';

  @override
  String get actionReset => 'रीसेट करें';

  @override
  String get actionSkip => 'छोड़ें';

  @override
  String get actionNext => 'आगे';

  @override
  String get actionImport => 'इम्पोर्ट करें';

  @override
  String get actionDownload => 'डाउनलोड करें';

  @override
  String get actionCopyAll => 'सब कॉपी करें';

  @override
  String get actionClear => 'साफ़ करें';

  @override
  String get tooltipMore => 'और';

  @override
  String get tooltipShow => 'दिखाएँ';

  @override
  String get tooltipHide => 'छिपाएँ';

  @override
  String get searchHint => 'खोजें';

  @override
  String get tooltipLogs => 'लॉग';

  @override
  String get tooltipSettings => 'सेटिंग्स';

  @override
  String get statusConnected => 'कनेक्टेड';

  @override
  String get statusConnecting => 'कनेक्ट हो रहा है…';

  @override
  String get statusDisconnecting => 'डिस्कनेक्ट हो रहा है…';

  @override
  String get statusError => 'कनेक्शन विफल रहा';

  @override
  String get statusNoInternet => 'इंटरनेट कनेक्शन नहीं है';

  @override
  String get statusDisconnected => 'कनेक्ट नहीं है';

  @override
  String get stagePermission => 'VPN अनुमति की प्रतीक्षा';

  @override
  String get stageNetworkCheck => 'इंटरनेट कनेक्शन जाँचा जा रहा है';

  @override
  String get stagePrepare => 'कॉन्फ़िगरेशन तैयार हो रहा है';

  @override
  String get stageEngineStart => 'इंजन शुरू हो रहा है';

  @override
  String get stageTunnelUp => 'टनल खुल रही है';

  @override
  String get stageHandshake => 'सर्वर से संपर्क हो रहा है';

  @override
  String get stageConnected => 'कनेक्टेड';

  @override
  String get buttonConnect => 'कनेक्ट करें';

  @override
  String get buttonDisconnect => 'डिस्कनेक्ट करें';

  @override
  String get buttonCancel => 'रद्द करें';

  @override
  String get locationLabel => 'स्थान';

  @override
  String get noServers => 'कोई सर्वर नहीं';

  @override
  String get noServersHint => 'शुरू करने के लिए एक जोड़ें';

  @override
  String get automatic => 'स्वचालित';

  @override
  String get automaticHint => 'सबसे तेज़ सर्वर, विफल होने पर बदलता है';

  @override
  String get anyServerInCountry => 'इस देश का कोई भी सर्वर';

  @override
  String get torNetwork => 'Tor नेटवर्क';

  @override
  String get torHopBridge => 'ब्रिज';

  @override
  String get torHopEntry => 'एंट्री';

  @override
  String get torHopRelay => 'रिले';

  @override
  String get torHopExit => 'एग्ज़िट';

  @override
  String get torHopHidden => 'छिपा';

  @override
  String get torHopUnknown => 'अज्ञात';

  @override
  String get hopYou => 'आप';

  @override
  String get hopYouNote =>
      'यहीं आप असल में हैं। आपका ट्रैफ़िक यहीं से शुरू होता है।';

  @override
  String get hopServer => 'सर्वर';

  @override
  String get hopServerNote =>
      'आपका ट्रैफ़िक एन्क्रिप्टेड होकर इस सर्वर तक जाता है और यहीं से निकलता है, इसलिए वेबसाइटें आपका नहीं, इसका पता देखती हैं।';

  @override
  String get hopBridgeNote =>
      'आपका पहला पड़ाव। ब्रिज आपके नेटवर्क से छिपाता है कि आप Tor इस्तेमाल कर रहे हैं। यह जानता है कि आप कौन हैं, पर यह नहीं कि आप कहाँ जा रहे हैं।';

  @override
  String get hopEntryNote =>
      'पहला रिले। यह आपका पता जानता है, पर यह नहीं कि आप क्या देखते हैं।';

  @override
  String get hopRelayNote =>
      'बीच का रिले। यह न जानता है कि आप कौन हैं, न यह कि आप क्या देखते हैं; बस ट्रैफ़िक आगे बढ़ाता है।';

  @override
  String get hopExitNote =>
      'आख़िरी रिले। यह देखता है कि आप कहाँ जा रहे हैं, पर यह नहीं कि आप कौन हैं, और वेबसाइटें इसका पता देखती हैं।';

  @override
  String get hopHiddenNote =>
      'ब्रिज की जगह उसके ट्रांसपोर्ट ने छिपा रखी है, इसलिए उसे नक़्शे पर नहीं दिखाया जा सकता।';

  @override
  String get hopTransport => 'ट्रांसपोर्ट';

  @override
  String get hopProtocol => 'प्रोटोकॉल';

  @override
  String get hopAddress => 'पता';

  @override
  String get hopLatency => 'लेटेंसी';

  @override
  String get hopExitAddress => 'एग्ज़िट का पता';

  @override
  String get menuNewGroup => 'नया समूह';

  @override
  String get groupNameHint => 'समूह का नाम';

  @override
  String get groupCreate => 'बनाएँ';

  @override
  String get menuMoveToGroup => 'समूह में ले जाएँ';

  @override
  String get groupMoveTitle => 'यहाँ ले जाएँ';

  @override
  String get menuRenameGroup => 'नाम बदलें';

  @override
  String get menuDeleteGroup => 'समूह हटाएँ';

  @override
  String get groupDeleteTitle => 'यह समूह हटाएँ?';

  @override
  String groupDeleteBody(String name) {
    return 'इसके सर्वर नहीं हटेंगे। वे $name में लौट जाएँगे।';
  }

  @override
  String get groupEmptyHint =>
      'अभी कोई सर्वर नहीं है। किसी सर्वर का मेनू खोलें और «समूह में ले जाएँ» चुनें।';

  @override
  String get menuShareGroupFile => 'टेक्स्ट फ़ाइल के रूप में सहेजें';

  @override
  String get menuCopyGroupLinks => 'लिंक कॉपी करें';

  @override
  String groupSavedToast(String servers) {
    return 'सहेजा गया: $servers';
  }

  @override
  String groupCopiedToast(String servers) {
    return 'कॉपी किया गया: $servers';
  }

  @override
  String get groupNothingToShare => 'इनमें से किसी सर्वर का शेयर लिंक नहीं है।';

  @override
  String groupSkipped(String servers) {
    return 'छोड़े गए, शेयर लिंक नहीं: $servers';
  }

  @override
  String get emptyTitle => 'अभी कोई प्रोफ़ाइल नहीं';

  @override
  String get emptyHint => 'कॉन्फ़िग, लिंक या सब्सक्रिप्शन इम्पोर्ट करें।';

  @override
  String get importConfig => 'कॉन्फ़िग इम्पोर्ट करें';

  @override
  String failoverToast(String to, String from) {
    return '$to पर स्विच किया गया — $from ने जवाब देना बंद कर दिया';
  }

  @override
  String get unknownLocation => 'अज्ञात स्थान';

  @override
  String errorFailed(String stage, String reason) {
    return '$stage विफल: $reason';
  }

  @override
  String get errTimeout => 'सर्वर ने समय पर जवाब नहीं दिया';

  @override
  String get errRefused => 'सर्वर ने कनेक्शन अस्वीकार कर दिया';

  @override
  String get errReset => 'नेटवर्क ने कनेक्शन रीसेट कर दिया';

  @override
  String get errNoRoute => 'इस नेटवर्क से सर्वर तक पहुँचा नहीं जा सकता';

  @override
  String get errNetworkUnreachable => 'नेटवर्क उपलब्ध नहीं है';

  @override
  String get errDns => 'सर्वर का नाम हल नहीं हो सका';

  @override
  String get errTls => 'सर्वर का सुरक्षा प्रमाणपत्र अस्वीकार कर दिया गया';

  @override
  String get errAuth => 'यूज़रनेम या पासवर्ड अस्वीकार कर दिया गया';

  @override
  String get errClosed => 'सर्वर ने कनेक्शन बंद कर दिया';

  @override
  String get errCertDate =>
      'सर्वर का प्रमाणपत्र समाप्त हो चुका है या अभी मान्य नहीं हुआ है (इस फ़ोन की तारीख़ और समय भी जाँचें)';

  @override
  String get errCertUntrusted =>
      'सर्वर का प्रमाणपत्र किसी भरोसेमंद अथॉरिटी द्वारा हस्ताक्षरित नहीं है';

  @override
  String get errCertName =>
      'सर्वर का प्रमाणपत्र उस नाम के लिए नहीं है जिससे आप कनेक्ट कर रहे हैं';

  @override
  String get errTlsKeys =>
      'साझा कुंजी (tls-auth या tls-crypt) सर्वर की कुंजी से मेल नहीं खाती';

  @override
  String get errReality =>
      'सर्वर ने Reality हैंडशेक अस्वीकार कर दिया (पब्लिक की, शॉर्ट ID और सर्वर नाम जाँचें)';

  @override
  String get errNoHandshake =>
      'सर्वर ने हैंडशेक का जवाब नहीं दिया (कुंजियाँ, एंडपॉइंट जाँचें और देखें कि उसका UDP पोर्ट खुला है)';

  @override
  String get errUdpBlocked =>
      'सर्वर ने UDP पर जवाब नहीं दिया; यह नेटवर्क उसे रोक सकता है, TCP आधारित सर्वर आज़माएँ';

  @override
  String get errPortInUse =>
      'लोकल पोर्ट पहले से किसी दूसरे ऐप में उपयोग हो रहा है';

  @override
  String get errTorTimeout =>
      'Tor समय पर कनेक्ट नहीं हो सका। यह नेटवर्क Tor को रोक सकता है; ब्रिज (Snowflake या obfs4) उपयोग करें';

  @override
  String get errTorBridgeTimeout =>
      'Tor समय पर कनेक्ट नहीं हो सका। ब्रिज बंद या अत्यधिक व्यस्त हो सकता है; दूसरे प्रकार का ब्रिज (Snowflake या obfs4) आज़माएँ';

  @override
  String get errTorBadBridge =>
      'Tor ब्रिज लाइन मान्य नहीं है (इसमें ट्रांसपोर्ट, पता और फ़िंगरप्रिंट चाहिए)';

  @override
  String get errTorMissing => 'इस बिल्ड में Tor क्लाइंट शामिल नहीं है';

  @override
  String get errPermission => 'VPN की अनुमति नहीं दी गई';

  @override
  String get errCoreLost => 'कोर सेवा से कनेक्शन टूट गया';

  @override
  String get selectLocation => 'स्थान चुनें';

  @override
  String get testSpeedTooltip => 'सभी सर्वरों की गति जाँचें';

  @override
  String get addServersTooltip => 'सर्वर जोड़ें';

  @override
  String get menuImport => 'कॉन्फ़िग, लिंक या QR इम्पोर्ट करें';

  @override
  String get menuNewServer => 'हाथ से सर्वर जोड़ें';

  @override
  String get menuSubscription => 'सब्सक्रिप्शन जोड़ें';

  @override
  String get menuManage => 'सर्वर और सब्सक्रिप्शन प्रबंधित करें';

  @override
  String get menuSetDefault => 'डिफ़ॉल्ट बनाएँ';

  @override
  String get badgeDefault => 'डिफ़ॉल्ट';

  @override
  String get menuDeleteAll => 'सभी सर्वर हटाएँ';

  @override
  String get deleteAllTitle => 'सभी सर्वर हटाएँ?';

  @override
  String get deleteAllBody =>
      'आपके जोड़े हुए सभी सर्वर और सब्सक्रिप्शन हटा दिए जाएँगे। बिल्ट-इन Tor कनेक्शन बना रहेगा और ऐप उसी पर लौट आएगा।';

  @override
  String get menuRestoreTor => 'Tor डिफ़ॉल्ट बहाल करें';

  @override
  String get deletedAllToast => 'सभी सर्वर हटा दिए गए';

  @override
  String defaultSetToast(String name) {
    return '$name अब डिफ़ॉल्ट है';
  }

  @override
  String serversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सर्वर',
      one: '$count सर्वर',
    );
    return '$_temp0';
  }

  @override
  String get otherGroup => 'अन्य';

  @override
  String get torGroup => 'Tor';

  @override
  String get noServersYet => 'अभी कोई सर्वर नहीं';

  @override
  String get importHintShort =>
      'कॉन्फ़िग फ़ाइल, लिंक या सब्सक्रिप्शन इम्पोर्ट करें।';

  @override
  String get showServers => 'सर्वर दिखाएँ';

  @override
  String get hideServers => 'सर्वर छिपाएँ';

  @override
  String get menuEditServer => 'संपादित करें';

  @override
  String get menuBridgeSettings => 'ब्रिज सेटिंग्स';

  @override
  String get menuShare => 'लिंक या QR साझा करें';

  @override
  String get menuSetCountry => 'देश चुनें';

  @override
  String get menuCredentials => 'यूज़रनेम और पासवर्ड';

  @override
  String needsSignIn(String address) {
    return '$address — साइन-इन ज़रूरी है';
  }

  @override
  String get countryOfServer => 'इस सर्वर का देश';

  @override
  String get guessFromName => 'नाम से पता लगाएँ';

  @override
  String get latencyNotTested => 'जाँचा नहीं गया';

  @override
  String get latencyUnreachable => 'पहुँच से बाहर';

  @override
  String get latencyTimeout => 'टाइमआउट';

  @override
  String latencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String get unknownCountry => 'अज्ञात देश';

  @override
  String get addServerTitle => 'सर्वर जोड़ें';

  @override
  String get addServerIntro =>
      'प्रोटोकॉल चुनें। लिंक या QR तेज़ है: इम्पोर्ट का उपयोग करें।';

  @override
  String newServerTitle(String label) {
    return 'नया $label सर्वर';
  }

  @override
  String get editServerTitle => 'सर्वर संपादित करें';

  @override
  String get torBridgesTitle => 'Tor ब्रिज';

  @override
  String get subscriptionEditNote =>
      'यह सर्वर एक सब्सक्रिप्शन से आता है: रिफ़्रेश होने पर आपके बदलाव बदल दिए जाएँगे।';

  @override
  String get moreOptions => 'और विकल्प';

  @override
  String get countryRow => 'देश';

  @override
  String get countryAuto => 'नाम और पते से पता लगाया गया';

  @override
  String get alreadyInList => 'यह सर्वर पहले से सूची में है';

  @override
  String get choiceDefault => 'डिफ़ॉल्ट';

  @override
  String get torBridgesNone => 'कोई नहीं (सीधा, या नीचे दी गई लाइनें)';

  @override
  String get torBridgesSnowflake => 'Snowflake';

  @override
  String get torBridgesObfs4 => 'obfs4 (बिल्ट-इन ब्रिज)';

  @override
  String get listHelper => 'मानों को अल्पविराम से अलग करें';

  @override
  String get fillPaste => 'पेस्ट करें';

  @override
  String get fillFile => 'फ़ाइल';

  @override
  String get fillScanQr => 'QR स्कैन करें';

  @override
  String get openTextFile => 'टेक्स्ट फ़ाइल खोलें';

  @override
  String couldNotReadFile(String error) {
    return 'फ़ाइल पढ़ी नहीं जा सकी: $error';
  }

  @override
  String fieldRequired(String label) {
    return '$label *';
  }

  @override
  String formNoEditor(String protocol) {
    return '$protocol के लिए कोई एडिटर नहीं';
  }

  @override
  String get shareScanHint => 'Wardkeep से स्कैन करें, या लिंक कॉपी करें।';

  @override
  String get shareCopy => 'लिंक कॉपी करें';

  @override
  String get shareCopied => 'लिंक कॉपी हो गया';

  @override
  String get shareWarning =>
      'इसमें सर्वर का पासवर्ड या कुंजी है। सावधानी से साझा करें।';

  @override
  String shareFailed(String reason) {
    return 'इस सर्वर को लिंक के रूप में साझा नहीं किया जा सकता: $reason';
  }

  @override
  String get shareTooLong => 'QR कोड के लिए बहुत लंबा: लिंक कॉपी करें';

  @override
  String get obTitle1 => 'निजी और सरल';

  @override
  String get obText1 =>
      'VPN, प्रॉक्सी और Tor के लिए एक शांत स्क्रीन। जगह चुनें, कनेक्ट दबाएँ।';

  @override
  String get obTitle2 => 'अपने सर्वर जोड़ें';

  @override
  String get obText2 =>
      'लिंक, QR कोड, कॉन्फ़िग फ़ाइल या सब्सक्रिप्शन इम्पोर्ट करें। या हाथ से सर्वर जोड़ें।';

  @override
  String get obTitle3Android => 'Android एक बार पूछेगा';

  @override
  String get obText3Android =>
      'Android VPN कनेक्शन की अनुमति माँगेगा। सुरक्षित रहने के लिए स्वीकार करें।';

  @override
  String get obTitle3Desktop => 'जब आप चाहें, तैयार';

  @override
  String get obText3Desktop =>
      'प्रॉक्सी मोड में शुरू होता है, किसी विशेष अधिकार की ज़रूरत नहीं। सारा ट्रैफ़िक कैप्चर करने के लिए सेटिंग्स में VPN मोड चालू करें।';

  @override
  String get obAddFirst => 'मेरा पहला सर्वर जोड़ें';

  @override
  String get bypassTitle => 'बायपास सूचियाँ';

  @override
  String get bypassAddTooltip => 'सूची जोड़ें';

  @override
  String get bypassFromClipboard => 'क्लिपबोर्ड से पेस्ट करें';

  @override
  String get bypassFromFile => '.txt फ़ाइल खोलें';

  @override
  String get bypassFromUrl => 'लिंक से डाउनलोड करें';

  @override
  String get bypassType => 'खुद लिखें';

  @override
  String get bypassClipboardEmpty => 'क्लिपबोर्ड खाली है';

  @override
  String get bypassPickFile => 'बायपास सूची खोलें (.txt)';

  @override
  String bypassDownloadFailed(String error) {
    return 'सूची डाउनलोड नहीं हो सकी: $error';
  }

  @override
  String get bypassIntro =>
      'वे साइटें और पते जो VPN को छोड़ देते हैं। हर पंक्ति में एक: example.com, full:www.example.com, keyword:bank, regexp:…, 203.0.113.7 या 10.0.0.0/8। # से शुरू होने वाली पंक्तियाँ अनदेखी की जाती हैं।';

  @override
  String get bypassNoLists => 'अभी कोई सूची नहीं।';

  @override
  String get bypassTypeList => 'सूची लिखें';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रविष्टियाँ',
      one: '$count प्रविष्टि',
    );
    return '$_temp0';
  }

  @override
  String get bypassOnlyTitle => 'केवल सूचीबद्ध VPN उपयोग करें';

  @override
  String get bypassOnlyOn => 'बाकी सब सीधे जाता है।';

  @override
  String get bypassOnlyOff => 'सूचीबद्ध सीधे जाते हैं; बाकी VPN से जाते हैं।';

  @override
  String get bypassNothing => 'कोई सूची चालू नहीं है।';

  @override
  String bypassInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रविष्टियाँ उपयोग में',
      one: '$count प्रविष्टि उपयोग में',
    );
    return '$_temp0। अगले कनेक्ट पर लागू होगा।';
  }

  @override
  String get bypassHttpLink => 'http(s) लिंक दर्ज करें';

  @override
  String bypassServerAnswered(int code) {
    return 'सर्वर ने $code जवाब दिया';
  }

  @override
  String get bypassTooLarge => 'सूची 5 MB से बड़ी है';

  @override
  String get bypassDownloadTitle => 'सूची डाउनलोड करें';

  @override
  String get bypassNewList => 'नई सूची';

  @override
  String get bypassEditList => 'सूची संपादित करें';

  @override
  String get bypassName => 'नाम';

  @override
  String get bypassEntriesLabel => 'प्रविष्टियाँ, हर पंक्ति में एक';

  @override
  String get bypassNoUsable => 'अभी कोई उपयोगी प्रविष्टि नहीं।';

  @override
  String bypassSummary(String entries, String names, String ranges) {
    return '$entries · $names, $ranges।';
  }

  @override
  String bypassNames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count नाम',
      one: '$count नाम',
    );
    return '$_temp0';
  }

  @override
  String bypassRanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पते या रेंज',
      one: '$count पता या रेंज',
    );
    return '$_temp0';
  }

  @override
  String bypassIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पंक्तियाँ अनदेखी की जाएँगी:',
      one: '$count पंक्ति अनदेखी की जाएगी:',
    );
    return '$_temp0';
  }

  @override
  String bypassMoreIssues(int count) {
    return '… और $count और';
  }

  @override
  String get bypassReconnect => 'नई सूची उपयोग करने के लिए फिर से कनेक्ट करें';

  @override
  String get bypassDefaultName => 'मेरी सूची';

  @override
  String get bypassPastedName => 'पेस्ट की गई सूची';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get settingsServers => 'सर्वर';

  @override
  String get manageServers => 'सर्वर प्रबंधित करें';

  @override
  String get manageServersHint => 'सर्वर और सब्सक्रिप्शन';

  @override
  String get settingsConnection => 'कनेक्शन';

  @override
  String get vpnMode => 'VPN मोड (सारा ट्रैफ़िक)';

  @override
  String get vpnModeHint => 'बंद: केवल प्रॉक्सी, VPN अनुमति नहीं';

  @override
  String get systemProxy => 'सिस्टम प्रॉक्सी सेट करें';

  @override
  String get systemProxyHint => 'कनेक्ट रहने के दौरान सिस्टम प्रॉक्सी सेट करें';

  @override
  String get autoSwitch => 'विफलता पर ऑटो-स्विच';

  @override
  String get autoSwitchHint => 'एक विफल हो तो अगला सर्वर आज़माएँ';

  @override
  String get bypassLan => 'लोकल नेटवर्क बायपास करें';

  @override
  String get bypassLanHint =>
      'लोकल डिवाइस तक सीधे पहुँचें (192.168.x.x, 10.x.x.x)';

  @override
  String get bypassListsHint => 'वेबसाइटें और पते जो VPN को छोड़ देते हैं';

  @override
  String bypassListsInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रविष्टियाँ उपयोग में',
      one: '$count प्रविष्टि उपयोग में',
    );
    return '$_temp0';
  }

  @override
  String get alwaysOnTitle => 'हमेशा चालू VPN और किल स्विच';

  @override
  String get alwaysOnHint =>
      'बूट पर फिर से कनेक्ट करें और लीक रोकें। Android की VPN सेटिंग्स में सेट करें।';

  @override
  String get openVpnSettingsFallback =>
      'सेटिंग्स → नेटवर्क → VPN → Wardkeep के पास गियर आइकन';

  @override
  String get splitTunneling => 'स्प्लिट टनलिंग';

  @override
  String splitSummaryOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'केवल चुने गए $count ऐप VPN उपयोग करते हैं',
      one: 'केवल चुने गए $count ऐप VPN उपयोग करते हैं',
    );
    return '$_temp0';
  }

  @override
  String splitSummaryBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ऐप VPN को बायपास करते हैं',
      one: '$count ऐप VPN को बायपास करता है',
    );
    return '$_temp0';
  }

  @override
  String get splitSummaryOff => 'सभी ऐप VPN उपयोग करते हैं';

  @override
  String get remoteDns => 'रिमोट DNS';

  @override
  String get remoteDnsHelp =>
      'टनल के ज़रिए उपयोग होने वाला DNS, जैसे https://1.1.1.1/dns-query या tls://1.1.1.1';

  @override
  String get settingsApp => 'ऐप';

  @override
  String get appearance => 'रूप-रंग';

  @override
  String get themeDark => 'डार्क';

  @override
  String get themeLight => 'लाइट';

  @override
  String get themeSystem => 'सिस्टम के अनुसार';

  @override
  String get language => 'भाषा';

  @override
  String get languageSystem => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get stopOnClose => 'ऐप बंद होने पर VPN रोकें';

  @override
  String aboutLine(String engine) {
    return 'MIT लाइसेंस · इंजन: $engine';
  }

  @override
  String get splitTitle => 'स्प्लिट टनलिंग';

  @override
  String get splitAll => 'सभी ऐप';

  @override
  String get splitOnlySelected => 'केवल चुने हुए';

  @override
  String get splitBypassSelected => 'चुने हुए बायपास करें';

  @override
  String get splitHelpOffMode => 'हर ऐप VPN उपयोग करता है।';

  @override
  String get splitHelpOnlyNone => 'कोई ऐप नहीं चुना: सभी VPN उपयोग करते हैं।';

  @override
  String splitHelpOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'केवल $count ऐप VPN उपयोग करते हैं।',
      one: 'केवल $count ऐप VPN उपयोग करता है।',
    );
    return '$_temp0';
  }

  @override
  String splitHelpBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ऐप सीधे जाते हैं।',
      one: '$count ऐप सीधे जाता है।',
    );
    return '$_temp0';
  }

  @override
  String get searchApps => 'ऐप खोजें';

  @override
  String get showSystemApps => 'सिस्टम ऐप दिखाएँ';

  @override
  String couldNotListApps(String error) {
    return 'ऐप की सूची नहीं बन सकी: $error';
  }

  @override
  String get scanTitle => 'QR कोड स्कैन करें';

  @override
  String get scanTorch => 'टॉर्च';

  @override
  String scanCameraUnavailable(String code) {
    return 'कैमरा उपलब्ध नहीं: $code';
  }

  @override
  String get scanPoint => 'कैमरे को कॉन्फ़िग QR कोड की ओर रखें';

  @override
  String get credTitle => 'साइन इन करें';

  @override
  String credNeeds(String name) {
    return '$name को यूज़रनेम और पासवर्ड चाहिए।';
  }

  @override
  String get credUsername => 'यूज़रनेम';

  @override
  String get credPassword => 'पासवर्ड';

  @override
  String get logsEmpty => 'अभी कोई लॉग प्रविष्टि नहीं।';

  @override
  String get profilesTitle => 'सर्वर प्रबंधित करें';

  @override
  String get addSubscriptionTooltip => 'सब्सक्रिप्शन जोड़ें';

  @override
  String get testLatencyTooltip => 'लेटेंसी जाँचें';

  @override
  String get profilesEmptyHint =>
      'कोई प्रोफ़ाइल नहीं। जोड़ने के लिए इम्पोर्ट दबाएँ।';

  @override
  String get profilesDragHint =>
      'क्रम बदलने के लिए दबाकर खींचें। फ़ेलओवर इसी क्रम में चलता है।';

  @override
  String get myProfiles => 'मेरी प्रोफ़ाइलें';

  @override
  String subRefreshed(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रोफ़ाइलें',
      one: '$count प्रोफ़ाइल',
    );
    return '$name: $_temp0';
  }

  @override
  String get refreshTooltip => 'रिफ़्रेश करें';

  @override
  String get subDeleteWithProfiles => 'सब्सक्रिप्शन और उसकी प्रोफ़ाइलें हटाएँ';

  @override
  String subUsageOf(String used, String total) {
    return '$total में से $used';
  }

  @override
  String subUsed(String used) {
    return '$used उपयोग हुआ';
  }

  @override
  String get subExpired => 'समाप्त हो गया';

  @override
  String get subExpiresToday => 'आज समाप्त होगा';

  @override
  String subExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिन में समाप्त होगा',
      one: '$days दिन में समाप्त होगा',
    );
    return '$_temp0';
  }

  @override
  String subUpdated(String ago) {
    return '$ago अपडेट हुआ';
  }

  @override
  String get agoJustNow => 'अभी-अभी';

  @override
  String agoMinutes(int count) {
    return '$count मिनट पहले';
  }

  @override
  String agoHours(int count) {
    return '$count घंटे पहले';
  }

  @override
  String agoDays(int count) {
    return '$count दिन पहले';
  }

  @override
  String subRefreshFailed(String error) {
    return 'पिछला रिफ़्रेश विफल रहा: $error';
  }

  @override
  String get importTitle => 'कॉन्फ़िग इम्पोर्ट करें';

  @override
  String get importDescription =>
      'लिंक, कॉन्फ़िग या सब्सक्रिप्शन पेस्ट करें — या फ़ाइल खोलें या QR कोड स्कैन करें।';

  @override
  String get importScanQr => 'QR स्कैन करें';

  @override
  String get importOpenFile => 'फ़ाइल खोलें';

  @override
  String get importPaste => 'पेस्ट करें';

  @override
  String get importSubscription => 'सब्सक्रिप्शन';

  @override
  String get importTor => 'Tor';

  @override
  String get importAddTor => 'Tor जोड़ें';

  @override
  String get importTorDirect => 'Tor (सीधा)';

  @override
  String get importTorSnowflake => 'Tor + Snowflake ब्रिज';

  @override
  String get importTorObfs4 => 'Tor + obfs4 ब्रिज';

  @override
  String importedProfiles(int added, int dupes) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added प्रोफ़ाइलें इम्पोर्ट हुईं',
      one: '$added प्रोफ़ाइल इम्पोर्ट हुई',
    );
    String _temp1 = intl.Intl.pluralLogic(
      dupes,
      locale: localeName,
      other: ', $dupes पहले से मौजूद',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String importNothing(String reason) {
    return 'कुछ इम्पोर्ट नहीं हुआ: $reason';
  }

  @override
  String importPartial(int added, int failed) {
    return '$added इम्पोर्ट हुए, $failed विफल';
  }

  @override
  String get subAddTitle => 'सब्सक्रिप्शन जोड़ें';

  @override
  String get subEditTitle => 'सब्सक्रिप्शन संपादित करें';

  @override
  String get subUrlLabel => 'सब्सक्रिप्शन URL';

  @override
  String get subUrlHint =>
      'https://provider.example/sub/… या nordvpn://<token>';

  @override
  String get subNameLabel => 'नाम (वैकल्पिक)';

  @override
  String get subNameHelp => 'डिफ़ॉल्ट रूप से प्रोवाइडर का शीर्षक या होस्ट नाम';

  @override
  String get subAuthLabel => 'प्रमाणीकरण';

  @override
  String get authNone => 'कोई नहीं';

  @override
  String get authBasic => 'यूज़रनेम और पासवर्ड (Basic)';

  @override
  String get authBearer => 'Bearer टोकन';

  @override
  String get authHeader => 'कस्टम हेडर';

  @override
  String get authQuery => 'URL में टोकन';

  @override
  String get subUsername => 'यूज़रनेम';

  @override
  String get subPassword => 'पासवर्ड';

  @override
  String get subHeaderName => 'हेडर का नाम';

  @override
  String get subHeaderValue => 'हेडर का मान';

  @override
  String get subParamName => 'पैरामीटर का नाम';

  @override
  String get subToken => 'टोकन';

  @override
  String get subDownloadLabel => 'डाउनलोड';

  @override
  String get subDownloadHelp => 'प्रोवाइडर ब्लॉक है? VPN फिर भी इसे ला सकता है';

  @override
  String get subViaDirect => 'सीधे';

  @override
  String get subViaAuto => 'सीधे, या ब्लॉक होने पर VPN से';

  @override
  String get subViaTunnel => 'हमेशा VPN से (पहले कनेक्ट करें)';

  @override
  String get subErrUrl =>
      'http(s) सब्सक्रिप्शन URL दर्ज करें (या nordvpn://<access token>)';

  @override
  String get subErrHeader => 'हेडर का नाम दर्ज करें';

  @override
  String get subErrToken => 'टोकन दर्ज करें';

  @override
  String get subAddAndDownload => 'जोड़ें और डाउनलोड करें';

  @override
  String get subSaveAndRefresh => 'सहेजें और रिफ़्रेश करें';

  @override
  String subUpdatedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रोफ़ाइलें',
      one: '$count प्रोफ़ाइल',
    );
    return 'सब्सक्रिप्शन अपडेट हुआ: $_temp0';
  }

  @override
  String get flName => 'नाम';

  @override
  String get flServer => 'सर्वर';

  @override
  String get flPort => 'पोर्ट';

  @override
  String get flPassword => 'पासवर्ड';

  @override
  String get flUsername => 'यूज़रनेम';

  @override
  String get flUuid => 'UUID';

  @override
  String get flSecurity => 'सुरक्षा';

  @override
  String get flFlow => 'Flow';

  @override
  String get flCipher => 'सिफ़र';

  @override
  String get flEncryption => 'एन्क्रिप्शन';

  @override
  String get flAlterId => 'Alter id';

  @override
  String get flTlsServerName => 'TLS सर्वर नाम (SNI)';

  @override
  String get flTlsFingerprint => 'TLS फ़िंगरप्रिंट';

  @override
  String get flAlpn => 'ALPN';

  @override
  String get flSkipCertCheck => 'प्रमाणपत्र जाँच छोड़ें';

  @override
  String get flPinnedCert => 'पिन किया हुआ प्रमाणपत्र (PEM)';

  @override
  String get flRealityPublicKey => 'Reality पब्लिक की';

  @override
  String get flRealityShortId => 'Reality शॉर्ट ID';

  @override
  String get flTransport => 'ट्रांसपोर्ट';

  @override
  String get flHostHeader => 'होस्ट हेडर';

  @override
  String get flPath => 'पाथ';

  @override
  String get flGrpcService => 'gRPC सेवा का नाम';

  @override
  String get flPlugin => 'प्लगइन';

  @override
  String get flPluginOptions => 'प्लगइन विकल्प';

  @override
  String get flObfuscation => 'ऑब्फ़स्केशन';

  @override
  String get flObfsPassword => 'ऑब्फ़स्केशन पासवर्ड';

  @override
  String get flUploadMbps => 'अपलोड (Mbps)';

  @override
  String get flDownloadMbps => 'डाउनलोड (Mbps)';

  @override
  String get flCongestion => 'कंजेशन कंट्रोल';

  @override
  String get flUdpRelay => 'UDP रिले मोड';

  @override
  String get flUseQuic => 'HTTP/3 (QUIC) उपयोग करें';

  @override
  String get flTunnelAddress => 'आपका टनल पता';

  @override
  String get flRoutedNetworks => 'रूट किए गए नेटवर्क';

  @override
  String get flDnsServers => 'DNS सर्वर';

  @override
  String get flMtu => 'MTU';

  @override
  String get flKeepalive => 'Keepalive (सेकंड)';

  @override
  String get flPrivateKey => 'प्राइवेट की';

  @override
  String get flServerPublicKey => 'सर्वर पब्लिक की';

  @override
  String get flPresharedKey => 'प्री-शेयर्ड की';

  @override
  String get flReservedBytes => 'रिज़र्व्ड बाइट्स';

  @override
  String get flAuthentication => 'प्रमाणीकरण';

  @override
  String get flAuthDigest => 'Auth डाइजेस्ट';

  @override
  String get flCaCert => 'CA प्रमाणपत्र (PEM)';

  @override
  String get flClientCert => 'क्लाइंट प्रमाणपत्र (PEM)';

  @override
  String get flClientKey => 'क्लाइंट की (PEM)';

  @override
  String get flControlWrap => 'कंट्रोल चैनल सुरक्षा';

  @override
  String get flControlWrapKey => 'कंट्रोल चैनल की';

  @override
  String get flKeyDirection => 'की की दिशा';

  @override
  String get flRemoteCertType => 'रिमोट प्रमाणपत्र प्रकार';

  @override
  String get flVerifyServerName => 'सर्वर नाम सत्यापित करें';

  @override
  String get flYourIdentity => 'आपकी पहचान';

  @override
  String get flServerIdentity => 'सर्वर की पहचान';

  @override
  String get flServerCertTrust => 'भरोसेमंद सर्वर प्रमाणपत्र (PEM)';

  @override
  String get flUseSystemIke => 'फ़ोन का अपना IKEv2 क्लाइंट उपयोग करें';

  @override
  String get flUseTcp => 'TCP उपयोग करें';

  @override
  String get flHostKeys => 'होस्ट की';

  @override
  String get flPrivateKeyPem => 'प्राइवेट की (PEM)';

  @override
  String get flKeyPassphrase => 'की पासफ़्रेज़';

  @override
  String get flBridges => 'ब्रिज';

  @override
  String get flBridgeLines => 'ब्रिज लाइनें';

  @override
  String get flJc => 'Jc (जंक पैकेट संख्या)';

  @override
  String get flSignaturePacket => 'I1 (सिग्नेचर पैकेट)';

  @override
  String get hpAuthorizedKeys =>
      'authorized_keys प्रारूप; खाली होने पर कोई भी की स्वीकार';

  @override
  String get hpIkeTcp =>
      'UDP रोकने वाले नेटवर्क के लिए IKE और ESP को TCP पर चलाएँ';

  @override
  String get hpDefaultsToServer => 'डिफ़ॉल्ट रूप से सर्वर का पता';

  @override
  String get hpTorBridges =>
      'खाली होने पर Tor सीधे कनेक्ट होता है, या नीचे की ब्रिज लाइनें उपयोग करता है';

  @override
  String get hpExampleAddress => 'उदाहरण: 10.8.0.2/32';

  @override
  String get hpExamplePlugin => 'उदाहरण: shadow-tls या v2ray-plugin';

  @override
  String get hpHostOrIp => 'होस्ट नाम या IP पता';

  @override
  String get hpNeededReality => 'सुरक्षा reality होने पर ज़रूरी';

  @override
  String get hpOnlySelfSigned =>
      'केवल उन सर्वरों के लिए जिनका सेल्फ़-साइन्ड प्रमाणपत्र आप पिन नहीं कर सकते';

  @override
  String get hpSafeSstp =>
      'SSTP के लिए सुरक्षित: पासवर्ड एक्सचेंज सर्वर को प्रमाणित करता है';

  @override
  String get hpHysteriaObfs =>
      'Hysteria 2 के लिए salamander; Hysteria 1 के लिए ऑब्फ़स्केशन पासवर्ड';

  @override
  String get hpTrustCert =>
      'सिस्टम की अथॉरिटी के बजाय इस प्रमाणपत्र पर भरोसा करें';

  @override
  String get hpWhichBrowser => 'किस ब्राउज़र के TLS हैंडशेक की नकल करनी है';

  @override
  String get hpWarpReserved =>
      'तीन संख्याएँ, जैसा WARP कॉन्फ़िगरेशन में दी जाती हैं';

  @override
  String get hpOneBridgePerLine =>
      'हर पंक्ति में एक ब्रिज, torrc की तरह लेकिन \"Bridge \" के बिना';

  @override
  String get exitTitle => 'एग्ज़िट पता और देश दिखाएँ';

  @override
  String get exitHint =>
      'api.country.is से आपका IP और देश पूछें, कनेक्ट न होने पर भी।';

  @override
  String exitIpLabel(String ip) {
    return 'IP $ip';
  }

  @override
  String connectedTo(String place) {
    return '$place से कनेक्टेड';
  }

  @override
  String get noticesTitle => 'ओपन-सोर्स लाइसेंस';

  @override
  String get noticesIntro =>
      'Wardkeep MIT लाइसेंस के तहत है। इसमें नीचे दिया गया सॉफ़्टवेयर शामिल है, हर एक अपने लाइसेंस के तहत।';

  @override
  String noticesMore(int count) {
    return '+$count और';
  }

  @override
  String noticesPackages(int count) {
    return '$count पैकेज';
  }

  @override
  String get noticesLoadFailed => 'लाइसेंस सूची पढ़ी नहीं जा सकी।';

  @override
  String formRequired(String label) {
    return '$label ज़रूरी है';
  }

  @override
  String formNotNumber(String label) {
    return '$label पूर्ण संख्या होनी चाहिए';
  }

  @override
  String formNotBool(String label) {
    return '$label चालू या बंद होना चाहिए';
  }

  @override
  String formBadChoice(String label, String value, String choices) {
    return '$label: $value, $choices में से नहीं है';
  }

  @override
  String get formRealityOnlyVless => 'Reality केवल VLESS के लिए उपलब्ध है';

  @override
  String formUnknownSecurity(String value) {
    return 'अज्ञात सुरक्षा: $value';
  }

  @override
  String get formReservedBytes =>
      'रिज़र्व्ड बाइट्स 0 से 255 तक की संख्याएँ होनी चाहिए';

  @override
  String get formRealityKeyRequired =>
      'सुरक्षा Reality होने पर Reality पब्लिक की ज़रूरी है';

  @override
  String get importUnsupported =>
      'यह सर्वर लिंक, सब्सक्रिप्शन या कॉन्फ़िग नहीं है जिसे Wardkeep पढ़ सके';

  @override
  String importUnsupportedScheme(String scheme) {
    return '$scheme:// से शुरू होने वाले लिंक समर्थित नहीं हैं';
  }

  @override
  String get importXrayServer =>
      'यह Xray सर्वर कॉन्फ़िग है। इसे सर्वर पर इम्पोर्ट करें (omnitun-server import xray), क्लाइंट प्रोफ़ाइल के रूप में नहीं';

  @override
  String get subAuthFailed =>
      'सब्सक्रिप्शन ने साइन-इन अस्वीकार कर दिया। यूज़रनेम, पासवर्ड या टोकन जाँचें';

  @override
  String subHttp(String status) {
    return 'सब्सक्रिप्शन सर्वर ने HTTP $status जवाब दिया';
  }

  @override
  String get subTooLarge => 'सब्सक्रिप्शन 10 MB से बड़ा है';

  @override
  String get subBadUrl => 'यह मान्य सब्सक्रिप्शन पता नहीं है';

  @override
  String get bypassIssueEmptyExpression => 'खाली एक्सप्रेशन';

  @override
  String get bypassIssueBadExpression => 'मान्य एक्सप्रेशन नहीं';

  @override
  String get bypassIssueBadName => 'मान्य नाम नहीं';

  @override
  String get bypassIssueGeo =>
      'geo सूचियाँ समर्थित नहीं हैं; डोमेन या रेंज लिखें';

  @override
  String get bypassIssueBadEntry => 'डोमेन, पता या रेंज नहीं';

  @override
  String bypassIssueTooMany(int limit) {
    return '$limit से अधिक प्रविष्टियाँ: बाकी अनदेखी की जाएँगी';
  }

  @override
  String get torStarting => 'Tor शुरू हो रहा है';

  @override
  String torBootstrap(int percent) {
    return 'Tor से कनेक्ट हो रहा है $percent%';
  }

  @override
  String get torCircuit => 'Tor सर्किट बन रहा है';

  @override
  String torRetry(int attempt, int attempts) {
    return 'Tor फिर से आज़माया जा रहा है ($attempt/$attempts)';
  }

  @override
  String get importNoServer => 'इस टेक्स्ट में कोई मान्य सर्वर नहीं मिला';

  @override
  String importJsonSyntax(String found, int line, int column) {
    return 'यह मान्य JSON नहीं है: पंक्ति $line, कॉलम $column पर अप्रत्याशित वर्ण $found।';
  }

  @override
  String importJsonEnd(int line, int column) {
    return 'यह मान्य JSON नहीं है: पाठ बहुत जल्दी समाप्त हो जाता है (पंक्ति $line, कॉलम $column)। हो सकता है कोई बंद करने वाला ब्रैकेट, ब्रेस या उद्धरण चिह्न छूट गया हो।';
  }

  @override
  String get importJsonNoServer =>
      'यह JSON मान्य है, लेकिन इसमें कोई प्रॉक्सी सर्वर नहीं है। VLESS, VMess, Trojan, Shadowsocks या इसी तरह के आउटबाउंड वाला क्लाइंट कॉन्फ़िग इस्तेमाल करें।';

  @override
  String importJsonNoServerFound(String found) {
    return 'यह JSON मान्य है, लेकिन इसमें कोई प्रॉक्सी सर्वर नहीं है (इसमें $found है)। VLESS, VMess, Trojan, Shadowsocks या इसी तरह के आउटबाउंड वाला क्लाइंट कॉन्फ़िग इस्तेमाल करें।';
  }

  @override
  String importTooLarge(int limit) {
    return 'इसे आयात करने के लिए यह बहुत बड़ा है (सीमा $limit MB है)।';
  }

  @override
  String get importFileEmpty => 'फ़ाइल खाली है।';

  @override
  String get importFileNotText =>
      'यह फ़ाइल ऐसा टेक्स्ट नहीं है जिसे Wardkeep पढ़ सके (यह बाइनरी लगती है या अज्ञात एन्कोडिंग में है)। UTF-8 या UTF-16 टेक्स्ट फ़ाइल इस्तेमाल करें।';

  @override
  String get importFileNoPermission =>
      'Wardkeep को यह फ़ाइल पढ़ने की अनुमति नहीं है।';

  @override
  String get importFileMissing =>
      'फ़ाइल नहीं मिली। हो सकता है उसे हटा दिया गया हो या दूसरी जगह ले जाया गया हो।';

  @override
  String get importDetails => 'विवरण';

  @override
  String get importJsonNote =>
      'JSON कॉन्फ़िग (Xray, sing-box, SIP008) या उनकी सूची भी चलती है, टेक्स्ट या फ़ाइल के रूप में।';

  @override
  String get ipdbTitle => 'ऑफ़लाइन देश डेटाबेस';

  @override
  String get ipdbIntro =>
      'एक बार डेटाबेस डाउनलोड करें, और Wardkeep किसी वेबसाइट से पूछे बिना खुद सर्वर या पते का देश पता कर लेगा।';

  @override
  String ipdbSizeNote(String size) {
    return 'लगभग $size · मुफ़्त डेटा (पब्लिक डोमेन)';
  }

  @override
  String get ipdbDownload => 'डाउनलोड करें';

  @override
  String get ipdbContinue => 'जारी रखें';

  @override
  String get ipdbPause => 'रोकें';

  @override
  String get ipdbUpdate => 'अपडेट करें';

  @override
  String get ipdbDelete => 'हटाएँ';

  @override
  String get ipdbDeleteTitle => 'डेटाबेस हटाएँ?';

  @override
  String get ipdbUse => 'डेटाबेस उपयोग करें';

  @override
  String get ipdbStepV4 => 'IPv4';

  @override
  String get ipdbStepV6 => 'IPv6';

  @override
  String get ipdbStepPrepare => 'तैयारी';

  @override
  String get ipdbPreparing => 'तैयार हो रहा है…';

  @override
  String get ipdbReady => 'तैयार';

  @override
  String ipdbStoppedAt(int percent) {
    return '$percent% पर रुका। जारी रखें दबाने पर वहीं से शुरू होगा।';
  }

  @override
  String ipdbFailed(String reason) {
    return 'डाउनलोड विफल: $reason';
  }

  @override
  String ipdbReadyLine(String ranges, String size) {
    return '$ranges रेंज · $size';
  }

  @override
  String ipdbVersion(String version, String date) {
    return 'संस्करण $version · $date';
  }

  @override
  String ipdbLeft(String time) {
    return '$time बाकी';
  }

  @override
  String get ipdbSource =>
      'डेटा: क्षेत्रीय इंटरनेट रजिस्ट्री और ASN घोषणाएँ (CC0), ip-location-db प्रोजेक्ट से।';

  @override
  String get ipdbSubNone => 'वेबसाइट से पूछे बिना देश पता करें';

  @override
  String ipdbSubReady(String size) {
    return 'चालू · $size';
  }

  @override
  String ipdbSubOff(String size) {
    return 'बंद · $size';
  }

  @override
  String ipdbSubDownloading(int percent) {
    return 'डाउनलोड हो रहा है $percent%';
  }

  @override
  String ipdbSubStopped(int percent) {
    return '$percent% पर रुका';
  }

  @override
  String get ipdbErrNetwork => 'डेटा सर्वरों से कनेक्शन नहीं है';

  @override
  String get ipdbErrMirrors => 'डेटा सर्वरों ने सही फ़ाइल नहीं भेजी';

  @override
  String get bypassCountriesTitle => 'देश';

  @override
  String get bypassCountriesNone => 'कोई देश नहीं चुना';

  @override
  String bypassCountriesMore(String names, int count) {
    return '$names +$count';
  }

  @override
  String get bypassCountriesIntro =>
      'चुने गए देशों का ट्रैफ़िक VPN को छोड़कर सीधे इंटरनेट पर जाता है। उनकी एड्रेस रेंज ऑफ़लाइन देश डेटाबेस से आती हैं।';

  @override
  String get bypassCountriesGetDb => 'देश डेटाबेस प्राप्त करें';

  @override
  String get bypassCountriesSearch => 'देश खोजें';

  @override
  String get windowMinimize => 'छोटा करें';

  @override
  String get windowMaximize => 'बड़ा करें';

  @override
  String get windowRestore => 'पहले जैसा करें';

  @override
  String get windowClose => 'बंद करें';

  @override
  String get windowFullScreen => 'पूर्ण स्क्रीन';

  @override
  String get windowExitFullScreen => 'पूर्ण स्क्रीन से बाहर निकलें';

  @override
  String get globeRecenter => 'पृथ्वी को केंद्र में लाएँ';

  @override
  String get bypassCountriesZoneIntro =>
      'आप जिस भी देश पर टिक करते हैं, उसकी एड्रेस रेंज डाउनलोड होती है (कुछ किलोबाइट)। पूरा ऑफ़लाइन डेटाबेस अधिक सटीक है और उसे डाउनलोड नहीं करना पड़ता।';

  @override
  String get bypassCountriesDownloading => 'डाउनलोड हो रहा है…';

  @override
  String get bypassCountriesFailed =>
      'डाउनलोड नहीं हो सका। फिर कोशिश करने के लिए टैप करें।';

  @override
  String get bypassCountriesYourServer =>
      'आपका चुना हुआ सर्वर यहाँ है: उसका ट्रैफ़िक भी VPN को छोड़ देगा।';

  @override
  String get ipv6Title => 'IPv6';

  @override
  String get ipv6Hint =>
      'बंद: केवल IPv4 उपयोग होता है; IPv6 कनेक्शन अस्वीकार होते हैं, VPN के बाहर नहीं जाते।';

  @override
  String get mtuTitle => 'MTU';

  @override
  String get mtuAuto => 'डिफ़ॉल्ट';

  @override
  String get mtuHelp =>
      'टनल में पैकेट का आकार (केवल VPN मोड)। मोबाइल नेटवर्क पर कुछ साइटें अटकें तो 1280 से 1420 आज़माएँ। खाली का मतलब डिफ़ॉल्ट।';

  @override
  String mtuInvalid(int min, int max) {
    return '$min से $max के बीच की संख्या दर्ज करें।';
  }

  @override
  String get trayOpen => 'Wardkeep खोलें';

  @override
  String get trayQuit => 'बाहर निकलें';

  @override
  String get traySwitchServer => 'सर्वर बदलें';

  @override
  String get keepInTray => 'ट्रे में चलता रहे';

  @override
  String get keepInTrayHint =>
      'विंडो बंद करने पर वह केवल छिप जाती है। ऐप और VPN बंद करने के लिए ट्रे मेनू में “बाहर निकलें” चुनें।';

  @override
  String usageUsed(String size) {
    return '$size उपयोग हुआ';
  }

  @override
  String get menuResetUsage => 'डेटा उपयोग रीसेट करें';

  @override
  String get dnsPickerHelp =>
      'वेबसाइट के नाम VPN के ज़रिए आपके चुने हुए रिज़ॉल्वर से खोजे जाते हैं। DNSCrypt यह भी साबित करता है कि जवाब उसी रिज़ॉल्वर से आया है।';

  @override
  String get dnsDefault => 'डिफ़ॉल्ट';

  @override
  String get dnsSectionDnscrypt => 'DNSCrypt · DNSSEC, बिना लॉग, बिना फ़िल्टर';

  @override
  String get dnsCustom => 'कस्टम';

  @override
  String get dnsCustomLabel => 'पता या DNS stamp';

  @override
  String get dnsAnonymized => 'गुमनाम DNSCrypt';

  @override
  String get dnsAnonymizedHint =>
      'क्वेरी एक रिले से होकर जाती हैं, इसलिए रिज़ॉल्वर कभी नहीं देखता कि वे कहाँ से आईं';

  @override
  String get dnsAnonymizedNeedsDnscrypt =>
      'इसके लिए कोई DNSCrypt रिज़ॉल्वर चुनें';

  @override
  String get dnsRelay => 'रिले';

  @override
  String get dnsRelayChoose => 'रिले चुनें';

  @override
  String get dnsRelayAutomatic => 'अपने-आप (दूसरा ऑपरेटर)';

  @override
  String get dnsErrAddress =>
      'https://, tls://, tcp:// या udp:// से शुरू होने वाला पता, या sdns:// stamp दें';

  @override
  String get dnsErrDamaged =>
      'यह stamp खराब या अधूरा है। इसे दोबारा कॉपी करें।';

  @override
  String get dnsErrUnsupported => 'इस तरह का stamp समर्थित नहीं है';

  @override
  String get dnsErrRelayStamp => 'यह रिले का stamp है, रिज़ॉल्वर का नहीं';

  @override
  String dnsLine(String resolver) {
    return 'DNS: $resolver';
  }

  @override
  String get dnsLimits =>
      'यह आपके खोजे गए नामों की सुरक्षा करता है। यह नहीं छिपाता कि आप बाद में किन साइटों से जुड़ते हैं।';

  @override
  String get dnsAnonymizedShort => 'गुमनाम';

  @override
  String get flAuthKey => 'प्रमाणीकरण कुंजी';

  @override
  String get flControlServer => 'कंट्रोल सर्वर';

  @override
  String get flDeviceName => 'डिवाइस का नाम';

  @override
  String get flExitDevice => 'एग्ज़िट डिवाइस';

  @override
  String get flUseSubnets => 'अन्य डिवाइसों के सबनेट का उपयोग करें';

  @override
  String get flTempDevice => 'अस्थायी डिवाइस';

  @override
  String get hpAuthKey =>
      'Tailscale एडमिन पेज से मिली पूर्व-अधिकृत कुंजी, या headscale preauthkeys create से बनाई गई';

  @override
  String get hpControlServer =>
      'खाली छोड़ने पर Tailscale; Headscale के लिए उसका पता, जैसे https://hs.example.com';

  @override
  String get hpDeviceName =>
      'नेटवर्क में इस डिवाइस का नाम; खाली छोड़ने पर डिवाइस का अपना नाम';

  @override
  String get hpExitDevice =>
      'उस डिवाइस का नाम या पता जिसका इंटरनेट कनेक्शन इस्तेमाल करना है; खाली छोड़ने पर केवल आपके डिवाइस तक पहुँच';

  @override
  String get hpTempDevice => 'ऑफ़लाइन होने पर नेटवर्क से हटा दिया जाता है';

  @override
  String get devicesTitle => 'मेरे डिवाइस';

  @override
  String get devicesNotConnected =>
      'अपने डिवाइस देखने के लिए Tailscale या Headscale प्रोफ़ाइल से कनेक्ट करें।';

  @override
  String get devicesJoining => 'नेटवर्क से जुड़ रहे हैं…';

  @override
  String get devicesLoginNeeded =>
      'नेटवर्क ने इस डिवाइस की कुंजी स्वीकार नहीं की। नई कुंजी बनाएँ और प्रोफ़ाइल बदलें।';

  @override
  String get devicesEmpty => 'इस नेटवर्क में अभी कोई और डिवाइस नहीं है।';

  @override
  String get devicesThisDevice => 'यह डिवाइस';

  @override
  String get deviceOnline => 'ऑनलाइन';

  @override
  String get deviceOffline => 'ऑफ़लाइन';

  @override
  String deviceLastSeen(String when) {
    return 'आख़िरी बार $when को देखा गया';
  }

  @override
  String get deviceUseAsExit => 'एग्ज़िट के रूप में उपयोग करें';

  @override
  String get deviceStopExit => 'एग्ज़िट के रूप में उपयोग बंद करें';

  @override
  String get deviceIsExit => 'एग्ज़िट उपयोग में';

  @override
  String get devicesExitHint =>
      'अपने किसी डिवाइस को एग्ज़िट बनाएँ: आपका सारा ट्रैफ़िक उसके कनेक्शन से बाहर जाएगा।';

  @override
  String get deviceCopyName => 'नाम कॉपी करें';

  @override
  String get deviceCopyAddress => 'पता कॉपी करें';

  @override
  String get deviceCopied => 'कॉपी किया गया';

  @override
  String get errMeshExit =>
      'उस डिवाइस को अभी एग्ज़िट के रूप में उपयोग नहीं किया जा सकता। वह ऑनलाइन होना चाहिए और अपना कनेक्शन साझा करना चाहिए।';

  @override
  String get wnTlsInsecure =>
      'सर्वर का प्रमाणपत्र जाँचा नहीं जाता। रास्ते में कोई भी आपका ट्रैफ़िक पढ़ या बदल सकता है।';

  @override
  String get wnNoTls =>
      'ट्रैफ़िक TLS में लिपटा नहीं है। इसे पहचानना आसान है और रास्ते में पढ़ा जा सकता है।';

  @override
  String get wnVmessLegacy =>
      'VMess पुराना प्रोटोकॉल है और इसे पहचानना आसान है। Reality के साथ VLESS बेहतर विकल्प है।';

  @override
  String get wnSsPlain =>
      'shadow-tls जैसे प्लगइन के बिना ट्रैफ़िक यादृच्छिक बाइट जैसा दिखता है, और कुछ नेटवर्क इस पैटर्न को रोक देते हैं।';

  @override
  String get wnHysteria1 =>
      'Hysteria 1 अब पुराना हो चुका है। सर्वर समर्थन करे तो Hysteria 2 इस्तेमाल करें।';

  @override
  String get wnDpiVisible =>
      'इस प्रोटोकॉल को पहचानना आसान है और सख़्त नेटवर्क पर यह अक्सर रोका जाता है।';

  @override
  String get wnSshVisible => 'SSH टनल को पहचानना आसान है।';

  @override
  String get wnDnsttSlow =>
      'धीमा (आमतौर पर 1 Mbit/s से काफ़ी कम) और केवल TCP। यह बहुत सारी DNS क्वेरी भेजता है जिन्हें नेटवर्क देख सकता है। तभी इस्तेमाल करें जब और कुछ न चले।';

  @override
  String get wnDnsttOpen =>
      'कोई उपयोगकर्ता नाम या पासवर्ड नहीं: इस लिंक वाला कोई भी सर्वर इस्तेमाल कर सकता है।';

  @override
  String get wnMuxLossy =>
      'मल्टीप्लेक्सिंग कई कनेक्शन एक में रखती है। ख़राब लाइन सबको धीमा कर सकती है।';

  @override
  String get wnFragmentSide =>
      'हैंडशेक को टुकड़ों में बाँटना कुछ फ़िल्टरों के ख़िलाफ़ मदद करता है, कुछ पर काम बिगाड़ सकता है और देरी जोड़ता है।';

  @override
  String get wnEchServer =>
      'ECH समर्थन वाला सर्वर चाहिए, वरना कनेक्शन विफल होगा।';

  @override
  String get wnWgChain =>
      'प्रॉक्सी के अंदर WireGuard: प्रॉक्सी धीमा हो तो टनल अटक सकता है। प्रॉक्सी को UDP ले जाना होगा।';

  @override
  String get wnSubUnsigned =>
      'यह सूची हस्ताक्षरित नहीं है, इसलिए बदलाव का पता नहीं चल सकता।';

  @override
  String get choiceOff => 'बंद';

  @override
  String get flMultiplexing => 'मल्टीप्लेक्सिंग';

  @override
  String get flMuxPadding => 'मल्टीप्लेक्सिंग पैडिंग';

  @override
  String get flMuxMaxConnections => 'अधिकतम कनेक्शन';

  @override
  String get flMuxMinStreams => 'प्रति कनेक्शन न्यूनतम स्ट्रीम';

  @override
  String get flMuxMaxStreams => 'प्रति कनेक्शन अधिकतम स्ट्रीम';

  @override
  String get hpMultiplexing =>
      'कई कनेक्शन एक में; सर्वर को अनुमति देनी होगी। VLESS flow के साथ नहीं';

  @override
  String get hpMuxMaxStreams => 'ऊपर के दो के बदले';

  @override
  String get flTlsFragment => 'TLS हैंडशेक को टुकड़ों में बाँटें';

  @override
  String get flTlsRecordFragment => 'TLS रिकॉर्ड को टुकड़ों में बाँटें';

  @override
  String get flEch => 'एन्क्रिप्टेड Client Hello (ECH)';

  @override
  String get flEchConfig => 'ECH कॉन्फ़िग (PEM)';

  @override
  String get flEchQueryName => 'ECH खोज का नाम';

  @override
  String get hpTlsFragment =>
      'पहले पैकेट को बाँटता है ताकि फ़िल्टर सर्वर का नाम न पढ़ सके';

  @override
  String get hpTlsRecordFragment => 'पैकेट की जगह रिकॉर्ड को बाँटता है';

  @override
  String get hpEch =>
      'सर्वर का नाम छिपाता है; इसका समर्थन करने वाला सर्वर चाहिए';

  @override
  String get hpEchConfig => 'खाली होने पर DNS में खोजा जाता है';

  @override
  String get hpEchQueryName => 'डिफ़ॉल्ट सर्वर का नाम है';

  @override
  String get flWgVia => 'प्रॉक्सी के ज़रिए (शेयर लिंक)';

  @override
  String get hpWgVia =>
      'UDP रोकने वाले नेटवर्क के लिए WireGuard को इस प्रॉक्सी के अंदर ले जाता है। प्रॉक्सी को UDP पास करना होगा';

  @override
  String get subSigned => 'हस्ताक्षरित';

  @override
  String get subKeyLabel => 'हस्ताक्षर कुंजी (वैकल्पिक)';

  @override
  String get subKeyHelp =>
      'प्रदाता की सार्वजनिक कुंजी। इससे बने वैध हस्ताक्षर के बिना जवाब अस्वीकार कर दिया जाता है';

  @override
  String get subBackupLabel => 'बैकअप पते (वैकल्पिक)';

  @override
  String get subBackupHelp =>
      'हर पंक्ति में एक। पहला न मिले तो क्रम से आज़माए जाते हैं';

  @override
  String get subErrKey => 'हस्ताक्षर कुंजी वैध सार्वजनिक कुंजी नहीं है';

  @override
  String get subUnsigned =>
      'सदस्यता हस्ताक्षरित नहीं है जबकि हस्ताक्षर कुंजी सेट है, इसलिए अस्वीकार की गई';

  @override
  String get subBadSignature =>
      'सदस्यता का हस्ताक्षर गलत है: रास्ते में बदला गया हो सकता है, या कुंजी पुरानी है';

  @override
  String get subStale =>
      'यह जवाब पिछले स्वीकार किए गए जवाब से पुराना है, इसलिए अस्वीकार किया गया। यदि प्रदाता ने पुराना बैकअप बहाल किया है, तो सदस्यता संपादित करें और फिर से सहेजें।';

  @override
  String get flTunnelDomain => 'टनल का डोमेन';

  @override
  String get flServerKey => 'सर्वर कुंजी';

  @override
  String get flResolvers => 'रिज़ॉल्वर';

  @override
  String get hpTunnelDomain =>
      'वह ज़ोन जो आपने टनल सर्वर को सौंपा है, जैसे t.example.com';

  @override
  String get hpServerKey => '64 हेक्साडेसिमल अंक; सर्वर इसे दिखाता है';

  @override
  String get hpResolvers =>
      'क्रम से आज़माए जाते हैं: udp://IP:port, tls://host:port या https://host/path';

  @override
  String get hpTunnelLogin =>
      'सर्वर के SOCKS5 अपस्ट्रीम का लॉगिन; न हो तो खाली छोड़ें';

  @override
  String get scanFind => 'काम करने वाले रिज़ॉल्वर खोजें';

  @override
  String get scanBusy => 'रिज़ॉल्वर आज़माए जा रहे हैं…';

  @override
  String scanFound(int count) {
    return 'काम करने वाले रिज़ॉल्वर मिले: $count';
  }

  @override
  String get scanNone =>
      'कोई रिज़ॉल्वर काम नहीं आया। डोमेन और कुंजी जाँचें, और देखें कि सर्वर चल रहा है।';

  @override
  String get scanConnected =>
      'पहले डिस्कनेक्ट करें: जाँच को नेटवर्क सीधे इस्तेमाल करना होगा, VPN से नहीं।';

  @override
  String get scanNeedsFields => 'पहले टनल का डोमेन और सर्वर कुंजी भरें।';
}
