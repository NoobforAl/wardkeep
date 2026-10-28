import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/engine.dart';
import '../../l10n/l10n.dart';
import '../../state/subscriptions.dart' show formatBytes;
import '../../state/usage.dart';

/// The two small lines under a server's name: its address (or "sign in"), and how much data the app has
/// sent through it ("1.2 GB used"), once it has sent any.
class ProfileSubtitle extends ConsumerWidget {
  const ProfileSubtitle(this.profile, {super.key});

  final ProfileInfo profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final used = ref.watch(usageOfProvider(profile.id));
    final address = profile.needsCredentials && !profile.hasCredentials
        ? context.l10n.needsSignIn(profileAddress(context, profile))
        : profileAddress(context, profile);
    if (used <= 0) return Text(address, overflow: TextOverflow.ellipsis);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(address, overflow: TextOverflow.ellipsis),
        Text(
          context.l10n.usageUsed(formatBytes(used)),
          key: const Key('profile-usage'),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
