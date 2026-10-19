// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'Wardkeep';

  @override
  String get actionSave => 'Kaydet';

  @override
  String get actionCancel => 'İptal';

  @override
  String get actionDelete => 'Sil';

  @override
  String get actionEdit => 'Düzenle';

  @override
  String get actionReset => 'Sıfırla';

  @override
  String get actionSkip => 'Atla';

  @override
  String get actionNext => 'İleri';

  @override
  String get actionImport => 'İçe aktar';

  @override
  String get actionDownload => 'İndir';

  @override
  String get actionCopyAll => 'Tümünü kopyala';

  @override
  String get actionClear => 'Temizle';

  @override
  String get tooltipMore => 'Daha fazla';

  @override
  String get tooltipShow => 'Göster';

  @override
  String get tooltipHide => 'Gizle';

  @override
  String get searchHint => 'Ara';

  @override
  String get tooltipLogs => 'Günlükler';

  @override
  String get tooltipSettings => 'Ayarlar';

  @override
  String get statusConnected => 'Bağlandı';

  @override
  String get statusConnecting => 'Bağlanıyor…';

  @override
  String get statusDisconnecting => 'Bağlantı kesiliyor…';

  @override
  String get statusError => 'Bağlantı başarısız';

  @override
  String get statusNoInternet => 'İnternet bağlantısı yok';

  @override
  String get statusDisconnected => 'Bağlı değil';

  @override
  String get stagePermission => 'VPN izni bekleniyor';

  @override
  String get stageNetworkCheck => 'İnternet bağlantısı denetleniyor';

  @override
  String get stagePrepare => 'Yapılandırma hazırlanıyor';

  @override
  String get stageEngineStart => 'Motor başlatılıyor';

  @override
  String get stageTunnelUp => 'Tünel açılıyor';

  @override
  String get stageHandshake => 'Sunucuyla iletişim kuruluyor';

  @override
  String get stageConnected => 'Bağlandı';

  @override
  String get buttonConnect => 'Bağlan';

  @override
  String get buttonDisconnect => 'Bağlantıyı kes';

  @override
  String get buttonCancel => 'İptal';

  @override
  String get locationLabel => 'Konum';

  @override
  String get noServers => 'Sunucu yok';

  @override
  String get noServersHint => 'Başlamak için bir tane ekleyin';

  @override
  String get automatic => 'Otomatik';

  @override
  String get automaticHint => 'En hızlı sunucu, hata olursa değişir';

  @override
  String get anyServerInCountry => 'Bu ülkedeki herhangi bir sunucu';

  @override
  String get torNetwork => 'Tor ağı';

  @override
  String get torHopBridge => 'Köprü';

  @override
  String get torHopEntry => 'Giriş';

  @override
  String get torHopRelay => 'Aktarıcı';

  @override
  String get torHopExit => 'Çıkış';

  @override
  String get torHopHidden => 'Gizli';

  @override
  String get torHopUnknown => 'Bilinmiyor';

  @override
  String get hopYou => 'Siz';

  @override
  String get hopYouNote =>
      'Gerçekte bulunduğunuz yer burası. Trafiğiniz buradan başlar.';

  @override
  String get hopServer => 'Sunucu';

  @override
  String get hopServerNote =>
      'Trafiğiniz şifreli olarak bu sunucuya gider ve buradan çıkar; bu yüzden web siteleri sizin değil onun adresini görür.';

  @override
  String get hopBridgeNote =>
      'İlk atlamanız. Köprü, Tor kullandığınızı ağınızdan gizler. Kim olduğunuzu bilir ama nereye gittiğinizi bilmez.';

  @override
  String get hopEntryNote =>
      'İlk aktarıcı. Adresinizi bilir ama ne ziyaret ettiğinizi bilmez.';

  @override
  String get hopRelayNote =>
      'Ortadaki aktarıcı. Ne kim olduğunuzu ne de ne ziyaret ettiğinizi bilir; yalnızca trafiği iletir.';

  @override
  String get hopExitNote =>
      'Son aktarıcı. Nereye gittiğinizi görür ama kim olduğunuzu bilmez; web siteleri onun adresini görür.';

  @override
  String get hopHiddenNote =>
      'Köprünün konumu taşıma yöntemiyle gizlenir, bu yüzden haritada gösterilemez.';

  @override
  String get hopTransport => 'Taşıma';

  @override
  String get hopProtocol => 'Protokol';

  @override
  String get hopAddress => 'Adres';

  @override
  String get hopLatency => 'Gecikme';

  @override
  String get hopExitAddress => 'Çıkış adresi';

  @override
  String get menuNewGroup => 'Yeni grup';

  @override
  String get groupNameHint => 'Grup adı';

  @override
  String get groupCreate => 'Oluştur';

  @override
  String get menuMoveToGroup => 'Gruba taşı';

  @override
  String get groupMoveTitle => 'Şuraya taşı';

  @override
  String get menuRenameGroup => 'Yeniden adlandır';

  @override
  String get menuDeleteGroup => 'Grubu sil';

  @override
  String get groupDeleteTitle => 'Bu grup silinsin mi?';

  @override
  String groupDeleteBody(String name) {
    return 'Sunucuları silinmez. $name grubuna geri döner.';
  }

  @override
  String get groupEmptyHint =>
      'Henüz sunucu yok. Bir sunucunun menüsünü açıp Gruba taşı\'yı seçin.';

  @override
  String get menuShareGroupFile => 'Metin dosyası olarak kaydet';

  @override
  String get menuCopyGroupLinks => 'Bağlantıları kopyala';

  @override
  String groupSavedToast(String servers) {
    return 'Kaydedildi: $servers';
  }

  @override
  String groupCopiedToast(String servers) {
    return 'Kopyalandı: $servers';
  }

  @override
  String get groupNothingToShare =>
      'Bu sunuculardan hiçbirinin paylaşım bağlantısı yok.';

  @override
  String groupSkipped(String servers) {
    return 'Paylaşım bağlantısı olmadığı için atlandı: $servers';
  }

  @override
  String get emptyTitle => 'Henüz profil yok';

  @override
  String get emptyHint =>
      'Bir yapılandırma, bağlantı veya abonelik içe aktarın.';

  @override
  String get importConfig => 'Yapılandırma içe aktar';

  @override
  String failoverToast(String to, String from) {
    return '$to sunucusuna geçildi — $from yanıt vermeyi kesti';
  }

  @override
  String get unknownLocation => 'Bilinmeyen konum';

  @override
  String errorFailed(String stage, String reason) {
    return '$stage başarısız: $reason';
  }

  @override
  String get errTimeout => 'sunucu zamanında yanıt vermedi';

  @override
  String get errRefused => 'sunucu bağlantıyı reddetti';

  @override
  String get errReset => 'bağlantı ağ tarafından sıfırlandı';

  @override
  String get errNoRoute => 'sunucuya bu ağdan ulaşılamıyor';

  @override
  String get errNetworkUnreachable => 'ağa ulaşılamıyor';

  @override
  String get errDns => 'sunucu adı çözümlenemedi';

  @override
  String get errTls => 'sunucunun güvenlik sertifikası reddedildi';

  @override
  String get errAuth => 'kullanıcı adı veya parola reddedildi';

  @override
  String get errClosed => 'sunucu bağlantıyı kapattı';

  @override
  String get errCertDate =>
      'sunucunun sertifikasının süresi dolmuş veya henüz geçerli değil (bu telefonun tarih ve saatini de denetleyin)';

  @override
  String get errCertUntrusted =>
      'sunucunun sertifikası güvenilir bir otorite tarafından imzalanmamış';

  @override
  String get errCertName =>
      'sunucunun sertifikası, bağlandığınız addan farklı bir ad için düzenlenmiş';

  @override
  String get errTlsKeys =>
      'ortak anahtar (tls-auth veya tls-crypt) sunucununkiyle eşleşmiyor';

  @override
  String get errReality =>
      'sunucu Reality el sıkışmasını reddetti (genel anahtarı, kısa kimliği ve sunucu adını denetleyin)';

  @override
  String get errNoHandshake =>
      'sunucu el sıkışmasına yanıt vermedi (anahtarları, uç noktayı ve UDP bağlantı noktasının açık olduğunu denetleyin)';

  @override
  String get errUdpBlocked =>
      'sunucu UDP üzerinden yanıt vermedi; bu ağ UDP\'yi engelliyor olabilir, TCP tabanlı bir sunucu deneyin';

  @override
  String get errPortInUse =>
      'yerel bağlantı noktası başka bir uygulama tarafından kullanılıyor';

  @override
  String get errTorTimeout =>
      'Tor zamanında bağlanmayı tamamlayamadı. Bu ağ Tor\'u engelliyor olabilir; bir köprü kullanın (Snowflake veya obfs4)';

  @override
  String get errTorBridgeTimeout =>
      'Tor zamanında bağlanmayı tamamlayamadı. Köprü engellenmiş veya aşırı yüklenmiş olabilir; başka bir köprü türü deneyin (Snowflake veya obfs4)';

  @override
  String get errTorBadBridge =>
      'bir Tor köprü satırı geçerli değil (aktarım, adres ve parmak izi gerekir)';

  @override
  String get errTorMissing => 'bu sürüm Tor istemcisini içermiyor';

  @override
  String get errPermission => 'VPN izni verilmedi';

  @override
  String get errCoreLost => 'Çekirdek hizmetle bağlantı kesildi';

  @override
  String get selectLocation => 'Konum seçin';

  @override
  String get testSpeedTooltip => 'Tüm sunucuların hızını test et';

  @override
  String get addServersTooltip => 'Sunucu ekle';

  @override
  String get menuImport => 'Yapılandırma, bağlantı veya QR içe aktar';

  @override
  String get menuNewServer => 'Elle sunucu ekle';

  @override
  String get menuSubscription => 'Abonelik ekle';

  @override
  String get menuManage => 'Sunucuları ve abonelikleri yönet';

  @override
  String get menuSetDefault => 'Varsayılan yap';

  @override
  String get badgeDefault => 'Varsayılan';

  @override
  String get menuDeleteAll => 'Tüm sunucuları sil';

  @override
  String get deleteAllTitle => 'Tüm sunucular silinsin mi?';

  @override
  String get deleteAllBody =>
      'Eklediğiniz tüm sunucular ve abonelikler kaldırılır. Yerleşik Tor bağlantısı kalır ve uygulama ona döner.';

  @override
  String get menuRestoreTor => 'Tor varsayılanlarını geri yükle';

  @override
  String get deletedAllToast => 'Tüm sunucular silindi';

  @override
  String defaultSetToast(String name) {
    return '$name artık varsayılan';
  }

  @override
  String serversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sunucu',
      one: '1 sunucu',
    );
    return '$_temp0';
  }

  @override
  String get otherGroup => 'Diğer';

  @override
  String get torGroup => 'Tor';

  @override
  String get noServersYet => 'Henüz sunucu yok';

  @override
  String get importHintShort =>
      'Bir yapılandırma dosyası, bağlantı veya abonelik içe aktarın.';

  @override
  String get showServers => 'Sunucuları göster';

  @override
  String get hideServers => 'Sunucuları gizle';

  @override
  String get menuEditServer => 'Düzenle';

  @override
  String get menuBridgeSettings => 'Köprü ayarları';

  @override
  String get menuShare => 'Bağlantıyı veya QR\'ı paylaş';

  @override
  String get menuSetCountry => 'Ülke belirle';

  @override
  String get menuCredentials => 'Kullanıcı adı ve parola';

  @override
  String needsSignIn(String address) {
    return '$address · oturum açılmalı';
  }

  @override
  String get countryOfServer => 'Bu sunucunun ülkesi';

  @override
  String get guessFromName => 'Addan çıkar';

  @override
  String get latencyNotTested => 'Test edilmedi';

  @override
  String get latencyUnreachable => 'Ulaşılamıyor';

  @override
  String get latencyTimeout => 'zaman aşımı';

  @override
  String latencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String get unknownCountry => 'Bilinmeyen ülke';

  @override
  String get addServerTitle => 'Sunucu ekle';

  @override
  String get addServerIntro =>
      'Bir protokol seçin. Bağlantı veya QR daha hızlıdır: İçe aktar\'ı kullanın.';

  @override
  String newServerTitle(String label) {
    return 'Yeni $label sunucusu';
  }

  @override
  String get editServerTitle => 'Sunucuyu düzenle';

  @override
  String get torBridgesTitle => 'Tor köprüleri';

  @override
  String get subscriptionEditNote =>
      'Bu sunucu bir abonelikten geliyor: yenilendiğinde değişikliklerinizin üzerine yazılır.';

  @override
  String get moreOptions => 'Diğer seçenekler';

  @override
  String get countryRow => 'Ülke';

  @override
  String get countryAuto => 'Ad ve adresten çıkarıldı';

  @override
  String get alreadyInList => 'Bu sunucu zaten listede';

  @override
  String get choiceDefault => 'Varsayılan';

  @override
  String get torBridgesNone => 'Yok (doğrudan veya aşağıdaki satırlar)';

  @override
  String get torBridgesSnowflake => 'Snowflake';

  @override
  String get torBridgesObfs4 => 'obfs4 (yerleşik köprüler)';

  @override
  String get listHelper => 'Değerleri virgülle ayırın';

  @override
  String get fillPaste => 'Yapıştır';

  @override
  String get fillFile => 'Dosya';

  @override
  String get fillScanQr => 'QR tara';

  @override
  String get openTextFile => 'Metin dosyası aç';

  @override
  String couldNotReadFile(String error) {
    return 'Dosya okunamadı: $error';
  }

  @override
  String fieldRequired(String label) {
    return '$label *';
  }

  @override
  String formNoEditor(String protocol) {
    return '$protocol için düzenleyici yok';
  }

  @override
  String get shareScanHint =>
      'Wardkeep ile tarayın veya bağlantıyı kopyalayın.';

  @override
  String get shareCopy => 'Bağlantıyı kopyala';

  @override
  String get shareCopied => 'Bağlantı kopyalandı';

  @override
  String get shareWarning =>
      'Sunucunun parolasını veya anahtarını içerir. Dikkatli paylaşın.';

  @override
  String shareFailed(String reason) {
    return 'Bu sunucu bağlantı olarak paylaşılamaz: $reason';
  }

  @override
  String get shareTooLong => 'QR kodu için çok uzun: bağlantıyı kopyalayın';

  @override
  String get obTitle1 => 'Gizli ve basit';

  @override
  String get obText1 =>
      'VPN, proxy ve Tor için tek sakin ekran. Bir yer seçin, Bağlan\'a basın.';

  @override
  String get obTitle2 => 'Sunucularınızı ekleyin';

  @override
  String get obText2 =>
      'Bir bağlantı, QR kodu, yapılandırma dosyası veya abonelik içe aktarın. Ya da elle sunucu ekleyin.';

  @override
  String get obTitle3Android => 'Android bir kez soracak';

  @override
  String get obText3Android =>
      'Android bir VPN bağlantısına izin vermenizi isteyecek. Korunmak için kabul edin.';

  @override
  String get obTitle3Desktop => 'Hazır olduğunuzda';

  @override
  String get obText3Desktop =>
      'Özel yetki gerektirmeyen proxy modunda başlar. Tüm trafiği yakalamak için Ayarlar\'dan VPN modunu açın.';

  @override
  String get obAddFirst => 'İlk sunucumu ekle';

  @override
  String get bypassTitle => 'Atlama listeleri';

  @override
  String get bypassAddTooltip => 'Liste ekle';

  @override
  String get bypassFromClipboard => 'Panodan yapıştır';

  @override
  String get bypassFromFile => '.txt dosyası aç';

  @override
  String get bypassFromUrl => 'Bağlantıdan indir';

  @override
  String get bypassType => 'Elle yaz';

  @override
  String get bypassClipboardEmpty => 'Pano boş';

  @override
  String get bypassPickFile => 'Atlama listesi aç (.txt)';

  @override
  String bypassDownloadFailed(String error) {
    return 'Liste indirilemedi: $error';
  }

  @override
  String get bypassIntro =>
      'VPN\'i atlayan siteler ve adresler. Her satıra bir tane: example.com, full:www.example.com, keyword:bank, regexp:…, 203.0.113.7 veya 10.0.0.0/8. # ile başlayan satırlar yok sayılır.';

  @override
  String get bypassNoLists => 'Henüz liste yok.';

  @override
  String get bypassTypeList => 'Liste yaz';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count girdi',
      one: '1 girdi',
    );
    return '$_temp0';
  }

  @override
  String get bypassOnlyTitle => 'Yalnızca listedekiler VPN kullanır';

  @override
  String get bypassOnlyOn => 'Geri kalan her şey doğrudan gider.';

  @override
  String get bypassOnlyOff =>
      'Listedekiler doğrudan gider; geri kalanı VPN kullanır.';

  @override
  String get bypassNothing => 'Hiçbir liste açık değil.';

  @override
  String bypassInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count girdi kullanımda',
      one: '1 girdi kullanımda',
    );
    return '$_temp0. Sonraki bağlanışta uygulanır.';
  }

  @override
  String get bypassHttpLink => 'Bir http(s) bağlantısı girin';

  @override
  String bypassServerAnswered(int code) {
    return 'sunucu $code yanıtı verdi';
  }

  @override
  String get bypassTooLarge => 'liste 5 MB\'tan büyük';

  @override
  String get bypassDownloadTitle => 'Liste indir';

  @override
  String get bypassNewList => 'Yeni liste';

  @override
  String get bypassEditList => 'Listeyi düzenle';

  @override
  String get bypassName => 'Ad';

  @override
  String get bypassEntriesLabel => 'Girdiler, her satıra bir tane';

  @override
  String get bypassNoUsable => 'Henüz kullanılabilir girdi yok.';

  @override
  String bypassSummary(String entries, String names, String ranges) {
    return '$entries · $names, $ranges.';
  }

  @override
  String bypassNames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ad',
      one: '1 ad',
    );
    return '$_temp0';
  }

  @override
  String bypassRanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count adres veya aralık',
      one: '1 adres veya aralık',
    );
    return '$_temp0';
  }

  @override
  String bypassIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count satır yok sayılacak:',
      one: '1 satır yok sayılacak:',
    );
    return '$_temp0';
  }

  @override
  String bypassMoreIssues(int count) {
    return '… ve $count tane daha';
  }

  @override
  String get bypassReconnect => 'Yeni listeyi kullanmak için yeniden bağlanın';

  @override
  String get bypassDefaultName => 'Listem';

  @override
  String get bypassPastedName => 'Yapıştırılan liste';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsServers => 'Sunucular';

  @override
  String get manageServers => 'Sunucuları yönet';

  @override
  String get manageServersHint => 'Sunucular ve abonelikler';

  @override
  String get settingsConnection => 'Bağlantı';

  @override
  String get vpnMode => 'VPN modu (tüm trafik)';

  @override
  String get vpnModeHint => 'Kapalı: yalnızca proxy, VPN izni yok';

  @override
  String get systemProxy => 'Sistem proxy\'sini ayarla';

  @override
  String get systemProxyHint => 'Bağlıyken sistem proxy\'sini ayarlar';

  @override
  String get autoSwitch => 'Hata olunca otomatik geç';

  @override
  String get autoSwitchHint => 'Biri başarısız olursa sıradaki sunucuyu dener';

  @override
  String get bypassLan => 'Yerel ağı atla';

  @override
  String get bypassLanHint =>
      'Yerel cihazlara doğrudan ulaşın (192.168.x.x, 10.x.x.x)';

  @override
  String get bypassListsHint => 'VPN\'i atlayan web siteleri ve adresler';

  @override
  String bypassListsInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count girdi kullanımda',
      one: '1 girdi kullanımda',
    );
    return '$_temp0';
  }

  @override
  String get alwaysOnTitle => 'Her zaman açık VPN ve kill switch';

  @override
  String get alwaysOnHint =>
      'Açılışta yeniden bağlanır ve sızıntıları engeller. Android\'in VPN ayarlarından yapılır.';

  @override
  String get openVpnSettingsFallback =>
      'Ayarlar → Ağ → VPN → Wardkeep yanındaki dişli';

  @override
  String get splitTunneling => 'Bölünmüş tünelleme';

  @override
  String splitSummaryOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Yalnızca seçilen $count uygulama VPN kullanır',
      one: 'Yalnızca seçilen 1 uygulama VPN kullanır',
    );
    return '$_temp0';
  }

  @override
  String splitSummaryBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uygulama VPN\'i atlar',
      one: '1 uygulama VPN\'i atlar',
    );
    return '$_temp0';
  }

  @override
  String get splitSummaryOff => 'Tüm uygulamalar VPN kullanır';

  @override
  String get remoteDns => 'Uzak DNS';

  @override
  String get remoteDnsHelp =>
      'Tünel üzerinden kullanılan DNS, örn. https://1.1.1.1/dns-query veya tls://1.1.1.1';

  @override
  String get settingsApp => 'Uygulama';

  @override
  String get appearance => 'Görünüm';

  @override
  String get themeDark => 'Koyu';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeSystem => 'Sistemi izle';

  @override
  String get language => 'Dil';

  @override
  String get languageSystem => 'Sistem varsayılanı';

  @override
  String get stopOnClose => 'Uygulama kapanınca VPN\'i durdur';

  @override
  String aboutLine(String engine) {
    return 'MIT Lisansı · motor: $engine';
  }

  @override
  String get splitTitle => 'Bölünmüş tünelleme';

  @override
  String get splitAll => 'Tüm uygulamalar';

  @override
  String get splitOnlySelected => 'Yalnızca seçilenler';

  @override
  String get splitBypassSelected => 'Seçilenleri atla';

  @override
  String get splitHelpOffMode => 'Her uygulama VPN kullanır.';

  @override
  String get splitHelpOnlyNone => 'Uygulama seçilmedi: hepsi VPN kullanır.';

  @override
  String splitHelpOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Yalnızca $count uygulama VPN kullanır.',
      one: 'Yalnızca 1 uygulama VPN kullanır.',
    );
    return '$_temp0';
  }

  @override
  String splitHelpBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uygulama doğrudan gider.',
      one: '1 uygulama doğrudan gider.',
    );
    return '$_temp0';
  }

  @override
  String get searchApps => 'Uygulama ara';

  @override
  String get showSystemApps => 'Sistem uygulamalarını göster';

  @override
  String couldNotListApps(String error) {
    return 'Uygulamalar listelenemedi: $error';
  }

  @override
  String get scanTitle => 'QR kodu tara';

  @override
  String get scanTorch => 'Fener';

  @override
  String scanCameraUnavailable(String code) {
    return 'Kamera kullanılamıyor: $code';
  }

  @override
  String get scanPoint => 'Kamerayı bir yapılandırma QR koduna doğrultun';

  @override
  String get credTitle => 'Oturum aç';

  @override
  String credNeeds(String name) {
    return '$name için kullanıcı adı ve parola gerekli.';
  }

  @override
  String get credUsername => 'Kullanıcı adı';

  @override
  String get credPassword => 'Parola';

  @override
  String get logsEmpty => 'Henüz günlük kaydı yok.';

  @override
  String get profilesTitle => 'Sunucuları yönet';

  @override
  String get addSubscriptionTooltip => 'Abonelik ekle';

  @override
  String get testLatencyTooltip => 'Gecikmeyi test et';

  @override
  String get profilesEmptyHint =>
      'Profil yok. Eklemek için İçe aktar\'a dokunun.';

  @override
  String get profilesDragHint =>
      'Sıralamak için basılı tutup sürükleyin. Yedek geçiş bu sırayı izler.';

  @override
  String get myProfiles => 'Profillerim';

  @override
  String subRefreshed(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profil',
      one: '1 profil',
    );
    return '$name: $_temp0';
  }

  @override
  String get refreshTooltip => 'Yenile';

  @override
  String get subDeleteWithProfiles => 'Aboneliği ve profillerini sil';

  @override
  String subUsageOf(String used, String total) {
    return '$used / $total';
  }

  @override
  String subUsed(String used) {
    return '$used kullanıldı';
  }

  @override
  String get subExpired => 'süresi doldu';

  @override
  String get subExpiresToday => 'bugün sona eriyor';

  @override
  String subExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days gün içinde sona eriyor',
      one: '1 gün içinde sona eriyor',
    );
    return '$_temp0';
  }

  @override
  String subUpdated(String ago) {
    return '$ago güncellendi';
  }

  @override
  String get agoJustNow => 'az önce';

  @override
  String agoMinutes(int count) {
    return '$count dk önce';
  }

  @override
  String agoHours(int count) {
    return '$count sa önce';
  }

  @override
  String agoDays(int count) {
    return '$count gün önce';
  }

  @override
  String subRefreshFailed(String error) {
    return 'Son yenileme başarısız: $error';
  }

  @override
  String get importTitle => 'Yapılandırma içe aktar';

  @override
  String get importDescription =>
      'Bir bağlantı, yapılandırma veya abonelik yapıştırın — ya da bir dosya açın veya QR kodu tarayın.';

  @override
  String get importScanQr => 'QR tara';

  @override
  String get importOpenFile => 'Dosya aç';

  @override
  String get importPaste => 'Yapıştır';

  @override
  String get importSubscription => 'Abonelik';

  @override
  String get importTor => 'Tor';

  @override
  String get importAddTor => 'Tor ekle';

  @override
  String get importTorDirect => 'Tor (doğrudan)';

  @override
  String get importTorSnowflake => 'Tor + Snowflake köprüsü';

  @override
  String get importTorObfs4 => 'Tor + obfs4 köprüleri';

  @override
  String importedProfiles(int added, int dupes) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added profil içe aktarıldı',
      one: '1 profil içe aktarıldı',
    );
    String _temp1 = intl.Intl.pluralLogic(
      dupes,
      locale: localeName,
      other: ', $dupes tanesi zaten var',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String importNothing(String reason) {
    return 'Hiçbir şey içe aktarılmadı: $reason';
  }

  @override
  String importPartial(int added, int failed) {
    return '$added içe aktarıldı, $failed başarısız';
  }

  @override
  String get subAddTitle => 'Abonelik ekle';

  @override
  String get subEditTitle => 'Aboneliği düzenle';

  @override
  String get subUrlLabel => 'Abonelik URL\'si';

  @override
  String get subUrlHint =>
      'https://provider.example/sub/… veya nordvpn://<token>';

  @override
  String get subNameLabel => 'Ad (isteğe bağlı)';

  @override
  String get subNameHelp =>
      'Varsayılan olarak sağlayıcının başlığı veya ana makine adı kullanılır';

  @override
  String get subAuthLabel => 'Kimlik doğrulama';

  @override
  String get authNone => 'Yok';

  @override
  String get authBasic => 'Kullanıcı adı ve parola (Basic)';

  @override
  String get authBearer => 'Bearer jetonu';

  @override
  String get authHeader => 'Özel başlık';

  @override
  String get authQuery => 'URL\'de jeton';

  @override
  String get subUsername => 'Kullanıcı adı';

  @override
  String get subPassword => 'Parola';

  @override
  String get subHeaderName => 'Başlık adı';

  @override
  String get subHeaderValue => 'Başlık değeri';

  @override
  String get subParamName => 'Parametre adı';

  @override
  String get subToken => 'Jeton';

  @override
  String get subDownloadLabel => 'İndirme';

  @override
  String get subDownloadHelp => 'Sağlayıcı engellendi mi? VPN yine de alabilir';

  @override
  String get subViaDirect => 'Doğrudan';

  @override
  String get subViaAuto => 'Doğrudan, engelliyse VPN ile';

  @override
  String get subViaTunnel => 'Her zaman VPN üzerinden (önce bağlanın)';

  @override
  String get subErrUrl =>
      'Bir http(s) abonelik URL\'si girin (veya nordvpn://<access token>)';

  @override
  String get subErrHeader => 'Başlık adını girin';

  @override
  String get subErrToken => 'Jetonu girin';

  @override
  String get subAddAndDownload => 'Ekle ve indir';

  @override
  String get subSaveAndRefresh => 'Kaydet ve yenile';

  @override
  String subUpdatedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profil',
      one: '1 profil',
    );
    return 'Abonelik güncellendi: $_temp0';
  }

  @override
  String get flName => 'Ad';

  @override
  String get flServer => 'Sunucu';

  @override
  String get flPort => 'Bağlantı noktası';

  @override
  String get flPassword => 'Parola';

  @override
  String get flUsername => 'Kullanıcı adı';

  @override
  String get flUuid => 'UUID';

  @override
  String get flSecurity => 'Güvenlik';

  @override
  String get flFlow => 'Flow';

  @override
  String get flCipher => 'Şifre';

  @override
  String get flEncryption => 'Şifreleme';

  @override
  String get flAlterId => 'Alter id';

  @override
  String get flTlsServerName => 'TLS sunucu adı (SNI)';

  @override
  String get flTlsFingerprint => 'TLS parmak izi';

  @override
  String get flAlpn => 'ALPN';

  @override
  String get flSkipCertCheck => 'Sertifika denetimini atla';

  @override
  String get flPinnedCert => 'Sabitlenmiş sertifika (PEM)';

  @override
  String get flRealityPublicKey => 'Reality genel anahtarı';

  @override
  String get flRealityShortId => 'Reality kısa kimliği';

  @override
  String get flTransport => 'Aktarım';

  @override
  String get flHostHeader => 'Host başlığı';

  @override
  String get flPath => 'Yol';

  @override
  String get flGrpcService => 'gRPC hizmet adı';

  @override
  String get flPlugin => 'Eklenti';

  @override
  String get flPluginOptions => 'Eklenti seçenekleri';

  @override
  String get flObfuscation => 'Gizleme';

  @override
  String get flObfsPassword => 'Gizleme parolası';

  @override
  String get flUploadMbps => 'Yükleme (Mbps)';

  @override
  String get flDownloadMbps => 'İndirme (Mbps)';

  @override
  String get flCongestion => 'Tıkanıklık denetimi';

  @override
  String get flUdpRelay => 'UDP aktarma modu';

  @override
  String get flUseQuic => 'HTTP/3 (QUIC) kullan';

  @override
  String get flTunnelAddress => 'Tünel adresiniz';

  @override
  String get flRoutedNetworks => 'Yönlendirilen ağlar';

  @override
  String get flDnsServers => 'DNS sunucuları';

  @override
  String get flMtu => 'MTU';

  @override
  String get flKeepalive => 'Keepalive (saniye)';

  @override
  String get flPrivateKey => 'Özel anahtar';

  @override
  String get flServerPublicKey => 'Sunucu genel anahtarı';

  @override
  String get flPresharedKey => 'Önceden paylaşılan anahtar';

  @override
  String get flReservedBytes => 'Ayrılmış baytlar';

  @override
  String get flAuthentication => 'Kimlik doğrulama';

  @override
  String get flAuthDigest => 'Doğrulama özeti';

  @override
  String get flCaCert => 'CA sertifikası (PEM)';

  @override
  String get flClientCert => 'İstemci sertifikası (PEM)';

  @override
  String get flClientKey => 'İstemci anahtarı (PEM)';

  @override
  String get flControlWrap => 'Kontrol kanalı koruması';

  @override
  String get flControlWrapKey => 'Kontrol kanalı anahtarı';

  @override
  String get flKeyDirection => 'Anahtar yönü';

  @override
  String get flRemoteCertType => 'Uzak sertifika türü';

  @override
  String get flVerifyServerName => 'Sunucu adını doğrula';

  @override
  String get flYourIdentity => 'Kimliğiniz';

  @override
  String get flServerIdentity => 'Sunucu kimliği';

  @override
  String get flServerCertTrust => 'Güvenilecek sunucu sertifikası (PEM)';

  @override
  String get flUseSystemIke => 'Telefonun kendi IKEv2 istemcisini kullan';

  @override
  String get flUseTcp => 'TCP kullan';

  @override
  String get flHostKeys => 'Ana makine anahtarları';

  @override
  String get flPrivateKeyPem => 'Özel anahtar (PEM)';

  @override
  String get flKeyPassphrase => 'Anahtar parolası';

  @override
  String get flBridges => 'Köprüler';

  @override
  String get flBridgeLines => 'Köprü satırları';

  @override
  String get flJc => 'Jc (gereksiz paket sayısı)';

  @override
  String get flSignaturePacket => 'I1 (imza paketi)';

  @override
  String get hpAuthorizedKeys =>
      'authorized_keys biçimi; boşsa her anahtar kabul edilir';

  @override
  String get hpIkeTcp =>
      'UDP\'yi engelleyen ağlar için IKE ve ESP\'yi TCP üzerinden taşır';

  @override
  String get hpDefaultsToServer => 'Varsayılan olarak sunucu adresi kullanılır';

  @override
  String get hpTorBridges =>
      'Boşsa Tor\'a doğrudan bağlanır veya aşağıdaki köprü satırlarını kullanır';

  @override
  String get hpExampleAddress => 'Örneğin 10.8.0.2/32';

  @override
  String get hpExamplePlugin => 'Örneğin shadow-tls veya v2ray-plugin';

  @override
  String get hpHostOrIp => 'Ana makine adı veya IP adresi';

  @override
  String get hpNeededReality => 'Güvenlik reality olduğunda gerekir';

  @override
  String get hpOnlySelfSigned =>
      'Yalnızca sabitleyemediğiniz, kendinden imzalı sertifikalı sunucular için';

  @override
  String get hpSafeSstp =>
      'SSTP için güvenli: parola değişimi sunucuyu doğrular';

  @override
  String get hpHysteriaObfs =>
      'Hysteria 2 için salamander; Hysteria 1 için gizleme parolası';

  @override
  String get hpTrustCert => 'Sistemin otoriteleri yerine bu sertifikaya güven';

  @override
  String get hpWhichBrowser =>
      'Hangi tarayıcının TLS el sıkışması taklit edilsin';

  @override
  String get hpWarpReserved => 'WARP yapılandırmalarındaki gibi üç sayı';

  @override
  String get hpOneBridgePerLine =>
      'Her satıra bir köprü, torrc\'deki gibi \"Bridge \" olmadan';

  @override
  String get exitTitle => 'Çıkış adresini ve ülkeyi göster';

  @override
  String get exitHint =>
      'IP\'nizi ve ülkenizi api.country.is\'e sorar, bağlı değilken de.';

  @override
  String exitIpLabel(String ip) {
    return 'IP $ip';
  }

  @override
  String connectedTo(String place) {
    return '$place konumuna bağlandı';
  }

  @override
  String get noticesTitle => 'Açık kaynak lisansları';

  @override
  String get noticesIntro =>
      'Wardkeep MIT lisanslıdır. Aşağıdaki yazılımları da içerir, her biri kendi lisansı altındadır.';

  @override
  String noticesMore(int count) {
    return '+$count tane daha';
  }

  @override
  String noticesPackages(int count) {
    return '$count paket';
  }

  @override
  String get noticesLoadFailed => 'Lisans listesi okunamadı.';

  @override
  String formRequired(String label) {
    return '$label gerekli';
  }

  @override
  String formNotNumber(String label) {
    return '$label bir tam sayı olmalı';
  }

  @override
  String formNotBool(String label) {
    return '$label açık veya kapalı olmalı';
  }

  @override
  String formBadChoice(String label, String value, String choices) {
    return '$label: $value, $choices içinde yok';
  }

  @override
  String get formRealityOnlyVless =>
      'Reality yalnızca VLESS için kullanılabilir';

  @override
  String formUnknownSecurity(String value) {
    return 'Bilinmeyen güvenlik: $value';
  }

  @override
  String get formReservedBytes =>
      'Ayrılmış baytlar 0 ile 255 arasında sayılar olmalı';

  @override
  String get formRealityKeyRequired =>
      'Güvenlik Reality olduğunda Reality genel anahtarı gerekli';

  @override
  String get importUnsupported =>
      'Bu, Wardkeep\'in okuyabileceği bir sunucu bağlantısı, abonelik veya yapılandırma değil';

  @override
  String importUnsupportedScheme(String scheme) {
    return '$scheme:// ile başlayan bağlantılar desteklenmiyor';
  }

  @override
  String get importXrayServer =>
      'Bu bir Xray sunucu yapılandırması. İstemci profili olarak değil, sunucuda içe aktarın (omnitun-server import xray)';

  @override
  String get subAuthFailed =>
      'Abonelik oturum açmayı reddetti. Kullanıcı adını, parolayı veya jetonu denetleyin';

  @override
  String subHttp(String status) {
    return 'Abonelik sunucusu HTTP $status yanıtı verdi';
  }

  @override
  String get subTooLarge => 'Abonelik 10 MB\'tan büyük';

  @override
  String get subBadUrl => 'Bu geçerli bir abonelik adresi değil';

  @override
  String get bypassIssueEmptyExpression => 'boş ifade';

  @override
  String get bypassIssueBadExpression => 'geçerli bir ifade değil';

  @override
  String get bypassIssueBadName => 'geçerli bir ad değil';

  @override
  String get bypassIssueGeo =>
      'geo listeleri desteklenmiyor; alan adlarını veya aralıkları yazın';

  @override
  String get bypassIssueBadEntry => 'bir alan adı, adres veya aralık değil';

  @override
  String bypassIssueTooMany(int limit) {
    return '$limit girdiden fazla: kalanı yok sayılır';
  }

  @override
  String get torStarting => 'Tor başlatılıyor';

  @override
  String torBootstrap(int percent) {
    return 'Tor\'a bağlanılıyor %$percent';
  }

  @override
  String get torCircuit => 'Tor devresi oluşturuluyor';

  @override
  String torRetry(int attempt, int attempts) {
    return 'Tor yeniden deneniyor ($attempt/$attempts)';
  }

  @override
  String get importNoServer => 'Bu metinde geçerli sunucu bulunamadı';

  @override
  String importJsonSyntax(String found, int line, int column) {
    return 'Bu geçerli bir JSON değil: $line. satır, $column. sütunda beklenmeyen $found karakteri.';
  }

  @override
  String importJsonEnd(int line, int column) {
    return 'Bu geçerli bir JSON değil: metin çok erken bitiyor ($line. satır, $column. sütun). Kapanış parantezi, küme ayracı veya tırnak eksik olabilir.';
  }

  @override
  String get importJsonNoServer =>
      'Bu JSON geçerli, ancak içinde hiçbir proxy sunucusu yok. VLESS, VMess, Trojan, Shadowsocks veya benzeri bir çıkışı olan bir istemci yapılandırması kullanın.';

  @override
  String importJsonNoServerFound(String found) {
    return 'Bu JSON geçerli, ancak içinde hiçbir proxy sunucusu yok (içinde $found var). VLESS, VMess, Trojan, Shadowsocks veya benzeri bir çıkışı olan bir istemci yapılandırması kullanın.';
  }

  @override
  String importTooLarge(int limit) {
    return 'İçe aktarmak için çok büyük (sınır $limit MB).';
  }

  @override
  String get importFileEmpty => 'Dosya boş.';

  @override
  String get importFileNotText =>
      'Dosya, Wardkeep\'in okuyabileceği bir metin değil (ikili görünüyor ya da kodlaması bilinmiyor). UTF-8 veya UTF-16 bir metin dosyası kullanın.';

  @override
  String get importFileNoPermission =>
      'Wardkeep\'in bu dosyayı okuma izni yok.';

  @override
  String get importFileMissing =>
      'Dosya bulunamadı. Taşınmış veya silinmiş olabilir.';

  @override
  String get importDetails => 'Ayrıntılar';

  @override
  String get importJsonNote =>
      'JSON yapılandırması (Xray, sing-box, SIP008) veya bunların bir listesi de, metin ya da dosya olarak kullanılabilir.';

  @override
  String get ipdbTitle => 'Çevrimdışı ülke veritabanı';

  @override
  String get ipdbIntro =>
      'Veritabanını bir kez indirin; Wardkeep bir sunucunun veya adresin ülkesini bir web sitesine sormadan kendisi bulur.';

  @override
  String ipdbSizeNote(String size) {
    return 'Yaklaşık $size · ücretsiz veri (kamu malı)';
  }

  @override
  String get ipdbDownload => 'İndir';

  @override
  String get ipdbContinue => 'Devam et';

  @override
  String get ipdbPause => 'Duraklat';

  @override
  String get ipdbUpdate => 'Güncelle';

  @override
  String get ipdbDelete => 'Sil';

  @override
  String get ipdbDeleteTitle => 'Veritabanı silinsin mi?';

  @override
  String get ipdbUse => 'Veritabanını kullan';

  @override
  String get ipdbStepV4 => 'IPv4';

  @override
  String get ipdbStepV6 => 'IPv6';

  @override
  String get ipdbStepPrepare => 'Hazırla';

  @override
  String get ipdbPreparing => 'Hazırlanıyor…';

  @override
  String get ipdbReady => 'Hazır';

  @override
  String ipdbStoppedAt(int percent) {
    return '%$percent noktasında durdu. Devam et tam oradan sürdürür.';
  }

  @override
  String ipdbFailed(String reason) {
    return 'İndirme başarısız: $reason';
  }

  @override
  String ipdbReadyLine(String ranges, String size) {
    return '$ranges aralık · $size';
  }

  @override
  String ipdbVersion(String version, String date) {
    return 'Sürüm $version · $date';
  }

  @override
  String ipdbLeft(String time) {
    return '$time kaldı';
  }

  @override
  String get ipdbSource =>
      'Veri: bölgesel internet kayıt kuruluşları ve ASN duyuruları (CC0), ip-location-db projesinden.';

  @override
  String get ipdbSubNone => 'Ülkeleri bir web sitesine sormadan bul';

  @override
  String ipdbSubReady(String size) {
    return 'Açık · $size';
  }

  @override
  String ipdbSubOff(String size) {
    return 'Kapalı · $size';
  }

  @override
  String ipdbSubDownloading(int percent) {
    return 'İndiriliyor %$percent';
  }

  @override
  String ipdbSubStopped(int percent) {
    return '%$percent noktasında durdu';
  }

  @override
  String get ipdbErrNetwork => 'veri sunucularına bağlantı yok';

  @override
  String get ipdbErrMirrors => 'veri sunucuları doğru dosyayı göndermedi';

  @override
  String get bypassCountriesTitle => 'Ülkeler';

  @override
  String get bypassCountriesNone => 'Ülke seçilmedi';

  @override
  String bypassCountriesMore(String names, int count) {
    return '$names +$count';
  }

  @override
  String get bypassCountriesIntro =>
      'Seçilen ülkelere giden trafik VPN\'i atlayıp doğrudan internete gider. Adres aralıkları çevrimdışı ülke veritabanından gelir.';

  @override
  String get bypassCountriesGetDb => 'Ülke veritabanını al';

  @override
  String get bypassCountriesSearch => 'Ülke ara';

  @override
  String get windowMinimize => 'Küçült';

  @override
  String get windowMaximize => 'Büyüt';

  @override
  String get windowRestore => 'Geri yükle';

  @override
  String get windowClose => 'Kapat';

  @override
  String get globeRecenter => 'Dünya\'yı ortala';

  @override
  String get bypassCountriesZoneIntro =>
      'İşaretlediğiniz her ülke, adres aralıklarını indirir (birkaç kilobayt). Tam çevrimdışı veritabanı daha kesindir ve indirme gerektirmez.';

  @override
  String get bypassCountriesDownloading => 'İndiriliyor…';

  @override
  String get bypassCountriesFailed =>
      'İndirilemedi. Yeniden denemek için dokunun.';

  @override
  String get bypassCountriesYourServer =>
      'Seçtiğiniz sunucu burada: trafiği de VPN\'i atlar.';

  @override
  String get ipv6Title => 'IPv6';

  @override
  String get ipv6Hint =>
      'Kapalı: yalnızca IPv4 kullanılır; IPv6 bağlantıları reddedilir, VPN dışına gönderilmez.';

  @override
  String get mtuTitle => 'MTU';

  @override
  String get mtuAuto => 'Varsayılan';

  @override
  String get mtuHelp =>
      'Tünelin paket boyutu (yalnızca VPN modu). Mobil ağda bazı siteler takılırsa 1280 ile 1420 arasını deneyin. Boş bırakmak varsayılandır.';

  @override
  String mtuInvalid(int min, int max) {
    return '$min ile $max arasında bir sayı girin.';
  }

  @override
  String get trayOpen => 'Wardkeep\'i aç';

  @override
  String get trayQuit => 'Çık';

  @override
  String get traySwitchServer => 'Sunucuyu değiştir';

  @override
  String get keepInTray => 'Sistem tepsisinde çalışmaya devam et';

  @override
  String get keepInTrayHint =>
      'Pencereyi kapatmak onu yalnızca gizler. Uygulamayı ve VPN\'i sonlandırmak için tepsi menüsünden “Çık”ı seçin.';

  @override
  String usageUsed(String size) {
    return '$size kullanıldı';
  }

  @override
  String get menuResetUsage => 'Veri kullanımını sıfırla';

  @override
  String get dnsPickerHelp =>
      'Site adları, seçtiğiniz çözümleyici tarafından VPN üzerinden sorgulanır. DNSCrypt ayrıca yanıtın o çözümleyiciden geldiğini kanıtlar.';

  @override
  String get dnsDefault => 'Varsayılan';

  @override
  String get dnsSectionDnscrypt => 'DNSCrypt · DNSSEC, günlüksüz, filtresiz';

  @override
  String get dnsCustom => 'Özel';

  @override
  String get dnsCustomLabel => 'Adres veya DNS stamp';

  @override
  String get dnsAnonymized => 'Anonim DNSCrypt';

  @override
  String get dnsAnonymizedHint =>
      'Sorgular bir aktarıcıdan geçer; çözümleyici nereden geldiklerini hiç görmez';

  @override
  String get dnsAnonymizedNeedsDnscrypt =>
      'Bunu kullanmak için bir DNSCrypt çözümleyici seçin';

  @override
  String get dnsRelay => 'Aktarıcı';

  @override
  String get dnsRelayChoose => 'Bir aktarıcı seçin';

  @override
  String get dnsRelayAutomatic => 'Otomatik (başka işletmeci)';

  @override
  String get dnsErrAddress =>
      'https://, tls://, tcp:// veya udp:// ile başlayan bir adres ya da sdns:// stamp girin';

  @override
  String get dnsErrDamaged => 'Bu stamp bozuk veya yarım. Yeniden kopyalayın.';

  @override
  String get dnsErrUnsupported => 'Bu tür stamp desteklenmiyor';

  @override
  String get dnsErrRelayStamp => 'Bu bir aktarıcı stamp\'i, çözümleyici değil';

  @override
  String dnsLine(String resolver) {
    return 'DNS: $resolver';
  }

  @override
  String get dnsLimits =>
      'Bu, sorguladığınız adları korur. Ardından hangi sitelere bağlandığınızı gizlemez.';

  @override
  String get dnsAnonymizedShort => 'anonim';

  @override
  String get flAuthKey => 'Kimlik doğrulama anahtarı';

  @override
  String get flControlServer => 'Kontrol sunucusu';

  @override
  String get flDeviceName => 'Cihaz adı';

  @override
  String get flExitDevice => 'Çıkış cihazı';

  @override
  String get flUseSubnets => 'Diğer cihazların alt ağlarını kullan';

  @override
  String get flTempDevice => 'Geçici cihaz';

  @override
  String get hpAuthKey =>
      'Tailscale yönetim sayfasından alınan önceden yetkilendirilmiş bir anahtar ya da headscale preauthkeys create ile oluşturulmuş';

  @override
  String get hpControlServer =>
      'Boş bırakılırsa Tailscale kullanılır; Headscale için adresi, örneğin https://hs.example.com';

  @override
  String get hpDeviceName =>
      'Bu cihazın ağdaki adı; boşsa cihazın kendi adı kullanılır';

  @override
  String get hpExitDevice =>
      'İnternet bağlantısı kullanılacak cihazın adı veya adresi; boşsa yalnızca kendi cihazlarınıza ulaşılır';

  @override
  String get hpTempDevice => 'Çevrimdışı olunca ağdan kaldırılır';

  @override
  String get devicesTitle => 'Cihazlarım';

  @override
  String get devicesNotConnected =>
      'Cihazlarınızı görmek için bir Tailscale veya Headscale profiline bağlanın.';

  @override
  String get devicesJoining => 'Ağa katılınıyor…';

  @override
  String get devicesLoginNeeded =>
      'Ağ bu cihazın anahtarını kabul etmedi. Yeni bir anahtar oluşturup profili düzenleyin.';

  @override
  String get devicesEmpty => 'Bu ağda henüz başka cihaz yok.';

  @override
  String get devicesThisDevice => 'Bu cihaz';

  @override
  String get deviceOnline => 'Çevrimiçi';

  @override
  String get deviceOffline => 'Çevrimdışı';

  @override
  String deviceLastSeen(String when) {
    return 'Son görülme $when';
  }

  @override
  String get deviceUseAsExit => 'Çıkış olarak kullan';

  @override
  String get deviceStopExit => 'Çıkış olarak kullanmayı bırak';

  @override
  String get deviceIsExit => 'Çıkış kullanımda';

  @override
  String get devicesExitHint =>
      'Cihazlarınızdan birini çıkış olarak kullanın: tüm trafiğiniz onun bağlantısından çıkar.';

  @override
  String get deviceCopyName => 'Adı kopyala';

  @override
  String get deviceCopyAddress => 'Adresi kopyala';

  @override
  String get deviceCopied => 'Kopyalandı';

  @override
  String get errMeshExit =>
      'Bu cihaz şu anda çıkış olarak kullanılamıyor. Çevrimiçi olmalı ve bağlantısını sunmalı.';
}
