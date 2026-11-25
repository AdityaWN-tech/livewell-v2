import { describe, expect, it } from 'vitest';

import { MAX_MFA_WAIVER_SECONDS, mfaOf, requireStaff, type Staff, type StaffRole } from '../src/admin/staff.js';
import {
  applyEdit,
  applyTransition,
  changedFields,
  offerFieldsSchema,
  type OfferState,
} from '../src/portal/portal-offer-model.js';

// Pure checks (no emulator needed): the MFA/role gate, field validation and
// the review workflow (T-PRT-02, D-92).

const NOW = 1_800_000_000;
const staff = (uid: string, ...roles: StaffRole[]): Staff => ({
  uid,
  roles: new Set(roles),
  mfa: 'second_factor',
});
const state = (o: Partial<OfferState> = {}): OfferState => ({
  review_status: 'draft',
  active: false,
  version: 1,
  version_editors: ['ed'],
  submitted_by: null,
  ...o,
});
const fields = {
  title: 'Gut health in 30 days',
  url: 'https://livewell.conciergeconnectedcare.net/web/courses/gut',
  offer_type: 'course',
};

describe('staff gate (spec 16.2)', () => {
  const token = (extra: Record<string, unknown>) => ({ uid: 'u', token: { iat: NOW - 10, ...extra } });

  it('refuses no token, no role, unknown roles', () => {
    expect(() => requireStaff(undefined, ['admin'], NOW)).toThrow(/Sign in/);
    expect(() => requireStaff(token({}), ['admin'], NOW)).toThrow(/no staff role/);
    expect(() => requireStaff(token({ staff_roles: ['owner', 'root'] }), ['admin'], NOW)).toThrow(
      /no staff role/,
    );
    expect(() => requireStaff(token({ staff_roles: 'admin' }), ['admin'], NOW)).toThrow(/no staff role/);
  });

  it('a role without MFA or a live waiver is refused', () => {
    expect(() => requireStaff(token({ staff_roles: ['admin'] }), ['admin'], NOW)).toThrow(/Two-step/);
    // Expired waiver.
    expect(() =>
      requireStaff(token({ staff_roles: ['admin'], staff_mfa_waiver_until: NOW - 1 }), ['admin'], NOW),
    ).toThrow(/Two-step/);
    // Waiver longer than 30 days is not honoured.
    expect(
      mfaOf({ iat: NOW, staff_mfa_waiver_until: NOW + MAX_MFA_WAIVER_SECONDS + 1 }, NOW),
    ).toBeNull();
    // A waiver claim of the wrong type is ignored.
    expect(mfaOf({ iat: NOW, staff_mfa_waiver_until: String(NOW + 60) }, NOW)).toBeNull();
  });

  it('accepts a second factor or a live, short waiver', () => {
    const a = requireStaff(
      token({ staff_roles: ['content_editor'], firebase: { sign_in_second_factor: 'totp' } }),
      ['content_editor'],
      NOW,
    );
    expect(a.mfa).toBe('second_factor');
    const b = requireStaff(
      token({ staff_roles: ['content_editor'], staff_mfa_waiver_until: NOW + 3600 }),
      ['content_editor'],
      NOW,
    );
    expect(b.mfa).toBe('waiver');
  });

  it('checks the role last', () => {
    expect(() =>
      requireStaff(
        token({ staff_roles: ['safety_reviewer'], firebase: { sign_in_second_factor: 'totp' } }),
        ['content_editor', 'admin'],
        NOW,
      ),
    ).toThrow(/Your role/);
  });
});

describe('offer fields (spec 11, 13.4)', () => {
  it('accepts a valid offer and fills defaults', () => {
    const r = offerFieldsSchema.parse({ ...fields, driver_tags: ['Gut', 'gut', 'sleep'] });
    expect(r.description).toBe('');
    expect(r.price_display).toBe('');
    expect(r.driver_tags).toEqual(['gut', 'sleep']);
  });

  it.each([
    ['http link', { url: 'http://livewell.conciergeconnectedcare.net/web/courses/gut' }],
    ['other host', { url: 'https://example.com/web/courses/gut' }],
    ['look-alike host', { url: 'https://livewell.conciergeconnectedcare.net.evil.com/x' }],
    ['credentials', { url: 'https://a:b@livewell.conciergeconnectedcare.net/x' }],
    ['utm parameter', { url: 'https://livewell.conciergeconnectedcare.net/x?utm_source=x' }],
    ['lw_cid parameter', { url: 'https://livewell.conciergeconnectedcare.net/x?lw_cid=1' }],
    ['javascript url', { url: 'javascript:alert(1)' }],
    ['short title', { title: 'Hi' }],
    ['long title', { title: 'x'.repeat(81) }],
    ['newline in title', { title: 'Gut\nhealth' }],
    ['unknown type', { offer_type: 'webinar' }],
    ['bad tag', { topic_tags: ['gut health'] }],
    ['too many tags', { topic_tags: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'] }],
    ['price on a free lesson', { offer_type: 'free_lesson', price_display: '$10' }],
    ['unknown field', { review_status: 'approved' }],
    ['active from the client', { active: true }],
  ])('refuses %s', (_name, patch) => {
    expect(offerFieldsSchema.safeParse({ ...fields, ...patch }).success).toBe(false);
  });

  it('lists changed field names only', () => {
    const after = offerFieldsSchema.parse(fields);
    expect(changedFields({ ...after }, after)).toEqual([]);
    expect(changedFields({ ...after, title: 'Old' }, after)).toEqual(['title']);
  });
});

describe('review workflow (D-92)', () => {
  const editor = staff('ed', 'content_editor');
  const editor2 = staff('ed2', 'content_editor');
  const reviewer = staff('rev', 'clinical_reviewer');
  const safety = staff('saf', 'safety_reviewer');
  const admin = staff('adm', 'admin');

  const step = (s: OfferState, action: Parameters<typeof applyTransition>[1], who: Staff) => {
    const r = applyTransition(s, action, who);
    if (!r.ok) throw new Error(r.error);
    return r.next;
  };

  it('draft → in_review → approved → live → archived', () => {
    let s = step(state(), 'submit', editor);
    expect(s).toMatchObject({ review_status: 'in_review', submitted_by: 'ed' });
    s = step(s, 'approve', reviewer);
    expect(s).toMatchObject({ review_status: 'approved', active: false, version_editors: [] });
    s = step(s, 'publish', editor);
    expect(s.active).toBe(true);
    s = step(s, 'archive', editor);
    expect(s).toMatchObject({ review_status: 'archived', active: false });
  });

  it('nobody approves their own edits or submission, admins included', () => {
    const s = step(state({ version_editors: ['adm'] }), 'submit', editor2);
    expect(applyTransition(s, 'approve', admin)).toEqual({ ok: false, error: 'own_offer' });
    const t = step(state(), 'submit', staff('adm', 'admin'));
    expect(applyTransition(t, 'approve', admin)).toEqual({ ok: false, error: 'own_offer' });
    const both = staff('ed', 'content_editor', 'clinical_reviewer');
    expect(applyTransition(step(state(), 'submit', editor2), 'approve', both)).toEqual({
      ok: false,
      error: 'own_offer',
    });
    expect(applyTransition(step(state(), 'submit', editor), 'approve', admin).ok).toBe(true);
  });

  it('roles: editors cannot approve; reviewers cannot publish; anyone can take an offer down', () => {
    const inReview = step(state(), 'submit', editor);
    expect(applyTransition(inReview, 'approve', editor2)).toEqual({ ok: false, error: 'role' });
    const approved = step(inReview, 'approve', reviewer);
    expect(applyTransition(approved, 'publish', reviewer)).toEqual({ ok: false, error: 'role' });
    expect(applyTransition(approved, 'publish', safety)).toEqual({ ok: false, error: 'role' });
    const live = step(approved, 'publish', editor);
    for (const who of [editor, reviewer, safety, admin]) {
      expect(applyTransition(live, 'unpublish', who).ok).toBe(true);
    }
    expect(applyEdit(live, reviewer)).toEqual({ ok: false, error: 'role' });
  });

  it('only approved offers can go live', () => {
    for (const st of ['draft', 'in_review', 'rejected', 'archived'] as const) {
      expect(applyTransition(state({ review_status: st }), 'publish', editor)).toEqual({
        ok: false,
        error: 'wrong_status',
      });
    }
  });

  it('an edit takes a live offer offline and back to draft', () => {
    const live = state({ review_status: 'approved', active: true, version_editors: [] });
    const r = applyEdit(live, editor2);
    expect(r).toEqual({
      ok: true,
      next: { review_status: 'draft', active: false, version: 2, version_editors: ['ed2'], submitted_by: null },
    });
    expect(applyEdit(state({ review_status: 'archived' }), editor)).toEqual({
      ok: false,
      error: 'wrong_status',
    });
  });

  it('reject, withdraw and restore', () => {
    const rejected = step(step(state(), 'submit', editor), 'reject', reviewer);
    expect(rejected.review_status).toBe('rejected');
    expect(step(rejected, 'submit', editor).review_status).toBe('in_review');
    expect(step(step(state(), 'submit', editor), 'withdraw', editor).review_status).toBe('draft');
    const restored = step(state({ review_status: 'archived' }), 'restore', editor2);
    expect(restored).toMatchObject({ review_status: 'draft', active: false, version_editors: ['ed2'] });
    expect(applyTransition(state(), 'unpublish', editor)).toEqual({ ok: false, error: 'not_active' });
  });
});
