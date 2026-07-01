import type { TokenAggregate } from '@/lib/useSentimentFeed';

function trendArrow(delta: number) {
  if (delta > 0) return <span className="text-bull">↑</span>;
  if (delta < 0) return <span className="text-bear">↓</span>;
  return <span className="text-muted">→</span>;
}

export function TopTokensTable({ rows }: { rows: TokenAggregate[] }) {
  // Find max mentions for scaling the bars
  const maxMentions = rows.reduce((max, item) => Math.max(max, item.mentions), 1);

  return (
    <article className="border border-border bg-card">
      <div className="border-b border-border px-6 py-4">
        <p className="text-[10px] uppercase tracking-[0.2em] text-muted font-medium">Top Mentioned Tokens · This Hour</p>
      </div>
      <div className="px-6 py-5">
        {rows.length ? (
          <div className="flex flex-col gap-4">
            {rows.map((item) => {
              const widthPct = Math.max(10, (item.mentions / maxMentions) * 100);
              return (
                <div key={item.token} className="flex items-center gap-4 text-[11px]">
                  <span className="w-10 font-bold tracking-wider">{item.token}</span>
                  <div className="flex-1 h-[2px] bg-border relative">
                    <div 
                      className="absolute top-0 left-0 h-full bg-ink"
                      style={{ width: `${widthPct}%` }}
                    />
                  </div>
                  <div className="flex w-8 items-center justify-end gap-1 font-medium text-muted">
                    {item.mentions} {trendArrow(item.delta)}
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div className="py-8 text-center text-[11px] text-muted">
            No token history yet.
          </div>
        )}
      </div>
    </article>
  );
}
