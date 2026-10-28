// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Wardkeep';

  @override
  String get actionSave => 'Enregistrer';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionDelete => 'Supprimer';

  @override
  String get actionEdit => 'Modifier';

  @override
  String get actionReset => 'Réinitialiser';

  @override
  String get actionSkip => 'Passer';

  @override
  String get actionNext => 'Suivant';

  @override
  String get actionImport => 'Importer';

  @override
  String get actionDownload => 'Télécharger';

  @override
  String get actionCopyAll => 'Tout copier';

  @override
  String get actionClear => 'Effacer';

  @override
  String get tooltipMore => 'Plus';

  @override
  String get tooltipShow => 'Afficher';

  @override
  String get tooltipHide => 'Masquer';

  @override
  String get searchHint => 'Rechercher';

  @override
  String get tooltipLogs => 'Journaux';

  @override
  String get tooltipSettings => 'Paramètres';

  @override
  String get statusConnected => 'Connecté';

  @override
  String get statusConnecting => 'Connexion…';

  @override
  String get statusDisconnecting => 'Déconnexion…';

  @override
  String get statusError => 'Échec de la connexion';

  @override
  String get statusNoInternet => 'Pas de connexion Internet';

  @override
  String get statusDisconnected => 'Non connecté';

  @override
  String get stagePermission => 'En attente de l’autorisation VPN';

  @override
  String get stageNetworkCheck => 'Vérification de la connexion Internet';

  @override
  String get stagePrepare => 'Préparation de la configuration';

  @override
  String get stageEngineStart => 'Démarrage du moteur';

  @override
  String get stageTunnelUp => 'Ouverture du tunnel';

  @override
  String get stageHandshake => 'Contact du serveur';

  @override
  String get stageConnected => 'Connecté';

  @override
  String get buttonConnect => 'Connecter';

  @override
  String get buttonDisconnect => 'Déconnecter';

  @override
  String get buttonCancel => 'Annuler';

  @override
  String get locationLabel => 'Emplacement';

  @override
  String get noServers => 'Aucun serveur';

  @override
  String get noServersHint => 'Ajoutez-en un pour commencer';

  @override
  String get automatic => 'Automatique';

  @override
  String get automaticHint => 'Serveur le plus rapide, bascule en cas d’échec';

  @override
  String get anyServerInCountry => 'N’importe quel serveur de ce pays';

  @override
  String get torNetwork => 'Réseau Tor';

  @override
  String get torHopBridge => 'Pont';

  @override
  String get torHopEntry => 'Entrée';

  @override
  String get torHopRelay => 'Relais';

  @override
  String get torHopExit => 'Sortie';

  @override
  String get torHopHidden => 'Masqué';

  @override
  String get torHopUnknown => 'Inconnu';

  @override
  String get hopYou => 'Vous';

  @override
  String get hopYouNote =>
      'C\'est ici que vous êtes vraiment. Votre trafic part d\'ici.';

  @override
  String get hopServer => 'Serveur';

  @override
  String get hopServerNote =>
      'Votre trafic voyage chiffré jusqu\'à ce serveur et en ressort ici : les sites voient donc son adresse, pas la vôtre.';

  @override
  String get hopBridgeNote =>
      'Votre premier saut. Un pont cache à votre réseau que vous utilisez Tor. Il sait qui vous êtes, mais pas où vous allez.';

  @override
  String get hopEntryNote =>
      'Le premier relais. Il connaît votre adresse, mais pas ce que vous visitez.';

  @override
  String get hopRelayNote =>
      'Le relais intermédiaire. Il ignore qui vous êtes et ce que vous visitez ; il ne fait que transmettre le trafic.';

  @override
  String get hopExitNote =>
      'Le dernier relais. Il voit où vous allez, mais pas qui vous êtes, et les sites voient son adresse.';

  @override
  String get hopHiddenNote =>
      'L\'emplacement du pont est caché par son transport : il ne peut pas être placé sur la carte.';

  @override
  String get hopTransport => 'Transport';

  @override
  String get hopProtocol => 'Protocole';

  @override
  String get hopAddress => 'Adresse';

  @override
  String get hopLatency => 'Latence';

  @override
  String get hopExitAddress => 'Adresse de sortie';

  @override
  String get menuNewGroup => 'Nouveau groupe';

  @override
  String get groupNameHint => 'Nom du groupe';

  @override
  String get groupCreate => 'Créer';

  @override
  String get menuMoveToGroup => 'Déplacer vers un groupe';

  @override
  String get groupMoveTitle => 'Déplacer vers';

  @override
  String get menuRenameGroup => 'Renommer';

  @override
  String get menuDeleteGroup => 'Supprimer le groupe';

  @override
  String get groupDeleteTitle => 'Supprimer ce groupe ?';

  @override
  String groupDeleteBody(String name) {
    return 'Ses serveurs ne sont pas supprimés. Ils retournent dans $name.';
  }

  @override
  String get groupEmptyHint =>
      'Aucun serveur pour l\'instant. Ouvrez le menu d\'un serveur et choisissez Déplacer vers un groupe.';

  @override
  String get menuShareGroupFile => 'Enregistrer en fichier texte';

  @override
  String get menuCopyGroupLinks => 'Copier les liens';

  @override
  String groupSavedToast(String servers) {
    return 'Enregistré : $servers';
  }

  @override
  String groupCopiedToast(String servers) {
    return 'Copié : $servers';
  }

  @override
  String get groupNothingToShare =>
      'Aucun de ces serveurs n\'a de lien de partage.';

  @override
  String groupSkipped(String servers) {
    return 'Ignorés, sans lien de partage : $servers';
  }

  @override
  String get emptyTitle => 'Aucun profil';

  @override
  String get emptyHint => 'Importez une config, un lien ou un abonnement.';

  @override
  String get importConfig => 'Importer une config';

  @override
  String failoverToast(String to, String from) {
    return 'Passage à $to · $from ne répond plus';
  }

  @override
  String get unknownLocation => 'Emplacement inconnu';

  @override
  String errorFailed(String stage, String reason) {
    return 'Échec ($stage) : $reason';
  }

  @override
  String get errTimeout => 'le serveur n’a pas répondu à temps';

  @override
  String get errRefused => 'le serveur a refusé la connexion';

  @override
  String get errReset => 'la connexion a été réinitialisée par le réseau';

  @override
  String get errNoRoute => 'le serveur est inaccessible depuis ce réseau';

  @override
  String get errNetworkUnreachable => 'le réseau est inaccessible';

  @override
  String get errDns => 'le nom du serveur n’a pas pu être résolu';

  @override
  String get errTls => 'le certificat de sécurité du serveur a été rejeté';

  @override
  String get errAuth => 'le nom d’utilisateur ou le mot de passe a été rejeté';

  @override
  String get errClosed => 'le serveur a fermé la connexion';

  @override
  String get errCertDate =>
      'le certificat du serveur a expiré ou n’est pas encore valide (vérifiez aussi la date et l’heure de ce téléphone)';

  @override
  String get errCertUntrusted =>
      'le certificat du serveur n’est pas signé par une autorité de confiance';

  @override
  String get errCertName =>
      'le certificat du serveur correspond à un autre nom que celui auquel vous vous connectez';

  @override
  String get errTlsKeys =>
      'la clé partagée (tls-auth ou tls-crypt) ne correspond pas à celle du serveur';

  @override
  String get errReality =>
      'le serveur a rejeté la négociation Reality (vérifiez la clé publique, le short ID et le nom du serveur)';

  @override
  String get errNoHandshake =>
      'le serveur n’a pas répondu à la négociation (vérifiez les clés, le point de terminaison et que son port UDP est ouvert)';

  @override
  String get errUdpBlocked =>
      'le serveur n’a pas répondu en UDP ; ce réseau le bloque peut-être, essayez un serveur basé sur TCP';

  @override
  String get errPortInUse =>
      'le port local est déjà utilisé par une autre application';

  @override
  String get errTorTimeout =>
      'Tor n’a pas fini de se connecter à temps. Ce réseau bloque peut-être Tor ; utilisez un pont (Snowflake ou obfs4)';

  @override
  String get errTorBridgeTimeout =>
      'Tor n’a pas fini de se connecter à temps. Le pont est peut-être bloqué ou surchargé ; essayez un autre type de pont (Snowflake ou obfs4)';

  @override
  String get errTorBadBridge =>
      'une ligne de pont Tor n’est pas valide (il faut un transport, une adresse et une empreinte)';

  @override
  String get errTorMissing => 'cette version n’inclut pas le client Tor';

  @override
  String get errPermission => 'l’autorisation VPN n’a pas été accordée';

  @override
  String get errCoreLost => 'Connexion perdue avec le service principal';

  @override
  String get selectLocation => 'Choisir l’emplacement';

  @override
  String get testSpeedTooltip => 'Tester la vitesse de tous les serveurs';

  @override
  String get addServersTooltip => 'Ajouter des serveurs';

  @override
  String get menuImport => 'Importer une config, un lien ou un QR';

  @override
  String get menuNewServer => 'Ajouter un serveur manuellement';

  @override
  String get menuSubscription => 'Ajouter un abonnement';

  @override
  String get menuManage => 'Gérer les serveurs et abonnements';

  @override
  String get menuSetDefault => 'Définir par défaut';

  @override
  String get badgeDefault => 'Par défaut';

  @override
  String get menuDeleteAll => 'Supprimer tous les serveurs';

  @override
  String get deleteAllTitle => 'Supprimer tous les serveurs ?';

  @override
  String get deleteAllBody =>
      'Tous les serveurs et abonnements ajoutés sont supprimés. La connexion Tor intégrée est conservée et l’app y revient.';

  @override
  String get menuRestoreTor => 'Restaurer les valeurs Tor par défaut';

  @override
  String get deletedAllToast => 'Tous les serveurs ont été supprimés';

  @override
  String defaultSetToast(String name) {
    return '$name est maintenant le serveur par défaut';
  }

  @override
  String serversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serveurs',
      many: '$count serveurs',
      one: '$count serveur',
    );
    return '$_temp0';
  }

  @override
  String get otherGroup => 'Autres';

  @override
  String get torGroup => 'Tor';

  @override
  String get noServersYet => 'Aucun serveur pour l’instant';

  @override
  String get importHintShort =>
      'Importez un fichier de config, un lien ou un abonnement.';

  @override
  String get showServers => 'Afficher les serveurs';

  @override
  String get hideServers => 'Masquer les serveurs';

  @override
  String get menuEditServer => 'Modifier';

  @override
  String get menuBridgeSettings => 'Paramètres des ponts';

  @override
  String get menuShare => 'Partager un lien ou un QR';

  @override
  String get menuSetCountry => 'Définir le pays';

  @override
  String get menuCredentials => 'Nom d’utilisateur et mot de passe';

  @override
  String needsSignIn(String address) {
    return '$address · connexion requise';
  }

  @override
  String get countryOfServer => 'Pays de ce serveur';

  @override
  String get guessFromName => 'Déduire du nom';

  @override
  String get latencyNotTested => 'Non testé';

  @override
  String get latencyUnreachable => 'Injoignable';

  @override
  String get latencyTimeout => 'délai dépassé';

  @override
  String latencyMs(int ms) {
    return '$ms ms';
  }

  @override
  String get unknownCountry => 'Pays inconnu';

  @override
  String get addServerTitle => 'Ajouter un serveur';

  @override
  String get addServerIntro =>
      'Choisissez un protocole. Un lien ou un QR est plus rapide : utilisez Importer.';

  @override
  String newServerTitle(String label) {
    return 'Nouveau serveur $label';
  }

  @override
  String get editServerTitle => 'Modifier le serveur';

  @override
  String get torBridgesTitle => 'Ponts Tor';

  @override
  String get subscriptionEditNote =>
      'Ce serveur provient d’un abonnement : vos modifications seront remplacées à l’actualisation.';

  @override
  String get moreOptions => 'Plus d’options';

  @override
  String get countryRow => 'Pays';

  @override
  String get countryAuto => 'Déduit du nom et de l’adresse';

  @override
  String get alreadyInList => 'Ce serveur figure déjà dans la liste';

  @override
  String get choiceDefault => 'Par défaut';

  @override
  String get torBridgesNone => 'Aucun (direct, ou les lignes ci-dessous)';

  @override
  String get torBridgesSnowflake => 'Snowflake';

  @override
  String get torBridgesObfs4 => 'obfs4 (ponts intégrés)';

  @override
  String get listHelper => 'Séparez les valeurs par des virgules';

  @override
  String get fillPaste => 'Coller';

  @override
  String get fillFile => 'Fichier';

  @override
  String get fillScanQr => 'Scanner un QR';

  @override
  String get openTextFile => 'Ouvrir un fichier texte';

  @override
  String couldNotReadFile(String error) {
    return 'Impossible de lire le fichier : $error';
  }

  @override
  String fieldRequired(String label) {
    return '$label *';
  }

  @override
  String formNoEditor(String protocol) {
    return 'Aucun éditeur pour $protocol';
  }

  @override
  String get shareScanHint => 'Scannez avec Wardkeep ou copiez le lien.';

  @override
  String get shareCopy => 'Copier le lien';

  @override
  String get shareCopied => 'Lien copié';

  @override
  String get shareWarning =>
      'Contient le mot de passe ou la clé du serveur. Partagez avec prudence.';

  @override
  String shareFailed(String reason) {
    return 'Ce serveur ne peut pas être partagé sous forme de lien : $reason';
  }

  @override
  String get shareTooLong => 'Trop long pour un QR code : copiez le lien';

  @override
  String get obTitle1 => 'Privé et simple';

  @override
  String get obText1 =>
      'Un seul écran serein pour VPN, proxy et Tor. Choisissez un lieu, appuyez sur Connecter.';

  @override
  String get obTitle2 => 'Ajoutez vos serveurs';

  @override
  String get obText2 =>
      'Importez un lien, un QR code, un fichier de config ou un abonnement. Ou ajoutez un serveur manuellement.';

  @override
  String get obTitle3Android => 'Android demandera une fois';

  @override
  String get obText3Android =>
      'Android demandera d’autoriser une connexion VPN. Acceptez pour être protégé.';

  @override
  String get obTitle3Desktop => 'Prêt quand vous l’êtes';

  @override
  String get obText3Desktop =>
      'Démarre en mode proxy, sans droits spéciaux. Activez le mode VPN dans les Paramètres pour capturer tout le trafic.';

  @override
  String get obAddFirst => 'Ajouter mon premier serveur';

  @override
  String get bypassTitle => 'Listes de contournement';

  @override
  String get bypassAddTooltip => 'Ajouter une liste';

  @override
  String get bypassFromClipboard => 'Coller depuis le presse-papiers';

  @override
  String get bypassFromFile => 'Ouvrir un fichier .txt';

  @override
  String get bypassFromUrl => 'Télécharger depuis un lien';

  @override
  String get bypassType => 'Saisir à la main';

  @override
  String get bypassClipboardEmpty => 'Le presse-papiers est vide';

  @override
  String get bypassPickFile => 'Ouvrir une liste de contournement (.txt)';

  @override
  String bypassDownloadFailed(String error) {
    return 'Impossible de télécharger la liste : $error';
  }

  @override
  String get bypassIntro =>
      'Sites et adresses qui contournent le VPN. Un par ligne : example.com, full:www.example.com, keyword:bank, regexp:…, 203.0.113.7 ou 10.0.0.0/8. Les lignes commençant par # sont ignorées.';

  @override
  String get bypassNoLists => 'Aucune liste pour l’instant.';

  @override
  String get bypassTypeList => 'Saisir une liste';

  @override
  String entriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées',
      many: '$count entrées',
      one: '$count entrée',
    );
    return '$_temp0';
  }

  @override
  String get bypassOnlyTitle => 'Seuls les éléments listés utilisent le VPN';

  @override
  String get bypassOnlyOn => 'Tout le reste passe en direct.';

  @override
  String get bypassOnlyOff =>
      'Les éléments listés passent en direct ; le reste utilise le VPN.';

  @override
  String get bypassNothing => 'Aucune liste activée.';

  @override
  String bypassInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées utilisées',
      many: '$count entrées utilisées',
      one: '$count entrée utilisée',
    );
    return '$_temp0. S’applique à la prochaine connexion.';
  }

  @override
  String get bypassHttpLink => 'Saisissez un lien http(s)';

  @override
  String bypassServerAnswered(int code) {
    return 'le serveur a répondu $code';
  }

  @override
  String get bypassTooLarge => 'la liste dépasse 5 Mo';

  @override
  String get bypassDownloadTitle => 'Télécharger une liste';

  @override
  String get bypassNewList => 'Nouvelle liste';

  @override
  String get bypassEditList => 'Modifier la liste';

  @override
  String get bypassName => 'Nom';

  @override
  String get bypassEntriesLabel => 'Entrées, une par ligne';

  @override
  String get bypassNoUsable => 'Aucune entrée utilisable pour l’instant.';

  @override
  String bypassSummary(String entries, String names, String ranges) {
    return '$entries · $names, $ranges.';
  }

  @override
  String bypassNames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count noms',
      many: '$count noms',
      one: '$count nom',
    );
    return '$_temp0';
  }

  @override
  String bypassRanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count adresses ou plages',
      many: '$count adresses ou plages',
      one: '$count adresse ou plage',
    );
    return '$_temp0';
  }

  @override
  String bypassIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes seront ignorées :',
      many: '$count lignes seront ignorées :',
      one: '$count ligne sera ignorée :',
    );
    return '$_temp0';
  }

  @override
  String bypassMoreIssues(int count) {
    return '… et $count de plus';
  }

  @override
  String get bypassReconnect =>
      'Reconnectez-vous pour utiliser la nouvelle liste';

  @override
  String get bypassDefaultName => 'Ma liste';

  @override
  String get bypassPastedName => 'Liste collée';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsServers => 'Serveurs';

  @override
  String get manageServers => 'Gérer les serveurs';

  @override
  String get manageServersHint => 'Serveurs et abonnements';

  @override
  String get settingsConnection => 'Connexion';

  @override
  String get vpnMode => 'Mode VPN (tout le trafic)';

  @override
  String get vpnModeHint =>
      'Désactivé : proxy uniquement, sans autorisation VPN';

  @override
  String get systemProxy => 'Définir le proxy système';

  @override
  String get systemProxyHint => 'Définit le proxy système pendant la connexion';

  @override
  String get autoSwitch => 'Basculer automatiquement en cas d’échec';

  @override
  String get autoSwitchHint => 'Essayer le serveur suivant en cas d’échec';

  @override
  String get bypassLan => 'Contourner le réseau local';

  @override
  String get bypassLanHint =>
      'Accéder directement aux appareils locaux (192.168.x.x, 10.x.x.x)';

  @override
  String get bypassListsHint => 'Sites web et adresses qui contournent le VPN';

  @override
  String bypassListsInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées utilisées',
      many: '$count entrées utilisées',
      one: '$count entrée utilisée',
    );
    return '$_temp0';
  }

  @override
  String get alwaysOnTitle => 'VPN permanent et kill switch';

  @override
  String get alwaysOnHint =>
      'Reconnecte au démarrage et bloque les fuites. À régler dans les paramètres VPN d’Android.';

  @override
  String get openVpnSettingsFallback =>
      'Paramètres → Réseau → VPN → engrenage à côté de Wardkeep';

  @override
  String get splitTunneling => 'Tunnel fractionné';

  @override
  String splitSummaryOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Seules $count applis sélectionnées utilisent le VPN',
      many: 'Seules $count applis sélectionnées utilisent le VPN',
      one: 'Seule $count appli sélectionnée utilise le VPN',
    );
    return '$_temp0';
  }

  @override
  String splitSummaryBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count applis contournent le VPN',
      many: '$count applis contournent le VPN',
      one: '$count appli contourne le VPN',
    );
    return '$_temp0';
  }

  @override
  String get splitSummaryOff => 'Toutes les applis utilisent le VPN';

  @override
  String get remoteDns => 'DNS distant';

  @override
  String get remoteDnsHelp =>
      'DNS utilisé via le tunnel, p. ex. https://1.1.1.1/dns-query ou tls://1.1.1.1';

  @override
  String get settingsApp => 'Application';

  @override
  String get appearance => 'Apparence';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeSystem => 'Suivre le système';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Par défaut du système';

  @override
  String get stopOnClose => 'Arrêter le VPN à la fermeture de l’app';

  @override
  String aboutLine(String engine) {
    return 'Licence MIT · moteur : $engine';
  }

  @override
  String get splitTitle => 'Tunnel fractionné';

  @override
  String get splitAll => 'Toutes les applis';

  @override
  String get splitOnlySelected => 'Sélection uniquement';

  @override
  String get splitBypassSelected => 'Contourner la sélection';

  @override
  String get splitHelpOffMode => 'Toutes les applis utilisent le VPN.';

  @override
  String get splitHelpOnlyNone =>
      'Aucune appli choisie : toutes utilisent le VPN.';

  @override
  String splitHelpOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Seules $count applis utilisent le VPN.',
      many: 'Seules $count applis utilisent le VPN.',
      one: 'Seule $count appli utilise le VPN.',
    );
    return '$_temp0';
  }

  @override
  String splitHelpBypass(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count applis passent en direct.',
      many: '$count applis passent en direct.',
      one: '$count appli passe en direct.',
    );
    return '$_temp0';
  }

  @override
  String get searchApps => 'Rechercher des applis';

  @override
  String get showSystemApps => 'Afficher les applis système';

  @override
  String couldNotListApps(String error) {
    return 'Impossible de lister les applis : $error';
  }

  @override
  String get scanTitle => 'Scanner un QR code';

  @override
  String get scanTorch => 'Lampe torche';

  @override
  String scanCameraUnavailable(String code) {
    return 'Caméra indisponible : $code';
  }

  @override
  String get scanPoint => 'Pointez la caméra vers un QR code de config';

  @override
  String get credTitle => 'Connexion';

  @override
  String credNeeds(String name) {
    return '$name nécessite un nom d’utilisateur et un mot de passe.';
  }

  @override
  String get credUsername => 'Nom d’utilisateur';

  @override
  String get credPassword => 'Mot de passe';

  @override
  String get logsEmpty => 'Aucune entrée de journal.';

  @override
  String get profilesTitle => 'Gérer les serveurs';

  @override
  String get addSubscriptionTooltip => 'Ajouter un abonnement';

  @override
  String get testLatencyTooltip => 'Tester la latence';

  @override
  String get profilesEmptyHint =>
      'Aucun profil. Touchez Importer pour en ajouter un.';

  @override
  String get profilesDragHint =>
      'Maintenez et faites glisser pour réorganiser. La bascule suit cet ordre.';

  @override
  String get myProfiles => 'Mes profils';

  @override
  String subRefreshed(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profils',
      many: '$count profils',
      one: '$count profil',
    );
    return '$name : $_temp0';
  }

  @override
  String get refreshTooltip => 'Actualiser';

  @override
  String get subDeleteWithProfiles => 'Supprimer l’abonnement et ses profils';

  @override
  String subUsageOf(String used, String total) {
    return '$used sur $total';
  }

  @override
  String subUsed(String used) {
    return '$used utilisés';
  }

  @override
  String get subExpired => 'expiré';

  @override
  String get subExpiresToday => 'expire aujourd’hui';

  @override
  String subExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'expire dans $days jours',
      many: 'expire dans $days jours',
      one: 'expire dans $days jour',
    );
    return '$_temp0';
  }

  @override
  String subUpdated(String ago) {
    return 'mis à jour $ago';
  }

  @override
  String get agoJustNow => 'à l’instant';

  @override
  String agoMinutes(int count) {
    return 'il y a $count min';
  }

  @override
  String agoHours(int count) {
    return 'il y a $count h';
  }

  @override
  String agoDays(int count) {
    return 'il y a $count j';
  }

  @override
  String subRefreshFailed(String error) {
    return 'Échec de la dernière actualisation : $error';
  }

  @override
  String get importTitle => 'Importer une config';

  @override
  String get importDescription =>
      'Collez un lien, une config ou un abonnement — ou ouvrez un fichier ou scannez un QR code.';

  @override
  String get importScanQr => 'Scanner un QR';

  @override
  String get importOpenFile => 'Ouvrir un fichier';

  @override
  String get importPaste => 'Coller';

  @override
  String get importSubscription => 'Abonnement';

  @override
  String get importTor => 'Tor';

  @override
  String get importAddTor => 'Ajouter Tor';

  @override
  String get importTorDirect => 'Tor (direct)';

  @override
  String get importTorSnowflake => 'Tor + pont Snowflake';

  @override
  String get importTorObfs4 => 'Tor + ponts obfs4';

  @override
  String importedProfiles(int added, int dupes) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added profils importés',
      many: '$added profils importés',
      one: '$added profil importé',
    );
    String _temp1 = intl.Intl.pluralLogic(
      dupes,
      locale: localeName,
      other: ', $dupes déjà présents',
      many: ', $dupes déjà présents',
      one: ', $dupes déjà présent',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String importNothing(String reason) {
    return 'Rien d’importé : $reason';
  }

  @override
  String importPartial(int added, int failed) {
    return 'Importés : $added, échecs : $failed';
  }

  @override
  String get subAddTitle => 'Ajouter un abonnement';

  @override
  String get subEditTitle => 'Modifier l’abonnement';

  @override
  String get subUrlLabel => 'URL de l’abonnement';

  @override
  String get subUrlHint =>
      'https://provider.example/sub/… ou nordvpn://<token>';

  @override
  String get subNameLabel => 'Nom (facultatif)';

  @override
  String get subNameHelp =>
      'Par défaut : le titre du fournisseur ou le nom d’hôte';

  @override
  String get subAuthLabel => 'Authentification';

  @override
  String get authNone => 'Aucune';

  @override
  String get authBasic => 'Nom d’utilisateur et mot de passe (Basic)';

  @override
  String get authBearer => 'Jeton Bearer';

  @override
  String get authHeader => 'En-tête personnalisé';

  @override
  String get authQuery => 'Jeton dans l’URL';

  @override
  String get subUsername => 'Nom d’utilisateur';

  @override
  String get subPassword => 'Mot de passe';

  @override
  String get subHeaderName => 'Nom de l’en-tête';

  @override
  String get subHeaderValue => 'Valeur de l’en-tête';

  @override
  String get subParamName => 'Nom du paramètre';

  @override
  String get subToken => 'Jeton';

  @override
  String get subDownloadLabel => 'Téléchargement';

  @override
  String get subDownloadHelp =>
      'Fournisseur bloqué ? Le VPN peut quand même le récupérer';

  @override
  String get subViaDirect => 'Directement';

  @override
  String get subViaAuto => 'Direct, ou via le VPN si bloqué';

  @override
  String get subViaTunnel => 'Toujours via le VPN (connectez-vous d’abord)';

  @override
  String get subErrUrl =>
      'Saisissez une URL d’abonnement http(s) (ou nordvpn://<access token>)';

  @override
  String get subErrHeader => 'Saisissez le nom de l’en-tête';

  @override
  String get subErrToken => 'Saisissez le jeton';

  @override
  String get subAddAndDownload => 'Ajouter et télécharger';

  @override
  String get subSaveAndRefresh => 'Enregistrer et actualiser';

  @override
  String subUpdatedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profils',
      many: '$count profils',
      one: '$count profil',
    );
    return 'Abonnement mis à jour : $_temp0';
  }

  @override
  String get flName => 'Nom';

  @override
  String get flServer => 'Serveur';

  @override
  String get flPort => 'Port';

  @override
  String get flPassword => 'Mot de passe';

  @override
  String get flUsername => 'Nom d’utilisateur';

  @override
  String get flUuid => 'UUID';

  @override
  String get flSecurity => 'Sécurité';

  @override
  String get flFlow => 'Flow';

  @override
  String get flCipher => 'Algorithme de chiffrement';

  @override
  String get flEncryption => 'Chiffrement';

  @override
  String get flAlterId => 'Alter id';

  @override
  String get flTlsServerName => 'Nom du serveur TLS (SNI)';

  @override
  String get flTlsFingerprint => 'Empreinte TLS';

  @override
  String get flAlpn => 'ALPN';

  @override
  String get flSkipCertCheck => 'Ignorer la vérification du certificat';

  @override
  String get flPinnedCert => 'Certificat épinglé (PEM)';

  @override
  String get flRealityPublicKey => 'Clé publique Reality';

  @override
  String get flRealityShortId => 'Short ID Reality';

  @override
  String get flTransport => 'Transport';

  @override
  String get flHostHeader => 'En-tête Host';

  @override
  String get flPath => 'Chemin';

  @override
  String get flGrpcService => 'Nom du service gRPC';

  @override
  String get flPlugin => 'Plugin';

  @override
  String get flPluginOptions => 'Options du plugin';

  @override
  String get flObfuscation => 'Obfuscation';

  @override
  String get flObfsPassword => 'Mot de passe d’obfuscation';

  @override
  String get flUploadMbps => 'Débit montant (Mbps)';

  @override
  String get flDownloadMbps => 'Débit descendant (Mbps)';

  @override
  String get flCongestion => 'Contrôle de congestion';

  @override
  String get flUdpRelay => 'Mode de relais UDP';

  @override
  String get flUseQuic => 'Utiliser HTTP/3 (QUIC)';

  @override
  String get flTunnelAddress => 'Votre adresse de tunnel';

  @override
  String get flRoutedNetworks => 'Réseaux routés';

  @override
  String get flDnsServers => 'Serveurs DNS';

  @override
  String get flMtu => 'MTU';

  @override
  String get flKeepalive => 'Keepalive (secondes)';

  @override
  String get flPrivateKey => 'Clé privée';

  @override
  String get flServerPublicKey => 'Clé publique du serveur';

  @override
  String get flPresharedKey => 'Clé pré-partagée';

  @override
  String get flReservedBytes => 'Octets réservés';

  @override
  String get flAuthentication => 'Authentification';

  @override
  String get flAuthDigest => 'Condensat d’authentification';

  @override
  String get flCaCert => 'Certificat CA (PEM)';

  @override
  String get flClientCert => 'Certificat client (PEM)';

  @override
  String get flClientKey => 'Clé client (PEM)';

  @override
  String get flControlWrap => 'Protection du canal de contrôle';

  @override
  String get flControlWrapKey => 'Clé du canal de contrôle';

  @override
  String get flKeyDirection => 'Sens de la clé';

  @override
  String get flRemoteCertType => 'Type de certificat distant';

  @override
  String get flVerifyServerName => 'Vérifier le nom du serveur';

  @override
  String get flYourIdentity => 'Votre identité';

  @override
  String get flServerIdentity => 'Identité du serveur';

  @override
  String get flServerCertTrust => 'Certificat du serveur à approuver (PEM)';

  @override
  String get flUseSystemIke => 'Utiliser le client IKEv2 du téléphone';

  @override
  String get flUseTcp => 'Utiliser TCP';

  @override
  String get flHostKeys => 'Clés d’hôte';

  @override
  String get flPrivateKeyPem => 'Clé privée (PEM)';

  @override
  String get flKeyPassphrase => 'Phrase secrète de la clé';

  @override
  String get flBridges => 'Ponts';

  @override
  String get flBridgeLines => 'Lignes de pont';

  @override
  String get flJc => 'Jc (nombre de paquets parasites)';

  @override
  String get flSignaturePacket => 'I1 (paquet de signature)';

  @override
  String get hpAuthorizedKeys =>
      'format authorized_keys ; vide accepte n’importe quelle clé';

  @override
  String get hpIkeTcp =>
      'Transporte IKE et ESP sur TCP pour les réseaux qui bloquent l’UDP';

  @override
  String get hpDefaultsToServer => 'Par défaut : l’adresse du serveur';

  @override
  String get hpTorBridges =>
      'Vide : connexion directe à Tor, ou utilisation des lignes de pont ci-dessous';

  @override
  String get hpExampleAddress => 'Par exemple 10.8.0.2/32';

  @override
  String get hpExamplePlugin => 'Par exemple shadow-tls ou v2ray-plugin';

  @override
  String get hpHostOrIp => 'Nom d’hôte ou adresse IP';

  @override
  String get hpNeededReality => 'Requis quand Sécurité vaut reality';

  @override
  String get hpOnlySelfSigned =>
      'Uniquement pour les serveurs à certificat auto-signé que vous ne pouvez pas épingler';

  @override
  String get hpSafeSstp =>
      'Sans risque pour SSTP : l’échange de mot de passe authentifie le serveur';

  @override
  String get hpHysteriaObfs =>
      'salamander pour Hysteria 2 ; le mot de passe d’obfuscation pour Hysteria 1';

  @override
  String get hpTrustCert =>
      'Approuver ce certificat plutôt que les autorités du système';

  @override
  String get hpWhichBrowser => 'Quelle négociation TLS de navigateur imiter';

  @override
  String get hpWarpReserved =>
      'Trois nombres, comme les listent les configurations WARP';

  @override
  String get hpOneBridgePerLine =>
      'Un pont par ligne, comme dans un torrc sans « Bridge »';

  @override
  String get exitTitle => 'Afficher l’adresse et le pays de sortie';

  @override
  String get exitHint =>
      'Interroge api.country.is pour votre IP et votre pays, y compris hors connexion.';

  @override
  String exitIpLabel(String ip) {
    return 'IP $ip';
  }

  @override
  String connectedTo(String place) {
    return 'Connecté à $place';
  }

  @override
  String get noticesTitle => 'Licences open source';

  @override
  String get noticesIntro =>
      'Wardkeep est sous licence MIT. Il inclut les logiciels ci-dessous, chacun sous sa propre licence.';

  @override
  String noticesMore(int count) {
    return '+$count de plus';
  }

  @override
  String noticesPackages(int count) {
    return '$count paquets';
  }

  @override
  String get noticesLoadFailed => 'La liste des licences n’a pas pu être lue.';

  @override
  String formRequired(String label) {
    return '$label est obligatoire';
  }

  @override
  String formNotNumber(String label) {
    return '$label doit être un nombre entier';
  }

  @override
  String formNotBool(String label) {
    return '$label doit être activé ou désactivé';
  }

  @override
  String formBadChoice(String label, String value, String choices) {
    return '$label : $value ne fait pas partie de $choices';
  }

  @override
  String get formRealityOnlyVless => 'Reality n’est disponible que pour VLESS';

  @override
  String formUnknownSecurity(String value) {
    return 'Sécurité inconnue : $value';
  }

  @override
  String get formReservedBytes =>
      'Les octets réservés doivent être des nombres de 0 à 255';

  @override
  String get formRealityKeyRequired =>
      'La clé publique Reality est obligatoire quand Sécurité vaut Reality';

  @override
  String get importUnsupported =>
      'Ceci n’est pas un lien de serveur, un abonnement ou une config que Wardkeep sait lire';

  @override
  String importUnsupportedScheme(String scheme) {
    return 'Les liens commençant par $scheme:// ne sont pas pris en charge';
  }

  @override
  String get importXrayServer =>
      'Il s’agit d’une config de serveur Xray. Importez-la sur le serveur (omnitun-server import xray), pas comme profil client';

  @override
  String get subAuthFailed =>
      'L’abonnement a rejeté la connexion. Vérifiez le nom d’utilisateur, le mot de passe ou le jeton';

  @override
  String subHttp(String status) {
    return 'Le serveur d’abonnement a répondu HTTP $status';
  }

  @override
  String get subTooLarge => 'L’abonnement dépasse 10 Mo';

  @override
  String get subBadUrl => 'Ce n’est pas une adresse d’abonnement valide';

  @override
  String get bypassIssueEmptyExpression => 'expression vide';

  @override
  String get bypassIssueBadExpression => 'expression non valide';

  @override
  String get bypassIssueBadName => 'nom non valide';

  @override
  String get bypassIssueGeo =>
      'les listes geo ne sont pas prises en charge ; listez les domaines ou les plages';

  @override
  String get bypassIssueBadEntry =>
      'ni un domaine, ni une adresse, ni une plage';

  @override
  String bypassIssueTooMany(int limit) {
    return 'plus de $limit entrées : le reste est ignoré';
  }

  @override
  String get torStarting => 'Démarrage de Tor';

  @override
  String torBootstrap(int percent) {
    return 'Connexion à Tor $percent %';
  }

  @override
  String get torCircuit => 'Construction d’un circuit Tor';

  @override
  String torRetry(int attempt, int attempts) {
    return 'Nouvelle tentative Tor ($attempt/$attempts)';
  }

  @override
  String get importNoServer => 'Aucun serveur valide trouvé dans ce texte';

  @override
  String importJsonSyntax(String found, int line, int column) {
    return 'Ce n\'est pas un JSON valide : caractère inattendu $found à la ligne $line, colonne $column.';
  }

  @override
  String importJsonEnd(int line, int column) {
    return 'Ce n\'est pas un JSON valide : le texte se termine trop tôt, à la ligne $line, colonne $column. Il manque peut-être un crochet, une accolade ou un guillemet fermant.';
  }

  @override
  String get importJsonNoServer =>
      'Ce JSON est valide, mais il ne contient aucun serveur proxy. Utilisez une configuration client avec une sortie VLESS, VMess, Trojan, Shadowsocks ou similaire.';

  @override
  String importJsonNoServerFound(String found) {
    return 'Ce JSON est valide, mais il ne contient aucun serveur proxy (il contient $found). Utilisez une configuration client avec une sortie VLESS, VMess, Trojan, Shadowsocks ou similaire.';
  }

  @override
  String importTooLarge(int limit) {
    return 'C\'est trop volumineux pour être importé (la limite est de $limit Mo).';
  }

  @override
  String get importFileEmpty => 'Le fichier est vide.';

  @override
  String get importFileNotText =>
      'Le fichier n\'est pas du texte que Wardkeep peut lire (il semble binaire ou dans un encodage inconnu). Utilisez un fichier texte UTF-8 ou UTF-16.';

  @override
  String get importFileNoPermission =>
      'Wardkeep n\'a pas le droit de lire ce fichier.';

  @override
  String get importFileMissing =>
      'Fichier introuvable. Il a peut-être été déplacé ou supprimé.';

  @override
  String get importDetails => 'Détails';

  @override
  String get importJsonNote =>
      'Une configuration JSON (Xray, sing-box, SIP008) ou une liste de configurations fonctionne aussi, en texte ou en fichier.';

  @override
  String get ipdbTitle => 'Base de données de pays hors ligne';

  @override
  String get ipdbIntro =>
      'Téléchargez une base une fois, et Wardkeep trouve seul le pays d’un serveur ou d’une adresse, sans interroger de site web.';

  @override
  String ipdbSizeNote(String size) {
    return 'Environ $size · données libres (domaine public)';
  }

  @override
  String get ipdbDownload => 'Télécharger';

  @override
  String get ipdbContinue => 'Continuer';

  @override
  String get ipdbPause => 'Pause';

  @override
  String get ipdbUpdate => 'Mettre à jour';

  @override
  String get ipdbDelete => 'Supprimer';

  @override
  String get ipdbDeleteTitle => 'Supprimer la base de données ?';

  @override
  String get ipdbUse => 'Utiliser la base de données';

  @override
  String get ipdbStepV4 => 'IPv4';

  @override
  String get ipdbStepV6 => 'IPv6';

  @override
  String get ipdbStepPrepare => 'Préparation';

  @override
  String get ipdbPreparing => 'Préparation…';

  @override
  String get ipdbReady => 'Prêt';

  @override
  String ipdbStoppedAt(int percent) {
    return 'Arrêté à $percent %. Continuer reprend exactement là.';
  }

  @override
  String ipdbFailed(String reason) {
    return 'Échec du téléchargement : $reason';
  }

  @override
  String ipdbReadyLine(String ranges, String size) {
    return '$ranges plages · $size';
  }

  @override
  String ipdbVersion(String version, String date) {
    return 'Version $version · $date';
  }

  @override
  String ipdbLeft(String time) {
    return 'Il reste $time';
  }

  @override
  String get ipdbSource =>
      'Données : registres Internet régionaux et annonces ASN (CC0), du projet ip-location-db.';

  @override
  String get ipdbSubNone => 'Trouver les pays sans interroger de site web';

  @override
  String ipdbSubReady(String size) {
    return 'Activée · $size';
  }

  @override
  String ipdbSubOff(String size) {
    return 'Désactivée · $size';
  }

  @override
  String ipdbSubDownloading(int percent) {
    return 'Téléchargement $percent %';
  }

  @override
  String ipdbSubStopped(int percent) {
    return 'Arrêté à $percent %';
  }

  @override
  String get ipdbErrNetwork => 'pas de connexion aux serveurs de données';

  @override
  String get ipdbErrMirrors =>
      'les serveurs de données n’ont pas envoyé le bon fichier';

  @override
  String get bypassCountriesTitle => 'Pays';

  @override
  String get bypassCountriesNone => 'Aucun pays choisi';

  @override
  String bypassCountriesMore(String names, int count) {
    return '$names +$count';
  }

  @override
  String get bypassCountriesIntro =>
      'Le trafic vers les pays choisis va directement sur Internet, en contournant le VPN. Leurs plages d’adresses viennent de la base de données de pays hors ligne.';

  @override
  String get bypassCountriesGetDb => 'Obtenir la base de données de pays';

  @override
  String get bypassCountriesSearch => 'Rechercher des pays';

  @override
  String get windowMinimize => 'Réduire';

  @override
  String get windowMaximize => 'Agrandir';

  @override
  String get windowRestore => 'Restaurer';

  @override
  String get windowClose => 'Fermer';

  @override
  String get windowFullScreen => 'Plein écran';

  @override
  String get windowExitFullScreen => 'Quitter le plein écran';

  @override
  String get globeRecenter => 'Centrer la Terre';

  @override
  String get bypassCountriesZoneIntro =>
      'Chaque pays coché télécharge ses plages d’adresses (quelques kilo-octets). La base de données hors ligne complète est plus précise et ne demande aucun téléchargement.';

  @override
  String get bypassCountriesDownloading => 'Téléchargement…';

  @override
  String get bypassCountriesFailed =>
      'Téléchargement impossible. Touchez pour réessayer.';

  @override
  String get bypassCountriesYourServer =>
      'Votre serveur sélectionné est ici : son trafic contournerait aussi le VPN.';

  @override
  String get ipv6Title => 'IPv6';

  @override
  String get ipv6Hint =>
      'Désactivé : seul IPv4 est utilisé ; les connexions IPv6 sont refusées, pas envoyées hors du VPN.';

  @override
  String get mtuTitle => 'MTU';

  @override
  String get mtuAuto => 'Par défaut';

  @override
  String get mtuHelp =>
      'Taille des paquets du tunnel (mode VPN seulement). Essayez de 1280 à 1420 si certains sites se bloquent sur le réseau mobile. Vide : valeur par défaut.';

  @override
  String mtuInvalid(int min, int max) {
    return 'Saisissez un nombre de $min à $max.';
  }

  @override
  String get trayOpen => 'Ouvrir Wardkeep';

  @override
  String get trayQuit => 'Quitter';

  @override
  String get traySwitchServer => 'Changer de serveur';

  @override
  String get keepInTray => 'Rester dans la zone de notification';

  @override
  String get keepInTrayHint =>
      'Fermer la fenêtre la masque seulement. Utilisez « Quitter » dans le menu de l’icône pour arrêter l’app et le VPN.';

  @override
  String usageUsed(String size) {
    return '$size utilisés';
  }

  @override
  String get menuResetUsage => 'Réinitialiser la conso de données';

  @override
  String get dnsPickerHelp =>
      'Les noms de sites sont résolus via le VPN par le résolveur que vous choisissez. DNSCrypt prouve en plus que la réponse vient bien de ce résolveur.';

  @override
  String get dnsDefault => 'Par défaut';

  @override
  String get dnsSectionDnscrypt =>
      'DNSCrypt · DNSSEC, sans journaux, sans filtrage';

  @override
  String get dnsCustom => 'Personnalisé';

  @override
  String get dnsCustomLabel => 'Adresse ou DNS stamp';

  @override
  String get dnsAnonymized => 'DNSCrypt anonymisé';

  @override
  String get dnsAnonymizedHint =>
      'Les requêtes passent par un relais : le résolveur ne voit jamais d\'où elles viennent';

  @override
  String get dnsAnonymizedNeedsDnscrypt =>
      'Choisissez un résolveur DNSCrypt pour l\'utiliser';

  @override
  String get dnsRelay => 'Relais';

  @override
  String get dnsRelayChoose => 'Choisissez un relais';

  @override
  String get dnsRelayAutomatic => 'Automatique (autre opérateur)';

  @override
  String get dnsErrAddress =>
      'Saisissez une adresse commençant par https://, tls://, tcp:// ou udp://, ou un stamp sdns://';

  @override
  String get dnsErrDamaged =>
      'Ce stamp est abîmé ou tronqué. Copiez-le à nouveau.';

  @override
  String get dnsErrUnsupported => 'Ce type de stamp n\'est pas pris en charge';

  @override
  String get dnsErrRelayStamp =>
      'Ceci est le stamp d\'un relais, pas d\'un résolveur';

  @override
  String dnsLine(String resolver) {
    return 'DNS : $resolver';
  }

  @override
  String get dnsLimits =>
      'Cela protège les noms que vous résolvez. Cela ne cache pas les sites auxquels vous vous connectez ensuite.';

  @override
  String get dnsAnonymizedShort => 'anonymisé';

  @override
  String get flAuthKey => 'Clé d\'authentification';

  @override
  String get flControlServer => 'Serveur de contrôle';

  @override
  String get flDeviceName => 'Nom de l\'appareil';

  @override
  String get flExitDevice => 'Appareil de sortie';

  @override
  String get flUseSubnets => 'Utiliser les sous-réseaux des autres appareils';

  @override
  String get flTempDevice => 'Appareil temporaire';

  @override
  String get hpAuthKey =>
      'Une clé préautorisée de la page d\'administration de Tailscale, ou créée avec headscale preauthkeys create';

  @override
  String get hpControlServer =>
      'Vide : Tailscale ; pour Headscale, son adresse, par exemple https://hs.example.com';

  @override
  String get hpDeviceName =>
      'Le nom de cet appareil dans le réseau ; vide : celui de l\'appareil';

  @override
  String get hpExitDevice =>
      'Nom ou adresse de l\'appareil dont la connexion internet est utilisée ; vide : seulement vos appareils';

  @override
  String get hpTempDevice => 'Retiré du réseau quand il se déconnecte';

  @override
  String get devicesTitle => 'Mes appareils';

  @override
  String get devicesNotConnected =>
      'Connectez un profil Tailscale ou Headscale pour voir vos appareils.';

  @override
  String get devicesJoining => 'Connexion au réseau…';

  @override
  String get devicesLoginNeeded =>
      'Le réseau n\'a pas accepté la clé de cet appareil. Créez une nouvelle clé et modifiez le profil.';

  @override
  String get devicesEmpty =>
      'Aucun autre appareil dans ce réseau pour l\'instant.';

  @override
  String get devicesThisDevice => 'Cet appareil';

  @override
  String get deviceOnline => 'En ligne';

  @override
  String get deviceOffline => 'Hors ligne';

  @override
  String deviceLastSeen(String when) {
    return 'Vu pour la dernière fois $when';
  }

  @override
  String get deviceUseAsExit => 'Utiliser comme sortie';

  @override
  String get deviceStopExit => 'Ne plus utiliser comme sortie';

  @override
  String get deviceIsExit => 'Sortie utilisée';

  @override
  String get devicesExitHint =>
      'Utilisez l\'un de vos appareils comme sortie : tout votre trafic passe par sa connexion.';

  @override
  String get deviceCopyName => 'Copier le nom';

  @override
  String get deviceCopyAddress => 'Copier l\'adresse';

  @override
  String get deviceCopied => 'Copié';

  @override
  String get errMeshExit =>
      'Cet appareil ne peut pas servir de sortie pour le moment. Il doit être en ligne et proposer sa connexion.';

  @override
  String get wnTlsInsecure =>
      'Le certificat du serveur n\'est pas vérifié. N\'importe qui sur le chemin peut lire ou modifier votre trafic.';

  @override
  String get wnNoTls =>
      'Le trafic n\'est pas enveloppé dans du TLS. Il est facile à reconnaître et peut être lu en chemin.';

  @override
  String get wnVmessLegacy =>
      'VMess est un ancien protocole, facile à reconnaître. VLESS avec Reality est un meilleur choix.';

  @override
  String get wnSsPlain =>
      'Sans module comme shadow-tls, le trafic ressemble à des octets aléatoires, et certains réseaux bloquent ce motif.';

  @override
  String get wnHysteria1 =>
      'Hysteria 1 est obsolète. Utilisez Hysteria 2 si le serveur le gère.';

  @override
  String get wnDpiVisible =>
      'Ce protocole est facile à identifier et souvent bloqué sur les réseaux stricts.';

  @override
  String get wnSshVisible => 'Les tunnels SSH sont faciles à identifier.';

  @override
  String get wnDnsttSlow =>
      'Lent (généralement bien en dessous de 1 Mbit/s) et TCP uniquement. Il envoie beaucoup de requêtes DNS que le réseau peut voir. À utiliser quand rien d\'autre ne marche.';

  @override
  String get wnDnsttOpen =>
      'Ni nom d\'utilisateur ni mot de passe : toute personne ayant ce lien peut utiliser le serveur.';

  @override
  String get wnMuxLossy =>
      'Le multiplexage met plusieurs connexions dans une seule. Une mauvaise liaison peut toutes les ralentir.';

  @override
  String get wnFragmentSide =>
      'Fragmenter la poignée de main aide contre certains filtres, peut échouer sur d\'autres et ajoute du délai.';

  @override
  String get wnEchServer =>
      'Nécessite un serveur compatible ECH. Sinon la connexion échoue.';

  @override
  String get wnWgChain =>
      'WireGuard dans un proxy : si le proxy est lent, le tunnel peut se bloquer. Le proxy doit transporter l\'UDP.';

  @override
  String get wnSubUnsigned =>
      'Cette liste n\'est pas signée : une modification ne peut pas être détectée.';

  @override
  String get choiceOff => 'Désactivé';

  @override
  String get flMultiplexing => 'Multiplexage';

  @override
  String get flMuxPadding => 'Remplissage du multiplexage';

  @override
  String get flMuxMaxConnections => 'Connexions maximum';

  @override
  String get flMuxMinStreams => 'Flux minimum par connexion';

  @override
  String get flMuxMaxStreams => 'Flux maximum par connexion';

  @override
  String get hpMultiplexing =>
      'Plusieurs connexions en une ; le serveur doit l\'autoriser. Pas avec le flow VLESS';

  @override
  String get hpMuxMaxStreams => 'À la place des deux précédents';

  @override
  String get flTlsFragment => 'Fragmenter la poignée de main TLS';

  @override
  String get flTlsRecordFragment => 'Fragmenter les enregistrements TLS';

  @override
  String get flEch => 'Client Hello chiffré (ECH)';

  @override
  String get flEchConfig => 'Configuration ECH (PEM)';

  @override
  String get flEchQueryName => 'Nom de recherche ECH';

  @override
  String get hpTlsFragment =>
      'Coupe le premier paquet pour qu\'un filtre ne puisse pas lire le nom du serveur';

  @override
  String get hpTlsRecordFragment =>
      'Coupe les enregistrements au lieu des paquets';

  @override
  String get hpEch =>
      'Cache le nom du serveur ; nécessite un serveur compatible';

  @override
  String get hpEchConfig => 'Vide : recherché dans le DNS';

  @override
  String get hpEchQueryName => 'Par défaut, le nom du serveur';

  @override
  String get flWgVia => 'Via un proxy (lien de partage)';

  @override
  String get hpWgVia =>
      'Fait passer WireGuard dans ce proxy, pour les réseaux qui bloquent l\'UDP. Le proxy doit laisser passer l\'UDP';

  @override
  String get subSigned => 'Signée';

  @override
  String get subKeyLabel => 'Clé de signature (facultatif)';

  @override
  String get subKeyHelp =>
      'La clé publique du fournisseur. Une réponse sans signature valide faite avec elle est refusée';

  @override
  String get subBackupLabel => 'Adresses de secours (facultatif)';

  @override
  String get subBackupHelp =>
      'Une par ligne. Essayées dans l\'ordre quand la première est injoignable';

  @override
  String get subErrKey =>
      'La clé de signature n\'est pas une clé publique valide';

  @override
  String get subUnsigned =>
      'L\'abonnement n\'est pas signé alors qu\'une clé de signature est définie ; il a été refusé';

  @override
  String get subBadSignature =>
      'La signature de l\'abonnement est fausse : il a pu être modifié en chemin, ou la clé est ancienne';

  @override
  String get subStale =>
      'Cette réponse est plus ancienne que la dernière acceptée, elle a donc été refusée. Si le fournisseur a restauré une ancienne sauvegarde, modifiez l\'abonnement et enregistrez-le de nouveau.';

  @override
  String get flTunnelDomain => 'Domaine du tunnel';

  @override
  String get flServerKey => 'Clé du serveur';

  @override
  String get flResolvers => 'Résolveurs';

  @override
  String get hpTunnelDomain =>
      'La zone déléguée au serveur du tunnel, comme t.example.com';

  @override
  String get hpServerKey => '64 chiffres hexadécimaux ; le serveur l\'affiche';

  @override
  String get hpResolvers =>
      'Essayés dans l\'ordre : udp://IP:port, tls://host:port ou https://host/path';

  @override
  String get hpTunnelLogin =>
      'L\'identifiant du SOCKS5 en amont du serveur ; vide s\'il n\'y en a pas';

  @override
  String get scanFind => 'Trouver les résolveurs qui marchent';

  @override
  String get scanBusy => 'Essai des résolveurs…';

  @override
  String scanFound(int count) {
    return 'Résolveurs qui marchent : $count';
  }

  @override
  String get scanNone =>
      'Aucun résolveur n\'a fonctionné. Vérifiez le domaine et la clé, et que le serveur tourne.';

  @override
  String get scanConnected =>
      'Déconnectez-vous d\'abord : la recherche doit utiliser le réseau directement, pas le VPN.';

  @override
  String get scanNeedsFields =>
      'Renseignez d\'abord le domaine du tunnel et la clé du serveur.';

  @override
  String get settingsLogging => 'Journaux et erreurs';

  @override
  String get debugLogging => 'Journal de débogage';

  @override
  String get debugLoggingOff => 'Désactivé';

  @override
  String debugLoggingUntil(String level, String time) {
    return '$level jusqu\'à $time';
  }

  @override
  String debugLoggingCore(String level, String mode) {
    return 'Le cœur journalise : $level (version $mode)';
  }

  @override
  String get debugLoggingWarning =>
      'Le journal de débogage ralentit les connexions, consomme plus de batterie et garde plus de détails. Il se désactive tout seul après 24 heures.';

  @override
  String get logLevelInfo => 'Info';

  @override
  String get logLevelDebug => 'Débogage';

  @override
  String get logLevelTrace => 'Trace (tout)';

  @override
  String get notifyPopup => 'M\'avertir des erreurs';

  @override
  String get notifyPopupHint =>
      'Un avis rouge dans l\'app quand une panne n\'a pas pu être réparée par l\'app';

  @override
  String get notifyOs => 'Notifications système pour les erreurs';

  @override
  String get notifyOsHint =>
      'Une notification du système, même quand l\'app est en arrière-plan';

  @override
  String get logsView => 'Voir les journaux';

  @override
  String get logsExport => 'Enregistrer en JSON Lines';

  @override
  String get logsSaved => 'Journal enregistré';

  @override
  String get logsLevel => 'Niveau';

  @override
  String get logsLevelAll => 'Tous les niveaux';

  @override
  String logsConnection(String conn) {
    return 'Connexion $conn';
  }

  @override
  String get logsNoMatch => 'Aucune entrée ne correspond au filtre.';

  @override
  String get errTorExited =>
      'Tor s\'est arrêté de façon inattendue. Reconnectez-vous ; si cela se répète, consultez les journaux.';

  @override
  String get errDnsttExited =>
      'Le tunnel DNS s\'est arrêté de façon inattendue. Reconnectez-vous ; si cela se répète, consultez les journaux.';

  @override
  String get errEngineFatal =>
      'Le moteur de connexion s\'est arrêté sur une erreur. Reconnectez-vous ; si cela se répète, consultez les journaux.';

  @override
  String get errPanic =>
      'Une erreur interne de Wardkeep a arrêté la connexion. Les journaux donnent les détails.';

  @override
  String get errTorStreamFailed =>
      'Tor n\'a pas pu ouvrir de connexion vers ce site via le réseau Tor.';
}
