import { formatTimestamp } from '@/lib/utils';
import type { Snapshot } from '@/lib/useSentimentFeed';

export function HistoryTable({ rows }: { rows: Snapshot[] }) {
  return (
    <article className="border border-border bg-card">
      <div className="border-b border-border px-6 py-4">
        <p className="text-[10px] uppercase tracking-[0.2em] text-muted font-medium">Hourly History</p>
      </div>
      <div>
        <table className="w-full text-left text-[11px] whitespace-nowrap">
          <thead>
            <tr className="border-b border-border uppercase tracking-widest text-muted">
              <th className="px-6 py-4 font-normal">Time</th>
              <th className="px-6 py-4 font-normal">Score</th>
              <th className="px-6 py-4 font-normal">Signal</th>
              <th className="px-6 py-4 font-normal">Risk</th>
              <th className="px-6 py-4 font-normal">Top</th>
            </tr>
          </thead>
          <tbody>
            {rows.length ? (
              rows.map((item) => {
                const rowScore = Number(item.score);
                return (
                  <tr key={item.timestamp.toString()} className="border-b border-border last:border-0 hover:bg-card2 transition-colors">
                    <td className="px-6 py-4 font-medium">{formatTimestamp(item.timestamp)}</td>
                    <td className="px-6 py-4 font-medium">
                      {rowScore > 0 ? '+' : ''}
                      {rowScore}
                    </td>
                    <td className="px-6 py-4">{item.signal}</td>
                    <td className="px-6 py-4">{item.riskLevel}</td>
                    <td className="px-6 py-4">{item.topTokens[0] ?? '—'}</td>
                  </tr>
                );
              })
            ) : (
              <tr>
                <td colSpan={5} className="px-6 py-8 text-center text-muted">
                  No hourly history yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </article>
  );
}
