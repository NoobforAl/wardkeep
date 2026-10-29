// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appName => 'Wardkeep';

  @override
  String get actionSave => 'Simpan';

  @override
  String get actionCancel => 'Batal';

  @override
  String get actionDelete => 'Hapus';

  @override
  String get actionEdit => 'Ubah';

  @override
  String get actionReset => 'Atur ulang';

  @override
  String get actionSkip => 'Lewati';

  @override
  String get actionNext => 'Lanjut';

  @override
  String get actionImport => 'Impor';

  @override
  String get actionDownload => 'Unduh';

  @override
  String get actionCopyAll => 'Salin semua';

  @override
  String get actionClear => 'Bersihkan';

  @override
  String get tooltipMore => 'Lainnya';

  @override
  String get tooltipShow => 'Tampilkan';

  @override
  String get tooltipHide => 'Sembunyikan';

  @override
  String get searchHint => 'Cari';

  @override
  String get tooltipLogs => 'Log';

  @override
  String get tooltipSettings => 'Pengaturan';

  @override
  String get statusConnected => 'Terhubung';

  @override
  String get statusConnecting => 'Menghubungkan…';

  @override
  String get statusDisconnecting => 'Memutuskan…';

  @override
  String get statusError => 'Koneksi gagal';

  @override
  String get statusNoInternet => 'Tidak ada koneksi internet';

  @override
  String get statusDisconnected => 'Tidak terhubung';

  @override
  String get stagePermission => 'Menunggu izin VPN';

  @override
  String get stageNetworkCheck => 'Memeriksa koneksi internet';

  @override
  String get stagePrepare => 'Menyiapkan konfigurasi';

  @override
  String get stageEngineStart => 'Memulai mesin';

  @override
  String get stageTunnelUp => 'Membuka terowongan';

  @override
  String get stageHandshake => 'Menghubungi server';

  @override
  String get stageConnected => 'Terhubung';

  @override
  String get buttonConnect => 'Hubungkan';

  @override
  String get buttonDisconnect => 'Putuskan';

  @override
  String get buttonCancel => 'Batal';

  @override
  String get locationLabel => 'Lokasi';

  @override
  String get noServers => 'Tidak ada server';

  @override
  String get noServersHint => 'Tambahkan satu untuk memulai';

  @override
  String get automatic => 'Otomatis';

  @override
  String get automaticHint => 'Server tercepat, berpindah saat gagal';

  @override
  String get anyServerInCountry => 'Server mana pun di negara ini';

  @override
  String get torNetwork => 'Jaringan Tor';

  @override
  String get torHopBridge => 'Jembatan';

  @override
  String get torHopEntry => 'Masuk';

  @override
  String get torHopRelay => 'Relai';

  @override
  String get torHopExit => 'Keluar';

  @override
  String get torHopHidden => 'Tersembunyi';

  @override
  String get torHopUnknown => 'Tidak diketahui';

  @override
  String get hopYou => 'Anda';

  @override
  String get hopYouNote =>
      'Di sinilah Anda sebenarnya berada. Lalu lintas Anda dimulai dari sini.';

  @override
  String get hopServer => 'Server';

  @override
  String get hopServerNote =>
      'Lalu lintas Anda dikirim terenkripsi ke server ini dan keluar dari sini, sehingga situs web melihat alamatnya, bukan alamat Anda.';

  @override
  String get hopBridgeNote =>
      'Lompatan pertama Anda. Jembatan menyembunyikan dari jaringan Anda bahwa Anda memakai Tor. Ia tahu siapa Anda, tetapi tidak tahu ke mana Anda pergi.';

  @override
  String get hopEntryNote =>
      'Relai pertama. Ia tahu alamat Anda, tetapi tidak tahu apa yang Anda kunjungi.';

  @override
  String get hopRelayNote =>
      'Relai tengah. Ia tidak tahu siapa Anda maupun apa yang Anda kunjungi; ia hanya meneruskan lalu lintas.';

  @override
  String get hopExitNote =>
      'Relai terakhir. Ia melihat ke mana Anda pergi, tetapi tidak tahu siapa Anda, dan situs web melihat alamatnya.';

  @override
  String get hopHiddenNote =>
      'Lokasi jembatan disembunyikan oleh transportnya, jadi tidak bisa ditampilkan di peta.';

  @override
  String get hopTransport => 'Transport';

  @override
  String get hopProtocol => 'Protokol';

  @override
  String get hopAddress => 'Alamat';

  @override
  String get hopLatency => 'Latensi';

  @override
  String get hopExitAddress => 'Alamat keluar';

  @override
  String get menuNewGroup => 'Grup baru';

  @override
  String get groupNameHint => 'Nama grup';

  @override
  String get groupCreate => 'Buat';

  @override
  String get menuMoveToGroup => 'Pindahkan ke grup';

  @override
  String get groupMoveTitle => 'Pindahkan ke';

  @override
  String get menuRenameGroup => 'Ganti nama';

  @override
  String get menuDeleteGroup => 'Hapus grup';

  @override
  String get groupDeleteTitle => 'Hapus grup ini?';

  @override
  String groupDeleteBody(String name) {
    return 'Server di dalamnya tidak dihapus. Server dikembalikan ke $name.';
  }

  @override
  String get groupEmptyHint =>
      'Belum ada server. Buka menu server dan pilih Pindahkan ke grup.';

  @override
  String get menuShareGroupFile => 'Simpan sebagai file teks';

  @override
  String get menuCopyGroupLinks => 'Salin tautan';

  @override
  String groupSavedToast(String servers) {
    return 'Tersimpan: $servers';
  }

  @override
  String groupCopiedToast(String servers) {
    return 'Tersalin: $servers';
  }

  @override
  String get groupNothingToShare =>
      'Tidak ada server ini yang punya tautan berbagi.';

  @override
  String groupSkipped(String servers) {
    return 'Dilewati, tanpa tautan berbagi: $servers';
  }

  @override
  String get emptyTitle => 'Belum ada profil';

  @override
  String get emptyHint => 'Impor konfigurasi, tautan, atau langganan.';

  @override
  String get importConfig => 'Impor konfigurasi';

  @override
  String failoverToast(String to, String from) {
    return 'Beralih ke $to — $from berhenti merespons';
  }

  @override
  String get unknownLocation => 'Lokasi tidak dikenal';

  @override
  String errorFailed(String stage, String reason) {
    return '$stage gagal: $reason';
  }

  @override
  String get errTimeout => 'server tidak menjawab tepat waktu';

  @override
  String get errRefused => 'server menolak koneksi';

  @override
  String get errReset => 'koneksi direset oleh jaringan';

  @override
  String get errNoRoute => 'server tidak dapat dijangkau dari jaringan ini';

  @override
  String get errNetworkUnreachable => 'jaringan tidak dapat dijangkau';

  @override
  String get errDns => 'nama server tidak dapat diselesaikan';

  @override
  String get errTls => 'sertifikat keamanan server ditolak';

  @override
  String get errAuth => 'nama pengguna atau kata sandi ditolak';

  @override
  String get errClosed => 'server menutup koneksi';

  @override
  String get errCertDate =>
      'sertifikat server sudah kedaluwarsa atau belum berlaku (periksa juga tanggal dan jam ponsel ini)';

  @override
  String get errCertUntrusted =>
      'sertifikat server tidak ditandatangani oleh otoritas tepercaya';

  @override
  String get errCertName =>
      'sertifikat server dibuat untuk nama yang berbeda dari nama tujuan koneksi';

  @override
  String get errTlsKeys =>
      'kunci bersama (tls-auth atau tls-crypt) tidak cocok dengan milik server';

  @override
  String get errReality =>
      'server menolak handshake Reality (periksa kunci publik, short ID, dan nama server)';

  @override
  String get errNoHandshake =>
      'server tidak menjawab handshake (periksa kunci, endpoint, dan pastikan port UDP-nya terbuka)';

  @override
  String get errUdpBlocked =>
      'server tidak menjawab lewat UDP; jaringan ini mungkin memblokirnya, coba server berbasis TCP';

  @override
  String get errPortInUse => 'port lokal sudah dipakai aplikasi lain';

  @override
  String get errTorTimeout =>
      'Tor tidak selesai terhubung tepat waktu. Jaringan ini mungkin memblokir Tor; gunakan bridge (Snowflake atau obfs4)';

  @override
  String get errTorBridgeTimeout =>
      'Tor tidak selesai terhubung tepat waktu. Bridge mungkin diblokir atau kelebihan beban; coba jenis bridge lain (Snowflake atau obfs4)';

  @override
  String get errTorBadBridge =>
      'ada baris bridge Tor yang tidak valid (perlu transport, alamat, dan sidik jari)';

  @override
  String get errTorMissing => 'build ini tidak menyertakan klien Tor';

  @override
  String get errPermission => 'izin VPN tidak diberikan';

  @override
  String get errCoreLost => 'Koneksi ke layanan inti terputus';

  @override
  String get selectLocation => 'Pilih lokasi';

  @override
  String get testSpeedTooltip => 'Uji kecepatan semua server';

  @override
  String get addServersTooltip => 'Tambah server';

  @override
  String get menuImport => 'Impor konfigurasi, tautan, atau QR';

  @override
  String get menuNewServer => 'Tambah server secara manual';

  @override
  String get menuSubscription => 'Tambah langganan';

  @override
  String get menuManage => 'Kelola server dan langganan';

  @override
  String get menuSetDefault => 'Jadikan default';

  @override
  String get badgeDefault => 'Default';

  @override
  String get menuDeleteAll => 'Hapus semua server';

  @override
  String get deleteAllTitle => 'Hapus semua server?';

  @override
  String get deleteAllBody =>
      'Semua server dan langganan yang Anda tambahkan akan dihapus. Koneksi Tor bawaan tetap ada, dan aplikasi kembali ke sana.';

  @override
  String get menuRestoreTor => 'Pulihkan default Tor';

  @override
  String get deletedAllToast => 'Semua server dihapus';

  @override
  String defaultSetToast(String name) {
    return '$name kini jadi default';
  }

  @override
  String serversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count server',
    );
    return '$_temp0';
  }

  @override
  String get otherGroup => 'Lainnya';

  @override
  String get torGroup => 'Tor';

  @override
  String get noServersYet => 'Belum ada server';

  @override
  String get importHintShort =>
      'Impor file konfigurasi, tautan, atau langganan.';

  @override
  String get showServers => 'Tampilkan server';

  @override
  String get hideServers => 'Sembunyikan server';

  @override
  String get menuEditServer => 'Ubah';

  @override
  String get menuBridgeSettings => 'Pengaturan bridge';

  @override
  String get menuShare => 'Bagikan tautan atau QR';

  @override
  String get menuSetCountry => 'Atur negara';

  @override
  String get menuCredentials => 'Nama pengguna dan kata sandi';

  @override
  String needsSignIn(String address) {
    return '$address · perlu masuk';
  }

  @override
  String get countryOfServer => 'Negara server ini';

  @override
  String get guessFromName => 'Tentukan dari nama';

  @override
  String get latencyNotTested => 'Belum diuji';

  @override
  String get latencyUnreachable => 'Tidak terjangkau';

  @override
  String get latencyTimeout => 'waktu habis';

  @override
  String latencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String get unknownCountry => 'Negara tidak dikenal';

  @override
  String get addServerTitle => 'Tambah server';

  @override
  String get addServerIntro =>
      'Pilih protokol. Tautan atau QR lebih cepat: gunakan Impor.';

  @override
  String newServerTitle(String label) {
    return 'Server $label baru';
  }

  @override
  String get editServerTitle => 'Ubah server';

  @override
  String get torBridgesTitle => 'Bridge Tor';

  @override
  String get subscriptionEditNote =>
      'Server ini berasal dari langganan: perubahan Anda akan ditimpa saat langganan disegarkan.';

  @override
  String get moreOptions => 'Opsi lainnya';

  @override
  String get countryRow => 'Negara';

  @override
  String get countryAuto => 'Ditentukan dari nama dan alamat';

  @override
  String get alreadyInList => 'Server ini sudah ada di daftar';

  @override
  String get choiceDefault => 'Default';

  @override
  String get torBridgesNone => 'Tidak ada (langsung, atau baris di bawah)';

  @override
  String get torBridgesSnowflake => 'Snowflake';

  @override
  String get torBridgesObfs4 => 'obfs4 (bridge bawaan)';

  @override
  String get listHelper => 'Pisahkan nilai dengan koma';

  @override
  String get fillPaste => 'Tempel';

  @override
  String get fillFile => 'File';

  @override
  String get fillScanQr => 'Pindai QR';

  @override
  String get openTextFile => 'Buka file teks';

  @override
  String couldNotReadFile(String error) {
    return 'Tidak dapat membaca file: $error';
  }

  @override
  String fieldRequired(String label) {
    return '$label *';
  }

  @override
  String formNoEditor(String protocol) {
    return 'Tidak ada editor untuk $protocol';
  }

  @override
  String get shareScanHint => 'Pindai dengan Wardkeep, atau salin tautan.';

  @override
  String get shareCopy => 'Salin tautan';

  @override
  String get shareCopied => 'Tautan disalin';

  @override
  String get shareWarning =>
      'Berisi kata sandi atau kunci server. Bagikan dengan hati-hati.';

  @override
  String shareFailed(String reason) {
    return 'Server ini tidak dapat dibagikan sebagai tautan: $reason';
  }

  @override
  String get shareTooLong => 'Terlalu panjang untuk kode QR: salin tautannya';

  @override
  String get obTitle1 => 'Privat dan sederhana';

  @override
  String get obText1 =>
      'Satu layar yang tenang untuk VPN, proxy, dan Tor. Pilih tempat, tekan Hubungkan.';

  @override
  String get obTitle2 => 'Tambahkan server Anda';

  @override
  String get obText2 =>
      'Impor tautan, kode QR, file konfigurasi, atau langganan. Atau tambah server secara manual.';

  @override
  String get obTitle3Android => 'Android akan bertanya sekali';

  @override
  String get obText3Android =>
      'Android akan meminta izin koneksi VPN. Setujui agar terlindungi.';

  @override
  String get obTitle3Desktop => 'Siap kapan pun Anda siap';

  @override
  String get obText3Desktop =>
      'Dimulai dalam mode proxy, tanpa hak khusus. Aktifkan mode VPN di Pengaturan untuk menangkap semua lalu lintas.';

  @override
  String get obAddFirst => 'Tambah server pertama saya';

  @override
  String get bypassTitle => 'Daftar pengecualian';

  @override
  String get bypassAddTooltip => 'Tambah daftar';

  @override
  String get bypassFromClipboard => 'Tempel dari papan klip';

  @override
  String get bypassFromFile => 'Buka file .txt';

  @override
  String get bypassFromUrl => 'Unduh dari tautan';

  @override
  String get bypassType => 'Ketik sendiri';

  @override
  String get bypassClipboardEmpty => 'Papan klip kosong';

  @override
  String get bypassPickFile => 'Buka daftar pengecualian (.txt)';

  @override
  String bypassDownloadFailed(String error) {
    return 'Tidak dapat mengunduh daftar: $error';
  }

  @override
  String get bypassIntro =>
      'Situs dan alamat yang melewati VPN. Satu per baris: example.com, full:www.example.com, keyword:bank, regexp:…, 203.0.113.7 atau 10.0.0.0/8. Baris yang diawali # diabaikan.';

  @override
  String get bypassNoLists => 'Belum ada daftar.';

  @override
  String get bypassTypeList => 'Ketik daftar';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entri',
    );
    return '$_temp0';
  }

  @override
  String get bypassOnlyTitle => 'Hanya yang terdaftar memakai VPN';

  @override
  String get bypassOnlyOn => 'Semua yang lain langsung.';

  @override
  String get bypassOnlyOff => 'Yang terdaftar langsung; sisanya memakai VPN.';

  @override
  String get bypassNothing => 'Tidak ada daftar yang aktif.';

  @override
  String bypassInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entri dipakai',
    );
    return '$_temp0. Berlaku saat koneksi berikutnya.';
  }

  @override
  String get bypassHttpLink => 'Masukkan tautan http(s)';

  @override
  String bypassServerAnswered(int code) {
    return 'server menjawab $code';
  }

  @override
  String get bypassTooLarge => 'daftar lebih besar dari 5 MB';

  @override
  String get bypassDownloadTitle => 'Unduh daftar';

  @override
  String get bypassNewList => 'Daftar baru';

  @override
  String get bypassEditList => 'Ubah daftar';

  @override
  String get bypassName => 'Nama';

  @override
  String get bypassEntriesLabel => 'Entri, satu per baris';

  @override
  String get bypassNoUsable => 'Belum ada entri yang bisa dipakai.';

  @override
  String bypassSummary(String entries, String names, String ranges) {
    return '$entries · $names, $ranges.';
  }

  @override
  String bypassNames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nama',
    );
    return '$_temp0';
  }

  @override
  String bypassRanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alamat atau rentang',
    );
    return '$_temp0';
  }

  @override
  String bypassIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count baris akan diabaikan:',
    );
    return '$_temp0';
  }

  @override
  String bypassMoreIssues(int count) {
    return '… dan $count lagi';
  }

  @override
  String get bypassReconnect => 'Hubungkan ulang untuk memakai daftar baru';

  @override
  String get bypassDefaultName => 'Daftar saya';

  @override
  String get bypassPastedName => 'Daftar tempelan';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsServers => 'Server';

  @override
  String get manageServers => 'Kelola server';

  @override
  String get manageServersHint => 'Server dan langganan';

  @override
  String get settingsConnection => 'Koneksi';

  @override
  String get vpnMode => 'Mode VPN (semua lalu lintas)';

  @override
  String get vpnModeHint => 'Mati: hanya proxy, tanpa izin VPN';

  @override
  String get systemProxy => 'Atur proxy sistem';

  @override
  String get systemProxyHint => 'Atur proxy sistem saat terhubung';

  @override
  String get autoSwitch => 'Beralih otomatis saat gagal';

  @override
  String get autoSwitchHint => 'Coba server berikutnya jika satu gagal';

  @override
  String get bypassLan => 'Lewati jaringan lokal';

  @override
  String get bypassLanHint =>
      'Jangkau perangkat lokal secara langsung (192.168.x.x, 10.x.x.x)';

  @override
  String get bypassListsHint => 'Situs web dan alamat yang melewati VPN';

  @override
  String bypassListsInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entri dipakai',
    );
    return '$_temp0';
  }

  @override
  String get alwaysOnTitle => 'VPN selalu aktif dan kill switch';

  @override
  String get alwaysOnHint =>
      'Terhubung ulang saat boot dan blokir kebocoran. Atur di pengaturan VPN Android.';

  @override
  String get openVpnSettingsFallback =>
      'Pengaturan → Jaringan → VPN → ikon roda gigi di samping Wardkeep';

  @override
  String get splitTunneling => 'Split tunneling';

  @override
  String splitSummaryOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hanya $count aplikasi terpilih yang memakai VPN',
    );
    return '$_temp0';
  }

  @override
  String splitSummaryBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aplikasi melewati VPN',
    );
    return '$_temp0';
  }

  @override
  String get splitSummaryOff => 'Semua aplikasi memakai VPN';

  @override
  String get remoteDns => 'DNS jarak jauh';

  @override
  String get remoteDnsHelp =>
      'DNS yang dipakai lewat terowongan, mis. https://1.1.1.1/dns-query atau tls://1.1.1.1';

  @override
  String get settingsApp => 'Aplikasi';

  @override
  String get appearance => 'Tampilan';

  @override
  String get themeDark => 'Gelap';

  @override
  String get themeLight => 'Terang';

  @override
  String get themeSystem => 'Ikuti sistem';

  @override
  String get language => 'Bahasa';

  @override
  String get languageSystem => 'Default sistem';

  @override
  String get stopOnClose => 'Hentikan VPN saat aplikasi ditutup';

  @override
  String aboutLine(String engine) {
    return 'Lisensi MIT · mesin: $engine';
  }

  @override
  String get splitTitle => 'Split tunneling';

  @override
  String get splitAll => 'Semua aplikasi';

  @override
  String get splitOnlySelected => 'Hanya yang dipilih';

  @override
  String get splitBypassSelected => 'Lewati yang dipilih';

  @override
  String get splitHelpOffMode => 'Setiap aplikasi memakai VPN.';

  @override
  String get splitHelpOnlyNone =>
      'Tidak ada aplikasi dipilih: semua memakai VPN.';

  @override
  String splitHelpOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hanya $count aplikasi yang memakai VPN.',
    );
    return '$_temp0';
  }

  @override
  String splitHelpBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aplikasi langsung.',
    );
    return '$_temp0';
  }

  @override
  String get searchApps => 'Cari aplikasi';

  @override
  String get showSystemApps => 'Tampilkan aplikasi sistem';

  @override
  String couldNotListApps(String error) {
    return 'Tidak dapat menampilkan daftar aplikasi: $error';
  }

  @override
  String get scanTitle => 'Pindai kode QR';

  @override
  String get scanTorch => 'Senter';

  @override
  String scanCameraUnavailable(String code) {
    return 'Kamera tidak tersedia: $code';
  }

  @override
  String get scanPoint => 'Arahkan kamera ke kode QR konfigurasi';

  @override
  String get credTitle => 'Masuk';

  @override
  String credNeeds(String name) {
    return '$name memerlukan nama pengguna dan kata sandi.';
  }

  @override
  String get credUsername => 'Nama pengguna';

  @override
  String get credPassword => 'Kata sandi';

  @override
  String get logsEmpty => 'Belum ada entri log.';

  @override
  String get profilesTitle => 'Kelola server';

  @override
  String get addSubscriptionTooltip => 'Tambah langganan';

  @override
  String get testLatencyTooltip => 'Uji latensi';

  @override
  String get profilesEmptyHint =>
      'Tidak ada profil. Ketuk Impor untuk menambahkan.';

  @override
  String get profilesDragHint =>
      'Tahan dan seret untuk mengubah urutan. Failover mengikuti urutan ini.';

  @override
  String get myProfiles => 'Profil saya';

  @override
  String subRefreshed(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profil',
    );
    return '$name: $_temp0';
  }

  @override
  String get refreshTooltip => 'Segarkan';

  @override
  String get subDeleteWithProfiles => 'Hapus langganan beserta profilnya';

  @override
  String subUsageOf(String used, String total) {
    return '$used dari $total';
  }

  @override
  String subUsed(String used) {
    return '$used terpakai';
  }

  @override
  String get subExpired => 'kedaluwarsa';

  @override
  String get subExpiresToday => 'berakhir hari ini';

  @override
  String subExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'berakhir dalam $days hari',
    );
    return '$_temp0';
  }

  @override
  String subUpdated(String ago) {
    return 'diperbarui $ago';
  }

  @override
  String get agoJustNow => 'baru saja';

  @override
  String agoMinutes(int count) {
    return '$count mnt lalu';
  }

  @override
  String agoHours(int count) {
    return '$count jam lalu';
  }

  @override
  String agoDays(int count) {
    return '$count hari lalu';
  }

  @override
  String subRefreshFailed(String error) {
    return 'Penyegaran terakhir gagal: $error';
  }

  @override
  String get importTitle => 'Impor konfigurasi';

  @override
  String get importDescription =>
      'Tempel tautan, konfigurasi, atau langganan — atau buka file atau pindai kode QR.';

  @override
  String get importScanQr => 'Pindai QR';

  @override
  String get importOpenFile => 'Buka file';

  @override
  String get importPaste => 'Tempel';

  @override
  String get importSubscription => 'Langganan';

  @override
  String get importTor => 'Tor';

  @override
  String get importAddTor => 'Tambah Tor';

  @override
  String get importTorDirect => 'Tor (langsung)';

  @override
  String get importTorSnowflake => 'Tor + bridge Snowflake';

  @override
  String get importTorObfs4 => 'Tor + bridge obfs4';

  @override
  String importedProfiles(int added, int dupes) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added profil diimpor',
    );
    String _temp1 = intl.Intl.pluralLogic(
      dupes,
      locale: localeName,
      other: ', $dupes sudah ada',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String importNothing(String reason) {
    return 'Tidak ada yang diimpor: $reason';
  }

  @override
  String importPartial(int added, int failed) {
    return '$added diimpor, $failed gagal';
  }

  @override
  String get subAddTitle => 'Tambah langganan';

  @override
  String get subEditTitle => 'Ubah langganan';

  @override
  String get subUrlLabel => 'URL langganan';

  @override
  String get subUrlHint =>
      'https://provider.example/sub/… atau nordvpn://<token>';

  @override
  String get subNameLabel => 'Nama (opsional)';

  @override
  String get subNameHelp => 'Default-nya judul penyedia atau nama host';

  @override
  String get subAuthLabel => 'Autentikasi';

  @override
  String get authNone => 'Tidak ada';

  @override
  String get authBasic => 'Nama pengguna & kata sandi (Basic)';

  @override
  String get authBearer => 'Token Bearer';

  @override
  String get authHeader => 'Header kustom';

  @override
  String get authQuery => 'Token di URL';

  @override
  String get subUsername => 'Nama pengguna';

  @override
  String get subPassword => 'Kata sandi';

  @override
  String get subHeaderName => 'Nama header';

  @override
  String get subHeaderValue => 'Nilai header';

  @override
  String get subParamName => 'Nama parameter';

  @override
  String get subToken => 'Token';

  @override
  String get subDownloadLabel => 'Unduh';

  @override
  String get subDownloadHelp =>
      'Penyedia diblokir? VPN tetap bisa mengambilnya';

  @override
  String get subViaDirect => 'Langsung';

  @override
  String get subViaAuto => 'Langsung, atau lewat VPN jika diblokir';

  @override
  String get subViaTunnel => 'Selalu lewat VPN (hubungkan dulu)';

  @override
  String get subErrUrl =>
      'Masukkan URL langganan http(s) (atau nordvpn://<access token>)';

  @override
  String get subErrHeader => 'Masukkan nama header';

  @override
  String get subErrToken => 'Masukkan token';

  @override
  String get subAddAndDownload => 'Tambah dan unduh';

  @override
  String get subSaveAndRefresh => 'Simpan dan segarkan';

  @override
  String subUpdatedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profil',
    );
    return 'Langganan diperbarui: $_temp0';
  }

  @override
  String get flName => 'Nama';

  @override
  String get flServer => 'Server';

  @override
  String get flPort => 'Port';

  @override
  String get flPassword => 'Kata sandi';

  @override
  String get flUsername => 'Nama pengguna';

  @override
  String get flUuid => 'UUID';

  @override
  String get flSecurity => 'Keamanan';

  @override
  String get flFlow => 'Flow';

  @override
  String get flCipher => 'Cipher';

  @override
  String get flEncryption => 'Enkripsi';

  @override
  String get flAlterId => 'Alter id';

  @override
  String get flTlsServerName => 'Nama server TLS (SNI)';

  @override
  String get flTlsFingerprint => 'Sidik jari TLS';

  @override
  String get flAlpn => 'ALPN';

  @override
  String get flSkipCertCheck => 'Lewati pemeriksaan sertifikat';

  @override
  String get flPinnedCert => 'Sertifikat yang disematkan (PEM)';

  @override
  String get flRealityPublicKey => 'Kunci publik Reality';

  @override
  String get flRealityShortId => 'Short id Reality';

  @override
  String get flTransport => 'Transport';

  @override
  String get flHostHeader => 'Header Host';

  @override
  String get flPath => 'Path';

  @override
  String get flGrpcService => 'Nama layanan gRPC';

  @override
  String get flPlugin => 'Plugin';

  @override
  String get flPluginOptions => 'Opsi plugin';

  @override
  String get flObfuscation => 'Obfuskasi';

  @override
  String get flObfsPassword => 'Kata sandi obfuskasi';

  @override
  String get flUploadMbps => 'Unggah (Mbps)';

  @override
  String get flDownloadMbps => 'Unduh (Mbps)';

  @override
  String get flCongestion => 'Kontrol kemacetan';

  @override
  String get flUdpRelay => 'Mode relai UDP';

  @override
  String get flUseQuic => 'Gunakan HTTP/3 (QUIC)';

  @override
  String get flTunnelAddress => 'Alamat terowongan Anda';

  @override
  String get flRoutedNetworks => 'Jaringan yang dirutekan';

  @override
  String get flDnsServers => 'Server DNS';

  @override
  String get flMtu => 'MTU';

  @override
  String get flKeepalive => 'Keepalive (detik)';

  @override
  String get flPrivateKey => 'Kunci privat';

  @override
  String get flServerPublicKey => 'Kunci publik server';

  @override
  String get flPresharedKey => 'Kunci pra-bagi';

  @override
  String get flReservedBytes => 'Byte cadangan';

  @override
  String get flAuthDigest => 'Digest autentikasi';

  @override
  String get flCaCert => 'Sertifikat CA (PEM)';

  @override
  String get flClientCert => 'Sertifikat klien (PEM)';

  @override
  String get flClientKey => 'Kunci klien (PEM)';

  @override
  String get flControlWrap => 'Perlindungan kanal kontrol';

  @override
  String get flControlWrapKey => 'Kunci kanal kontrol';

  @override
  String get flKeyDirection => 'Arah kunci';

  @override
  String get flRemoteCertType => 'Jenis sertifikat jarak jauh';

  @override
  String get flVerifyServerName => 'Verifikasi nama server';

  @override
  String get flHostKeys => 'Kunci host';

  @override
  String get flPrivateKeyPem => 'Kunci privat (PEM)';

  @override
  String get flKeyPassphrase => 'Frasa sandi kunci';

  @override
  String get flBridges => 'Bridge';

  @override
  String get flBridgeLines => 'Baris bridge';

  @override
  String get flJc => 'Jc (jumlah paket sampah)';

  @override
  String get flSignaturePacket => 'I1 (paket tanda tangan)';

  @override
  String get hpAuthorizedKeys =>
      'Format authorized_keys; kosong menerima kunci apa pun';

  @override
  String get hpDefaultsToServer => 'Default-nya alamat server';

  @override
  String get hpTorBridges =>
      'Kosong berarti terhubung ke Tor secara langsung, atau memakai baris bridge di bawah';

  @override
  String get hpExampleAddress => 'Contoh: 10.8.0.2/32';

  @override
  String get hpExamplePlugin => 'Contoh: shadow-tls atau v2ray-plugin';

  @override
  String get hpHostOrIp => 'Nama host atau alamat IP';

  @override
  String get hpNeededReality => 'Diperlukan jika Keamanan adalah reality';

  @override
  String get hpOnlySelfSigned =>
      'Hanya untuk server dengan sertifikat self-signed yang tidak bisa Anda sematkan';

  @override
  String get hpHysteriaObfs =>
      'salamander untuk Hysteria 2; kata sandi obfuskasi untuk Hysteria 1';

  @override
  String get hpTrustCert => 'Percayai sertifikat ini, bukan otoritas sistem';

  @override
  String get hpWhichBrowser => 'Handshake TLS peramban mana yang ditiru';

  @override
  String get hpWarpReserved =>
      'Tiga angka, seperti yang tercantum di konfigurasi WARP';

  @override
  String get hpOneBridgePerLine =>
      'Satu bridge per baris, seperti di torrc tanpa \"Bridge \"';

  @override
  String get exitTitle => 'Tampilkan alamat dan negara keluar';

  @override
  String get exitHint =>
      'Tanyakan api.country.is untuk IP dan negara Anda, juga saat tidak terhubung.';

  @override
  String exitIpLabel(String ip) {
    return 'IP $ip';
  }

  @override
  String connectedTo(String place) {
    return 'Terhubung ke $place';
  }

  @override
  String get noticesTitle => 'Lisensi sumber terbuka';

  @override
  String get noticesIntro =>
      'Wardkeep berlisensi MIT. Aplikasi ini menyertakan perangkat lunak di bawah, masing-masing dengan lisensinya sendiri.';

  @override
  String noticesMore(int count) {
    return '+$count lagi';
  }

  @override
  String noticesPackages(int count) {
    return '$count paket';
  }

  @override
  String get noticesLoadFailed => 'Daftar lisensi tidak dapat dibaca.';

  @override
  String formRequired(String label) {
    return '$label wajib diisi';
  }

  @override
  String formNotNumber(String label) {
    return '$label harus berupa bilangan bulat';
  }

  @override
  String formNotBool(String label) {
    return '$label harus aktif atau mati';
  }

  @override
  String formBadChoice(String label, String value, String choices) {
    return '$label: $value bukan salah satu dari $choices';
  }

  @override
  String get formRealityOnlyVless => 'Reality hanya tersedia untuk VLESS';

  @override
  String formUnknownSecurity(String value) {
    return 'Keamanan tidak dikenal: $value';
  }

  @override
  String get formReservedBytes =>
      'Byte cadangan harus berupa angka 0 sampai 255';

  @override
  String get formRealityKeyRequired =>
      'Kunci publik Reality wajib diisi jika Keamanan adalah Reality';

  @override
  String get importUnsupported =>
      'Ini bukan tautan server, langganan, atau konfigurasi yang dapat dibaca Wardkeep';

  @override
  String importUnsupportedScheme(String scheme) {
    return 'Tautan yang diawali $scheme:// tidak didukung';
  }

  @override
  String get importXrayServer =>
      'Ini konfigurasi server Xray. Impor di server (omnitun-server import xray), bukan sebagai profil klien';

  @override
  String get subAuthFailed =>
      'Langganan menolak login. Periksa nama pengguna, kata sandi, atau token';

  @override
  String subHttp(String status) {
    return 'Server langganan menjawab HTTP $status';
  }

  @override
  String get subTooLarge => 'Langganan lebih besar dari 10 MB';

  @override
  String get subBadUrl => 'Itu bukan alamat langganan yang valid';

  @override
  String get bypassIssueEmptyExpression => 'ekspresi kosong';

  @override
  String get bypassIssueBadExpression => 'bukan ekspresi yang valid';

  @override
  String get bypassIssueBadName => 'bukan nama yang valid';

  @override
  String get bypassIssueGeo =>
      'daftar geo tidak didukung; tulis domain atau rentangnya';

  @override
  String get bypassIssueBadEntry => 'bukan domain, alamat, atau rentang';

  @override
  String bypassIssueTooMany(int limit) {
    return 'lebih dari $limit entri: sisanya diabaikan';
  }

  @override
  String get torStarting => 'Memulai Tor';

  @override
  String torBootstrap(int percent) {
    return 'Menghubungkan ke Tor $percent%';
  }

  @override
  String get torCircuit => 'Membangun sirkuit Tor';

  @override
  String torRetry(int attempt, int attempts) {
    return 'Mencoba Tor lagi ($attempt/$attempts)';
  }

  @override
  String get importNoServer => 'Tidak ada server valid di teks ini';

  @override
  String importJsonSyntax(String found, int line, int column) {
    return 'Ini bukan JSON yang valid: karakter $found tidak terduga di baris $line, kolom $column.';
  }

  @override
  String importJsonEnd(int line, int column) {
    return 'Ini bukan JSON yang valid: teks berakhir terlalu cepat, di baris $line, kolom $column. Mungkin ada kurung, kurung kurawal, atau tanda kutip penutup yang kurang.';
  }

  @override
  String get importJsonNoServer =>
      'JSON ini valid, tetapi tidak berisi server proxy. Gunakan konfigurasi klien dengan outbound VLESS, VMess, Trojan, Shadowsocks, atau sejenisnya.';

  @override
  String importJsonNoServerFound(String found) {
    return 'JSON ini valid, tetapi tidak berisi server proxy (isinya $found). Gunakan konfigurasi klien dengan outbound VLESS, VMess, Trojan, Shadowsocks, atau sejenisnya.';
  }

  @override
  String importTooLarge(int limit) {
    return 'Ini terlalu besar untuk diimpor (batasnya $limit MB).';
  }

  @override
  String get importFileEmpty => 'Berkas kosong.';

  @override
  String get importFileNotText =>
      'Berkas ini bukan teks yang dapat dibaca Wardkeep (tampaknya biner atau berenkode tidak dikenal). Gunakan berkas teks UTF-8 atau UTF-16.';

  @override
  String get importFileNoPermission =>
      'Wardkeep tidak diizinkan membaca berkas ini.';

  @override
  String get importFileMissing =>
      'Berkas tidak ditemukan. Mungkin sudah dipindahkan atau dihapus.';

  @override
  String get importDetails => 'Detail';

  @override
  String get importJsonNote =>
      'Konfigurasi JSON (Xray, sing-box, SIP008) atau daftarnya juga bisa dipakai, sebagai teks atau berkas.';

  @override
  String get ipdbTitle => 'Database negara offline';

  @override
  String get ipdbIntro =>
      'Unduh database sekali, dan Wardkeep menemukan negara server atau alamat sendiri, tanpa bertanya ke situs web.';

  @override
  String ipdbSizeNote(String size) {
    return 'Sekitar $size · data gratis (domain publik)';
  }

  @override
  String get ipdbDownload => 'Unduh';

  @override
  String get ipdbContinue => 'Lanjutkan';

  @override
  String get ipdbPause => 'Jeda';

  @override
  String get ipdbUpdate => 'Perbarui';

  @override
  String get ipdbDelete => 'Hapus';

  @override
  String get ipdbDeleteTitle => 'Hapus database?';

  @override
  String get ipdbUse => 'Gunakan database';

  @override
  String get ipdbStepV4 => 'IPv4';

  @override
  String get ipdbStepV6 => 'IPv6';

  @override
  String get ipdbStepPrepare => 'Siapkan';

  @override
  String get ipdbPreparing => 'Menyiapkan…';

  @override
  String get ipdbReady => 'Siap';

  @override
  String ipdbStoppedAt(int percent) {
    return 'Berhenti di $percent%. Lanjutkan melanjutkan tepat dari titik itu.';
  }

  @override
  String ipdbFailed(String reason) {
    return 'Unduhan gagal: $reason';
  }

  @override
  String ipdbReadyLine(String ranges, String size) {
    return '$ranges rentang · $size';
  }

  @override
  String ipdbVersion(String version, String date) {
    return 'Versi $version · $date';
  }

  @override
  String ipdbLeft(String time) {
    return '$time lagi';
  }

  @override
  String get ipdbSource =>
      'Data: registri internet regional dan pengumuman ASN (CC0), dari proyek ip-location-db.';

  @override
  String get ipdbSubNone => 'Temukan negara tanpa bertanya ke situs web';

  @override
  String ipdbSubReady(String size) {
    return 'Aktif · $size';
  }

  @override
  String ipdbSubOff(String size) {
    return 'Mati · $size';
  }

  @override
  String ipdbSubDownloading(int percent) {
    return 'Mengunduh $percent%';
  }

  @override
  String ipdbSubStopped(int percent) {
    return 'Berhenti di $percent%';
  }

  @override
  String get ipdbErrNetwork => 'tidak ada koneksi ke server data';

  @override
  String get ipdbErrMirrors => 'server data tidak mengirim file yang benar';

  @override
  String get bypassCountriesTitle => 'Negara';

  @override
  String get bypassCountriesNone => 'Belum ada negara dipilih';

  @override
  String bypassCountriesMore(String names, int count) {
    return '$names +$count';
  }

  @override
  String get bypassCountriesIntro =>
      'Lalu lintas ke negara terpilih langsung ke internet, melewati VPN. Rentang alamat mereka berasal dari database negara offline.';

  @override
  String get bypassCountriesGetDb => 'Dapatkan database negara';

  @override
  String get bypassCountriesSearch => 'Cari negara';

  @override
  String get windowMinimize => 'Minimalkan';

  @override
  String get windowMaximize => 'Maksimalkan';

  @override
  String get windowRestore => 'Pulihkan';

  @override
  String get windowClose => 'Tutup';

  @override
  String get windowFullScreen => 'Layar penuh';

  @override
  String get windowExitFullScreen => 'Keluar dari layar penuh';

  @override
  String get globeRecenter => 'Pusatkan Bumi';

  @override
  String get bypassCountriesZoneIntro =>
      'Setiap negara yang dicentang mengunduh rentang alamatnya (beberapa kilobyte). Database offline lengkap lebih akurat dan tidak perlu unduhan.';

  @override
  String get bypassCountriesDownloading => 'Mengunduh…';

  @override
  String get bypassCountriesFailed =>
      'Tidak dapat mengunduh. Ketuk untuk mencoba lagi.';

  @override
  String get bypassCountriesYourServer =>
      'Server pilihan Anda ada di sini: lalu lintasnya juga melewati VPN.';

  @override
  String get ipv6Title => 'IPv6';

  @override
  String get ipv6Hint =>
      'Mati: hanya IPv4 yang dipakai; koneksi IPv6 ditolak, tidak dikirim di luar VPN.';

  @override
  String get mtuTitle => 'MTU';

  @override
  String get mtuAuto => 'Bawaan';

  @override
  String get mtuHelp =>
      'Ukuran paket terowongan (hanya mode VPN). Coba 1280 sampai 1420 jika sebagian situs macet di jaringan seluler. Kosong berarti bawaan.';

  @override
  String mtuInvalid(int min, int max) {
    return 'Masukkan angka dari $min sampai $max.';
  }

  @override
  String get trayOpen => 'Buka Wardkeep';

  @override
  String get trayQuit => 'Keluar';

  @override
  String get traySwitchServer => 'Ganti server';

  @override
  String get keepInTray => 'Tetap berjalan di baki sistem';

  @override
  String get keepInTrayHint =>
      'Menutup jendela hanya menyembunyikannya. Pilih “Keluar” di menu baki untuk mengakhiri aplikasi dan VPN.';

  @override
  String usageUsed(String size) {
    return '$size terpakai';
  }

  @override
  String get menuResetUsage => 'Atur ulang pemakaian data';

  @override
  String get dnsPickerHelp =>
      'Nama situs dicari lewat VPN oleh resolver yang Anda pilih. DNSCrypt juga membuktikan bahwa jawabannya benar-benar dari resolver itu.';

  @override
  String get dnsDefault => 'Bawaan';

  @override
  String get dnsSectionDnscrypt => 'DNSCrypt · DNSSEC, tanpa log, tanpa filter';

  @override
  String get dnsCustom => 'Kustom';

  @override
  String get dnsCustomLabel => 'Alamat atau DNS stamp';

  @override
  String get dnsAnonymized => 'DNSCrypt anonim';

  @override
  String get dnsAnonymizedHint =>
      'Kueri melewati relay, jadi resolver tidak pernah melihat asalnya';

  @override
  String get dnsAnonymizedNeedsDnscrypt =>
      'Pilih resolver DNSCrypt untuk memakai ini';

  @override
  String get dnsRelay => 'Relay';

  @override
  String get dnsRelayChoose => 'Pilih relay';

  @override
  String get dnsRelayAutomatic => 'Otomatis (operator lain)';

  @override
  String get dnsErrAddress =>
      'Gunakan alamat yang diawali https://, tls://, tcp:// atau udp://, atau stamp sdns://';

  @override
  String get dnsErrDamaged => 'Stamp ini rusak atau terpotong. Salin ulang.';

  @override
  String get dnsErrUnsupported => 'Jenis stamp ini tidak didukung';

  @override
  String get dnsErrRelayStamp => 'Ini stamp relay, bukan resolver';

  @override
  String dnsLine(String resolver) {
    return 'DNS: $resolver';
  }

  @override
  String get dnsLimits =>
      'Ini melindungi nama yang Anda cari. Ini tidak menyembunyikan situs yang kemudian Anda sambungi.';

  @override
  String get dnsAnonymizedShort => 'anonim';

  @override
  String get flAuthKey => 'Kunci autentikasi';

  @override
  String get flControlServer => 'Server kontrol';

  @override
  String get flDeviceName => 'Nama perangkat';

  @override
  String get flExitDevice => 'Perangkat keluar';

  @override
  String get flUseSubnets => 'Gunakan subnet perangkat lain';

  @override
  String get flTempDevice => 'Perangkat sementara';

  @override
  String get hpAuthKey =>
      'Kunci pra-otorisasi dari halaman admin Tailscale, atau dibuat dengan headscale preauthkeys create';

  @override
  String get hpControlServer =>
      'Kosong memakai Tailscale; untuk Headscale, alamatnya, misalnya https://hs.example.com';

  @override
  String get hpDeviceName =>
      'Nama perangkat ini di jaringan; kosong memakai nama bawaan perangkat';

  @override
  String get hpExitDevice =>
      'Nama atau alamat perangkat yang koneksi internetnya dipakai; kosong hanya menjangkau perangkat Anda';

  @override
  String get hpTempDevice => 'Dihapus dari jaringan saat offline';

  @override
  String get devicesTitle => 'Perangkat saya';

  @override
  String get devicesNotConnected =>
      'Sambungkan profil Tailscale atau Headscale untuk melihat perangkat Anda.';

  @override
  String get devicesJoining => 'Bergabung ke jaringan…';

  @override
  String get devicesLoginNeeded =>
      'Jaringan tidak menerima kunci perangkat ini. Buat kunci baru dan ubah profilnya.';

  @override
  String get devicesEmpty => 'Belum ada perangkat lain di jaringan ini.';

  @override
  String get devicesThisDevice => 'Perangkat ini';

  @override
  String get deviceOnline => 'Online';

  @override
  String get deviceOffline => 'Offline';

  @override
  String deviceLastSeen(String when) {
    return 'Terakhir terlihat $when';
  }

  @override
  String get deviceUseAsExit => 'Gunakan sebagai jalur keluar';

  @override
  String get deviceStopExit => 'Berhenti memakai sebagai jalur keluar';

  @override
  String get deviceIsExit => 'Jalur keluar dipakai';

  @override
  String get devicesExitHint =>
      'Pakai salah satu perangkat Anda sebagai jalur keluar: semua lalu lintas Anda keluar lewat koneksinya.';

  @override
  String get deviceCopyName => 'Salin nama';

  @override
  String get deviceCopyAddress => 'Salin alamat';

  @override
  String get deviceCopied => 'Disalin';

  @override
  String get errMeshExit =>
      'Perangkat itu tidak bisa dipakai sebagai jalur keluar saat ini. Perangkat harus online dan menawarkan koneksinya.';

  @override
  String get wnTlsInsecure =>
      'Sertifikat server tidak diperiksa. Siapa pun di jalur dapat membaca atau mengubah lalu lintas Anda.';

  @override
  String get wnNoTls =>
      'Lalu lintas tidak dibungkus TLS. Mudah dikenali dan bisa dibaca di jalan.';

  @override
  String get wnVmessLegacy =>
      'VMess adalah protokol lama dan mudah dikenali. VLESS dengan Reality pilihan yang lebih baik.';

  @override
  String get wnSsPlain =>
      'Tanpa plugin seperti shadow-tls, lalu lintas tampak seperti byte acak, dan beberapa jaringan memblokir pola itu.';

  @override
  String get wnHysteria1 =>
      'Hysteria 1 sudah usang. Gunakan Hysteria 2 jika server mendukungnya.';

  @override
  String get wnDpiVisible =>
      'Protokol ini mudah dikenali dan sering diblokir di jaringan yang ketat.';

  @override
  String get wnSshVisible => 'Terowongan SSH mudah dikenali.';

  @override
  String get wnDnsttSlow =>
      'Lambat (biasanya jauh di bawah 1 Mbit/s) dan hanya TCP. Mengirim banyak kueri DNS yang bisa dilihat jaringan. Pakai saat tidak ada yang lain berhasil.';

  @override
  String get wnDnsttOpen =>
      'Tanpa nama pengguna dan kata sandi: siapa pun yang punya tautan ini dapat memakai server.';

  @override
  String get wnMuxLossy =>
      'Multipleks menaruh banyak koneksi dalam satu. Jalur yang buruk dapat memperlambat semuanya.';

  @override
  String get wnFragmentSide =>
      'Memecah handshake membantu melawan beberapa filter, bisa gagal di yang lain, dan menambah jeda.';

  @override
  String get wnEchServer =>
      'Perlu server yang mendukung ECH. Jika tidak, koneksi gagal.';

  @override
  String get wnWgChain =>
      'WireGuard di dalam proxy: jika proxy lambat, terowongan bisa macet. Proxy harus membawa UDP.';

  @override
  String get wnSubUnsigned =>
      'Daftar ini tidak bertanda tangan, jadi perubahan tidak bisa dideteksi.';

  @override
  String get choiceOff => 'Mati';

  @override
  String get flMultiplexing => 'Multipleks';

  @override
  String get flMuxPadding => 'Padding multipleks';

  @override
  String get flMuxMaxConnections => 'Koneksi terbanyak';

  @override
  String get flMuxMinStreams => 'Aliran paling sedikit per koneksi';

  @override
  String get flMuxMaxStreams => 'Aliran terbanyak per koneksi';

  @override
  String get hpMultiplexing =>
      'Banyak koneksi dalam satu; server harus mengizinkannya. Tidak dengan flow VLESS';

  @override
  String get hpMuxMaxStreams => 'Sebagai pengganti dua di atas';

  @override
  String get flTlsFragment => 'Pecah handshake TLS';

  @override
  String get flTlsRecordFragment => 'Pecah rekaman TLS';

  @override
  String get flEch => 'Client Hello terenkripsi (ECH)';

  @override
  String get flEchConfig => 'Konfigurasi ECH (PEM)';

  @override
  String get flEchQueryName => 'Nama pencarian ECH';

  @override
  String get hpTlsFragment =>
      'Memecah paket pertama agar filter tidak dapat membaca nama server';

  @override
  String get hpTlsRecordFragment => 'Memecah rekaman, bukan paket';

  @override
  String get hpEch =>
      'Menyembunyikan nama server; perlu server yang mendukungnya';

  @override
  String get hpEchConfig => 'Jika kosong, dicari di DNS';

  @override
  String get hpEchQueryName => 'Bawaan: nama server';

  @override
  String get flWgVia => 'Lewat proxy (tautan)';

  @override
  String get hpWgVia =>
      'Membawa WireGuard di dalam proxy ini, untuk jaringan yang memblokir UDP. Proxy harus meneruskan UDP';

  @override
  String get subSigned => 'Bertanda tangan';

  @override
  String get subKeyLabel => 'Kunci tanda tangan (opsional)';

  @override
  String get subKeyHelp =>
      'Kunci publik penyedia. Jawaban tanpa tanda tangan sah dari kunci ini ditolak';

  @override
  String get subBackupLabel => 'Alamat cadangan (opsional)';

  @override
  String get subBackupHelp =>
      'Satu per baris. Dicoba berurutan jika yang pertama tidak bisa dijangkau';

  @override
  String get subErrKey => 'Kunci tanda tangan bukan kunci publik yang sah';

  @override
  String get subUnsigned =>
      'Langganan tidak bertanda tangan, tetapi kunci tanda tangan sudah diatur, jadi ditolak';

  @override
  String get subBadSignature =>
      'Tanda tangan langganan salah: mungkin diubah di jalan, atau kuncinya lama';

  @override
  String get subStale =>
      'Jawaban ini lebih lama dari yang terakhir diterima, jadi ditolak. Jika penyedia memulihkan cadangan lama, ubah langganan lalu simpan lagi.';

  @override
  String get flTunnelDomain => 'Domain terowongan';

  @override
  String get flServerKey => 'Kunci server';

  @override
  String get flResolvers => 'Resolver';

  @override
  String get hpTunnelDomain =>
      'Zona yang Anda delegasikan ke server terowongan, seperti t.example.com';

  @override
  String get hpServerKey => '64 digit heksadesimal; server menampilkannya';

  @override
  String get hpResolvers =>
      'Dicoba berurutan: udp://IP:port, tls://host:port atau https://host/path';

  @override
  String get hpTunnelLogin =>
      'Login upstream SOCKS5 server; kosongkan jika tidak ada';

  @override
  String get scanFind => 'Cari resolver yang bekerja';

  @override
  String get scanBusy => 'Mencoba resolver…';

  @override
  String scanFound(int count) {
    return 'Resolver yang bekerja: $count';
  }

  @override
  String get scanNone =>
      'Tidak ada resolver yang bekerja. Periksa domain dan kunci, dan pastikan server berjalan.';

  @override
  String get scanConnected =>
      'Putuskan dulu: pemindaian harus memakai jaringan langsung, bukan lewat VPN.';

  @override
  String get scanNeedsFields => 'Isi dulu domain terowongan dan kunci server.';

  @override
  String get settingsLogging => 'Log dan galat';

  @override
  String get debugLogging => 'Log debug';

  @override
  String get debugLoggingOff => 'Mati';

  @override
  String debugLoggingUntil(String level, String time) {
    return '$level sampai $time';
  }

  @override
  String debugLoggingCore(String level, String mode) {
    return 'Level log inti: $level (build $mode)';
  }

  @override
  String get debugLoggingWarning =>
      'Log debug memperlambat koneksi, lebih boros baterai, dan menyimpan lebih banyak detail. Log ini mati sendiri setelah 24 jam.';

  @override
  String get logLevelInfo => 'Info';

  @override
  String get logLevelDebug => 'Debug';

  @override
  String get logLevelTrace => 'Trace (semuanya)';

  @override
  String get notifyPopup => 'Beri tahu saya tentang galat';

  @override
  String get notifyPopupHint =>
      'Pemberitahuan merah di aplikasi saat ada kegagalan yang tidak bisa diperbaiki aplikasi';

  @override
  String get notifyOs => 'Notifikasi sistem untuk galat';

  @override
  String get notifyOsHint =>
      'Notifikasi sistem, juga saat aplikasi di latar belakang';

  @override
  String get logsView => 'Lihat log';

  @override
  String get logsExport => 'Simpan sebagai JSON Lines';

  @override
  String get logsSaved => 'Log disimpan';

  @override
  String get logsLevel => 'Level';

  @override
  String get logsLevelAll => 'Semua level';

  @override
  String logsConnection(String conn) {
    return 'Koneksi $conn';
  }

  @override
  String get logsNoMatch => 'Tidak ada entri log yang cocok dengan filter.';

  @override
  String get errTorExited =>
      'Tor berhenti tiba-tiba. Hubungkan lagi; jika terus terjadi, lihat log.';

  @override
  String get errDnsttExited =>
      'Terowongan DNS berhenti tiba-tiba. Hubungkan lagi; jika terus terjadi, lihat log.';

  @override
  String get errEngineFatal =>
      'Mesin koneksi berhenti karena galat. Hubungkan lagi; jika terus terjadi, lihat log.';

  @override
  String get errPanic =>
      'Terjadi masalah di dalam Wardkeep dan koneksi dihentikan. Detailnya ada di log.';

  @override
  String get errTorStreamFailed =>
      'Tor tidak bisa membuka koneksi ke situs itu melalui jaringan Tor.';
}
