'use client';

import { useEffect, useMemo, useState } from 'react';
import { useBlockNumber, useReadContract, useReadContracts } from 'wagmi';
import { sentimentFeedAbi, sentimentFeedAddress } from '@/lib/contract';

export type Snapshot = {
  score: bigint;
  signal: string;
  riskLevel: string;
  summary: string;
  topTokens: string[];
  headlines: string[];
  headlineSources: string[];
  headlineSentiments: string[];
  headlineUrls: string[];
  timestamp: bigint;
  headlineCount: bigint;
};

export type TokenAggregate = {
  token: string;
  mentions: number;
  delta: number;
};

const EMPTY_ADDRESS = '0x0000000000000000000000000000000000000000';
const CONTRACT_ADDRESS = sentimentFeedAddress ?? EMPTY_ADDRESS;

export function useSentimentFeed() {
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));

  useEffect(() => {
    const intervalId = window.setInterval(() => {
      setNow(Math.floor(Date.now() / 1000));
    }, 1000);

    return () => window.clearInterval(intervalId);
  }, []);

  const latest = useReadContract({
    abi: sentimentFeedAbi,
    address: CONTRACT_ADDRESS,
    functionName: 'getLatest',
    query: {
      enabled: Boolean(sentimentFeedAddress),
      refetchInterval: 30_000,
      retry: false,
    },
  });

  const history = useReadContract({
    abi: sentimentFeedAbi,
    address: CONTRACT_ADDRESS,
    functionName: 'getRecentScores',
    args: [24n],
    query: {
      enabled: Boolean(sentimentFeedAddress),
      refetchInterval: 30_000,
    },
  });

  const totalSnapshots = useReadContract({
    abi: sentimentFeedAbi,
    address: CONTRACT_ADDRESS,
    functionName: 'totalSnapshots',
    query: {
      enabled: Boolean(sentimentFeedAddress),
      refetchInterval: 30_000,
    },
  });

  const blockNumber = useBlockNumber({
    query: {
      refetchInterval: 30_000,
    },
  });

  const snapshot = latest.data as Snapshot | undefined;
  const recentData = history.data as readonly [readonly bigint[], readonly bigint[]] | undefined;
  const snapshotCount = totalSnapshots.data ? Number(totalSnapshots.data) : 0;

  const snapshotIndices = useMemo(() => {
    if (!snapshotCount) return [] as bigint[];
    const start = Math.max(0, snapshotCount - 24);
    return Array.from({ length: snapshotCount - start }, (_, index) => BigInt(start + index));
  }, [snapshotCount]);

  const snapshotHistory = useReadContracts({
    contracts: snapshotIndices.map((index) => ({
      abi: sentimentFeedAbi,
      address: CONTRACT_ADDRESS,
      functionName: 'getSnapshot',
      args: [index],
    })),
    query: {
      enabled: Boolean(sentimentFeedAddress) && snapshotIndices.length > 0,
      refetchInterval: 30_000,
    },
  });

  const historySnapshots = useMemo(() => {
    return (snapshotHistory.data ?? [])
      .map((item) => item.result as Snapshot | undefined)
      .filter((item): item is Snapshot => Boolean(item));
  }, [snapshotHistory.data]);

  const last12History = useMemo(() => [...historySnapshots].slice(-12).reverse(), [historySnapshots]);

  const topTokens24h = useMemo<TokenAggregate[]>(() => {
    const recent = historySnapshots.slice(-12);
    const previous = historySnapshots.slice(Math.max(0, historySnapshots.length - 24), Math.max(0, historySnapshots.length - 12));
    const recentCounts = new Map<string, number>();
    const previousCounts = new Map<string, number>();

    for (const item of recent) {
      for (const token of item.topTokens) {
        recentCounts.set(token, (recentCounts.get(token) ?? 0) + 1);
      }
    }

    for (const item of previous) {
      for (const token of item.topTokens) {
        previousCounts.set(token, (previousCounts.get(token) ?? 0) + 1);
      }
    }

    return [...recentCounts.entries()]
      .map(([token, mentions]) => ({
        token,
        mentions,
        delta: mentions - (previousCounts.get(token) ?? 0),
      }))
      .sort((left, right) => right.mentions - left.mentions || right.delta - left.delta)
      .slice(0, 8);
  }, [historySnapshots]);

  const score = snapshot ? Number(snapshot.score) : undefined;
  const nextRunInSeconds = snapshot?.timestamp ? Math.max(0, Number(snapshot.timestamp) + 3600 - now) : undefined;
  const latestError = latest.error instanceof Error ? latest.error.message : undefined;
  const hasNoData = latestError?.includes('no data yet');
  const errorMessage = latestError ?? history.error?.message ?? totalSnapshots.error?.message ?? snapshotHistory.error?.message;

  return {
    blockNumber: blockNumber.data,
    history: history.data,
    errorMessage,
    hasNoData,
    historySnapshots,
    isConfigured: Boolean(sentimentFeedAddress),
    isLoading: latest.isLoading,
    last12History,
    latest: latest.data,
    latestQuery: latest,
    nextRunInSeconds,
    recentData,
    score,
    snapshot,
    snapshotCount,
    topTokens24h,
  };
}
