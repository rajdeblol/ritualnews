'use client';

import { HeadlinesFeed } from '@/components/HeadlinesFeed';
import { HeroSummary } from '@/components/HeroSummary';
import { HistoryTable } from '@/components/HistoryTable';
import { ScoreCards } from '@/components/ScoreCards';
import { SentimentChart } from '@/components/SentimentChart';
import { TopTokensTable } from '@/components/TopTokensTable';
import { TopNav } from '@/components/TopNav';
import { useSentimentFeed } from '@/lib/useSentimentFeed';

export default function HomePage() {
  const {
    errorMessage,
    hasNoData,
    isConfigured,
    last12History,
    recentData,
    score,
    snapshot,
    topTokens24h,
  } = useSentimentFeed();

  return (
    <div className="min-h-screen flex flex-col">
      <TopNav />
      <main className="mx-auto flex w-full max-w-7xl flex-col gap-4 px-4 py-8 sm:px-6 lg:px-8">
      {!isConfigured ? (
        <section className="border border-bear bg-card px-5 py-4 text-sm text-bear">
          Set <code className="bg-card2 px-1.5 py-0.5 font-bold">NEXT_PUBLIC_SENTIMENT_FEED_ADDRESS</code> and optionally
          <code className="bg-card2 px-1.5 py-0.5 font-bold ml-1">NEXT_PUBLIC_SENTIMENT_AGENT_ADDRESS</code> in your .env.local file.
        </section>
      ) : null}

      <ScoreCards score={score} snapshot={snapshot} />

      <section className="grid gap-4 xl:grid-cols-2">
        <HeroSummary hasNoData={hasNoData} snapshot={snapshot} />
        <SentimentChart recentData={recentData} />
      </section>

      <HeadlinesFeed hasNoData={hasNoData} snapshot={snapshot} />

      <section className="grid gap-4 xl:grid-cols-2">
        <HistoryTable rows={last12History} />
        <TopTokensTable rows={topTokens24h} />
      </section>

      {errorMessage && !hasNoData ? (
        <section className="border border-bear bg-bear/5 px-5 py-4 text-sm text-bear">
          RPC read error: {errorMessage}
        </section>
      ) : null}
      </main>
    </div>
  );
}
