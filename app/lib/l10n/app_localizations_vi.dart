// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appName => 'Wardkeep';

  @override
  String get actionSave => 'Lưu';

  @override
  String get actionCancel => 'Hủy';

  @override
  String get actionDelete => 'Xóa';

  @override
  String get actionEdit => 'Sửa';

  @override
  String get actionReset => 'Đặt lại';

  @override
  String get actionSkip => 'Bỏ qua';

  @override
  String get actionNext => 'Tiếp';

  @override
  String get actionImport => 'Nhập';

  @override
  String get actionDownload => 'Tải xuống';

  @override
  String get actionCopyAll => 'Sao chép tất cả';

  @override
  String get actionClear => 'Xóa sạch';

  @override
  String get tooltipMore => 'Thêm';

  @override
  String get tooltipShow => 'Hiện';

  @override
  String get tooltipHide => 'Ẩn';

  @override
  String get searchHint => 'Tìm kiếm';

  @override
  String get tooltipLogs => 'Nhật ký';

  @override
  String get tooltipSettings => 'Cài đặt';

  @override
  String get statusConnected => 'Đã kết nối';

  @override
  String get statusConnecting => 'Đang kết nối…';

  @override
  String get statusDisconnecting => 'Đang ngắt kết nối…';

  @override
  String get statusError => 'Kết nối thất bại';

  @override
  String get statusNoInternet => 'Không có kết nối Internet';

  @override
  String get statusDisconnected => 'Chưa kết nối';

  @override
  String get stagePermission => 'Đang chờ quyền VPN';

  @override
  String get stageNetworkCheck => 'Đang kiểm tra kết nối Internet';

  @override
  String get stagePrepare => 'Đang chuẩn bị cấu hình';

  @override
  String get stageEngineStart => 'Đang khởi động lõi';

  @override
  String get stageTunnelUp => 'Đang mở đường hầm';

  @override
  String get stageHandshake => 'Đang liên hệ máy chủ';

  @override
  String get stageConnected => 'Đã kết nối';

  @override
  String get buttonConnect => 'Kết nối';

  @override
  String get buttonDisconnect => 'Ngắt kết nối';

  @override
  String get buttonCancel => 'Hủy';

  @override
  String get locationLabel => 'Vị trí';

  @override
  String get noServers => 'Không có máy chủ';

  @override
  String get noServersHint => 'Thêm một máy chủ để bắt đầu';

  @override
  String get automatic => 'Tự động';

  @override
  String get automaticHint => 'Máy chủ nhanh nhất, tự chuyển khi lỗi';

  @override
  String get anyServerInCountry => 'Bất kỳ máy chủ nào ở quốc gia này';

  @override
  String get torNetwork => 'Mạng Tor';

  @override
  String get torHopBridge => 'Cầu nối';

  @override
  String get torHopEntry => 'Vào';

  @override
  String get torHopRelay => 'Chuyển tiếp';

  @override
  String get torHopExit => 'Thoát';

  @override
  String get torHopHidden => 'Ẩn';

  @override
  String get torHopUnknown => 'Không rõ';

  @override
  String get hopYou => 'Bạn';

  @override
  String get hopYouNote =>
      'Đây là nơi bạn thực sự đang ở. Lưu lượng của bạn bắt đầu từ đây.';

  @override
  String get hopServer => 'Máy chủ';

  @override
  String get hopServerNote =>
      'Lưu lượng của bạn đi được mã hóa tới máy chủ này và thoát ra từ đây, nên các trang web thấy địa chỉ của nó thay vì của bạn.';

  @override
  String get hopBridgeNote =>
      'Chặng đầu tiên của bạn. Cầu nối giấu mạng của bạn việc bạn dùng Tor. Nó biết bạn là ai, nhưng không biết bạn đi đâu.';

  @override
  String get hopEntryNote =>
      'Rơ-le đầu tiên. Nó biết địa chỉ của bạn, nhưng không biết bạn truy cập gì.';

  @override
  String get hopRelayNote =>
      'Rơ-le giữa. Nó không biết bạn là ai cũng như bạn truy cập gì; nó chỉ chuyển tiếp lưu lượng.';

  @override
  String get hopExitNote =>
      'Rơ-le cuối. Nó thấy bạn đi đâu, nhưng không biết bạn là ai, và các trang web thấy địa chỉ của nó.';

  @override
  String get hopHiddenNote =>
      'Vị trí của cầu nối bị phương thức truyền giấu đi, nên không thể hiển thị trên bản đồ.';

  @override
  String get hopTransport => 'Phương thức truyền';

  @override
  String get hopProtocol => 'Giao thức';

  @override
  String get hopAddress => 'Địa chỉ';

  @override
  String get hopLatency => 'Độ trễ';

  @override
  String get hopExitAddress => 'Địa chỉ thoát';

  @override
  String get menuNewGroup => 'Nhóm mới';

  @override
  String get groupNameHint => 'Tên nhóm';

  @override
  String get groupCreate => 'Tạo';

  @override
  String get menuMoveToGroup => 'Chuyển vào nhóm';

  @override
  String get groupMoveTitle => 'Chuyển đến';

  @override
  String get menuRenameGroup => 'Đổi tên';

  @override
  String get menuDeleteGroup => 'Xóa nhóm';

  @override
  String get groupDeleteTitle => 'Xóa nhóm này?';

  @override
  String groupDeleteBody(String name) {
    return 'Máy chủ trong nhóm không bị xóa. Chúng quay về $name.';
  }

  @override
  String get groupEmptyHint =>
      'Chưa có máy chủ. Mở menu của một máy chủ và chọn Chuyển vào nhóm.';

  @override
  String get menuShareGroupFile => 'Lưu thành tệp văn bản';

  @override
  String get menuCopyGroupLinks => 'Sao chép liên kết';

  @override
  String groupSavedToast(String servers) {
    return 'Đã lưu: $servers';
  }

  @override
  String groupCopiedToast(String servers) {
    return 'Đã sao chép: $servers';
  }

  @override
  String get groupNothingToShare =>
      'Không máy chủ nào trong số này có liên kết chia sẻ.';

  @override
  String groupSkipped(String servers) {
    return 'Đã bỏ qua, không có liên kết chia sẻ: $servers';
  }

  @override
  String get emptyTitle => 'Chưa có hồ sơ';

  @override
  String get emptyHint => 'Nhập cấu hình, liên kết hoặc gói đăng ký.';

  @override
  String get importConfig => 'Nhập cấu hình';

  @override
  String failoverToast(String to, String from) {
    return 'Đã chuyển sang $to · $from ngừng phản hồi';
  }

  @override
  String get unknownLocation => 'Vị trí không xác định';

  @override
  String errorFailed(String stage, String reason) {
    return '$stage thất bại: $reason';
  }

  @override
  String get errTimeout => 'máy chủ không phản hồi kịp thời';

  @override
  String get errRefused => 'máy chủ đã từ chối kết nối';

  @override
  String get errReset => 'kết nối bị mạng đặt lại';

  @override
  String get errNoRoute => 'không thể truy cập máy chủ từ mạng này';

  @override
  String get errNetworkUnreachable => 'không thể truy cập mạng';

  @override
  String get errDns => 'không thể phân giải tên máy chủ';

  @override
  String get errTls => 'chứng chỉ bảo mật của máy chủ bị từ chối';

  @override
  String get errAuth => 'tên người dùng hoặc mật khẩu bị từ chối';

  @override
  String get errClosed => 'máy chủ đã đóng kết nối';

  @override
  String get errCertDate =>
      'chứng chỉ của máy chủ đã hết hạn hoặc chưa có hiệu lực (hãy kiểm tra cả ngày giờ của điện thoại này)';

  @override
  String get errCertUntrusted =>
      'chứng chỉ của máy chủ không do tổ chức đáng tin cậy ký';

  @override
  String get errCertName =>
      'chứng chỉ của máy chủ dành cho một tên khác với tên đang kết nối';

  @override
  String get errTlsKeys =>
      'khóa chia sẻ (tls-auth hoặc tls-crypt) không khớp với khóa của máy chủ';

  @override
  String get errReality =>
      'máy chủ đã từ chối bước bắt tay Reality (kiểm tra khóa công khai, short ID và tên máy chủ)';

  @override
  String get errNoHandshake =>
      'máy chủ không phản hồi bước bắt tay (kiểm tra khóa, điểm cuối và xem cổng UDP của máy chủ đã mở chưa)';

  @override
  String get errUdpBlocked =>
      'máy chủ không phản hồi qua UDP; mạng này có thể chặn UDP, hãy thử máy chủ dùng TCP';

  @override
  String get errPortInUse => 'cổng cục bộ đang được ứng dụng khác sử dụng';

  @override
  String get errTorTimeout =>
      'Tor không kết nối xong kịp thời. Mạng này có thể chặn Tor; hãy dùng cầu nối (Snowflake hoặc obfs4)';

  @override
  String get errTorBridgeTimeout =>
      'Tor không kết nối xong kịp thời. Cầu nối có thể bị chặn hoặc quá tải; hãy thử loại cầu nối khác (Snowflake hoặc obfs4)';

  @override
  String get errTorBadBridge =>
      'một dòng cầu nối Tor không hợp lệ (cần giao thức truyền tải, địa chỉ và dấu vân tay)';

  @override
  String get errTorMissing => 'bản dựng này không có ứng dụng khách Tor';

  @override
  String get errPermission => 'quyền VPN chưa được cấp';

  @override
  String get errCoreLost => 'Mất kết nối với dịch vụ lõi';

  @override
  String get selectLocation => 'Chọn vị trí';

  @override
  String get testSpeedTooltip => 'Kiểm tra tốc độ của tất cả máy chủ';

  @override
  String get addServersTooltip => 'Thêm máy chủ';

  @override
  String get menuImport => 'Nhập cấu hình, liên kết hoặc mã QR';

  @override
  String get menuNewServer => 'Thêm máy chủ thủ công';

  @override
  String get menuSubscription => 'Thêm gói đăng ký';

  @override
  String get menuManage => 'Quản lý máy chủ và gói đăng ký';

  @override
  String get menuSetDefault => 'Đặt làm mặc định';

  @override
  String get badgeDefault => 'Mặc định';

  @override
  String get menuDeleteAll => 'Xóa tất cả máy chủ';

  @override
  String get deleteAllTitle => 'Xóa tất cả máy chủ?';

  @override
  String get deleteAllBody =>
      'Mọi máy chủ và gói đăng ký đã thêm sẽ bị xóa. Kết nối Tor tích hợp vẫn được giữ và ứng dụng quay lại dùng kết nối đó.';

  @override
  String get menuRestoreTor => 'Khôi phục mặc định của Tor';

  @override
  String get deletedAllToast => 'Đã xóa tất cả máy chủ';

  @override
  String defaultSetToast(String name) {
    return '$name hiện là mặc định';
  }

  @override
  String serversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count máy chủ',
    );
    return '$_temp0';
  }

  @override
  String get otherGroup => 'Khác';

  @override
  String get torGroup => 'Tor';

  @override
  String get noServersYet => 'Chưa có máy chủ';

  @override
  String get importHintShort => 'Nhập tệp cấu hình, liên kết hoặc gói đăng ký.';

  @override
  String get showServers => 'Hiện máy chủ';

  @override
  String get hideServers => 'Ẩn máy chủ';

  @override
  String get menuEditServer => 'Sửa';

  @override
  String get menuBridgeSettings => 'Cài đặt cầu nối';

  @override
  String get menuShare => 'Chia sẻ liên kết hoặc mã QR';

  @override
  String get menuSetCountry => 'Đặt quốc gia';

  @override
  String get menuCredentials => 'Tên người dùng và mật khẩu';

  @override
  String needsSignIn(String address) {
    return '$address · cần đăng nhập';
  }

  @override
  String get countryOfServer => 'Quốc gia của máy chủ này';

  @override
  String get guessFromName => 'Suy ra từ tên';

  @override
  String get latencyNotTested => 'Chưa kiểm tra';

  @override
  String get latencyUnreachable => 'Không truy cập được';

  @override
  String get latencyTimeout => 'hết thời gian chờ';

  @override
  String latencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String get unknownCountry => 'Quốc gia không xác định';

  @override
  String get addServerTitle => 'Thêm máy chủ';

  @override
  String get addServerIntro =>
      'Chọn một giao thức. Dùng liên kết hoặc mã QR sẽ nhanh hơn: hãy chọn Nhập.';

  @override
  String newServerTitle(String label) {
    return 'Máy chủ $label mới';
  }

  @override
  String get editServerTitle => 'Sửa máy chủ';

  @override
  String get torBridgesTitle => 'Cầu nối Tor';

  @override
  String get subscriptionEditNote =>
      'Máy chủ này đến từ gói đăng ký: các thay đổi sẽ bị ghi đè khi làm mới.';

  @override
  String get moreOptions => 'Thêm tùy chọn';

  @override
  String get countryRow => 'Quốc gia';

  @override
  String get countryAuto => 'Suy ra từ tên và địa chỉ';

  @override
  String get alreadyInList => 'Máy chủ này đã có trong danh sách';

  @override
  String get choiceDefault => 'Mặc định';

  @override
  String get torBridgesNone => 'Không (trực tiếp, hoặc các dòng bên dưới)';

  @override
  String get torBridgesSnowflake => 'Snowflake';

  @override
  String get torBridgesObfs4 => 'obfs4 (cầu nối tích hợp)';

  @override
  String get listHelper => 'Phân tách các giá trị bằng dấu phẩy';

  @override
  String get fillPaste => 'Dán';

  @override
  String get fillFile => 'Tệp';

  @override
  String get fillScanQr => 'Quét mã QR';

  @override
  String get openTextFile => 'Mở tệp văn bản';

  @override
  String couldNotReadFile(String error) {
    return 'Không thể đọc tệp: $error';
  }

  @override
  String fieldRequired(String label) {
    return '$label *';
  }

  @override
  String formNoEditor(String protocol) {
    return 'Không có trình chỉnh sửa cho $protocol';
  }

  @override
  String get shareScanHint => 'Quét bằng Wardkeep hoặc sao chép liên kết.';

  @override
  String get shareCopy => 'Sao chép liên kết';

  @override
  String get shareCopied => 'Đã sao chép liên kết';

  @override
  String get shareWarning =>
      'Chứa mật khẩu hoặc khóa của máy chủ. Hãy chia sẻ cẩn thận.';

  @override
  String shareFailed(String reason) {
    return 'Không thể chia sẻ máy chủ này dưới dạng liên kết: $reason';
  }

  @override
  String get shareTooLong => 'Quá dài cho mã QR: hãy sao chép liên kết';

  @override
  String get obTitle1 => 'Riêng tư và đơn giản';

  @override
  String get obText1 =>
      'Một màn hình gọn gàng cho VPN, proxy và Tor. Chọn một nơi, nhấn Kết nối.';

  @override
  String get obTitle2 => 'Thêm máy chủ';

  @override
  String get obText2 =>
      'Nhập liên kết, mã QR, tệp cấu hình hoặc gói đăng ký. Hoặc thêm máy chủ thủ công.';

  @override
  String get obTitle3Android => 'Android sẽ hỏi một lần';

  @override
  String get obText3Android =>
      'Android sẽ yêu cầu cho phép kết nối VPN. Hãy chấp nhận để được bảo vệ.';

  @override
  String get obTitle3Desktop => 'Sẵn sàng khi cần';

  @override
  String get obText3Desktop =>
      'Khởi động ở chế độ proxy, không cần quyền đặc biệt. Bật chế độ VPN trong Cài đặt để bắt toàn bộ lưu lượng.';

  @override
  String get obAddFirst => 'Thêm máy chủ đầu tiên';

  @override
  String get bypassTitle => 'Danh sách bỏ qua';

  @override
  String get bypassAddTooltip => 'Thêm danh sách';

  @override
  String get bypassFromClipboard => 'Dán từ bộ nhớ tạm';

  @override
  String get bypassFromFile => 'Mở tệp .txt';

  @override
  String get bypassFromUrl => 'Tải xuống từ liên kết';

  @override
  String get bypassType => 'Nhập tay';

  @override
  String get bypassClipboardEmpty => 'Bộ nhớ tạm trống';

  @override
  String get bypassPickFile => 'Mở danh sách bỏ qua (.txt)';

  @override
  String bypassDownloadFailed(String error) {
    return 'Không thể tải danh sách: $error';
  }

  @override
  String get bypassIntro =>
      'Trang web và địa chỉ bỏ qua VPN. Mỗi dòng một mục: example.com, full:www.example.com, keyword:bank, regexp:…, 203.0.113.7 hoặc 10.0.0.0/8. Các dòng bắt đầu bằng # sẽ bị bỏ qua.';

  @override
  String get bypassNoLists => 'Chưa có danh sách.';

  @override
  String get bypassTypeList => 'Nhập danh sách';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mục',
    );
    return '$_temp0';
  }

  @override
  String get bypassOnlyTitle => 'Chỉ mục trong danh sách dùng VPN';

  @override
  String get bypassOnlyOn => 'Mọi thứ còn lại đi trực tiếp.';

  @override
  String get bypassOnlyOff =>
      'Mục trong danh sách đi trực tiếp; phần còn lại dùng VPN.';

  @override
  String get bypassNothing => 'Không có danh sách nào đang bật.';

  @override
  String bypassInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mục đang dùng',
    );
    return '$_temp0. Áp dụng ở lần kết nối tiếp theo.';
  }

  @override
  String get bypassHttpLink => 'Nhập liên kết http(s)';

  @override
  String bypassServerAnswered(int code) {
    return 'máy chủ trả lời $code';
  }

  @override
  String get bypassTooLarge => 'danh sách lớn hơn 5 MB';

  @override
  String get bypassDownloadTitle => 'Tải danh sách';

  @override
  String get bypassNewList => 'Danh sách mới';

  @override
  String get bypassEditList => 'Sửa danh sách';

  @override
  String get bypassName => 'Tên';

  @override
  String get bypassEntriesLabel => 'Các mục, mỗi dòng một mục';

  @override
  String get bypassNoUsable => 'Chưa có mục nào dùng được.';

  @override
  String bypassSummary(String entries, String names, String ranges) {
    return '$entries · $names, $ranges.';
  }

  @override
  String bypassNames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tên',
    );
    return '$_temp0';
  }

  @override
  String bypassRanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count địa chỉ hoặc dải',
    );
    return '$_temp0';
  }

  @override
  String bypassIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dòng sẽ bị bỏ qua:',
    );
    return '$_temp0';
  }

  @override
  String bypassMoreIssues(int count) {
    return '… và $count mục nữa';
  }

  @override
  String get bypassReconnect => 'Kết nối lại để dùng danh sách mới';

  @override
  String get bypassDefaultName => 'Danh sách của tôi';

  @override
  String get bypassPastedName => 'Danh sách đã dán';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsServers => 'Máy chủ';

  @override
  String get manageServers => 'Quản lý máy chủ';

  @override
  String get manageServersHint => 'Máy chủ và gói đăng ký';

  @override
  String get settingsConnection => 'Kết nối';

  @override
  String get vpnMode => 'Chế độ VPN (toàn bộ lưu lượng)';

  @override
  String get vpnModeHint => 'Tắt: chỉ proxy, không cần quyền VPN';

  @override
  String get systemProxy => 'Đặt proxy hệ thống';

  @override
  String get systemProxyHint => 'Đặt proxy hệ thống khi đang kết nối';

  @override
  String get autoSwitch => 'Tự động chuyển khi lỗi';

  @override
  String get autoSwitchHint => 'Thử máy chủ tiếp theo nếu một máy chủ lỗi';

  @override
  String get bypassLan => 'Bỏ qua mạng cục bộ';

  @override
  String get bypassLanHint =>
      'Truy cập trực tiếp thiết bị cục bộ (192.168.x.x, 10.x.x.x)';

  @override
  String get bypassListsHint => 'Trang web và địa chỉ bỏ qua VPN';

  @override
  String bypassListsInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mục đang dùng',
    );
    return '$_temp0';
  }

  @override
  String get alwaysOnTitle => 'VPN luôn bật và kill switch';

  @override
  String get alwaysOnHint =>
      'Kết nối lại khi khởi động và chặn rò rỉ. Cài đặt trong phần cài đặt VPN của Android.';

  @override
  String get openVpnSettingsFallback =>
      'Cài đặt → Mạng → VPN → biểu tượng bánh răng cạnh Wardkeep';

  @override
  String get splitTunneling => 'Chia tách đường hầm';

  @override
  String splitSummaryOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Chỉ $count ứng dụng đã chọn dùng VPN',
    );
    return '$_temp0';
  }

  @override
  String splitSummaryBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ứng dụng bỏ qua VPN',
    );
    return '$_temp0';
  }

  @override
  String get splitSummaryOff => 'Tất cả ứng dụng dùng VPN';

  @override
  String get remoteDns => 'DNS từ xa';

  @override
  String get remoteDnsHelp =>
      'DNS dùng qua đường hầm, ví dụ https://1.1.1.1/dns-query hoặc tls://1.1.1.1';

  @override
  String get settingsApp => 'Ứng dụng';

  @override
  String get appearance => 'Giao diện';

  @override
  String get themeDark => 'Tối';

  @override
  String get themeLight => 'Sáng';

  @override
  String get themeSystem => 'Theo hệ thống';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get languageSystem => 'Mặc định của hệ thống';

  @override
  String get stopOnClose => 'Dừng VPN khi đóng ứng dụng';

  @override
  String aboutLine(String engine) {
    return 'Giấy phép MIT · lõi: $engine';
  }

  @override
  String get splitTitle => 'Chia tách đường hầm';

  @override
  String get splitAll => 'Tất cả ứng dụng';

  @override
  String get splitOnlySelected => 'Chỉ đã chọn';

  @override
  String get splitBypassSelected => 'Bỏ qua đã chọn';

  @override
  String get splitHelpOffMode => 'Mọi ứng dụng đều dùng VPN.';

  @override
  String get splitHelpOnlyNone => 'Chưa chọn ứng dụng nào: tất cả dùng VPN.';

  @override
  String splitHelpOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Chỉ $count ứng dụng dùng VPN.',
    );
    return '$_temp0';
  }

  @override
  String splitHelpBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ứng dụng đi trực tiếp.',
    );
    return '$_temp0';
  }

  @override
  String get searchApps => 'Tìm ứng dụng';

  @override
  String get showSystemApps => 'Hiện ứng dụng hệ thống';

  @override
  String couldNotListApps(String error) {
    return 'Không thể liệt kê ứng dụng: $error';
  }

  @override
  String get scanTitle => 'Quét mã QR';

  @override
  String get scanTorch => 'Đèn pin';

  @override
  String scanCameraUnavailable(String code) {
    return 'Camera không khả dụng: $code';
  }

  @override
  String get scanPoint => 'Hướng camera vào mã QR cấu hình';

  @override
  String get credTitle => 'Đăng nhập';

  @override
  String credNeeds(String name) {
    return '$name cần tên người dùng và mật khẩu.';
  }

  @override
  String get credUsername => 'Tên người dùng';

  @override
  String get credPassword => 'Mật khẩu';

  @override
  String get logsEmpty => 'Chưa có nhật ký.';

  @override
  String get profilesTitle => 'Quản lý máy chủ';

  @override
  String get addSubscriptionTooltip => 'Thêm gói đăng ký';

  @override
  String get testLatencyTooltip => 'Kiểm tra độ trễ';

  @override
  String get profilesEmptyHint => 'Chưa có hồ sơ. Nhấn Nhập để thêm.';

  @override
  String get profilesDragHint =>
      'Nhấn giữ và kéo để sắp xếp lại. Chuyển đổi dự phòng theo thứ tự này.';

  @override
  String get myProfiles => 'Hồ sơ của tôi';

  @override
  String subRefreshed(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hồ sơ',
    );
    return '$name: $_temp0';
  }

  @override
  String get refreshTooltip => 'Làm mới';

  @override
  String get subDeleteWithProfiles => 'Xóa gói đăng ký cùng các hồ sơ của nó';

  @override
  String subUsageOf(String used, String total) {
    return '$used trên $total';
  }

  @override
  String subUsed(String used) {
    return 'Đã dùng $used';
  }

  @override
  String get subExpired => 'đã hết hạn';

  @override
  String get subExpiresToday => 'hết hạn hôm nay';

  @override
  String subExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'hết hạn sau $days ngày',
    );
    return '$_temp0';
  }

  @override
  String subUpdated(String ago) {
    return 'cập nhật $ago';
  }

  @override
  String get agoJustNow => 'vừa xong';

  @override
  String agoMinutes(int count) {
    return '$count phút trước';
  }

  @override
  String agoHours(int count) {
    return '$count giờ trước';
  }

  @override
  String agoDays(int count) {
    return '$count ngày trước';
  }

  @override
  String subRefreshFailed(String error) {
    return 'Lần làm mới gần nhất thất bại: $error';
  }

  @override
  String get importTitle => 'Nhập cấu hình';

  @override
  String get importDescription =>
      'Dán liên kết, cấu hình hoặc gói đăng ký — hoặc mở tệp hay quét mã QR.';

  @override
  String get importScanQr => 'Quét mã QR';

  @override
  String get importOpenFile => 'Mở tệp';

  @override
  String get importPaste => 'Dán';

  @override
  String get importSubscription => 'Gói đăng ký';

  @override
  String get importTor => 'Tor';

  @override
  String get importAddTor => 'Thêm Tor';

  @override
  String get importTorDirect => 'Tor (trực tiếp)';

  @override
  String get importTorSnowflake => 'Tor + cầu nối Snowflake';

  @override
  String get importTorObfs4 => 'Tor + cầu nối obfs4';

  @override
  String importedProfiles(int added, int dupes) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Đã nhập $added hồ sơ',
    );
    String _temp1 = intl.Intl.pluralLogic(
      dupes,
      locale: localeName,
      other: ', $dupes đã có sẵn',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String importNothing(String reason) {
    return 'Không nhập được gì: $reason';
  }

  @override
  String importPartial(int added, int failed) {
    return 'Đã nhập $added, lỗi $failed';
  }

  @override
  String get subAddTitle => 'Thêm gói đăng ký';

  @override
  String get subEditTitle => 'Sửa gói đăng ký';

  @override
  String get subUrlLabel => 'URL gói đăng ký';

  @override
  String get subUrlHint =>
      'https://provider.example/sub/… hoặc nordvpn://<token>';

  @override
  String get subNameLabel => 'Tên (không bắt buộc)';

  @override
  String get subNameHelp =>
      'Mặc định là tiêu đề của nhà cung cấp hoặc tên máy chủ';

  @override
  String get subAuthLabel => 'Xác thực';

  @override
  String get authNone => 'Không';

  @override
  String get authBasic => 'Tên người dùng & mật khẩu (Basic)';

  @override
  String get authBearer => 'Token Bearer';

  @override
  String get authHeader => 'Header tùy chỉnh';

  @override
  String get authQuery => 'Token trong URL';

  @override
  String get subUsername => 'Tên người dùng';

  @override
  String get subPassword => 'Mật khẩu';

  @override
  String get subHeaderName => 'Tên header';

  @override
  String get subHeaderValue => 'Giá trị header';

  @override
  String get subParamName => 'Tên tham số';

  @override
  String get subToken => 'Token';

  @override
  String get subDownloadLabel => 'Tải xuống';

  @override
  String get subDownloadHelp => 'Nhà cung cấp bị chặn? VPN vẫn có thể tải về';

  @override
  String get subViaDirect => 'Trực tiếp';

  @override
  String get subViaAuto => 'Trực tiếp, hoặc qua VPN nếu bị chặn';

  @override
  String get subViaTunnel => 'Luôn qua VPN (kết nối trước)';

  @override
  String get subErrUrl =>
      'Nhập URL gói đăng ký http(s) (hoặc nordvpn://<access token>)';

  @override
  String get subErrHeader => 'Nhập tên header';

  @override
  String get subErrToken => 'Nhập token';

  @override
  String get subAddAndDownload => 'Thêm và tải xuống';

  @override
  String get subSaveAndRefresh => 'Lưu và làm mới';

  @override
  String subUpdatedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hồ sơ',
    );
    return 'Đã cập nhật gói đăng ký: $_temp0';
  }

  @override
  String get flName => 'Tên';

  @override
  String get flServer => 'Máy chủ';

  @override
  String get flPort => 'Cổng';

  @override
  String get flPassword => 'Mật khẩu';

  @override
  String get flUsername => 'Tên người dùng';

  @override
  String get flUuid => 'UUID';

  @override
  String get flSecurity => 'Bảo mật';

  @override
  String get flFlow => 'Flow';

  @override
  String get flCipher => 'Thuật toán mã hóa';

  @override
  String get flEncryption => 'Mã hóa';

  @override
  String get flAlterId => 'Alter id';

  @override
  String get flTlsServerName => 'Tên máy chủ TLS (SNI)';

  @override
  String get flTlsFingerprint => 'Dấu vân tay TLS';

  @override
  String get flAlpn => 'ALPN';

  @override
  String get flSkipCertCheck => 'Bỏ qua kiểm tra chứng chỉ';

  @override
  String get flPinnedCert => 'Chứng chỉ được ghim (PEM)';

  @override
  String get flRealityPublicKey => 'Khóa công khai Reality';

  @override
  String get flRealityShortId => 'Short ID Reality';

  @override
  String get flTransport => 'Giao thức truyền tải';

  @override
  String get flHostHeader => 'Header Host';

  @override
  String get flPath => 'Đường dẫn';

  @override
  String get flGrpcService => 'Tên dịch vụ gRPC';

  @override
  String get flPlugin => 'Plugin';

  @override
  String get flPluginOptions => 'Tùy chọn plugin';

  @override
  String get flObfuscation => 'Làm rối';

  @override
  String get flObfsPassword => 'Mật khẩu làm rối';

  @override
  String get flUploadMbps => 'Tải lên (Mbps)';

  @override
  String get flDownloadMbps => 'Tải xuống (Mbps)';

  @override
  String get flCongestion => 'Kiểm soát tắc nghẽn';

  @override
  String get flUdpRelay => 'Chế độ chuyển tiếp UDP';

  @override
  String get flUseQuic => 'Dùng HTTP/3 (QUIC)';

  @override
  String get flTunnelAddress => 'Địa chỉ đường hầm của bạn';

  @override
  String get flRoutedNetworks => 'Mạng được định tuyến';

  @override
  String get flDnsServers => 'Máy chủ DNS';

  @override
  String get flMtu => 'MTU';

  @override
  String get flKeepalive => 'Keepalive (giây)';

  @override
  String get flPrivateKey => 'Khóa riêng';

  @override
  String get flServerPublicKey => 'Khóa công khai của máy chủ';

  @override
  String get flPresharedKey => 'Khóa chia sẻ trước';

  @override
  String get flReservedBytes => 'Byte dành riêng';

  @override
  String get flAuthentication => 'Xác thực';

  @override
  String get flAuthDigest => 'Digest xác thực';

  @override
  String get flCaCert => 'Chứng chỉ CA (PEM)';

  @override
  String get flClientCert => 'Chứng chỉ máy khách (PEM)';

  @override
  String get flClientKey => 'Khóa máy khách (PEM)';

  @override
  String get flControlWrap => 'Bảo vệ kênh điều khiển';

  @override
  String get flControlWrapKey => 'Khóa kênh điều khiển';

  @override
  String get flKeyDirection => 'Hướng khóa';

  @override
  String get flRemoteCertType => 'Loại chứng chỉ từ xa';

  @override
  String get flVerifyServerName => 'Xác minh tên máy chủ';

  @override
  String get flYourIdentity => 'Danh tính của bạn';

  @override
  String get flServerIdentity => 'Danh tính máy chủ';

  @override
  String get flServerCertTrust => 'Chứng chỉ máy chủ cần tin cậy (PEM)';

  @override
  String get flUseSystemIke => 'Dùng ứng dụng IKEv2 có sẵn của điện thoại';

  @override
  String get flUseTcp => 'Dùng TCP';

  @override
  String get flHostKeys => 'Khóa host';

  @override
  String get flPrivateKeyPem => 'Khóa riêng (PEM)';

  @override
  String get flKeyPassphrase => 'Cụm mật khẩu của khóa';

  @override
  String get flBridges => 'Cầu nối';

  @override
  String get flBridgeLines => 'Dòng cầu nối';

  @override
  String get flJc => 'Jc (số gói rác)';

  @override
  String get flSignaturePacket => 'I1 (gói chữ ký)';

  @override
  String get hpAuthorizedKeys =>
      'định dạng authorized_keys; để trống sẽ chấp nhận mọi khóa';

  @override
  String get hpIkeTcp => 'Truyền IKE và ESP qua TCP cho mạng chặn UDP';

  @override
  String get hpDefaultsToServer => 'Mặc định là địa chỉ máy chủ';

  @override
  String get hpTorBridges =>
      'Để trống: kết nối Tor trực tiếp, hoặc dùng các dòng cầu nối bên dưới';

  @override
  String get hpExampleAddress => 'Ví dụ 10.8.0.2/32';

  @override
  String get hpExamplePlugin => 'Ví dụ shadow-tls hoặc v2ray-plugin';

  @override
  String get hpHostOrIp => 'Tên máy chủ hoặc địa chỉ IP';

  @override
  String get hpNeededReality => 'Cần khi Bảo mật là reality';

  @override
  String get hpOnlySelfSigned =>
      'Chỉ dùng cho máy chủ có chứng chỉ tự ký mà không thể ghim';

  @override
  String get hpSafeSstp =>
      'An toàn với SSTP: việc trao đổi mật khẩu xác thực máy chủ';

  @override
  String get hpHysteriaObfs =>
      'salamander cho Hysteria 2; mật khẩu làm rối cho Hysteria 1';

  @override
  String get hpTrustCert =>
      'Tin cậy chứng chỉ này thay vì các tổ chức cấp chứng chỉ của hệ thống';

  @override
  String get hpWhichBrowser => 'Bắt chước bắt tay TLS của trình duyệt nào';

  @override
  String get hpWarpReserved => 'Ba số, như được liệt kê trong cấu hình WARP';

  @override
  String get hpOneBridgePerLine =>
      'Mỗi dòng một cầu nối, như trong torrc nhưng không có “Bridge ”';

  @override
  String get exitTitle => 'Hiện địa chỉ và quốc gia đầu ra';

  @override
  String get exitHint =>
      'Hỏi api.country.is về IP và quốc gia, cả khi chưa kết nối.';

  @override
  String exitIpLabel(String ip) {
    return 'IP $ip';
  }

  @override
  String connectedTo(String place) {
    return 'Đã kết nối tới $place';
  }

  @override
  String get noticesTitle => 'Giấy phép mã nguồn mở';

  @override
  String get noticesIntro =>
      'Wardkeep dùng giấy phép MIT. Ứng dụng bao gồm các phần mềm dưới đây, mỗi phần theo giấy phép riêng.';

  @override
  String noticesMore(int count) {
    return '+$count nữa';
  }

  @override
  String noticesPackages(int count) {
    return '$count gói';
  }

  @override
  String get noticesLoadFailed => 'Không thể đọc danh sách giấy phép.';

  @override
  String formRequired(String label) {
    return 'Cần nhập $label';
  }

  @override
  String formNotNumber(String label) {
    return '$label phải là số nguyên';
  }

  @override
  String formNotBool(String label) {
    return '$label phải là bật hoặc tắt';
  }

  @override
  String formBadChoice(String label, String value, String choices) {
    return '$label: $value không nằm trong $choices';
  }

  @override
  String get formRealityOnlyVless => 'Reality chỉ có cho VLESS';

  @override
  String formUnknownSecurity(String value) {
    return 'Bảo mật không xác định: $value';
  }

  @override
  String get formReservedBytes => 'Byte dành riêng phải là số từ 0 đến 255';

  @override
  String get formRealityKeyRequired =>
      'Cần có khóa công khai Reality khi Bảo mật là Reality';

  @override
  String get importUnsupported =>
      'Đây không phải liên kết máy chủ, gói đăng ký hay cấu hình mà Wardkeep đọc được';

  @override
  String importUnsupportedScheme(String scheme) {
    return 'Không hỗ trợ liên kết bắt đầu bằng $scheme://';
  }

  @override
  String get importXrayServer =>
      'Đây là cấu hình máy chủ Xray. Hãy nhập nó trên máy chủ (omnitun-server import xray), không phải làm hồ sơ máy khách';

  @override
  String get subAuthFailed =>
      'Gói đăng ký đã từ chối đăng nhập. Hãy kiểm tra tên người dùng, mật khẩu hoặc token';

  @override
  String subHttp(String status) {
    return 'Máy chủ gói đăng ký trả lời HTTP $status';
  }

  @override
  String get subTooLarge => 'Gói đăng ký lớn hơn 10 MB';

  @override
  String get subBadUrl => 'Đây không phải địa chỉ gói đăng ký hợp lệ';

  @override
  String get bypassIssueEmptyExpression => 'biểu thức trống';

  @override
  String get bypassIssueBadExpression => 'biểu thức không hợp lệ';

  @override
  String get bypassIssueBadName => 'tên không hợp lệ';

  @override
  String get bypassIssueGeo =>
      'không hỗ trợ danh sách geo; hãy liệt kê tên miền hoặc dải địa chỉ';

  @override
  String get bypassIssueBadEntry =>
      'không phải tên miền, địa chỉ hay dải địa chỉ';

  @override
  String bypassIssueTooMany(int limit) {
    return 'hơn $limit mục: phần còn lại bị bỏ qua';
  }

  @override
  String get torStarting => 'Đang khởi động Tor';

  @override
  String torBootstrap(int percent) {
    return 'Đang kết nối Tor $percent%';
  }

  @override
  String get torCircuit => 'Đang xây dựng mạch Tor';

  @override
  String torRetry(int attempt, int attempts) {
    return 'Đang thử lại Tor ($attempt/$attempts)';
  }

  @override
  String get importNoServer =>
      'Không tìm thấy máy chủ hợp lệ trong văn bản này';

  @override
  String importJsonSyntax(String found, int line, int column) {
    return 'Đây không phải JSON hợp lệ: ký tự $found không mong đợi ở dòng $line, cột $column.';
  }

  @override
  String importJsonEnd(int line, int column) {
    return 'Đây không phải JSON hợp lệ: văn bản kết thúc quá sớm, ở dòng $line, cột $column. Có thể thiếu dấu ngoặc đóng hoặc dấu nháy đóng.';
  }

  @override
  String get importJsonNoServer =>
      'JSON này hợp lệ nhưng không chứa máy chủ proxy nào. Hãy dùng cấu hình máy khách có outbound VLESS, VMess, Trojan, Shadowsocks hoặc tương tự.';

  @override
  String importJsonNoServerFound(String found) {
    return 'JSON này hợp lệ nhưng không chứa máy chủ proxy nào (nó chứa $found). Hãy dùng cấu hình máy khách có outbound VLESS, VMess, Trojan, Shadowsocks hoặc tương tự.';
  }

  @override
  String importTooLarge(int limit) {
    return 'Quá lớn để nhập (giới hạn là $limit MB).';
  }

  @override
  String get importFileEmpty => 'Tệp trống.';

  @override
  String get importFileNotText =>
      'Tệp không phải văn bản mà Wardkeep đọc được (có vẻ là nhị phân hoặc dùng bảng mã không rõ). Hãy dùng tệp văn bản UTF-8 hoặc UTF-16.';

  @override
  String get importFileNoPermission => 'Wardkeep không được phép đọc tệp này.';

  @override
  String get importFileMissing =>
      'Không tìm thấy tệp. Có thể nó đã bị di chuyển hoặc xóa.';

  @override
  String get importDetails => 'Chi tiết';

  @override
  String get importJsonNote =>
      'Cấu hình JSON (Xray, sing-box, SIP008) hoặc danh sách của chúng cũng dùng được, dưới dạng văn bản hoặc tệp.';

  @override
  String get ipdbTitle => 'Cơ sở dữ liệu quốc gia ngoại tuyến';

  @override
  String get ipdbIntro =>
      'Tải cơ sở dữ liệu một lần, Wardkeep sẽ tự tìm quốc gia của máy chủ hoặc địa chỉ mà không cần hỏi trang web nào.';

  @override
  String ipdbSizeNote(String size) {
    return 'Khoảng $size · dữ liệu miễn phí (phạm vi công cộng)';
  }

  @override
  String get ipdbDownload => 'Tải xuống';

  @override
  String get ipdbContinue => 'Tiếp tục';

  @override
  String get ipdbPause => 'Tạm dừng';

  @override
  String get ipdbUpdate => 'Cập nhật';

  @override
  String get ipdbDelete => 'Xóa';

  @override
  String get ipdbDeleteTitle => 'Xóa cơ sở dữ liệu?';

  @override
  String get ipdbUse => 'Dùng cơ sở dữ liệu';

  @override
  String get ipdbStepV4 => 'IPv4';

  @override
  String get ipdbStepV6 => 'IPv6';

  @override
  String get ipdbStepPrepare => 'Chuẩn bị';

  @override
  String get ipdbPreparing => 'Đang chuẩn bị…';

  @override
  String get ipdbReady => 'Sẵn sàng';

  @override
  String ipdbStoppedAt(int percent) {
    return 'Đã dừng ở $percent%. Tiếp tục sẽ chạy tiếp từ đúng chỗ đó.';
  }

  @override
  String ipdbFailed(String reason) {
    return 'Tải xuống thất bại: $reason';
  }

  @override
  String ipdbReadyLine(String ranges, String size) {
    return '$ranges dải · $size';
  }

  @override
  String ipdbVersion(String version, String date) {
    return 'Phiên bản $version · $date';
  }

  @override
  String ipdbLeft(String time) {
    return 'Còn $time';
  }

  @override
  String get ipdbSource =>
      'Dữ liệu: các cơ quan đăng ký Internet khu vực và thông báo ASN (CC0), từ dự án ip-location-db.';

  @override
  String get ipdbSubNone => 'Tìm quốc gia mà không cần hỏi trang web';

  @override
  String ipdbSubReady(String size) {
    return 'Bật · $size';
  }

  @override
  String ipdbSubOff(String size) {
    return 'Tắt · $size';
  }

  @override
  String ipdbSubDownloading(int percent) {
    return 'Đang tải $percent%';
  }

  @override
  String ipdbSubStopped(int percent) {
    return 'Đã dừng ở $percent%';
  }

  @override
  String get ipdbErrNetwork => 'không có kết nối tới máy chủ dữ liệu';

  @override
  String get ipdbErrMirrors => 'máy chủ dữ liệu không gửi đúng tệp';

  @override
  String get bypassCountriesTitle => 'Quốc gia';

  @override
  String get bypassCountriesNone => 'Chưa chọn quốc gia';

  @override
  String bypassCountriesMore(String names, int count) {
    return '$names +$count';
  }

  @override
  String get bypassCountriesIntro =>
      'Lưu lượng tới các quốc gia đã chọn đi thẳng ra Internet, không qua VPN. Dải địa chỉ của các nước này lấy từ cơ sở dữ liệu quốc gia ngoại tuyến.';

  @override
  String get bypassCountriesGetDb => 'Lấy cơ sở dữ liệu quốc gia';

  @override
  String get bypassCountriesSearch => 'Tìm quốc gia';

  @override
  String get windowMinimize => 'Thu nhỏ';

  @override
  String get windowMaximize => 'Phóng to';

  @override
  String get windowRestore => 'Khôi phục';

  @override
  String get windowClose => 'Đóng';

  @override
  String get globeRecenter => 'Căn giữa Trái Đất';

  @override
  String get bypassCountriesZoneIntro =>
      'Mỗi quốc gia được chọn sẽ tải dải địa chỉ của mình (vài kilobyte). Cơ sở dữ liệu ngoại tuyến đầy đủ chính xác hơn và không cần tải thêm.';

  @override
  String get bypassCountriesDownloading => 'Đang tải xuống…';

  @override
  String get bypassCountriesFailed => 'Không thể tải xuống. Nhấn để thử lại.';

  @override
  String get bypassCountriesYourServer =>
      'Máy chủ đã chọn nằm ở đây: lưu lượng của nó cũng sẽ bỏ qua VPN.';

  @override
  String get ipv6Title => 'IPv6';

  @override
  String get ipv6Hint =>
      'Tắt: chỉ dùng IPv4; kết nối IPv6 bị từ chối, không đi ra ngoài VPN.';

  @override
  String get mtuTitle => 'MTU';

  @override
  String get mtuAuto => 'Mặc định';

  @override
  String get mtuHelp =>
      'Kích thước gói của đường hầm (chỉ chế độ VPN). Thử 1280 đến 1420 nếu một số trang bị treo trên mạng di động. Để trống là mặc định.';

  @override
  String mtuInvalid(int min, int max) {
    return 'Nhập một số từ $min đến $max.';
  }

  @override
  String get trayOpen => 'Mở Wardkeep';

  @override
  String get trayQuit => 'Thoát';

  @override
  String get traySwitchServer => 'Đổi máy chủ';

  @override
  String get keepInTray => 'Tiếp tục chạy trong khay hệ thống';

  @override
  String get keepInTrayHint =>
      'Đóng cửa sổ chỉ ẩn nó đi. Chọn “Thoát” trong menu khay để dừng ứng dụng và VPN.';

  @override
  String usageUsed(String size) {
    return 'Đã dùng $size';
  }

  @override
  String get menuResetUsage => 'Đặt lại dung lượng đã dùng';

  @override
  String get dnsPickerHelp =>
      'Tên trang web được tra cứu qua VPN bởi trình phân giải bạn chọn. DNSCrypt còn chứng minh câu trả lời đến đúng từ trình phân giải đó.';

  @override
  String get dnsDefault => 'Mặc định';

  @override
  String get dnsSectionDnscrypt =>
      'DNSCrypt · DNSSEC, không nhật ký, không lọc';

  @override
  String get dnsCustom => 'Tùy chỉnh';

  @override
  String get dnsCustomLabel => 'Địa chỉ hoặc DNS stamp';

  @override
  String get dnsAnonymized => 'DNSCrypt ẩn danh';

  @override
  String get dnsAnonymizedHint =>
      'Truy vấn đi qua một relay nên trình phân giải không bao giờ thấy chúng đến từ đâu';

  @override
  String get dnsAnonymizedNeedsDnscrypt =>
      'Chọn một trình phân giải DNSCrypt để dùng mục này';

  @override
  String get dnsRelay => 'Relay';

  @override
  String get dnsRelayChoose => 'Chọn một relay';

  @override
  String get dnsRelayAutomatic => 'Tự động (nhà vận hành khác)';

  @override
  String get dnsErrAddress =>
      'Dùng địa chỉ bắt đầu bằng https://, tls://, tcp:// hoặc udp://, hoặc một stamp sdns://';

  @override
  String get dnsErrDamaged =>
      'Stamp này bị hỏng hoặc bị cắt cụt. Hãy sao chép lại.';

  @override
  String get dnsErrUnsupported => 'Loại stamp này không được hỗ trợ';

  @override
  String get dnsErrRelayStamp =>
      'Đây là stamp của relay, không phải của trình phân giải';

  @override
  String dnsLine(String resolver) {
    return 'DNS: $resolver';
  }

  @override
  String get dnsLimits =>
      'Mục này bảo vệ các tên bạn tra cứu. Nó không che giấu những trang bạn kết nối tới sau đó.';

  @override
  String get dnsAnonymizedShort => 'ẩn danh';

  @override
  String get flAuthKey => 'Khóa xác thực';

  @override
  String get flControlServer => 'Máy chủ điều khiển';

  @override
  String get flDeviceName => 'Tên thiết bị';

  @override
  String get flExitDevice => 'Thiết bị thoát';

  @override
  String get flUseSubnets => 'Dùng mạng con của thiết bị khác';

  @override
  String get flTempDevice => 'Thiết bị tạm thời';

  @override
  String get hpAuthKey =>
      'Khóa được cấp phép trước từ trang quản trị Tailscale, hoặc tạo bằng headscale preauthkeys create';

  @override
  String get hpControlServer =>
      'Để trống là dùng Tailscale; với Headscale, nhập địa chỉ của nó, ví dụ https://hs.example.com';

  @override
  String get hpDeviceName =>
      'Tên của thiết bị này trong mạng; để trống sẽ dùng tên của thiết bị';

  @override
  String get hpExitDevice =>
      'Tên hoặc địa chỉ của thiết bị có kết nối internet sẽ được dùng; để trống chỉ truy cập các thiết bị của bạn';

  @override
  String get hpTempDevice => 'Bị xóa khỏi mạng khi ngoại tuyến';

  @override
  String get devicesTitle => 'Thiết bị của tôi';

  @override
  String get devicesNotConnected =>
      'Hãy kết nối hồ sơ Tailscale hoặc Headscale để xem thiết bị của bạn.';

  @override
  String get devicesJoining => 'Đang tham gia mạng…';

  @override
  String get devicesLoginNeeded =>
      'Mạng không chấp nhận khóa của thiết bị này. Hãy tạo khóa mới và sửa hồ sơ.';

  @override
  String get devicesEmpty => 'Mạng này chưa có thiết bị nào khác.';

  @override
  String get devicesThisDevice => 'Thiết bị này';

  @override
  String get deviceOnline => 'Trực tuyến';

  @override
  String get deviceOffline => 'Ngoại tuyến';

  @override
  String deviceLastSeen(String when) {
    return 'Lần cuối thấy $when';
  }

  @override
  String get deviceUseAsExit => 'Dùng làm lối ra';

  @override
  String get deviceStopExit => 'Ngừng dùng làm lối ra';

  @override
  String get deviceIsExit => 'Đang dùng làm lối ra';

  @override
  String get devicesExitHint =>
      'Dùng một thiết bị của bạn làm lối ra: toàn bộ lưu lượng sẽ đi ra từ kết nối của nó.';

  @override
  String get deviceCopyName => 'Sao chép tên';

  @override
  String get deviceCopyAddress => 'Sao chép địa chỉ';

  @override
  String get deviceCopied => 'Đã sao chép';

  @override
  String get errMeshExit =>
      'Hiện không thể dùng thiết bị đó làm lối ra. Nó phải trực tuyến và chia sẻ kết nối của mình.';
}
