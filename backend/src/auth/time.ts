export function addMinutes(minutes: number): string {
  return new Date(Date.now() + minutes * 60_000).toISOString();
}
