/**
 * Pure billing-calendar helpers (mirrors invoicing-tool.html logic; covered by unit tests).
 */

export function snapToFriday(dateStr: string): string {
  if (!dateStr) return '';
  const d = new Date(dateStr + 'T00:00:00');
  const day = d.getDay();
  const diff = day <= 5 ? 5 - day : 6;
  d.setDate(d.getDate() + diff);
  return d.toISOString().split('T')[0];
}

export function getFridaysInCycle(cycleStart: string, cycleEnd: string): string[] {
  const fridays: string[] = [];
  const start = new Date(cycleStart + 'T00:00:00');
  const end = new Date(cycleEnd + 'T00:00:00');
  let cur = new Date(start);
  const day = cur.getDay();
  const toFri = day <= 5 ? 5 - day : 6;
  cur.setDate(cur.getDate() + toFri);
  while (cur <= end) {
    fridays.push(cur.toISOString().split('T')[0]);
    cur = new Date(cur);
    cur.setDate(cur.getDate() + 7);
  }
  return fridays;
}
