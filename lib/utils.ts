export function formatTimestamp(value?: bigint) {
  if (!value) return '—';
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(new Date(Number(value)));
}

export function formatCountdown(value?: number) {
  if (value == null) return '—';
  const total = Math.max(0, value);
  const minutes = Math.floor(total / 60);
  const seconds = total % 60;
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

export function scoreTone(score?: number) {
  if (score == null) return 'text-muted';
  if (score > 10) return 'text-bull';
  if (score < -10) return 'text-bear';
  return 'text-neutral';
}

export function signalTone(signal?: string) {
  if (signal === 'BULLISH') return 'text-bull';
  if (signal === 'BEARISH') return 'text-bear';
  return 'text-neutral';
}

export function riskTone(risk?: string) {
  if (risk === 'LOW') return 'text-bull';
  if (risk === 'HIGH') return 'text-bear';
  return 'text-amber';
}

export function shortAddress(value?: string) {
  if (!value) return 'Not configured';
  return `${value.slice(0, 6)}…${value.slice(-4)}`;
}
