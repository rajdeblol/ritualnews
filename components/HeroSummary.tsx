import { formatTimestamp } from '@/lib/utils';
import type { Snapshot } from '@/lib/useSentimentFeed';

export function HeroSummary({ hasNoData, snapshot }: { hasNoData?: boolean; snapshot?: Snapshot }) {
  return (
    <article className="border border-border bg-card px-6 py-6 h-full flex flex-col justify-between">
      <div>
        <div className="flex items-center justify-between border-b border-border pb-3 mb-6">
          <p className="text-[10px] uppercase tracking-[0.2em] text-muted font-medium">AI Market Summary</p>
          <span className="border border-border bg-card2 px-2 py-0.5 text-[9px] uppercase tracking-[0.2em] text-muted">~ Unsigned</span>
        </div>
        <p className="text-sm leading-relaxed text-ink mb-6">
          {snapshot?.summary ?? (hasNoData ? 'No snapshots have been written on-chain yet.' : 'Waiting for contract response...')}
        </p>
        <div className="flex flex-wrap gap-2 mb-8">
          {snapshot?.topTokens?.length ? (
            snapshot.topTokens.map((token) => (
              <span key={token} className="bg-ink text-paper px-2.5 py-1 text-xs tracking-wider">
                {token}
              </span>
            ))
          ) : (
            <span className="text-xs text-muted">No tokens</span>
          )}
        </div>
      </div>
      <div>
        <p className="text-[10px] text-muted">
          Last update <span className="text-amber font-medium">{snapshot?.timestamp ? '6m ago' : '—'}</span> - Contract 0x11b7…bCe7
        </p>
      </div>
    </article>
  );
}
