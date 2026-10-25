// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Wardkeep';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionReset => 'Restablecer';

  @override
  String get actionSkip => 'Omitir';

  @override
  String get actionNext => 'Siguiente';

  @override
  String get actionImport => 'Importar';

  @override
  String get actionDownload => 'Descargar';

  @override
  String get actionCopyAll => 'Copiar todo';

  @override
  String get actionClear => 'Borrar';

  @override
  String get tooltipMore => 'Más';

  @override
  String get tooltipShow => 'Mostrar';

  @override
  String get tooltipHide => 'Ocultar';

  @override
  String get searchHint => 'Buscar';

  @override
  String get tooltipLogs => 'Registros';

  @override
  String get tooltipSettings => 'Ajustes';

  @override
  String get statusConnected => 'Conectado';

  @override
  String get statusConnecting => 'Conectando…';

  @override
  String get statusDisconnecting => 'Desconectando…';

  @override
  String get statusError => 'Error de conexión';

  @override
  String get statusNoInternet => 'Sin conexión a internet';

  @override
  String get statusDisconnected => 'No conectado';

  @override
  String get stagePermission => 'Esperando el permiso de VPN';

  @override
  String get stageNetworkCheck => 'Comprobando la conexión a internet';

  @override
  String get stagePrepare => 'Preparando la configuración';

  @override
  String get stageEngineStart => 'Iniciando el motor';

  @override
  String get stageTunnelUp => 'Abriendo el túnel';

  @override
  String get stageHandshake => 'Contactando con el servidor';

  @override
  String get stageConnected => 'Conectado';

  @override
  String get buttonConnect => 'Conectar';

  @override
  String get buttonDisconnect => 'Desconectar';

  @override
  String get buttonCancel => 'Cancelar';

  @override
  String get locationLabel => 'Ubicación';

  @override
  String get noServers => 'Sin servidores';

  @override
  String get noServersHint => 'Añade uno para empezar';

  @override
  String get automatic => 'Automático';

  @override
  String get automaticHint => 'El servidor más rápido; cambia si falla';

  @override
  String get anyServerInCountry => 'Cualquier servidor de este país';

  @override
  String get torNetwork => 'Red Tor';

  @override
  String get torHopBridge => 'Puente';

  @override
  String get torHopEntry => 'Entrada';

  @override
  String get torHopRelay => 'Relé';

  @override
  String get torHopExit => 'Salida';

  @override
  String get torHopHidden => 'Oculto';

  @override
  String get torHopUnknown => 'Desconocido';

  @override
  String get hopYou => 'Tú';

  @override
  String get hopYouNote => 'Aquí estás realmente. Tu tráfico empieza aquí.';

  @override
  String get hopServer => 'Servidor';

  @override
  String get hopServerNote =>
      'Tu tráfico viaja cifrado hasta este servidor y sale por aquí, así que los sitios web ven su dirección en lugar de la tuya.';

  @override
  String get hopBridgeNote =>
      'Tu primer salto. Un puente oculta a tu red que usas Tor. Sabe quién eres, pero no adónde vas.';

  @override
  String get hopEntryNote =>
      'El primer relé. Conoce tu dirección, pero no lo que visitas.';

  @override
  String get hopRelayNote =>
      'El relé intermedio. No sabe quién eres ni qué visitas; solo reenvía el tráfico.';

  @override
  String get hopExitNote =>
      'El último relé. Ve adónde vas, pero no quién eres, y los sitios web ven su dirección.';

  @override
  String get hopHiddenNote =>
      'La ubicación del puente está oculta por su transporte, así que no se puede mostrar en el mapa.';

  @override
  String get hopTransport => 'Transporte';

  @override
  String get hopProtocol => 'Protocolo';

  @override
  String get hopAddress => 'Dirección';

  @override
  String get hopLatency => 'Latencia';

  @override
  String get hopExitAddress => 'Dirección de salida';

  @override
  String get menuNewGroup => 'Grupo nuevo';

  @override
  String get groupNameHint => 'Nombre del grupo';

  @override
  String get groupCreate => 'Crear';

  @override
  String get menuMoveToGroup => 'Mover a un grupo';

  @override
  String get groupMoveTitle => 'Mover a';

  @override
  String get menuRenameGroup => 'Renombrar';

  @override
  String get menuDeleteGroup => 'Eliminar grupo';

  @override
  String get groupDeleteTitle => '¿Eliminar este grupo?';

  @override
  String groupDeleteBody(String name) {
    return 'Sus servidores no se eliminan. Vuelven a $name.';
  }

  @override
  String get groupEmptyHint =>
      'Aún no hay servidores. Abre el menú de un servidor y elige Mover a un grupo.';

  @override
  String get menuShareGroupFile => 'Guardar como archivo de texto';

  @override
  String get menuCopyGroupLinks => 'Copiar enlaces';

  @override
  String groupSavedToast(String servers) {
    return 'Guardado: $servers';
  }

  @override
  String groupCopiedToast(String servers) {
    return 'Copiado: $servers';
  }

  @override
  String get groupNothingToShare =>
      'Ninguno de estos servidores tiene enlace para compartir.';

  @override
  String groupSkipped(String servers) {
    return 'Omitidos, sin enlace para compartir: $servers';
  }

  @override
  String get emptyTitle => 'Aún no hay perfiles';

  @override
  String get emptyHint =>
      'Importa una configuración, un enlace o una suscripción.';

  @override
  String get importConfig => 'Importar configuración';

  @override
  String failoverToast(String to, String from) {
    return 'Cambiado a $to: $from dejó de responder';
  }

  @override
  String get unknownLocation => 'Ubicación desconocida';

  @override
  String errorFailed(String stage, String reason) {
    return 'Error en «$stage»: $reason';
  }

  @override
  String get errTimeout => 'el servidor no respondió a tiempo';

  @override
  String get errRefused => 'el servidor rechazó la conexión';

  @override
  String get errReset => 'la red restableció la conexión';

  @override
  String get errNoRoute => 'no se puede llegar al servidor desde esta red';

  @override
  String get errNetworkUnreachable => 'la red no es accesible';

  @override
  String get errDns => 'no se pudo resolver el nombre del servidor';

  @override
  String get errTls => 'se rechazó el certificado de seguridad del servidor';

  @override
  String get errAuth => 'se rechazó el usuario o la contraseña';

  @override
  String get errClosed => 'el servidor cerró la conexión';

  @override
  String get errCertDate =>
      'el certificado del servidor ha caducado o aún no es válido (comprueba también la fecha y la hora de este teléfono)';

  @override
  String get errCertUntrusted =>
      'el certificado del servidor no está firmado por una autoridad de confianza';

  @override
  String get errCertName =>
      'el certificado del servidor es para un nombre distinto del que usas para conectarte';

  @override
  String get errTlsKeys =>
      'la clave compartida (tls-auth o tls-crypt) no coincide con la del servidor';

  @override
  String get errReality =>
      'el servidor rechazó el handshake de Reality (revisa la clave pública, el short ID y el nombre del servidor)';

  @override
  String get errNoHandshake =>
      'el servidor no respondió al handshake (revisa las claves, el endpoint y que su puerto UDP esté abierto)';

  @override
  String get errUdpBlocked =>
      'el servidor no respondió por UDP; puede que esta red lo bloquee, prueba con un servidor basado en TCP';

  @override
  String get errPortInUse => 'el puerto local ya lo usa otra aplicación';

  @override
  String get errTorTimeout =>
      'Tor no terminó de conectarse a tiempo. Puede que esta red bloquee Tor; usa un puente (Snowflake u obfs4)';

  @override
  String get errTorBridgeTimeout =>
      'Tor no terminó de conectarse a tiempo. Puede que el puente esté bloqueado o sobrecargado; prueba otro tipo de puente (Snowflake u obfs4)';

  @override
  String get errTorBadBridge =>
      'una línea de puente de Tor no es válida (necesita transporte, dirección y huella)';

  @override
  String get errTorMissing => 'esta versión no incluye el cliente de Tor';

  @override
  String get errPermission => 'no se concedió el permiso de VPN';

  @override
  String get errCoreLost => 'Se perdió la conexión con el servicio principal';

  @override
  String get selectLocation => 'Seleccionar ubicación';

  @override
  String get testSpeedTooltip => 'Probar la velocidad de todos los servidores';

  @override
  String get addServersTooltip => 'Añadir servidores';

  @override
  String get menuImport => 'Importar una configuración, enlace o QR';

  @override
  String get menuNewServer => 'Añadir un servidor manualmente';

  @override
  String get menuSubscription => 'Añadir una suscripción';

  @override
  String get menuManage => 'Gestionar servidores y suscripciones';

  @override
  String get menuSetDefault => 'Establecer como predeterminado';

  @override
  String get badgeDefault => 'Predeterminado';

  @override
  String get menuDeleteAll => 'Eliminar todos los servidores';

  @override
  String get deleteAllTitle => '¿Eliminar todos los servidores?';

  @override
  String get deleteAllBody =>
      'Se eliminan todos los servidores y suscripciones que añadiste. La conexión Tor integrada se mantiene y la app vuelve a ella.';

  @override
  String get menuRestoreTor => 'Restaurar valores de Tor';

  @override
  String get deletedAllToast => 'Todos los servidores eliminados';

  @override
  String defaultSetToast(String name) {
    return '$name es ahora el predeterminado';
  }

  @override
  String serversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servidores',
      many: '$count servidores',
      one: '$count servidor',
    );
    return '$_temp0';
  }

  @override
  String get otherGroup => 'Otros';

  @override
  String get torGroup => 'Tor';

  @override
  String get noServersYet => 'Aún no hay servidores';

  @override
  String get importHintShort =>
      'Importa un archivo de configuración, un enlace o una suscripción.';

  @override
  String get showServers => 'Mostrar servidores';

  @override
  String get hideServers => 'Ocultar servidores';

  @override
  String get menuEditServer => 'Editar';

  @override
  String get menuBridgeSettings => 'Ajustes de puentes';

  @override
  String get menuShare => 'Compartir enlace o QR';

  @override
  String get menuSetCountry => 'Establecer país';

  @override
  String get menuCredentials => 'Usuario y contraseña';

  @override
  String needsSignIn(String address) {
    return '$address · requiere iniciar sesión';
  }

  @override
  String get countryOfServer => 'País de este servidor';

  @override
  String get guessFromName => 'Deducirlo del nombre';

  @override
  String get latencyNotTested => 'Sin probar';

  @override
  String get latencyUnreachable => 'Inaccesible';

  @override
  String get latencyTimeout => 'tiempo agotado';

  @override
  String latencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String get unknownCountry => 'País desconocido';

  @override
  String get addServerTitle => 'Añadir un servidor';

  @override
  String get addServerIntro =>
      'Elige un protocolo. Un enlace o QR es más rápido: usa Importar.';

  @override
  String newServerTitle(String label) {
    return 'Nuevo servidor $label';
  }

  @override
  String get editServerTitle => 'Editar servidor';

  @override
  String get torBridgesTitle => 'Puentes de Tor';

  @override
  String get subscriptionEditNote =>
      'Este servidor viene de una suscripción: tus cambios se sustituyen cuando se actualiza.';

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get countryRow => 'País';

  @override
  String get countryAuto => 'Deducido del nombre y la dirección';

  @override
  String get alreadyInList => 'Este servidor ya está en la lista';

  @override
  String get choiceDefault => 'Predeterminado';

  @override
  String get torBridgesNone => 'Ninguno (directo, o las líneas de abajo)';

  @override
  String get torBridgesSnowflake => 'Snowflake';

  @override
  String get torBridgesObfs4 => 'obfs4 (puentes integrados)';

  @override
  String get listHelper => 'Separa los valores con comas';

  @override
  String get fillPaste => 'Pegar';

  @override
  String get fillFile => 'Archivo';

  @override
  String get fillScanQr => 'Escanear QR';

  @override
  String get openTextFile => 'Abrir un archivo de texto';

  @override
  String couldNotReadFile(String error) {
    return 'No se pudo leer el archivo: $error';
  }

  @override
  String fieldRequired(String label) {
    return '$label *';
  }

  @override
  String formNoEditor(String protocol) {
    return 'No hay editor para $protocol';
  }

  @override
  String get shareScanHint => 'Escanea con Wardkeep o copia el enlace.';

  @override
  String get shareCopy => 'Copiar enlace';

  @override
  String get shareCopied => 'Enlace copiado';

  @override
  String get shareWarning =>
      'Contiene la contraseña o la clave del servidor. Compártelo con cuidado.';

  @override
  String shareFailed(String reason) {
    return 'Este servidor no se puede compartir como enlace: $reason';
  }

  @override
  String get shareTooLong =>
      'Demasiado largo para un código QR: copia el enlace';

  @override
  String get obTitle1 => 'Privado y sencillo';

  @override
  String get obText1 =>
      'Una pantalla tranquila para VPN, proxy y Tor. Elige un lugar y pulsa Conectar.';

  @override
  String get obTitle2 => 'Añade tus servidores';

  @override
  String get obText2 =>
      'Importa un enlace, código QR, archivo de configuración o suscripción. O añade un servidor manualmente.';

  @override
  String get obTitle3Android => 'Android preguntará una vez';

  @override
  String get obText3Android =>
      'Android pedirá permiso para una conexión VPN. Acéptalo para estar protegido.';

  @override
  String get obTitle3Desktop => 'Listo cuando tú lo estés';

  @override
  String get obText3Desktop =>
      'Empieza en modo proxy, sin permisos especiales. Activa el modo VPN en Ajustes para capturar todo el tráfico.';

  @override
  String get obAddFirst => 'Añadir mi primer servidor';

  @override
  String get bypassTitle => 'Listas de exclusión';

  @override
  String get bypassAddTooltip => 'Añadir una lista';

  @override
  String get bypassFromClipboard => 'Pegar desde el portapapeles';

  @override
  String get bypassFromFile => 'Abrir un archivo .txt';

  @override
  String get bypassFromUrl => 'Descargar desde un enlace';

  @override
  String get bypassType => 'Escribirla';

  @override
  String get bypassClipboardEmpty => 'El portapapeles está vacío';

  @override
  String get bypassPickFile => 'Abrir una lista de exclusión (.txt)';

  @override
  String bypassDownloadFailed(String error) {
    return 'No se pudo descargar la lista: $error';
  }

  @override
  String get bypassIntro =>
      'Sitios y direcciones que no pasan por la VPN. Uno por línea: example.com, full:www.example.com, keyword:bank, regexp:…, 203.0.113.7 o 10.0.0.0/8. Las líneas que empiezan por # se ignoran.';

  @override
  String get bypassNoLists => 'Aún no hay listas.';

  @override
  String get bypassTypeList => 'Escribir una lista';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas',
      many: '$count entradas',
      one: '$count entrada',
    );
    return '$_temp0';
  }

  @override
  String get bypassOnlyTitle => 'Solo los de la lista usan la VPN';

  @override
  String get bypassOnlyOn => 'Todo lo demás va directo.';

  @override
  String get bypassOnlyOff =>
      'Los de la lista van directos; el resto usa la VPN.';

  @override
  String get bypassNothing => 'Ninguna lista activada.';

  @override
  String bypassInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas en uso',
      many: '$count entradas en uso',
      one: '$count entrada en uso',
    );
    return '$_temp0. Se aplica en la próxima conexión.';
  }

  @override
  String get bypassHttpLink => 'Introduce un enlace http(s)';

  @override
  String bypassServerAnswered(int code) {
    return 'el servidor respondió $code';
  }

  @override
  String get bypassTooLarge => 'la lista supera los 5 MB';

  @override
  String get bypassDownloadTitle => 'Descargar una lista';

  @override
  String get bypassNewList => 'Nueva lista';

  @override
  String get bypassEditList => 'Editar lista';

  @override
  String get bypassName => 'Nombre';

  @override
  String get bypassEntriesLabel => 'Entradas, una por línea';

  @override
  String get bypassNoUsable => 'Aún no hay entradas utilizables.';

  @override
  String bypassSummary(String entries, String names, String ranges) {
    return '$entries · $names, $ranges.';
  }

  @override
  String bypassNames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nombres',
      many: '$count nombres',
      one: '$count nombre',
    );
    return '$_temp0';
  }

  @override
  String bypassRanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count direcciones o rangos',
      many: '$count direcciones o rangos',
      one: '$count dirección o rango',
    );
    return '$_temp0';
  }

  @override
  String bypassIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se ignorarán $count líneas:',
      many: 'Se ignorarán $count líneas:',
      one: 'Se ignorará $count línea:',
    );
    return '$_temp0';
  }

  @override
  String bypassMoreIssues(int count) {
    return '… y $count más';
  }

  @override
  String get bypassReconnect => 'Vuelve a conectar para usar la nueva lista';

  @override
  String get bypassDefaultName => 'Mi lista';

  @override
  String get bypassPastedName => 'Lista pegada';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsServers => 'Servidores';

  @override
  String get manageServers => 'Gestionar servidores';

  @override
  String get manageServersHint => 'Servidores y suscripciones';

  @override
  String get settingsConnection => 'Conexión';

  @override
  String get vpnMode => 'Modo VPN (todo el tráfico)';

  @override
  String get vpnModeHint => 'Desactivado: solo proxy, sin permiso de VPN';

  @override
  String get systemProxy => 'Configurar el proxy del sistema';

  @override
  String get systemProxyHint =>
      'Configura el proxy del sistema mientras hay conexión';

  @override
  String get autoSwitch => 'Cambio automático al fallar';

  @override
  String get autoSwitchHint => 'Prueba el siguiente servidor si uno falla';

  @override
  String get bypassLan => 'Excluir la red local';

  @override
  String get bypassLanHint =>
      'Accede directamente a los dispositivos locales (192.168.x.x, 10.x.x.x)';

  @override
  String get bypassListsHint =>
      'Sitios web y direcciones que no pasan por la VPN';

  @override
  String bypassListsInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas en uso',
      many: '$count entradas en uso',
      one: '$count entrada en uso',
    );
    return '$_temp0';
  }

  @override
  String get alwaysOnTitle => 'VPN siempre activa y kill switch';

  @override
  String get alwaysOnHint =>
      'Reconecta al arrancar y bloquea fugas. Se configura en los ajustes de VPN de Android.';

  @override
  String get openVpnSettingsFallback =>
      'Ajustes → Red → VPN → engranaje junto a Wardkeep';

  @override
  String get splitTunneling => 'Túnel dividido';

  @override
  String splitSummaryOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Solo $count apps seleccionadas usan la VPN',
      many: 'Solo $count apps seleccionadas usan la VPN',
      one: 'Solo $count app seleccionada usa la VPN',
    );
    return '$_temp0';
  }

  @override
  String splitSummaryBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps omiten la VPN',
      many: '$count apps omiten la VPN',
      one: '$count app omite la VPN',
    );
    return '$_temp0';
  }

  @override
  String get splitSummaryOff => 'Todas las apps usan la VPN';

  @override
  String get remoteDns => 'DNS remoto';

  @override
  String get remoteDnsHelp =>
      'DNS usado a través del túnel, p. ej. https://1.1.1.1/dns-query o tls://1.1.1.1';

  @override
  String get settingsApp => 'Aplicación';

  @override
  String get appearance => 'Apariencia';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeSystem => 'Seguir el sistema';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Predeterminado del sistema';

  @override
  String get stopOnClose => 'Detener la VPN al cerrar la app';

  @override
  String aboutLine(String engine) {
    return 'Licencia MIT · motor: $engine';
  }

  @override
  String get splitTitle => 'Túnel dividido';

  @override
  String get splitAll => 'Todas las apps';

  @override
  String get splitOnlySelected => 'Solo las seleccionadas';

  @override
  String get splitBypassSelected => 'Omitir las seleccionadas';

  @override
  String get splitHelpOffMode => 'Todas las apps usan la VPN.';

  @override
  String get splitHelpOnlyNone => 'No hay apps elegidas: todas usan la VPN.';

  @override
  String splitHelpOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Solo $count apps usan la VPN.',
      many: 'Solo $count apps usan la VPN.',
      one: 'Solo $count app usa la VPN.',
    );
    return '$_temp0';
  }

  @override
  String splitHelpBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps van directas.',
      many: '$count apps van directas.',
      one: '$count app va directa.',
    );
    return '$_temp0';
  }

  @override
  String get searchApps => 'Buscar apps';

  @override
  String get showSystemApps => 'Mostrar apps del sistema';

  @override
  String couldNotListApps(String error) {
    return 'No se pudo obtener la lista de apps: $error';
  }

  @override
  String get scanTitle => 'Escanear código QR';

  @override
  String get scanTorch => 'Linterna';

  @override
  String scanCameraUnavailable(String code) {
    return 'Cámara no disponible: $code';
  }

  @override
  String get scanPoint => 'Apunta la cámara a un código QR de configuración';

  @override
  String get credTitle => 'Iniciar sesión';

  @override
  String credNeeds(String name) {
    return '$name necesita un usuario y una contraseña.';
  }

  @override
  String get credUsername => 'Usuario';

  @override
  String get credPassword => 'Contraseña';

  @override
  String get logsEmpty => 'Aún no hay entradas en el registro.';

  @override
  String get profilesTitle => 'Gestionar servidores';

  @override
  String get addSubscriptionTooltip => 'Añadir suscripción';

  @override
  String get testLatencyTooltip => 'Probar latencia';

  @override
  String get profilesEmptyHint =>
      'No hay perfiles. Toca Importar para añadir uno.';

  @override
  String get profilesDragHint =>
      'Mantén pulsado y arrastra para reordenar. El cambio automático sigue este orden.';

  @override
  String get myProfiles => 'Mis perfiles';

  @override
  String subRefreshed(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perfiles',
      many: '$count perfiles',
      one: '$count perfil',
    );
    return '$name: $_temp0';
  }

  @override
  String get refreshTooltip => 'Actualizar';

  @override
  String get subDeleteWithProfiles => 'Eliminar la suscripción y sus perfiles';

  @override
  String subUsageOf(String used, String total) {
    return '$used de $total';
  }

  @override
  String subUsed(String used) {
    return '$used usados';
  }

  @override
  String get subExpired => 'caducada';

  @override
  String get subExpiresToday => 'caduca hoy';

  @override
  String subExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'caduca en $days días',
      many: 'caduca en $days días',
      one: 'caduca en $days día',
    );
    return '$_temp0';
  }

  @override
  String subUpdated(String ago) {
    return 'actualizada $ago';
  }

  @override
  String get agoJustNow => 'ahora mismo';

  @override
  String agoMinutes(int count) {
    return 'hace $count min';
  }

  @override
  String agoHours(int count) {
    return 'hace $count h';
  }

  @override
  String agoDays(int count) {
    return 'hace $count d';
  }

  @override
  String subRefreshFailed(String error) {
    return 'Falló la última actualización: $error';
  }

  @override
  String get importTitle => 'Importar configuración';

  @override
  String get importDescription =>
      'Pega un enlace, una configuración o una suscripción, o abre un archivo o escanea un código QR.';

  @override
  String get importScanQr => 'Escanear QR';

  @override
  String get importOpenFile => 'Abrir archivo';

  @override
  String get importPaste => 'Pegar';

  @override
  String get importSubscription => 'Suscripción';

  @override
  String get importTor => 'Tor';

  @override
  String get importAddTor => 'Añadir Tor';

  @override
  String get importTorDirect => 'Tor (directo)';

  @override
  String get importTorSnowflake => 'Tor + puente Snowflake';

  @override
  String get importTorObfs4 => 'Tor + puentes obfs4';

  @override
  String importedProfiles(int added, int dupes) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: 'Se importaron $added perfiles',
      many: 'Se importaron $added perfiles',
      one: 'Se importó $added perfil',
    );
    String _temp1 = intl.Intl.pluralLogic(
      dupes,
      locale: localeName,
      other: ', $dupes ya existentes',
      many: ', $dupes ya existentes',
      one: ', $dupes ya existente',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String importNothing(String reason) {
    return 'No se importó nada: $reason';
  }

  @override
  String importPartial(int added, int failed) {
    return 'Importados $added, fallidos $failed';
  }

  @override
  String get subAddTitle => 'Añadir suscripción';

  @override
  String get subEditTitle => 'Editar suscripción';

  @override
  String get subUrlLabel => 'URL de la suscripción';

  @override
  String get subUrlHint => 'https://provider.example/sub/… o nordvpn://<token>';

  @override
  String get subNameLabel => 'Nombre (opcional)';

  @override
  String get subNameHelp =>
      'Por defecto, el título del proveedor o el nombre del host';

  @override
  String get subAuthLabel => 'Autenticación';

  @override
  String get authNone => 'Ninguna';

  @override
  String get authBasic => 'Usuario y contraseña (Basic)';

  @override
  String get authBearer => 'Token Bearer';

  @override
  String get authHeader => 'Cabecera personalizada';

  @override
  String get authQuery => 'Token en la URL';

  @override
  String get subUsername => 'Usuario';

  @override
  String get subPassword => 'Contraseña';

  @override
  String get subHeaderName => 'Nombre de la cabecera';

  @override
  String get subHeaderValue => 'Valor de la cabecera';

  @override
  String get subParamName => 'Nombre del parámetro';

  @override
  String get subToken => 'Token';

  @override
  String get subDownloadLabel => 'Descarga';

  @override
  String get subDownloadHelp =>
      '¿El proveedor está bloqueado? La VPN aún puede descargarla';

  @override
  String get subViaDirect => 'Directamente';

  @override
  String get subViaAuto => 'Directo, o por la VPN si está bloqueado';

  @override
  String get subViaTunnel => 'Siempre por la VPN (conéctate primero)';

  @override
  String get subErrUrl =>
      'Introduce una URL de suscripción http(s) (o nordvpn://<access token>)';

  @override
  String get subErrHeader => 'Introduce el nombre de la cabecera';

  @override
  String get subErrToken => 'Introduce el token';

  @override
  String get subAddAndDownload => 'Añadir y descargar';

  @override
  String get subSaveAndRefresh => 'Guardar y actualizar';

  @override
  String subUpdatedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perfiles',
      many: '$count perfiles',
      one: '$count perfil',
    );
    return 'Suscripción actualizada: $_temp0';
  }

  @override
  String get flName => 'Nombre';

  @override
  String get flServer => 'Servidor';

  @override
  String get flPort => 'Puerto';

  @override
  String get flPassword => 'Contraseña';

  @override
  String get flUsername => 'Usuario';

  @override
  String get flUuid => 'UUID';

  @override
  String get flSecurity => 'Seguridad';

  @override
  String get flFlow => 'Flow';

  @override
  String get flCipher => 'Algoritmo de cifrado';

  @override
  String get flEncryption => 'Cifrado';

  @override
  String get flAlterId => 'Alter id';

  @override
  String get flTlsServerName => 'Nombre del servidor TLS (SNI)';

  @override
  String get flTlsFingerprint => 'Huella TLS';

  @override
  String get flAlpn => 'ALPN';

  @override
  String get flSkipCertCheck => 'Omitir la comprobación del certificado';

  @override
  String get flPinnedCert => 'Certificado fijado (PEM)';

  @override
  String get flRealityPublicKey => 'Clave pública de Reality';

  @override
  String get flRealityShortId => 'Short id de Reality';

  @override
  String get flTransport => 'Transporte';

  @override
  String get flHostHeader => 'Cabecera Host';

  @override
  String get flPath => 'Ruta';

  @override
  String get flGrpcService => 'Nombre del servicio gRPC';

  @override
  String get flPlugin => 'Plugin';

  @override
  String get flPluginOptions => 'Opciones del plugin';

  @override
  String get flObfuscation => 'Ofuscación';

  @override
  String get flObfsPassword => 'Contraseña de ofuscación';

  @override
  String get flUploadMbps => 'Subida (Mbps)';

  @override
  String get flDownloadMbps => 'Bajada (Mbps)';

  @override
  String get flCongestion => 'Control de congestión';

  @override
  String get flUdpRelay => 'Modo de relé UDP';

  @override
  String get flUseQuic => 'Usar HTTP/3 (QUIC)';

  @override
  String get flTunnelAddress => 'Tu dirección de túnel';

  @override
  String get flRoutedNetworks => 'Redes enrutadas';

  @override
  String get flDnsServers => 'Servidores DNS';

  @override
  String get flMtu => 'MTU';

  @override
  String get flKeepalive => 'Keepalive (segundos)';

  @override
  String get flPrivateKey => 'Clave privada';

  @override
  String get flServerPublicKey => 'Clave pública del servidor';

  @override
  String get flPresharedKey => 'Clave precompartida';

  @override
  String get flReservedBytes => 'Bytes reservados';

  @override
  String get flAuthentication => 'Autenticación';

  @override
  String get flAuthDigest => 'Resumen de autenticación';

  @override
  String get flCaCert => 'Certificado de CA (PEM)';

  @override
  String get flClientCert => 'Certificado de cliente (PEM)';

  @override
  String get flClientKey => 'Clave de cliente (PEM)';

  @override
  String get flControlWrap => 'Protección del canal de control';

  @override
  String get flControlWrapKey => 'Clave del canal de control';

  @override
  String get flKeyDirection => 'Dirección de la clave';

  @override
  String get flRemoteCertType => 'Tipo de certificado remoto';

  @override
  String get flVerifyServerName => 'Verificar el nombre del servidor';

  @override
  String get flYourIdentity => 'Tu identidad';

  @override
  String get flServerIdentity => 'Identidad del servidor';

  @override
  String get flServerCertTrust => 'Certificado del servidor de confianza (PEM)';

  @override
  String get flUseSystemIke => 'Usar el cliente IKEv2 propio del teléfono';

  @override
  String get flUseTcp => 'Usar TCP';

  @override
  String get flHostKeys => 'Claves del host';

  @override
  String get flPrivateKeyPem => 'Clave privada (PEM)';

  @override
  String get flKeyPassphrase => 'Frase de contraseña de la clave';

  @override
  String get flBridges => 'Puentes';

  @override
  String get flBridgeLines => 'Líneas de puente';

  @override
  String get flJc => 'Jc (cantidad de paquetes basura)';

  @override
  String get flSignaturePacket => 'I1 (paquete de firma)';

  @override
  String get hpAuthorizedKeys =>
      'formato authorized_keys; si está vacío, acepta cualquier clave';

  @override
  String get hpIkeTcp =>
      'Transporta IKE y ESP por TCP en redes que bloquean UDP';

  @override
  String get hpDefaultsToServer => 'Por defecto, la dirección del servidor';

  @override
  String get hpTorBridges =>
      'Vacío: se conecta a Tor directamente o usa las líneas de puente de abajo';

  @override
  String get hpExampleAddress => 'Por ejemplo 10.8.0.2/32';

  @override
  String get hpExamplePlugin => 'Por ejemplo shadow-tls o v2ray-plugin';

  @override
  String get hpHostOrIp => 'Nombre de host o dirección IP';

  @override
  String get hpNeededReality => 'Necesario cuando Seguridad es reality';

  @override
  String get hpOnlySelfSigned =>
      'Solo para servidores con un certificado autofirmado que no puedes fijar';

  @override
  String get hpSafeSstp =>
      'Seguro para SSTP: el intercambio de contraseña demuestra la identidad del servidor';

  @override
  String get hpHysteriaObfs =>
      'salamander para Hysteria 2; la contraseña de ofuscación para Hysteria 1';

  @override
  String get hpTrustCert =>
      'Confía en este certificado en lugar de las autoridades del sistema';

  @override
  String get hpWhichBrowser => 'Qué handshake TLS de navegador imitar';

  @override
  String get hpWarpReserved =>
      'Tres números, como los listan las configuraciones de WARP';

  @override
  String get hpOneBridgePerLine =>
      'Un puente por línea, como en un torrc sin \"Bridge \"';

  @override
  String get exitTitle => 'Mostrar dirección de salida y país';

  @override
  String get exitHint =>
      'Consulta api.country.is para obtener tu IP y país, también sin conexión.';

  @override
  String exitIpLabel(String ip) {
    return 'IP $ip';
  }

  @override
  String connectedTo(String place) {
    return 'Conectado a $place';
  }

  @override
  String get noticesTitle => 'Licencias de código abierto';

  @override
  String get noticesIntro =>
      'Wardkeep tiene licencia MIT. Incluye el software de abajo, cada uno con su propia licencia.';

  @override
  String noticesMore(int count) {
    return '+$count más';
  }

  @override
  String noticesPackages(int count) {
    return '$count paquetes';
  }

  @override
  String get noticesLoadFailed => 'No se pudo leer la lista de licencias.';

  @override
  String formRequired(String label) {
    return '$label es obligatorio';
  }

  @override
  String formNotNumber(String label) {
    return '$label debe ser un número entero';
  }

  @override
  String formNotBool(String label) {
    return '$label debe estar activado o desactivado';
  }

  @override
  String formBadChoice(String label, String value, String choices) {
    return '$label: $value no está entre $choices';
  }

  @override
  String get formRealityOnlyVless => 'Reality solo está disponible para VLESS';

  @override
  String formUnknownSecurity(String value) {
    return 'Seguridad desconocida: $value';
  }

  @override
  String get formReservedBytes =>
      'Los bytes reservados deben ser números del 0 al 255';

  @override
  String get formRealityKeyRequired =>
      'La clave pública de Reality es obligatoria cuando Seguridad es Reality';

  @override
  String get importUnsupported =>
      'Esto no es un enlace de servidor, suscripción o configuración que Wardkeep pueda leer';

  @override
  String importUnsupportedScheme(String scheme) {
    return 'No se admiten los enlaces que empiezan por $scheme://';
  }

  @override
  String get importXrayServer =>
      'Esta es una configuración de servidor Xray. Impórtala en el servidor (omnitun-server import xray), no como perfil de cliente';

  @override
  String get subAuthFailed =>
      'La suscripción rechazó el inicio de sesión. Revisa el usuario, la contraseña o el token';

  @override
  String subHttp(String status) {
    return 'El servidor de la suscripción respondió HTTP $status';
  }

  @override
  String get subTooLarge => 'La suscripción supera los 10 MB';

  @override
  String get subBadUrl => 'Esa no es una dirección de suscripción válida';

  @override
  String get bypassIssueEmptyExpression => 'expresión vacía';

  @override
  String get bypassIssueBadExpression => 'no es una expresión válida';

  @override
  String get bypassIssueBadName => 'no es un nombre válido';

  @override
  String get bypassIssueGeo =>
      'las listas geo no se admiten; indica los dominios o rangos';

  @override
  String get bypassIssueBadEntry => 'no es un dominio, dirección ni rango';

  @override
  String bypassIssueTooMany(int limit) {
    return 'más de $limit entradas: el resto se ignora';
  }

  @override
  String get torStarting => 'Iniciando Tor';

  @override
  String torBootstrap(int percent) {
    return 'Conectando a Tor $percent%';
  }

  @override
  String get torCircuit => 'Construyendo un circuito de Tor';

  @override
  String torRetry(int attempt, int attempts) {
    return 'Reintentando Tor ($attempt/$attempts)';
  }

  @override
  String get importNoServer =>
      'No se encontró ningún servidor válido en este texto';

  @override
  String importJsonSyntax(String found, int line, int column) {
    return 'Esto no es un JSON válido: carácter inesperado $found en la línea $line, columna $column.';
  }

  @override
  String importJsonEnd(int line, int column) {
    return 'Esto no es un JSON válido: el texto termina demasiado pronto, en la línea $line, columna $column. Puede faltar un corchete, una llave o unas comillas de cierre.';
  }

  @override
  String get importJsonNoServer =>
      'Este JSON es válido, pero no contiene ningún servidor proxy. Usa una configuración de cliente con una salida VLESS, VMess, Trojan, Shadowsocks o similar.';

  @override
  String importJsonNoServerFound(String found) {
    return 'Este JSON es válido, pero no contiene ningún servidor proxy (contiene $found). Usa una configuración de cliente con una salida VLESS, VMess, Trojan, Shadowsocks o similar.';
  }

  @override
  String importTooLarge(int limit) {
    return 'Es demasiado grande para importarlo (el límite es $limit MB).';
  }

  @override
  String get importFileEmpty => 'El archivo está vacío.';

  @override
  String get importFileNotText =>
      'El archivo no es texto que Wardkeep pueda leer (parece binario o tiene una codificación desconocida). Usa un archivo de texto UTF-8 o UTF-16.';

  @override
  String get importFileNoPermission =>
      'Wardkeep no tiene permiso para leer este archivo.';

  @override
  String get importFileMissing =>
      'No se encontró el archivo. Puede haberse movido o eliminado.';

  @override
  String get importDetails => 'Detalles';

  @override
  String get importJsonNote =>
      'También sirve una configuración JSON (Xray, sing-box, SIP008) o una lista de ellas, como texto o como archivo.';

  @override
  String get ipdbTitle => 'Base de datos de países sin conexión';

  @override
  String get ipdbIntro =>
      'Descarga una base de datos una vez y Wardkeep averigua por sí mismo el país de un servidor o de una dirección, sin consultar un sitio web.';

  @override
  String ipdbSizeNote(String size) {
    return 'Unos $size · datos libres (dominio público)';
  }

  @override
  String get ipdbDownload => 'Descargar';

  @override
  String get ipdbContinue => 'Continuar';

  @override
  String get ipdbPause => 'Pausar';

  @override
  String get ipdbUpdate => 'Actualizar';

  @override
  String get ipdbDelete => 'Eliminar';

  @override
  String get ipdbDeleteTitle => '¿Eliminar la base de datos?';

  @override
  String get ipdbUse => 'Usar la base de datos';

  @override
  String get ipdbStepV4 => 'IPv4';

  @override
  String get ipdbStepV6 => 'IPv6';

  @override
  String get ipdbStepPrepare => 'Preparar';

  @override
  String get ipdbPreparing => 'Preparando…';

  @override
  String get ipdbReady => 'Listo';

  @override
  String ipdbStoppedAt(int percent) {
    return 'Se detuvo en el $percent%. Continuar retoma justo ahí.';
  }

  @override
  String ipdbFailed(String reason) {
    return 'Falló la descarga: $reason';
  }

  @override
  String ipdbReadyLine(String ranges, String size) {
    return '$ranges rangos · $size';
  }

  @override
  String ipdbVersion(String version, String date) {
    return 'Versión $version · $date';
  }

  @override
  String ipdbLeft(String time) {
    return 'Quedan $time';
  }

  @override
  String get ipdbSource =>
      'Datos: registros regionales de internet y anuncios de ASN (CC0), del proyecto ip-location-db.';

  @override
  String get ipdbSubNone => 'Encuentra países sin consultar un sitio web';

  @override
  String ipdbSubReady(String size) {
    return 'Activado · $size';
  }

  @override
  String ipdbSubOff(String size) {
    return 'Desactivado · $size';
  }

  @override
  String ipdbSubDownloading(int percent) {
    return 'Descargando $percent%';
  }

  @override
  String ipdbSubStopped(int percent) {
    return 'Detenido en el $percent%';
  }

  @override
  String get ipdbErrNetwork => 'sin conexión con los servidores de datos';

  @override
  String get ipdbErrMirrors =>
      'los servidores de datos no enviaron el archivo correcto';

  @override
  String get bypassCountriesTitle => 'Países';

  @override
  String get bypassCountriesNone => 'Ningún país elegido';

  @override
  String bypassCountriesMore(String names, int count) {
    return '$names +$count';
  }

  @override
  String get bypassCountriesIntro =>
      'El tráfico hacia los países elegidos va directo a internet, sin pasar por la VPN. Sus rangos de direcciones vienen de la base de datos de países sin conexión.';

  @override
  String get bypassCountriesGetDb => 'Obtener la base de datos de países';

  @override
  String get bypassCountriesSearch => 'Buscar países';

  @override
  String get windowMinimize => 'Minimizar';

  @override
  String get windowMaximize => 'Maximizar';

  @override
  String get windowRestore => 'Restaurar';

  @override
  String get windowClose => 'Cerrar';

  @override
  String get windowFullScreen => 'Pantalla completa';

  @override
  String get windowExitFullScreen => 'Salir de pantalla completa';

  @override
  String get globeRecenter => 'Centrar la Tierra';

  @override
  String get bypassCountriesZoneIntro =>
      'Cada país que marcas descarga sus rangos de direcciones (unos pocos kilobytes). La base de datos completa sin conexión es más exacta y no necesita descarga.';

  @override
  String get bypassCountriesDownloading => 'Descargando…';

  @override
  String get bypassCountriesFailed =>
      'No se pudo descargar. Toca para reintentar.';

  @override
  String get bypassCountriesYourServer =>
      'Tu servidor seleccionado está aquí: su tráfico también se saltaría la VPN.';

  @override
  String get ipv6Title => 'IPv6';

  @override
  String get ipv6Hint =>
      'Desactivado: solo se usa IPv4; las conexiones IPv6 se rechazan, no salen por fuera de la VPN.';

  @override
  String get mtuTitle => 'MTU';

  @override
  String get mtuAuto => 'Predeterminado';

  @override
  String get mtuHelp =>
      'Tamaño de paquete del túnel (solo modo VPN). Prueba entre 1280 y 1420 si algunos sitios se cuelgan en la red móvil. Vacío es el valor predeterminado.';

  @override
  String mtuInvalid(int min, int max) {
    return 'Introduce un número de $min a $max.';
  }

  @override
  String get trayOpen => 'Abrir Wardkeep';

  @override
  String get trayQuit => 'Salir';

  @override
  String get traySwitchServer => 'Cambiar de servidor';

  @override
  String get keepInTray => 'Seguir en la bandeja del sistema';

  @override
  String get keepInTrayHint =>
      'Al cerrar la ventana solo se oculta. Usa «Salir» en el menú de la bandeja para cerrar la app y la VPN.';

  @override
  String usageUsed(String size) {
    return '$size usados';
  }

  @override
  String get menuResetUsage => 'Reiniciar uso de datos';

  @override
  String get dnsPickerHelp =>
      'Los nombres de sitios se consultan a través de la VPN con el resolvedor que elijas. DNSCrypt además demuestra que la respuesta viene de ese resolvedor.';

  @override
  String get dnsDefault => 'Predeterminado';

  @override
  String get dnsSectionDnscrypt =>
      'DNSCrypt · DNSSEC, sin registros, sin filtrado';

  @override
  String get dnsCustom => 'Personalizado';

  @override
  String get dnsCustomLabel => 'Dirección o DNS stamp';

  @override
  String get dnsAnonymized => 'DNSCrypt anonimizado';

  @override
  String get dnsAnonymizedHint =>
      'Las consultas pasan por un relé, así que el resolvedor nunca ve de dónde vienen';

  @override
  String get dnsAnonymizedNeedsDnscrypt =>
      'Elige un resolvedor DNSCrypt para usar esto';

  @override
  String get dnsRelay => 'Relé';

  @override
  String get dnsRelayChoose => 'Elige un relé';

  @override
  String get dnsRelayAutomatic => 'Automático (otro operador)';

  @override
  String get dnsErrAddress =>
      'Usa una dirección que empiece por https://, tls://, tcp:// o udp://, o un stamp sdns://';

  @override
  String get dnsErrDamaged =>
      'Este stamp está dañado o cortado. Cópialo de nuevo.';

  @override
  String get dnsErrUnsupported => 'Este tipo de stamp no es compatible';

  @override
  String get dnsErrRelayStamp =>
      'Este es el stamp de un relé, no de un resolvedor';

  @override
  String dnsLine(String resolver) {
    return 'DNS: $resolver';
  }

  @override
  String get dnsLimits =>
      'Esto protege los nombres que consultas. No oculta a qué sitios te conectas después.';

  @override
  String get dnsAnonymizedShort => 'anonimizado';

  @override
  String get flAuthKey => 'Clave de autenticación';

  @override
  String get flControlServer => 'Servidor de control';

  @override
  String get flDeviceName => 'Nombre del dispositivo';

  @override
  String get flExitDevice => 'Dispositivo de salida';

  @override
  String get flUseSubnets => 'Usar las subredes de otros dispositivos';

  @override
  String get flTempDevice => 'Dispositivo temporal';

  @override
  String get hpAuthKey =>
      'Una clave preautorizada de la página de administración de Tailscale o creada con headscale preauthkeys create';

  @override
  String get hpControlServer =>
      'Vacío usa Tailscale; para Headscale, su dirección, como https://hs.example.com';

  @override
  String get hpDeviceName =>
      'El nombre de este dispositivo en la red; vacío usa el propio del dispositivo';

  @override
  String get hpExitDevice =>
      'Nombre o dirección del dispositivo cuya conexión a internet usar; vacío solo llega a tus dispositivos';

  @override
  String get hpTempDevice => 'Se quita de la red cuando se desconecta';

  @override
  String get devicesTitle => 'Mis dispositivos';

  @override
  String get devicesNotConnected =>
      'Conéctate con un perfil de Tailscale o Headscale para ver tus dispositivos.';

  @override
  String get devicesJoining => 'Uniéndose a la red…';

  @override
  String get devicesLoginNeeded =>
      'La red no aceptó la clave de este dispositivo. Crea una clave nueva y edita el perfil.';

  @override
  String get devicesEmpty => 'Aún no hay otros dispositivos en esta red.';

  @override
  String get devicesThisDevice => 'Este dispositivo';

  @override
  String get deviceOnline => 'En línea';

  @override
  String get deviceOffline => 'Sin conexión';

  @override
  String deviceLastSeen(String when) {
    return 'Visto por última vez $when';
  }

  @override
  String get deviceUseAsExit => 'Usar como salida';

  @override
  String get deviceStopExit => 'Dejar de usar como salida';

  @override
  String get deviceIsExit => 'Salida en uso';

  @override
  String get devicesExitHint =>
      'Usa uno de tus dispositivos como salida: todo tu tráfico sale por su conexión.';

  @override
  String get deviceCopyName => 'Copiar nombre';

  @override
  String get deviceCopyAddress => 'Copiar dirección';

  @override
  String get deviceCopied => 'Copiado';

  @override
  String get errMeshExit =>
      'Ese dispositivo no se puede usar como salida ahora. Debe estar en línea y ofrecer su conexión.';

  @override
  String get wnTlsInsecure =>
      'No se comprueba el certificado del servidor. Cualquiera en la ruta puede leer o cambiar tu tráfico.';

  @override
  String get wnNoTls =>
      'El tráfico no va envuelto en TLS. Es fácil de reconocer y puede leerse por el camino.';

  @override
  String get wnVmessLegacy =>
      'VMess es un protocolo antiguo y fácil de reconocer. VLESS con Reality es mejor opción.';

  @override
  String get wnSsPlain =>
      'Sin un complemento como shadow-tls, el tráfico parece bytes aleatorios, y algunas redes bloquean ese patrón.';

  @override
  String get wnHysteria1 =>
      'Hysteria 1 está obsoleto. Usa Hysteria 2 si el servidor lo admite.';

  @override
  String get wnDpiVisible =>
      'Este protocolo es fácil de identificar y suele bloquearse en redes estrictas.';

  @override
  String get wnSshVisible => 'Los túneles SSH son fáciles de identificar.';

  @override
  String get wnDnsttSlow =>
      'Lento (normalmente muy por debajo de 1 Mbit/s) y solo TCP. Envía muchas consultas DNS que la red puede ver. Úsalo cuando nada más funcione.';

  @override
  String get wnDnsttOpen =>
      'Sin usuario ni contraseña: cualquiera con este enlace puede usar el servidor.';

  @override
  String get wnMuxLossy =>
      'La multiplexación junta muchas conexiones en una. Un enlace malo puede ralentizarlas todas.';

  @override
  String get wnFragmentSide =>
      'Fragmentar el saludo ayuda contra algunos filtros, puede fallar en otros y añade retardo.';

  @override
  String get wnEchServer =>
      'Necesita un servidor compatible con ECH. Si no, la conexión falla.';

  @override
  String get wnWgChain =>
      'WireGuard dentro de un proxy: si el proxy es lento, el túnel puede atascarse. El proxy debe transportar UDP.';

  @override
  String get wnSubUnsigned =>
      'Esta lista no está firmada, así que no se puede detectar si la cambian.';
}
