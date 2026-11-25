/// Portal offers as staff see them (spec 11 `portal_offers`, 13.2, 13.4;
/// T-PRT-02, D-92). The field names match what the app reads
/// (apps/mobile learn_repository.dart): title, description, url,
/// offer_type, price_display, driver_tags, topic_tags, active,
/// review_status.
library;

import '../../../core/auth/staff.dart';

enum OfferType {
  course('course', 'Course'),
  program('program', 'Program'),
  freeLesson('free_lesson', 'Free lesson'),
  coaching('coaching', 'Coaching');

  const OfferType(this.id, this.label);
  final String id;
  final String label;

  static OfferType fromId(Object? v) =>
      values.firstWhere((t) => t.id == v, orElse: () => course);
}

enum ReviewStatus {
  draft('draft', 'Draft'),
  inReview('in_review', 'In review'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Changes needed'),
  archived('archived', 'Archived');

  const ReviewStatus(this.id, this.label);
  final String id;
  final String label;

  static ReviewStatus fromId(Object? v) =>
      values.firstWhere((s) => s.id == v, orElse: () => draft);
}

/// Workflow steps (same names as the Core API's `action`).
enum OfferAction {
  submit('submit', 'Send for review'),
  withdraw('withdraw', 'Withdraw from review'),
  approve('approve', 'Approve'),
  reject('reject', 'Ask for changes'),
  publish('publish', 'Publish to the app'),
  unpublish('unpublish', 'Take offline'),
  archive('archive', 'Archive'),
  restore('restore', 'Restore as draft');

  const OfferAction(this.id, this.label);
  final String id;
  final String label;
}

/// What an editor writes.
class OfferFields {
  const OfferFields({
    required this.title,
    required this.url,
    required this.offerType,
    this.description = '',
    this.priceDisplay = '',
    this.driverTags = const [],
    this.topicTags = const [],
  });

  final String title;
  final String description;
  final String url;
  final OfferType offerType;

  /// Shown exactly as entered (spec 13.4). Empty: "Paid course".
  final String priceDisplay;
  final List<String> driverTags;
  final List<String> topicTags;

  Map<String, Object?> toJson() => {
    'title': title,
    'description': description,
    'url': url,
    'offer_type': offerType.id,
    'driver_tags': driverTags,
    'topic_tags': topicTags,
    'price_display': priceDisplay,
  };
}

class PortalOffer {
  const PortalOffer({
    required this.id,
    required this.fields,
    required this.status,
    required this.active,
    required this.version,
    required this.rev,
    this.versionEditors = const [],
    this.submittedBy,
    this.updatedAt,
  });

  factory PortalOffer.fromJson(Map<String, Object?> j) => PortalOffer(
    id: j['id']! as String,
    fields: OfferFields(
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      url: j['url'] as String? ?? '',
      offerType: OfferType.fromId(j['offer_type']),
      priceDisplay: j['price_display'] as String? ?? '',
      driverTags: [...?(j['driver_tags'] as List?)?.whereType<String>()],
      topicTags: [...?(j['topic_tags'] as List?)?.whereType<String>()],
    ),
    status: ReviewStatus.fromId(j['review_status']),
    active: j['active'] == true,
    version: (j['version'] as num?)?.toInt() ?? 1,
    rev: (j['rev'] as num?)?.toInt() ?? 1,
    versionEditors: [...?(j['version_editors'] as List?)?.whereType<String>()],
    submittedBy: j['submitted_by'] as String?,
    updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? ''),
  );

  final String id;
  final OfferFields fields;
  final ReviewStatus status;

  /// Shown in the app: only when approved and active (firestore.rules).
  final bool active;
  final int version;

  /// Revision for safe concurrent edits (the API's `expected_rev`).
  final int rev;
  final List<String> versionEditors;
  final String? submittedBy;
  final DateTime? updatedAt;

  bool get isLive => active && status == ReviewStatus.approved;

  /// Whether [uid] edited or submitted this version (two-person rule).
  bool touchedBy(String uid) =>
      versionEditors.contains(uid) || submittedBy == uid;
}

/// Roles for each step. Mirrors services/core-api portal-offer-model.ts;
/// the server decides, this only hides buttons that would be refused.
const editRoles = {StaffRole.contentEditor, StaffRole.admin};
const _reviewRoles = {StaffRole.clinicalReviewer, StaffRole.admin};
const actionRoles = <OfferAction, Set<StaffRole>>{
  OfferAction.submit: editRoles,
  OfferAction.withdraw: editRoles,
  OfferAction.approve: _reviewRoles,
  OfferAction.reject: _reviewRoles,
  OfferAction.publish: editRoles,
  OfferAction.unpublish: {
    StaffRole.contentEditor,
    StaffRole.clinicalReviewer,
    StaffRole.safetyReviewer,
    StaffRole.admin,
  },
  OfferAction.archive: editRoles,
  OfferAction.restore: editRoles,
};

/// Why a step is not offered (shown so nobody wonders where a button went).
enum ActionBlock { role, ownOffer }

/// Steps that fit the offer's state, with the reason any is blocked for
/// [me]. A step that doesn't fit the state at all is left out.
Map<OfferAction, ActionBlock?> actionsFor(PortalOffer o, StaffSession me) {
  final s = o.status;
  final fits = <OfferAction>[
    if (s == ReviewStatus.draft || s == ReviewStatus.rejected)
      OfferAction.submit,
    if (s == ReviewStatus.inReview) ...[
      OfferAction.approve,
      OfferAction.reject,
      OfferAction.withdraw,
    ],
    if (s == ReviewStatus.approved && !o.active) OfferAction.publish,
    if (o.active) OfferAction.unpublish,
    if (s != ReviewStatus.archived) OfferAction.archive,
    if (s == ReviewStatus.archived) OfferAction.restore,
  ];
  return {
    for (final a in fits)
      a: !me.hasAny(actionRoles[a]!)
          ? ActionBlock.role
          : a == OfferAction.approve && o.touchedBy(me.uid)
          ? ActionBlock.ownOffer
          : null,
  };
}

bool canEdit(PortalOffer o, StaffSession me) =>
    me.hasAny(editRoles) && o.status != ReviewStatus.archived;
