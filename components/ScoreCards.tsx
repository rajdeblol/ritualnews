import { riskTone, scoreTone, signalTone } from '@/lib/utils';
import type { Snapshot } from '@/lib/useSentimentFeed';

export function ScoreCards({ score, snapshot }: { score?: number; snapshot?: Snapshot }) {
  return (
    <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
      <article className="border border-border bg-card px-5 py-5">
        <p className="text-[10px] uppercase tracking-[0.25em] text-muted">Sentiment score</p>
        <div className="my-6">
          <p className="text-5xl font-semibold tracking-tighter">
            {score !== undefined ? `${score > 0 ? '+' : ''}${score}` : '—'}
          </p>
        </div>
        <p className="mt-2 text-xs text-muted">out of ±100</p>
        <div className="mt-4 flex h-0.5 w-full bg-border">
          {score !== undefined && (
            <div 
              className="h-full bg-ink" 
              style={{ 
                width: '4px', 
                marginLeft: `${(score + 100) / 2}%`,
                transform: 'translateX(-50%)'
              }} 
            />
          )}
        </div>
      </article>

      <article className="border border-border bg-card px-5 py-5">
        <p className="text-[10px] uppercase tracking-[0.25em] text-muted">Signal</p>
        <div className="my-6">
          <p className="text-3xl font-semibold tracking-wide">
            {snapshot?.signal ?? 'WAITING'}
          </p>
        </div>
        <div className="mt-6 border-t border-border pt-4">
          <p className="text-xs text-muted">AI-classified direction</p>
        </div>
      </article>

      <article className="border border-border bg-card px-5 py-5">
        <p className="text-[10px] uppercase tracking-[0.25em] text-muted">Risk level</p>
        <div className="my-6">
          <span className={`inline-block border px-3 py-1 text-sm font-medium ${riskTone(snapshot?.riskLevel)}`}>
            {snapshot?.riskLevel ?? '—'}
          </span>
        </div>
        <div className="mt-6 flex flex-col gap-1 text-[11px] text-muted">
          <p>Volatility assessment</p>
          <p>Macro uncertainty detected</p>
        </div>
      </article>

      <article className="border border-border bg-card px-5 py-5">
        <p className="text-[10px] uppercase tracking-[0.25em] text-muted">Total snapshots</p>
        <div className="my-6">
          <p className="text-4xl font-semibold tracking-tighter">
            {snapshot?.headlineCount?.toString() ?? '0'}
          </p>
        </div>
        <p className="text-[11px] text-muted">{snapshot?.headlineCount?.toString() ?? '0'} headlines · this hour</p>
      </article>
    </section>
  );
}
