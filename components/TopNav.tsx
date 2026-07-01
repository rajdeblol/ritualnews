'use client';

import { useSentimentFeed } from '@/lib/useSentimentFeed';
import { sentimentAgentAddress } from '@/lib/contract';

export function TopNav() {
  const { blockNumber, nextRunInSeconds } = useSentimentFeed();

  // Format next run time
  let nextRunText = '00m 00s';
  if (nextRunInSeconds && nextRunInSeconds > 0) {
    const mins = Math.floor(nextRunInSeconds / 60).toString().padStart(2, '0');
    const secs = (nextRunInSeconds % 60).toString().padStart(2, '0');
    nextRunText = `${mins}m ${secs}s`;
  }

  // Format agent address
  const formatAddress = (addr?: string) => {
    if (!addr) return 'UNKNOWN';
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  return (
    <div className="w-full bg-[#1c1a17] text-paper border-b-2 border-ink px-4 py-3 flex items-center justify-between text-xs tracking-wider uppercase shadow-terminal z-50 sticky top-0">
      <div className="flex items-center gap-6">
        <div className="font-bold tracking-[0.2em] text-sm flex items-center gap-2">
          <span>RITUAL</span>
          <span className="text-muted">/</span>
          <span>NEWS</span>
        </div>
        
        <div className="w-px h-4 bg-border/30 hidden sm:block"></div>
        
        <div className="hidden sm:flex items-center gap-4 text-muted font-medium">
          <div className="flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-bull shadow-[0_0_8px_rgba(34,197,94,0.6)]"></div>
            <span>CHAIN 1979</span>
            <span className="text-border/40">&middot;</span>
            <span className="text-bull">CONNECTED</span>
          </div>
          <div className="w-px h-4 bg-border/30"></div>
          <div className="border border-border/50 px-2 py-0.5 rounded-[2px] text-[10px] flex items-center gap-1.5 opacity-80">
            <span>~ UNSIGNED</span>
          </div>
        </div>
      </div>
      
      <div className="flex items-center gap-4 sm:gap-6 text-muted font-medium">
        <div className="hidden md:flex items-center gap-2">
          <span>AGENT</span>
          <span className="text-yellow-600">{formatAddress(sentimentAgentAddress)}</span>
        </div>
        
        <div className="hidden md:block w-px h-4 bg-border/30"></div>
        
        <div className="flex items-center gap-2">
          <span>NEXT RUN</span>
          <span className="text-paper">{nextRunText}</span>
        </div>
        
        <div className="w-px h-4 bg-border/30"></div>
        
        <div className="flex items-center gap-2">
          <span>BLOCK</span>
          <span className="text-paper">{blockNumber ? Number(blockNumber).toLocaleString() : '---'}</span>
        </div>
      </div>
    </div>
  );
}
