// The Live Well home-screen and lock-screen widgets (T-AVT-08g-b).
// Everything shown comes from the snapshot the app writes (lw_snapshot in
// the App Group, docs/design/widget-snapshot.md): the widget never works out
// the day itself and never sees check-in answers or health values.

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - The snapshot

struct WidgetActionData: Decodable {
  let id: String
  let label: String
  let link: String
}

struct WidgetEntryData: Decodable {
  let at: String
  let slot: String
  let expression: String
  let headline: String
  let subline: String?
  let lockHeadline: String
  let primaryAction: WidgetActionData
  let secondaryAction: WidgetActionData?
}

struct WidgetSnapshotData: Decodable {
  let version: Int
  let firstName: String?
  let streakDays: Int?
  let routine: [String: String]
  let routineLabels: [String: String]
  let entries: [WidgetEntryData]
  let afterDone: WidgetEntryData?
  let hideDetails: Bool
}

enum Shared {
  /// This flavour's App Group (Info.plist LWAppGroupId, from APP_GROUP_ID).
  static var group: String {
    Bundle.main.object(forInfoDictionaryKey: "LWAppGroupId") as? String ?? ""
  }

  static var defaults: UserDefaults? { UserDefaults(suiteName: group) }

  /// Done tapped on the widget: the app applies it once (HomeWidgetInbox).
  static let doneKey = "lw_done_date"

  static func snapshot() -> WidgetSnapshotData? {
    guard let text = defaults?.string(forKey: "lw_snapshot"),
      let data = text.data(using: .utf8)
    else { return nil }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try? decoder.decode(WidgetSnapshotData.self, from: data)
  }

  static func face(_ expression: String) -> UIImage? {
    guard let text = defaults?.string(forKey: "lw_face_\(expression)"),
      let data = Data(base64Encoded: text)
    else { return nil }
    return UIImage(data: data)
  }

  static func dayKey(_ date: Date) -> String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
  }

  /// The app writes local times like 2026-10-14T13:00:00.000.
  static func date(_ text: String) -> Date? {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return f.date(from: String(text.prefix(19)))
  }

  /// Opens the app; home_widget passes links that carry `homeWidget`.
  static func url(_ link: String) -> URL? {
    URL(string: link + (link.contains("?") ? "&" : "?") + "homeWidget=1")
  }
}

// MARK: - Done from the widget (iOS 17+)

@available(iOS 17.0, *)
struct MarkStepDoneIntent: AppIntent {
  static var title: LocalizedStringResource = "Mark today's step done"
  static var isDiscoverable: Bool = false

  func perform() async throws -> some IntentResult {
    // Idempotent: one date, applied once by the app.
    Shared.defaults?.set(Shared.dayKey(Date()), forKey: Shared.doneKey)
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}

// MARK: - Timeline

struct CoachEntry: TimelineEntry {
  let date: Date
  let entry: WidgetEntryData?
  let snapshot: WidgetSnapshotData?
  let doneHere: Bool
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> CoachEntry {
    CoachEntry(date: Date(), entry: nil, snapshot: nil, doneHere: false)
  }

  func getSnapshot(in context: Context, completion: @escaping (CoachEntry) -> Void) {
    completion(entries().first ?? placeholder(in: context))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CoachEntry>) -> Void) {
    let list = entries()
    // At least every 6 hours (FR-TCH-04), and after the last entry.
    let soon = Date().addingTimeInterval(6 * 3600)
    let last = list.last?.date ?? soon
    completion(
      Timeline(
        entries: list.isEmpty ? [placeholder(in: context)] : list,
        policy: .after(min(soon, max(last, Date().addingTimeInterval(60))))))
  }

  /// The app's timeline; after Done on the widget, today's to-do entries
  /// show the celebration until the app catches up.
  func entries() -> [CoachEntry] {
    guard let snapshot = Shared.snapshot() else { return [] }
    let now = Date()
    let today = Shared.dayKey(now)
    let doneHere = Shared.defaults?.string(forKey: Shared.doneKey) == today
    let todo: Set<String> = ["morning_checkin", "step", "step_window", "gentle"]
    var list: [CoachEntry] = []
    for (index, e) in snapshot.entries.enumerated() {
      var when = Shared.date(e.at) ?? now
      if index == 0 { when = min(when, now) }
      var shown = e
      if doneHere, todo.contains(e.slot), Shared.dayKey(when) == today,
        let after = snapshot.afterDone
      {
        shown = after
      }
      list.append(CoachEntry(date: when, entry: shown, snapshot: snapshot, doneHere: doneHere))
    }
    return list
  }
}

// MARK: - Look (the illustrated design, D-33)

enum Palette {
  static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(
      UIColor { trait in
        let v = trait.userInterfaceStyle == .dark ? dark : light
        return UIColor(
          red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
          blue: CGFloat(v & 0xFF) / 255, alpha: 1)
      })
  }

  static let background = dynamic(0xE8F6EF, 0x10201D)
  static let text = dynamic(0x1B2433, 0xF2F5F4)
  static let secondary = dynamic(0x445063, 0xB9C6C2)
  static let primary = dynamic(0x07806F, 0x4CC9A5)
  static let onPrimary = dynamic(0xFFFFFF, 0x0B1A17)
  static let dot = dynamic(0x07806F, 0x4CC9A5)
}

// MARK: - Views

struct FaceView: View {
  let expression: String
  var size: CGFloat

  var body: some View {
    if let image = Shared.face(expression) {
      Image(uiImage: image).resizable().scaledToFit()
        .frame(width: size, height: size).clipShape(Circle())
        .accessibilityHidden(true)
    } else {
      Circle().fill(Palette.primary.opacity(0.18))
        .frame(width: size, height: size)
        .overlay(Image(systemName: "leaf.fill").foregroundColor(Palette.primary))
        .accessibilityHidden(true)
    }
  }
}

struct ActionButton: View {
  let action: WidgetActionData
  var filled = true

  var body: some View {
    if #available(iOS 17.0, *) {
      interactive
    } else {
      opensApp
    }
  }

  /// iOS 17+: Done is logged right here, without opening the app.
  @available(iOS 17.0, *)
  @ViewBuilder var interactive: some View {
    if action.id == "done" {
      Button(intent: MarkStepDoneIntent()) { label }.buttonStyle(.plain)
    } else {
      opensApp
    }
  }

  @ViewBuilder var opensApp: some View {
    if let url = Shared.url(action.link) {
      Link(destination: url) { label }
    }
  }

  var label: some View {
    Text(action.label)
      .font(.system(size: 14, weight: .semibold))
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .padding(.horizontal, 12).padding(.vertical, 7)
      .frame(maxWidth: .infinity)
      .background(filled ? Palette.primary : Palette.primary.opacity(0.12))
      .foregroundColor(filled ? Palette.onPrimary : Palette.primary)
      .clipShape(Capsule())
  }
}

struct RoutineRow: View {
  let snapshot: WidgetSnapshotData
  var showLabels = true

  var body: some View {
    HStack(spacing: 10) {
      ForEach(["morning", "step", "evening"], id: \.self) { key in
        let done = snapshot.routine[key] == "done"
        HStack(spacing: 4) {
          // Done is filled, to do is an outline; never red for missed.
          Circle()
            .strokeBorder(Palette.dot, lineWidth: 1.5)
            .background(Circle().fill(done ? Palette.dot : Color.clear))
            .frame(width: 10, height: 10)
          if showLabels {
            Text(snapshot.routineLabels[key] ?? "")
              .font(.system(size: 11)).foregroundColor(Palette.secondary).lineLimit(1)
          }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.routineLabels[key] ?? "")
        .accessibilityValue(done ? "✓" : "")
      }
    }
  }
}

struct StreakChip: View {
  let days: Int

  var body: some View {
    HStack(spacing: 3) {
      Image(systemName: "flame.fill")
      Text("\(days)").font(.system(size: 12, weight: .semibold))
    }
    .foregroundColor(Palette.primary)
    .padding(.horizontal, 8).padding(.vertical, 3)
    .background(Palette.primary.opacity(0.12)).clipShape(Capsule())
  }
}

struct CoachWidgetView: View {
  @Environment(\.widgetFamily) var family
  let item: CoachEntry

  var body: some View {
    content.widgetBackground(Palette.background)
  }

  @ViewBuilder var content: some View {
    if let e = item.entry, let s = item.snapshot {
      switch family {
      case .accessoryCircular:
        ZStack {
          AccessoryWidgetBackground()
          VStack(spacing: 0) {
            Image(systemName: "flame.fill")
            Text("\(s.streakDays ?? 0)").font(.system(size: 14, weight: .semibold))
          }
        }
      case .accessoryRectangular:
        // Generic unless the person turned details on (lock_headline).
        Text(e.lockHeadline).font(.headline).lineLimit(2)
          .widgetURL(Shared.url("livewell://home"))
      case .systemSmall:
        VStack(alignment: .leading, spacing: 6) {
          FaceView(expression: e.expression, size: 44)
          Text(e.headline).font(.system(size: 15, weight: .semibold))
            .foregroundColor(Palette.text).lineLimit(2).minimumScaleFactor(0.85)
          Spacer(minLength: 0)
          ActionButton(action: e.primaryAction)
        }
        .widgetURL(Shared.url(e.primaryAction.link))
      case .systemLarge:
        VStack(alignment: .leading, spacing: 12) {
          header(e, s, face: 72)
          RoutineRow(snapshot: s)
          Spacer(minLength: 0)
          buttons(e)
        }
      default:
        VStack(alignment: .leading, spacing: 8) {
          header(e, s, face: 56)
          Spacer(minLength: 0)
          HStack(alignment: .center) {
            RoutineRow(snapshot: s, showLabels: true)
          }
          buttons(e)
        }
      }
    } else {
      // Not set up yet (or the app hasn't run since installing).
      VStack(spacing: 6) {
        FaceView(expression: "happy", size: 40)
        Text("Live Well").font(.headline).foregroundColor(Palette.text)
      }
      .widgetURL(Shared.url("livewell://home"))
    }
  }

  func header(_ e: WidgetEntryData, _ s: WidgetSnapshotData, face: CGFloat) -> some View {
    HStack(alignment: .top, spacing: 10) {
      FaceView(expression: e.expression, size: face)
      VStack(alignment: .leading, spacing: 3) {
        Text(e.headline).font(.system(size: 16, weight: .semibold))
          .foregroundColor(Palette.text).lineLimit(2).minimumScaleFactor(0.85)
        if let sub = e.subline {
          Text(sub).font(.system(size: 13)).foregroundColor(Palette.secondary).lineLimit(2)
        }
      }
      Spacer(minLength: 0)
      if let days = s.streakDays, days > 0 { StreakChip(days: days) }
    }
  }

  func buttons(_ e: WidgetEntryData) -> some View {
    HStack(spacing: 8) {
      ActionButton(action: e.primaryAction)
      if let second = e.secondaryAction { ActionButton(action: second, filled: false) }
    }
  }
}

extension View {
  /// iOS 17 needs the background declared for the widget's container.
  @ViewBuilder func widgetBackground(_ color: Color) -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(for: .widget) { color }
    } else {
      padding().background(color)
    }
  }
}

// MARK: - The widget

struct LiveWellWidget: Widget {
  let kind = "LiveWellWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { item in
      CoachWidgetView(item: item)
    }
    .configurationDisplayName("Live Well")
    .description("Your coach and one small thing to do now.")
    .supportedFamilies([
      .systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular,
    ])
  }
}

@main
struct LiveWellWidgetBundle: WidgetBundle {
  var body: some Widget {
    LiveWellWidget()
  }
}
