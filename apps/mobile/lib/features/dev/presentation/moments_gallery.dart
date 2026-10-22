import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../moments/domain/coach_message.dart';
import '../../moments/presentation/moment_screen.dart';

/// Dev-flavour list that opens each Avatar Moment with today's data
/// (T-DLY-03b), until notifications (T-DLY-03c) and Home (T-DLY-03d) open
/// them. Not reachable in staging or prod.
class MomentsGallery extends StatelessWidget {
  const MomentsGallery({super.key});

  static const path = '/dev/moments';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Avatar Moments')),
    body: ListView(
      padding: const EdgeInsets.all(LwSpacing.screenGutter),
      children: [
        for (final m in Moment.values)
          Card(
            child: ListTile(
              key: Key('dev-moment-${m.file}'),
              leading: const Icon(Icons.record_voice_over_outlined),
              title: Text(m.file),
              trailing: const Icon(Icons.play_arrow_rounded),
              onTap: () async {
                final action = await context.push<MomentAction>(
                  MomentScreen.pathFor(m),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Chose: ${action?.name ?? 'closed'}')),
                );
              },
            ),
          ),
      ],
    ),
  );
}
