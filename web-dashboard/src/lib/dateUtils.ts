/**
 * Utility functions for consistent date formatting across server and client
 */

// Cache formatter instances for better performance
const fullDateTimeFormatter = new Intl.DateTimeFormat('en-US', {
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hour12: false,
});

const timeOnlyFormatter = new Intl.DateTimeFormat('en-US', {
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hour12: false,
});

export function formatDateTimeFull(dateString: string): string {
  const date = new Date(dateString);
  const parts = fullDateTimeFormatter.formatToParts(date);
  const partMap = Object.fromEntries(parts.map(p => [p.type, p.value]));
  return `${partMap.year}-${partMap.month}-${partMap.day} ${partMap.hour}:${partMap.minute}:${partMap.second}`;
}

export function formatTimeOnly(dateString: string): string {
  const date = new Date(dateString);
  const parts = timeOnlyFormatter.formatToParts(date);
  const partMap = Object.fromEntries(parts.map(p => [p.type, p.value]));
  return `${partMap.hour}:${partMap.minute}:${partMap.second}`;
}
