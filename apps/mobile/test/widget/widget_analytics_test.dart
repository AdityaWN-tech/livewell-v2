import 'package:flutter_test/flutter_test.dart';
import 'package:livewell/features/widget/data/widget_inbox.dart';
import 'package:livewell/features/widget/domain/widget_interaction.dart';
import 'package:livewell/features/widget/domain/widget_snapshot.dart';

import '../home/home_screen_test.dart' show bootPreview, today;
import 'widget_links_test.dart' show backToTheApp;

/// T-AVT-08g-e part 2 (T-TCH-02 TCH-e): `widget_interaction {action, size,
/// slot}`, fixed names only.
void main() {
  group('reading a tap from its link', () {
    test('action from the link; size and slot added by the native widget', () {
      expect(
        widgetInteractionOf(
          Uri.parse(
            'livewell://step?done=1&size=small&slot=step_window&homeWidget=1',
          ),
        ),
        WidgetInteraction(action: 'done', size: 'small', slot: 'step_window'),
      );
      expect(
        widgetInteractionOf(
          Uri.parse('livewell://home?size=lock_rectangular&slot=step'),
        ),
        WidgetInteraction(
          action: 'open_home',
          size: 'lock_rectangular',
          slot: 'step',
        ),
      );
      expect(
        widgetInteractionOf(Uri.parse('livewell://checkin')),
        WidgetInteraction(action: 'check_in'),
      );
      expect(widgetInteractionOf(Uri.parse('livewell://portal')), isNull);
      expect(widgetInteractionOf(null), isNull);
    });

    test('every widget button has its own action name', () {
      for (final a in WidgetActionId.values) {
        final link = parseWidgetLink(Uri.parse(a.link))!;
        expect(widgetActionIdOf(link), a.id);
      }
    });

    test('anything not on the allow-list is "unknown": no text can reach '
        'analytics', () {
      final i = widgetInteractionOf(
        Uri.parse('livewell://step?size=Priya%27s%20phone&slot=feeling%20low'),
      )!;
      expect(i.action, 'open_step');
      expect(i.size, 'unknown');
      expect(i.slot, 'unknown');
      expect(
        WidgetInteraction(action: 'walk 10 min').action,
        WidgetInteraction.unknown,
      );
      expect(
        WidgetInteraction.doneOnWidget(size: 'medium', slot: 'step_window'),
        WidgetInteraction(action: 'done', size: 'medium', slot: 'step_window'),
      );
    });
  });

  group('logged by the app', () {
    testWidgets('a widget button that opened the app', (tester) async {
      final h = await bootPreview(tester);
      h.widgetInbox.interaction = WidgetInteraction(
        action: 'check_in',
        size: 'medium',
        slot: 'morning_checkin',
      );
      h.widgetInbox.tap(WidgetLink.checkIn);
      await tester.pumpAndSettle();
      expect(h.analytics.events, [
        {
          'name': 'widget_interaction',
          'action': 'check_in',
          'size': 'medium',
          'slot': 'morning_checkin',
        },
      ]);
    });

    testWidgets('Done tapped on the widget itself, once the app runs', (
      tester,
    ) async {
      final h = await bootPreview(tester);
      h.widgetInbox.done = today;
      h.widgetInbox.interaction = WidgetInteraction.doneOnWidget(
        size: 'small',
        slot: 'step_window',
      );
      backToTheApp(tester);
      await tester.pumpAndSettle();
      expect(
        h.analytics.events.where((e) => e['name'] == 'widget_interaction'),
        [
          {
            'name': 'widget_interaction',
            'action': 'done',
            'size': 'small',
            'slot': 'step_window',
          },
        ],
      );
    });
  });
}
