import { describe, expect, it } from 'vitest';
import { getFridaysInCycle, snapToFriday } from './billing';

describe('snapToFriday', () => {
  it('returns same week Friday when input is Friday', () => {
    expect(snapToFriday('2026-05-01')).toBe('2026-05-01');
  });

  it('snaps forward to next Friday from Monday', () => {
    expect(snapToFriday('2026-05-04')).toBe('2026-05-08');
  });
});

describe('getFridaysInCycle', () => {
  it('returns week-ending Fridays between cycle bounds', () => {
    const fri = getFridaysInCycle('2026-05-04', '2026-05-22');
    expect(fri).toEqual(['2026-05-08', '2026-05-15', '2026-05-22']);
  });
});
