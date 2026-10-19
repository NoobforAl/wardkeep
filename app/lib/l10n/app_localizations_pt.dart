// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Wardkeep';

  @override
  String get actionSave => 'Salvar';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionDelete => 'Excluir';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionReset => 'Redefinir';

  @override
  String get actionSkip => 'Pular';

  @override
  String get actionNext => 'Avançar';

  @override
  String get actionImport => 'Importar';

  @override
  String get actionDownload => 'Baixar';

  @override
  String get actionCopyAll => 'Copiar tudo';

  @override
  String get actionClear => 'Limpar';

  @override
  String get tooltipMore => 'Mais';

  @override
  String get tooltipShow => 'Mostrar';

  @override
  String get tooltipHide => 'Ocultar';

  @override
  String get searchHint => 'Pesquisar';

  @override
  String get tooltipLogs => 'Registros';

  @override
  String get tooltipSettings => 'Configurações';

  @override
  String get statusConnected => 'Conectado';

  @override
  String get statusConnecting => 'Conectando…';

  @override
  String get statusDisconnecting => 'Desconectando…';

  @override
  String get statusError => 'Falha na conexão';

  @override
  String get statusNoInternet => 'Sem conexão com a internet';

  @override
  String get statusDisconnected => 'Não conectado';

  @override
  String get stagePermission => 'Aguardando permissão de VPN';

  @override
  String get stageNetworkCheck => 'Verificando a conexão com a internet';

  @override
  String get stagePrepare => 'Preparando a configuração';

  @override
  String get stageEngineStart => 'Iniciando o motor';

  @override
  String get stageTunnelUp => 'Abrindo o túnel';

  @override
  String get stageHandshake => 'Contatando o servidor';

  @override
  String get stageConnected => 'Conectado';

  @override
  String get buttonConnect => 'Conectar';

  @override
  String get buttonDisconnect => 'Desconectar';

  @override
  String get buttonCancel => 'Cancelar';

  @override
  String get locationLabel => 'Local';

  @override
  String get noServers => 'Nenhum servidor';

  @override
  String get noServersHint => 'Adicione um para começar';

  @override
  String get automatic => 'Automático';

  @override
  String get automaticHint => 'O servidor mais rápido; troca em caso de falha';

  @override
  String get anyServerInCountry => 'Qualquer servidor deste país';

  @override
  String get torNetwork => 'Rede Tor';

  @override
  String get torHopBridge => 'Ponte';

  @override
  String get torHopEntry => 'Entrada';

  @override
  String get torHopRelay => 'Retransmissor';

  @override
  String get torHopExit => 'Saída';

  @override
  String get torHopHidden => 'Oculto';

  @override
  String get torHopUnknown => 'Desconhecido';

  @override
  String get hopYou => 'Você';

  @override
  String get hopYouNote =>
      'É aqui que você realmente está. Seu tráfego começa aqui.';

  @override
  String get hopServer => 'Servidor';

  @override
  String get hopServerNote =>
      'Seu tráfego viaja criptografado até este servidor e sai por aqui, então os sites veem o endereço dele, não o seu.';

  @override
  String get hopBridgeNote =>
      'Seu primeiro salto. Uma ponte esconde da sua rede que você usa o Tor. Ela sabe quem você é, mas não para onde você vai.';

  @override
  String get hopEntryNote =>
      'O primeiro retransmissor. Ele conhece seu endereço, mas não o que você visita.';

  @override
  String get hopRelayNote =>
      'O retransmissor do meio. Ele não sabe quem você é nem o que você visita; apenas repassa o tráfego.';

  @override
  String get hopExitNote =>
      'O último retransmissor. Ele vê para onde você vai, mas não quem você é, e os sites veem o endereço dele.';

  @override
  String get hopHiddenNote =>
      'A localização da ponte é escondida pelo transporte, então não pode ser mostrada no mapa.';

  @override
  String get hopTransport => 'Transporte';

  @override
  String get hopProtocol => 'Protocolo';

  @override
  String get hopAddress => 'Endereço';

  @override
  String get hopLatency => 'Latência';

  @override
  String get hopExitAddress => 'Endereço de saída';

  @override
  String get menuNewGroup => 'Novo grupo';

  @override
  String get groupNameHint => 'Nome do grupo';

  @override
  String get groupCreate => 'Criar';

  @override
  String get menuMoveToGroup => 'Mover para um grupo';

  @override
  String get groupMoveTitle => 'Mover para';

  @override
  String get menuRenameGroup => 'Renomear';

  @override
  String get menuDeleteGroup => 'Excluir grupo';

  @override
  String get groupDeleteTitle => 'Excluir este grupo?';

  @override
  String groupDeleteBody(String name) {
    return 'Os servidores dele não são excluídos. Eles voltam para $name.';
  }

  @override
  String get groupEmptyHint =>
      'Ainda não há servidores. Abra o menu de um servidor e escolha Mover para um grupo.';

  @override
  String get menuShareGroupFile => 'Salvar como arquivo de texto';

  @override
  String get menuCopyGroupLinks => 'Copiar links';

  @override
  String groupSavedToast(String servers) {
    return 'Salvo: $servers';
  }

  @override
  String groupCopiedToast(String servers) {
    return 'Copiado: $servers';
  }

  @override
  String get groupNothingToShare =>
      'Nenhum destes servidores tem link de compartilhamento.';

  @override
  String groupSkipped(String servers) {
    return 'Ignorados, sem link de compartilhamento: $servers';
  }

  @override
  String get emptyTitle => 'Nenhum perfil ainda';

  @override
  String get emptyHint => 'Importe uma configuração, link ou assinatura.';

  @override
  String get importConfig => 'Importar configuração';

  @override
  String failoverToast(String to, String from) {
    return 'Trocado para $to — $from parou de responder';
  }

  @override
  String get unknownLocation => 'Local desconhecido';

  @override
  String errorFailed(String stage, String reason) {
    return 'Falha em «$stage»: $reason';
  }

  @override
  String get errTimeout => 'o servidor não respondeu a tempo';

  @override
  String get errRefused => 'o servidor recusou a conexão';

  @override
  String get errReset => 'a conexão foi redefinida pela rede';

  @override
  String get errNoRoute =>
      'não é possível alcançar o servidor a partir desta rede';

  @override
  String get errNetworkUnreachable => 'a rede está inacessível';

  @override
  String get errDns => 'não foi possível resolver o nome do servidor';

  @override
  String get errTls => 'o certificado de segurança do servidor foi rejeitado';

  @override
  String get errAuth => 'o nome de usuário ou a senha foi rejeitado';

  @override
  String get errClosed => 'o servidor encerrou a conexão';

  @override
  String get errCertDate =>
      'o certificado do servidor expirou ou ainda não é válido (verifique também a data e a hora deste telefone)';

  @override
  String get errCertUntrusted =>
      'o certificado do servidor não é assinado por uma autoridade confiável';

  @override
  String get errCertName =>
      'o certificado do servidor é de um nome diferente do usado na conexão';

  @override
  String get errTlsKeys =>
      'a chave compartilhada (tls-auth ou tls-crypt) não corresponde à do servidor';

  @override
  String get errReality =>
      'o servidor rejeitou o handshake do Reality (verifique a chave pública, o short ID e o nome do servidor)';

  @override
  String get errNoHandshake =>
      'o servidor não respondeu ao handshake (verifique as chaves, o endpoint e se a porta UDP está aberta)';

  @override
  String get errUdpBlocked =>
      'o servidor não respondeu por UDP; esta rede pode bloqueá-lo, tente um servidor baseado em TCP';

  @override
  String get errPortInUse => 'a porta local já está em uso por outro app';

  @override
  String get errTorTimeout =>
      'O Tor não terminou de conectar a tempo. Esta rede pode bloquear o Tor; use uma ponte (Snowflake ou obfs4)';

  @override
  String get errTorBridgeTimeout =>
      'O Tor não terminou de conectar a tempo. A ponte pode estar bloqueada ou sobrecarregada; tente outro tipo de ponte (Snowflake ou obfs4)';

  @override
  String get errTorBadBridge =>
      'uma linha de ponte do Tor não é válida (precisa de transporte, endereço e impressão digital)';

  @override
  String get errTorMissing => 'esta versão não inclui o cliente Tor';

  @override
  String get errPermission => 'a permissão de VPN não foi concedida';

  @override
  String get errCoreLost => 'Conexão com o serviço principal perdida';

  @override
  String get selectLocation => 'Selecionar local';

  @override
  String get testSpeedTooltip => 'Testar a velocidade de todos os servidores';

  @override
  String get addServersTooltip => 'Adicionar servidores';

  @override
  String get menuImport => 'Importar configuração, link ou QR';

  @override
  String get menuNewServer => 'Adicionar um servidor manualmente';

  @override
  String get menuSubscription => 'Adicionar uma assinatura';

  @override
  String get menuManage => 'Gerenciar servidores e assinaturas';

  @override
  String get menuSetDefault => 'Tornar padrão';

  @override
  String get badgeDefault => 'Padrão';

  @override
  String get menuDeleteAll => 'Excluir todos os servidores';

  @override
  String get deleteAllTitle => 'Excluir todos os servidores?';

  @override
  String get deleteAllBody =>
      'Todos os servidores e assinaturas adicionados serão removidos. A conexão Tor integrada permanece, e o app volta a ela.';

  @override
  String get menuRestoreTor => 'Restaurar padrões do Tor';

  @override
  String get deletedAllToast => 'Todos os servidores excluídos';

  @override
  String defaultSetToast(String name) {
    return '$name agora é o padrão';
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
  String get otherGroup => 'Outros';

  @override
  String get torGroup => 'Tor';

  @override
  String get noServersYet => 'Nenhum servidor ainda';

  @override
  String get importHintShort =>
      'Importe um arquivo de configuração, link ou assinatura.';

  @override
  String get showServers => 'Mostrar servidores';

  @override
  String get hideServers => 'Ocultar servidores';

  @override
  String get menuEditServer => 'Editar';

  @override
  String get menuBridgeSettings => 'Configurações das pontes';

  @override
  String get menuShare => 'Compartilhar link ou QR';

  @override
  String get menuSetCountry => 'Definir país';

  @override
  String get menuCredentials => 'Usuário e senha';

  @override
  String needsSignIn(String address) {
    return '$address · requer login';
  }

  @override
  String get countryOfServer => 'País deste servidor';

  @override
  String get guessFromName => 'Deduzir pelo nome';

  @override
  String get latencyNotTested => 'Não testado';

  @override
  String get latencyUnreachable => 'Inacessível';

  @override
  String get latencyTimeout => 'tempo esgotado';

  @override
  String latencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String get unknownCountry => 'País desconhecido';

  @override
  String get addServerTitle => 'Adicionar um servidor';

  @override
  String get addServerIntro =>
      'Escolha um protocolo. Um link ou QR é mais rápido: use Importar.';

  @override
  String newServerTitle(String label) {
    return 'Novo servidor $label';
  }

  @override
  String get editServerTitle => 'Editar servidor';

  @override
  String get torBridgesTitle => 'Pontes do Tor';

  @override
  String get subscriptionEditNote =>
      'Este servidor vem de uma assinatura: as alterações são substituídas quando ela é atualizada.';

  @override
  String get moreOptions => 'Mais opções';

  @override
  String get countryRow => 'País';

  @override
  String get countryAuto => 'Deduzido pelo nome e endereço';

  @override
  String get alreadyInList => 'Este servidor já está na lista';

  @override
  String get choiceDefault => 'Padrão';

  @override
  String get torBridgesNone => 'Nenhuma (direto, ou as linhas abaixo)';

  @override
  String get torBridgesSnowflake => 'Snowflake';

  @override
  String get torBridgesObfs4 => 'obfs4 (pontes integradas)';

  @override
  String get listHelper => 'Separe os valores com vírgulas';

  @override
  String get fillPaste => 'Colar';

  @override
  String get fillFile => 'Arquivo';

  @override
  String get fillScanQr => 'Escanear QR';

  @override
  String get openTextFile => 'Abrir um arquivo de texto';

  @override
  String couldNotReadFile(String error) {
    return 'Não foi possível ler o arquivo: $error';
  }

  @override
  String fieldRequired(String label) {
    return '$label *';
  }

  @override
  String formNoEditor(String protocol) {
    return 'Não há editor para $protocol';
  }

  @override
  String get shareScanHint => 'Escaneie com o Wardkeep ou copie o link.';

  @override
  String get shareCopy => 'Copiar link';

  @override
  String get shareCopied => 'Link copiado';

  @override
  String get shareWarning =>
      'Contém a senha ou a chave do servidor. Compartilhe com cuidado.';

  @override
  String shareFailed(String reason) {
    return 'Este servidor não pode ser compartilhado como link: $reason';
  }

  @override
  String get shareTooLong => 'Longo demais para um código QR: copie o link';

  @override
  String get obTitle1 => 'Privado e simples';

  @override
  String get obText1 =>
      'Uma tela tranquila para VPN, proxy e Tor. Escolha um lugar e toque em Conectar.';

  @override
  String get obTitle2 => 'Adicione seus servidores';

  @override
  String get obText2 =>
      'Importe um link, código QR, arquivo de configuração ou assinatura. Ou adicione um servidor manualmente.';

  @override
  String get obTitle3Android => 'O Android vai perguntar uma vez';

  @override
  String get obText3Android =>
      'O Android vai pedir permissão para uma conexão VPN. Aceite para ficar protegido.';

  @override
  String get obTitle3Desktop => 'Pronto quando precisar';

  @override
  String get obText3Desktop =>
      'Inicia no modo proxy, sem permissões especiais. Ative o modo VPN em Configurações para capturar todo o tráfego.';

  @override
  String get obAddFirst => 'Adicionar meu primeiro servidor';

  @override
  String get bypassTitle => 'Listas de exceção';

  @override
  String get bypassAddTooltip => 'Adicionar uma lista';

  @override
  String get bypassFromClipboard => 'Colar da área de transferência';

  @override
  String get bypassFromFile => 'Abrir um arquivo .txt';

  @override
  String get bypassFromUrl => 'Baixar de um link';

  @override
  String get bypassType => 'Digitar';

  @override
  String get bypassClipboardEmpty => 'A área de transferência está vazia';

  @override
  String get bypassPickFile => 'Abrir uma lista de exceção (.txt)';

  @override
  String bypassDownloadFailed(String error) {
    return 'Não foi possível baixar a lista: $error';
  }

  @override
  String get bypassIntro =>
      'Sites e endereços que não passam pela VPN. Um por linha: example.com, full:www.example.com, keyword:bank, regexp:…, 203.0.113.7 ou 10.0.0.0/8. Linhas que começam com # são ignoradas.';

  @override
  String get bypassNoLists => 'Nenhuma lista ainda.';

  @override
  String get bypassTypeList => 'Digitar uma lista';

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
  String get bypassOnlyTitle => 'Só os listados usam a VPN';

  @override
  String get bypassOnlyOn => 'Todo o resto vai direto.';

  @override
  String get bypassOnlyOff => 'Os listados vão direto; o resto usa a VPN.';

  @override
  String get bypassNothing => 'Nenhuma lista ativada.';

  @override
  String bypassInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas em uso',
      many: '$count entradas em uso',
      one: '$count entrada em uso',
    );
    return '$_temp0. Vale a partir da próxima conexão.';
  }

  @override
  String get bypassHttpLink => 'Digite um link http(s)';

  @override
  String bypassServerAnswered(int code) {
    return 'o servidor respondeu $code';
  }

  @override
  String get bypassTooLarge => 'a lista é maior que 5 MB';

  @override
  String get bypassDownloadTitle => 'Baixar uma lista';

  @override
  String get bypassNewList => 'Nova lista';

  @override
  String get bypassEditList => 'Editar lista';

  @override
  String get bypassName => 'Nome';

  @override
  String get bypassEntriesLabel => 'Entradas, uma por linha';

  @override
  String get bypassNoUsable => 'Nenhuma entrada utilizável ainda.';

  @override
  String bypassSummary(String entries, String names, String ranges) {
    return '$entries · $names, $ranges.';
  }

  @override
  String bypassNames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nomes',
      many: '$count nomes',
      one: '$count nome',
    );
    return '$_temp0';
  }

  @override
  String bypassRanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count endereços ou intervalos',
      many: '$count endereços ou intervalos',
      one: '$count endereço ou intervalo',
    );
    return '$_temp0';
  }

  @override
  String bypassIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linhas serão ignoradas:',
      many: '$count linhas serão ignoradas:',
      one: '$count linha será ignorada:',
    );
    return '$_temp0';
  }

  @override
  String bypassMoreIssues(int count) {
    return '… e mais $count';
  }

  @override
  String get bypassReconnect => 'Reconecte para usar a nova lista';

  @override
  String get bypassDefaultName => 'Minha lista';

  @override
  String get bypassPastedName => 'Lista colada';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsServers => 'Servidores';

  @override
  String get manageServers => 'Gerenciar servidores';

  @override
  String get manageServersHint => 'Servidores e assinaturas';

  @override
  String get settingsConnection => 'Conexão';

  @override
  String get vpnMode => 'Modo VPN (todo o tráfego)';

  @override
  String get vpnModeHint => 'Desativado: só proxy, sem permissão de VPN';

  @override
  String get systemProxy => 'Definir o proxy do sistema';

  @override
  String get systemProxyHint =>
      'Define o proxy do sistema enquanto estiver conectado';

  @override
  String get autoSwitch => 'Troca automática em caso de falha';

  @override
  String get autoSwitchHint => 'Tenta o próximo servidor se um falhar';

  @override
  String get bypassLan => 'Ignorar a rede local';

  @override
  String get bypassLanHint =>
      'Acesse diretamente os dispositivos locais (192.168.x.x, 10.x.x.x)';

  @override
  String get bypassListsHint => 'Sites e endereços que não passam pela VPN';

  @override
  String bypassListsInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas em uso',
      many: '$count entradas em uso',
      one: '$count entrada em uso',
    );
    return '$_temp0';
  }

  @override
  String get alwaysOnTitle => 'VPN sempre ativa e kill switch';

  @override
  String get alwaysOnHint =>
      'Reconecta na inicialização e bloqueia vazamentos. Defina nas configurações de VPN do Android.';

  @override
  String get openVpnSettingsFallback =>
      'Configurações → Rede → VPN → engrenagem ao lado de Wardkeep';

  @override
  String get splitTunneling => 'Tunelamento dividido';

  @override
  String splitSummaryOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Só $count apps selecionados usam a VPN',
      many: 'Só $count apps selecionados usam a VPN',
      one: 'Só $count app selecionado usa a VPN',
    );
    return '$_temp0';
  }

  @override
  String splitSummaryBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps ignoram a VPN',
      many: '$count apps ignoram a VPN',
      one: '$count app ignora a VPN',
    );
    return '$_temp0';
  }

  @override
  String get splitSummaryOff => 'Todos os apps usam a VPN';

  @override
  String get remoteDns => 'DNS remoto';

  @override
  String get remoteDnsHelp =>
      'DNS usado pelo túnel, p. ex. https://1.1.1.1/dns-query ou tls://1.1.1.1';

  @override
  String get settingsApp => 'App';

  @override
  String get appearance => 'Aparência';

  @override
  String get themeDark => 'Escuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeSystem => 'Seguir o sistema';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Padrão do sistema';

  @override
  String get stopOnClose => 'Parar a VPN ao fechar o app';

  @override
  String aboutLine(String engine) {
    return 'Licença MIT · motor: $engine';
  }

  @override
  String get splitTitle => 'Tunelamento dividido';

  @override
  String get splitAll => 'Todos os apps';

  @override
  String get splitOnlySelected => 'Só os selecionados';

  @override
  String get splitBypassSelected => 'Ignorar os selecionados';

  @override
  String get splitHelpOffMode => 'Todos os apps usam a VPN.';

  @override
  String get splitHelpOnlyNone => 'Nenhum app escolhido: todos usam a VPN.';

  @override
  String splitHelpOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Só $count apps usam a VPN.',
      many: 'Só $count apps usam a VPN.',
      one: 'Só $count app usa a VPN.',
    );
    return '$_temp0';
  }

  @override
  String splitHelpBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps vão direto.',
      many: '$count apps vão direto.',
      one: '$count app vai direto.',
    );
    return '$_temp0';
  }

  @override
  String get searchApps => 'Pesquisar apps';

  @override
  String get showSystemApps => 'Mostrar apps do sistema';

  @override
  String couldNotListApps(String error) {
    return 'Não foi possível listar os apps: $error';
  }

  @override
  String get scanTitle => 'Escanear código QR';

  @override
  String get scanTorch => 'Lanterna';

  @override
  String scanCameraUnavailable(String code) {
    return 'Câmera indisponível: $code';
  }

  @override
  String get scanPoint => 'Aponte a câmera para um código QR de configuração';

  @override
  String get credTitle => 'Entrar';

  @override
  String credNeeds(String name) {
    return '$name precisa de nome de usuário e senha.';
  }

  @override
  String get credUsername => 'Usuário';

  @override
  String get credPassword => 'Senha';

  @override
  String get logsEmpty => 'Nenhuma entrada no registro ainda.';

  @override
  String get profilesTitle => 'Gerenciar servidores';

  @override
  String get addSubscriptionTooltip => 'Adicionar assinatura';

  @override
  String get testLatencyTooltip => 'Testar latência';

  @override
  String get profilesEmptyHint =>
      'Nenhum perfil. Toque em Importar para adicionar um.';

  @override
  String get profilesDragHint =>
      'Mantenha pressionado e arraste para reordenar. A troca automática segue esta ordem.';

  @override
  String get myProfiles => 'Meus perfis';

  @override
  String subRefreshed(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perfis',
      many: '$count perfis',
      one: '$count perfil',
    );
    return '$name: $_temp0';
  }

  @override
  String get refreshTooltip => 'Atualizar';

  @override
  String get subDeleteWithProfiles => 'Excluir a assinatura e seus perfis';

  @override
  String subUsageOf(String used, String total) {
    return '$used de $total';
  }

  @override
  String subUsed(String used) {
    return '$used usados';
  }

  @override
  String get subExpired => 'expirada';

  @override
  String get subExpiresToday => 'expira hoje';

  @override
  String subExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'expira em $days dias',
      many: 'expira em $days dias',
      one: 'expira em $days dia',
    );
    return '$_temp0';
  }

  @override
  String subUpdated(String ago) {
    return 'atualizada $ago';
  }

  @override
  String get agoJustNow => 'agora mesmo';

  @override
  String agoMinutes(int count) {
    return 'há $count min';
  }

  @override
  String agoHours(int count) {
    return 'há $count h';
  }

  @override
  String agoDays(int count) {
    return 'há $count d';
  }

  @override
  String subRefreshFailed(String error) {
    return 'A última atualização falhou: $error';
  }

  @override
  String get importTitle => 'Importar configuração';

  @override
  String get importDescription =>
      'Cole um link, configuração ou assinatura — ou abra um arquivo ou escaneie um código QR.';

  @override
  String get importScanQr => 'Escanear QR';

  @override
  String get importOpenFile => 'Abrir arquivo';

  @override
  String get importPaste => 'Colar';

  @override
  String get importSubscription => 'Assinatura';

  @override
  String get importTor => 'Tor';

  @override
  String get importAddTor => 'Adicionar Tor';

  @override
  String get importTorDirect => 'Tor (direto)';

  @override
  String get importTorSnowflake => 'Tor + ponte Snowflake';

  @override
  String get importTorObfs4 => 'Tor + pontes obfs4';

  @override
  String importedProfiles(int added, int dupes) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added perfis importados',
      many: '$added perfis importados',
      one: '$added perfil importado',
    );
    String _temp1 = intl.Intl.pluralLogic(
      dupes,
      locale: localeName,
      other: ', $dupes já existentes',
      many: ', $dupes já existentes',
      one: ', $dupes já existente',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String importNothing(String reason) {
    return 'Nada foi importado: $reason';
  }

  @override
  String importPartial(int added, int failed) {
    return 'Importados $added, com falha $failed';
  }

  @override
  String get subAddTitle => 'Adicionar assinatura';

  @override
  String get subEditTitle => 'Editar assinatura';

  @override
  String get subUrlLabel => 'URL da assinatura';

  @override
  String get subUrlHint =>
      'https://provider.example/sub/… ou nordvpn://<token>';

  @override
  String get subNameLabel => 'Nome (opcional)';

  @override
  String get subNameHelp => 'Padrão: o título do provedor ou o nome do host';

  @override
  String get subAuthLabel => 'Autenticação';

  @override
  String get authNone => 'Nenhuma';

  @override
  String get authBasic => 'Usuário e senha (Basic)';

  @override
  String get authBearer => 'Token Bearer';

  @override
  String get authHeader => 'Cabeçalho personalizado';

  @override
  String get authQuery => 'Token na URL';

  @override
  String get subUsername => 'Usuário';

  @override
  String get subPassword => 'Senha';

  @override
  String get subHeaderName => 'Nome do cabeçalho';

  @override
  String get subHeaderValue => 'Valor do cabeçalho';

  @override
  String get subParamName => 'Nome do parâmetro';

  @override
  String get subToken => 'Token';

  @override
  String get subDownloadLabel => 'Download';

  @override
  String get subDownloadHelp => 'Provedor bloqueado? A VPN ainda pode baixá-la';

  @override
  String get subViaDirect => 'Diretamente';

  @override
  String get subViaAuto => 'Direto, ou pela VPN se bloqueado';

  @override
  String get subViaTunnel => 'Sempre pela VPN (conecte primeiro)';

  @override
  String get subErrUrl =>
      'Digite uma URL de assinatura http(s) (ou nordvpn://<access token>)';

  @override
  String get subErrHeader => 'Digite o nome do cabeçalho';

  @override
  String get subErrToken => 'Digite o token';

  @override
  String get subAddAndDownload => 'Adicionar e baixar';

  @override
  String get subSaveAndRefresh => 'Salvar e atualizar';

  @override
  String subUpdatedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perfis',
      many: '$count perfis',
      one: '$count perfil',
    );
    return 'Assinatura atualizada: $_temp0';
  }

  @override
  String get flName => 'Nome';

  @override
  String get flServer => 'Servidor';

  @override
  String get flPort => 'Porta';

  @override
  String get flPassword => 'Senha';

  @override
  String get flUsername => 'Usuário';

  @override
  String get flUuid => 'UUID';

  @override
  String get flSecurity => 'Segurança';

  @override
  String get flFlow => 'Flow';

  @override
  String get flCipher => 'Cifra';

  @override
  String get flEncryption => 'Criptografia';

  @override
  String get flAlterId => 'Alter id';

  @override
  String get flTlsServerName => 'Nome do servidor TLS (SNI)';

  @override
  String get flTlsFingerprint => 'Impressão digital TLS';

  @override
  String get flAlpn => 'ALPN';

  @override
  String get flSkipCertCheck => 'Ignorar a verificação do certificado';

  @override
  String get flPinnedCert => 'Certificado fixado (PEM)';

  @override
  String get flRealityPublicKey => 'Chave pública do Reality';

  @override
  String get flRealityShortId => 'Short id do Reality';

  @override
  String get flTransport => 'Transporte';

  @override
  String get flHostHeader => 'Cabeçalho Host';

  @override
  String get flPath => 'Caminho';

  @override
  String get flGrpcService => 'Nome do serviço gRPC';

  @override
  String get flPlugin => 'Plugin';

  @override
  String get flPluginOptions => 'Opções do plugin';

  @override
  String get flObfuscation => 'Ofuscação';

  @override
  String get flObfsPassword => 'Senha de ofuscação';

  @override
  String get flUploadMbps => 'Upload (Mbps)';

  @override
  String get flDownloadMbps => 'Download (Mbps)';

  @override
  String get flCongestion => 'Controle de congestionamento';

  @override
  String get flUdpRelay => 'Modo de retransmissão UDP';

  @override
  String get flUseQuic => 'Usar HTTP/3 (QUIC)';

  @override
  String get flTunnelAddress => 'Seu endereço de túnel';

  @override
  String get flRoutedNetworks => 'Redes roteadas';

  @override
  String get flDnsServers => 'Servidores DNS';

  @override
  String get flMtu => 'MTU';

  @override
  String get flKeepalive => 'Keepalive (segundos)';

  @override
  String get flPrivateKey => 'Chave privada';

  @override
  String get flServerPublicKey => 'Chave pública do servidor';

  @override
  String get flPresharedKey => 'Chave pré-compartilhada';

  @override
  String get flReservedBytes => 'Bytes reservados';

  @override
  String get flAuthentication => 'Autenticação';

  @override
  String get flAuthDigest => 'Digest de autenticação';

  @override
  String get flCaCert => 'Certificado da CA (PEM)';

  @override
  String get flClientCert => 'Certificado do cliente (PEM)';

  @override
  String get flClientKey => 'Chave do cliente (PEM)';

  @override
  String get flControlWrap => 'Proteção do canal de controle';

  @override
  String get flControlWrapKey => 'Chave do canal de controle';

  @override
  String get flKeyDirection => 'Direção da chave';

  @override
  String get flRemoteCertType => 'Tipo de certificado remoto';

  @override
  String get flVerifyServerName => 'Verificar o nome do servidor';

  @override
  String get flYourIdentity => 'Sua identidade';

  @override
  String get flServerIdentity => 'Identidade do servidor';

  @override
  String get flServerCertTrust => 'Certificado do servidor a confiar (PEM)';

  @override
  String get flUseSystemIke => 'Usar o cliente IKEv2 do próprio telefone';

  @override
  String get flUseTcp => 'Usar TCP';

  @override
  String get flHostKeys => 'Chaves do host';

  @override
  String get flPrivateKeyPem => 'Chave privada (PEM)';

  @override
  String get flKeyPassphrase => 'Frase secreta da chave';

  @override
  String get flBridges => 'Pontes';

  @override
  String get flBridgeLines => 'Linhas de ponte';

  @override
  String get flJc => 'Jc (quantidade de pacotes lixo)';

  @override
  String get flSignaturePacket => 'I1 (pacote de assinatura)';

  @override
  String get hpAuthorizedKeys =>
      'formato authorized_keys; vazio aceita qualquer chave';

  @override
  String get hpIkeTcp =>
      'Transporta IKE e ESP por TCP em redes que bloqueiam UDP';

  @override
  String get hpDefaultsToServer => 'Padrão: o endereço do servidor';

  @override
  String get hpTorBridges =>
      'Vazio: conecta ao Tor diretamente ou usa as linhas de ponte abaixo';

  @override
  String get hpExampleAddress => 'Por exemplo 10.8.0.2/32';

  @override
  String get hpExamplePlugin => 'Por exemplo shadow-tls ou v2ray-plugin';

  @override
  String get hpHostOrIp => 'Nome do host ou endereço IP';

  @override
  String get hpNeededReality => 'Necessário quando Segurança é reality';

  @override
  String get hpOnlySelfSigned =>
      'Só para servidores com certificado autoassinado que não pode ser fixado';

  @override
  String get hpSafeSstp =>
      'Seguro para SSTP: a troca de senha comprova a identidade do servidor';

  @override
  String get hpHysteriaObfs =>
      'salamander para Hysteria 2; a senha de ofuscação para Hysteria 1';

  @override
  String get hpTrustCert =>
      'Confia neste certificado em vez das autoridades do sistema';

  @override
  String get hpWhichBrowser => 'O handshake TLS de qual navegador imitar';

  @override
  String get hpWarpReserved =>
      'Três números, como listados nas configurações do WARP';

  @override
  String get hpOneBridgePerLine =>
      'Uma ponte por linha, como em um torrc sem \"Bridge \"';

  @override
  String get exitTitle => 'Mostrar endereço de saída e país';

  @override
  String get exitHint =>
      'Consulta api.country.is para obter seu IP e país, também sem conexão.';

  @override
  String exitIpLabel(String ip) {
    return 'IP $ip';
  }

  @override
  String connectedTo(String place) {
    return 'Conectado a $place';
  }

  @override
  String get noticesTitle => 'Licenças de código aberto';

  @override
  String get noticesIntro =>
      'O Wardkeep tem licença MIT. Inclui os softwares abaixo, cada um com sua própria licença.';

  @override
  String noticesMore(int count) {
    return '+$count mais';
  }

  @override
  String noticesPackages(int count) {
    return '$count pacotes';
  }

  @override
  String get noticesLoadFailed => 'Não foi possível ler a lista de licenças.';

  @override
  String formRequired(String label) {
    return '$label é obrigatório';
  }

  @override
  String formNotNumber(String label) {
    return '$label deve ser um número inteiro';
  }

  @override
  String formNotBool(String label) {
    return '$label deve estar ativado ou desativado';
  }

  @override
  String formBadChoice(String label, String value, String choices) {
    return '$label: $value não está entre $choices';
  }

  @override
  String get formRealityOnlyVless => 'O Reality só está disponível para VLESS';

  @override
  String formUnknownSecurity(String value) {
    return 'Segurança desconhecida: $value';
  }

  @override
  String get formReservedBytes =>
      'Os bytes reservados devem ser números de 0 a 255';

  @override
  String get formRealityKeyRequired =>
      'A chave pública do Reality é obrigatória quando Segurança é Reality';

  @override
  String get importUnsupported =>
      'Isto não é um link de servidor, assinatura ou configuração que o Wardkeep consiga ler';

  @override
  String importUnsupportedScheme(String scheme) {
    return 'Links que começam com $scheme:// não são suportados';
  }

  @override
  String get importXrayServer =>
      'Esta é uma configuração de servidor Xray. Importe-a no servidor (omnitun-server import xray), não como perfil de cliente';

  @override
  String get subAuthFailed =>
      'A assinatura rejeitou o login. Verifique o usuário, a senha ou o token';

  @override
  String subHttp(String status) {
    return 'O servidor da assinatura respondeu HTTP $status';
  }

  @override
  String get subTooLarge => 'A assinatura é maior que 10 MB';

  @override
  String get subBadUrl => 'Esse não é um endereço de assinatura válido';

  @override
  String get bypassIssueEmptyExpression => 'expressão vazia';

  @override
  String get bypassIssueBadExpression => 'não é uma expressão válida';

  @override
  String get bypassIssueBadName => 'não é um nome válido';

  @override
  String get bypassIssueGeo =>
      'listas geo não são suportadas; liste os domínios ou intervalos';

  @override
  String get bypassIssueBadEntry => 'não é um domínio, endereço ou intervalo';

  @override
  String bypassIssueTooMany(int limit) {
    return 'mais de $limit entradas: o resto é ignorado';
  }

  @override
  String get torStarting => 'Iniciando o Tor';

  @override
  String torBootstrap(int percent) {
    return 'Conectando ao Tor $percent%';
  }

  @override
  String get torCircuit => 'Construindo um circuito do Tor';

  @override
  String torRetry(int attempt, int attempts) {
    return 'Tentando o Tor novamente ($attempt/$attempts)';
  }

  @override
  String get importNoServer =>
      'Nenhum servidor válido foi encontrado neste texto';

  @override
  String importJsonSyntax(String found, int line, int column) {
    return 'Isto não é um JSON válido: caractere inesperado $found na linha $line, coluna $column.';
  }

  @override
  String importJsonEnd(int line, int column) {
    return 'Isto não é um JSON válido: o texto termina cedo demais, na linha $line, coluna $column. Pode faltar um colchete, uma chave ou aspas de fechamento.';
  }

  @override
  String get importJsonNoServer =>
      'Este JSON é válido, mas não contém nenhum servidor proxy. Use uma configuração de cliente com uma saída VLESS, VMess, Trojan, Shadowsocks ou semelhante.';

  @override
  String importJsonNoServerFound(String found) {
    return 'Este JSON é válido, mas não contém nenhum servidor proxy (contém $found). Use uma configuração de cliente com uma saída VLESS, VMess, Trojan, Shadowsocks ou semelhante.';
  }

  @override
  String importTooLarge(int limit) {
    return 'É grande demais para importar (o limite é $limit MB).';
  }

  @override
  String get importFileEmpty => 'O arquivo está vazio.';

  @override
  String get importFileNotText =>
      'O arquivo não é um texto que o Wardkeep consiga ler (parece binário ou está em uma codificação desconhecida). Use um arquivo de texto UTF-8 ou UTF-16.';

  @override
  String get importFileNoPermission =>
      'O Wardkeep não tem permissão para ler este arquivo.';

  @override
  String get importFileMissing =>
      'O arquivo não foi encontrado. Pode ter sido movido ou excluído.';

  @override
  String get importDetails => 'Detalhes';

  @override
  String get importJsonNote =>
      'Uma configuração JSON (Xray, sing-box, SIP008) ou uma lista delas também funciona, como texto ou como arquivo.';

  @override
  String get ipdbTitle => 'Banco de dados de países offline';

  @override
  String get ipdbIntro =>
      'Baixe um banco de dados uma vez e o Wardkeep descobre sozinho o país de um servidor ou endereço, sem consultar um site.';

  @override
  String ipdbSizeNote(String size) {
    return 'Cerca de $size · dados livres (domínio público)';
  }

  @override
  String get ipdbDownload => 'Baixar';

  @override
  String get ipdbContinue => 'Continuar';

  @override
  String get ipdbPause => 'Pausar';

  @override
  String get ipdbUpdate => 'Atualizar';

  @override
  String get ipdbDelete => 'Excluir';

  @override
  String get ipdbDeleteTitle => 'Excluir o banco de dados?';

  @override
  String get ipdbUse => 'Usar o banco de dados';

  @override
  String get ipdbStepV4 => 'IPv4';

  @override
  String get ipdbStepV6 => 'IPv6';

  @override
  String get ipdbStepPrepare => 'Preparar';

  @override
  String get ipdbPreparing => 'Preparando…';

  @override
  String get ipdbReady => 'Pronto';

  @override
  String ipdbStoppedAt(int percent) {
    return 'Parou em $percent%. Continuar retoma exatamente daí.';
  }

  @override
  String ipdbFailed(String reason) {
    return 'Falha no download: $reason';
  }

  @override
  String ipdbReadyLine(String ranges, String size) {
    return '$ranges intervalos · $size';
  }

  @override
  String ipdbVersion(String version, String date) {
    return 'Versão $version · $date';
  }

  @override
  String ipdbLeft(String time) {
    return 'Faltam $time';
  }

  @override
  String get ipdbSource =>
      'Dados: registros regionais de internet e anúncios de ASN (CC0), do projeto ip-location-db.';

  @override
  String get ipdbSubNone => 'Encontre países sem consultar um site';

  @override
  String ipdbSubReady(String size) {
    return 'Ativado · $size';
  }

  @override
  String ipdbSubOff(String size) {
    return 'Desativado · $size';
  }

  @override
  String ipdbSubDownloading(int percent) {
    return 'Baixando $percent%';
  }

  @override
  String ipdbSubStopped(int percent) {
    return 'Parou em $percent%';
  }

  @override
  String get ipdbErrNetwork => 'sem conexão com os servidores de dados';

  @override
  String get ipdbErrMirrors =>
      'os servidores de dados não enviaram o arquivo correto';

  @override
  String get bypassCountriesTitle => 'Países';

  @override
  String get bypassCountriesNone => 'Nenhum país escolhido';

  @override
  String bypassCountriesMore(String names, int count) {
    return '$names +$count';
  }

  @override
  String get bypassCountriesIntro =>
      'O tráfego para os países escolhidos vai direto à internet, sem passar pela VPN. Os intervalos de endereços vêm do banco de dados de países offline.';

  @override
  String get bypassCountriesGetDb => 'Obter o banco de dados de países';

  @override
  String get bypassCountriesSearch => 'Pesquisar países';

  @override
  String get windowMinimize => 'Minimizar';

  @override
  String get windowMaximize => 'Maximizar';

  @override
  String get windowRestore => 'Restaurar';

  @override
  String get windowClose => 'Fechar';

  @override
  String get globeRecenter => 'Centralizar a Terra';

  @override
  String get bypassCountriesZoneIntro =>
      'Cada país marcado baixa seus intervalos de endereços (alguns quilobytes). O banco de dados offline completo é mais exato e não precisa de download.';

  @override
  String get bypassCountriesDownloading => 'Baixando…';

  @override
  String get bypassCountriesFailed =>
      'Não foi possível baixar. Toque para tentar novamente.';

  @override
  String get bypassCountriesYourServer =>
      'Seu servidor selecionado está aqui: o tráfego dele também ignoraria a VPN.';

  @override
  String get ipv6Title => 'IPv6';

  @override
  String get ipv6Hint =>
      'Desativado: só IPv4 é usado; conexões IPv6 são recusadas, não enviadas fora da VPN.';

  @override
  String get mtuTitle => 'MTU';

  @override
  String get mtuAuto => 'Padrão';

  @override
  String get mtuHelp =>
      'Tamanho do pacote do túnel (somente modo VPN). Tente de 1280 a 1420 se alguns sites travarem na rede móvel. Vazio é o padrão.';

  @override
  String mtuInvalid(int min, int max) {
    return 'Digite um número de $min a $max.';
  }

  @override
  String get trayOpen => 'Abrir o Wardkeep';

  @override
  String get trayQuit => 'Sair';

  @override
  String get traySwitchServer => 'Trocar de servidor';

  @override
  String get keepInTray => 'Continuar na bandeja do sistema';

  @override
  String get keepInTrayHint =>
      'Fechar a janela apenas a oculta. Use “Sair” no menu da bandeja para encerrar o app e a VPN.';

  @override
  String usageUsed(String size) {
    return '$size usados';
  }

  @override
  String get menuResetUsage => 'Zerar uso de dados';

  @override
  String get dnsPickerHelp =>
      'Os nomes de sites são consultados pela VPN no resolvedor que você escolher. O DNSCrypt também comprova que a resposta veio desse resolvedor.';

  @override
  String get dnsDefault => 'Padrão';

  @override
  String get dnsSectionDnscrypt =>
      'DNSCrypt · DNSSEC, sem registros, sem filtragem';

  @override
  String get dnsCustom => 'Personalizado';

  @override
  String get dnsCustomLabel => 'Endereço ou DNS stamp';

  @override
  String get dnsAnonymized => 'DNSCrypt anonimizado';

  @override
  String get dnsAnonymizedHint =>
      'As consultas passam por um relay, então o resolvedor nunca vê de onde vêm';

  @override
  String get dnsAnonymizedNeedsDnscrypt =>
      'Escolha um resolvedor DNSCrypt para usar isto';

  @override
  String get dnsRelay => 'Relay';

  @override
  String get dnsRelayChoose => 'Escolha um relay';

  @override
  String get dnsRelayAutomatic => 'Automático (outro operador)';

  @override
  String get dnsErrAddress =>
      'Use um endereço que comece com https://, tls://, tcp:// ou udp://, ou um stamp sdns://';

  @override
  String get dnsErrDamaged =>
      'Este stamp está danificado ou cortado. Copie-o novamente.';

  @override
  String get dnsErrUnsupported => 'Este tipo de stamp não é compatível';

  @override
  String get dnsErrRelayStamp =>
      'Este é o stamp de um relay, não de um resolvedor';

  @override
  String dnsLine(String resolver) {
    return 'DNS: $resolver';
  }

  @override
  String get dnsLimits =>
      'Isto protege os nomes que você consulta. Não esconde a quais sites você se conecta depois.';

  @override
  String get dnsAnonymizedShort => 'anonimizado';

  @override
  String get flAuthKey => 'Chave de autenticação';

  @override
  String get flControlServer => 'Servidor de controle';

  @override
  String get flDeviceName => 'Nome do dispositivo';

  @override
  String get flExitDevice => 'Dispositivo de saída';

  @override
  String get flUseSubnets => 'Usar as sub-redes de outros dispositivos';

  @override
  String get flTempDevice => 'Dispositivo temporário';

  @override
  String get hpAuthKey =>
      'Uma chave pré-autorizada da página de administração do Tailscale ou criada com headscale preauthkeys create';

  @override
  String get hpControlServer =>
      'Vazio usa o Tailscale; para o Headscale, o endereço dele, como https://hs.example.com';

  @override
  String get hpDeviceName =>
      'O nome deste dispositivo na rede; vazio usa o nome do próprio dispositivo';

  @override
  String get hpExitDevice =>
      'Nome ou endereço do dispositivo cuja conexão de internet usar; vazio alcança só os seus dispositivos';

  @override
  String get hpTempDevice => 'Removido da rede quando fica offline';

  @override
  String get devicesTitle => 'Meus dispositivos';

  @override
  String get devicesNotConnected =>
      'Conecte um perfil Tailscale ou Headscale para ver seus dispositivos.';

  @override
  String get devicesJoining => 'Entrando na rede…';

  @override
  String get devicesLoginNeeded =>
      'A rede não aceitou a chave deste dispositivo. Crie uma nova chave e edite o perfil.';

  @override
  String get devicesEmpty => 'Ainda não há outros dispositivos nesta rede.';

  @override
  String get devicesThisDevice => 'Este dispositivo';

  @override
  String get deviceOnline => 'Online';

  @override
  String get deviceOffline => 'Offline';

  @override
  String deviceLastSeen(String when) {
    return 'Visto pela última vez $when';
  }

  @override
  String get deviceUseAsExit => 'Usar como saída';

  @override
  String get deviceStopExit => 'Parar de usar como saída';

  @override
  String get deviceIsExit => 'Saída em uso';

  @override
  String get devicesExitHint =>
      'Use um dos seus dispositivos como saída: todo o seu tráfego sai pela conexão dele.';

  @override
  String get deviceCopyName => 'Copiar nome';

  @override
  String get deviceCopyAddress => 'Copiar endereço';

  @override
  String get deviceCopied => 'Copiado';

  @override
  String get errMeshExit =>
      'Esse dispositivo não pode ser usado como saída agora. Ele precisa estar online e oferecer a conexão.';
}
