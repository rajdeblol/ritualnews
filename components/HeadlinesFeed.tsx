import { timeAgo } from '@/lib/utils';
import type { Snapshot } from '@/lib/useSentimentFeed';

function sentimentPillTone(value?: string) {
  if (value === 'bull') return 'border-bull bg-bull/10 text-bull';
  if (value === 'bear') return 'border-bear bg-bear/10 text-bear';
  return 'border-muted/30 bg-muted/5 text-muted';
}

export function HeadlinesFeed({ hasNoData, snapshot }: { hasNoData?: boolean; snapshot?: Snapshot }) {
  return (
    <section className="border border-border bg-card">
      <div className="flex items-center justify-between border-b border-border px-6 py-4">
        <p className="text-[10px] uppercase tracking-[0.2em] text-muted font-medium">Live Headlines Feed</p>
        <span className="text-[9px] uppercase tracking-wider text-muted">
          {snapshot?.headlineCount?.toString() ?? '0'} headlines · updated {timeAgo(snapshot?.timestamp)}
        </span>
      </div>
      <div className="flex flex-col">
        {snapshot?.headlines?.length ? (
          snapshot.headlines.map((headline, index) => {
            const sentiment = snapshot.headlineSentiments[index];
            const url = snapshot.headlineUrls?.[index] || '#';
            return (
              <div key={`${headline}-${index}`} className="flex items-center gap-4 border-b border-border/60 px-6 py-3 last:border-0 hover:bg-card2 transition-colors">
                <span
                  className={`flex-shrink-0 rounded-[2px] border px-2 py-0.5 text-[9px] font-bold uppercase tracking-[0.1em] ${sentimentPillTone(
                    sentiment
                  )}`}
                >
                  {sentiment?.substring(0, 4) ?? 'neut'}
                </span>
                <span className="flex-shrink-0 text-[11px] text-muted w-32 truncate">
                  {snapshot.headlineSources[index] ?? 'Unknown'}
                </span>
                <a href={url} target="_blank" rel="noopener noreferrer" className="text-xs text-ink truncate leading-relaxed hover:underline">
                  {headline}
                </a>
              </div>
            );
          })
        ) : (
          <div className="px-6 py-8 text-center text-xs text-muted">
            {hasNoData ? 'No headline batch has been written yet.' : 'Waiting for snapshot headlines...'}
          </div>
        )}
      </div>
    </section>
  );
}
