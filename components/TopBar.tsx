import { ritualChain, sentimentAgentAddress } from '@/lib/contract';
import { formatCountdown, shortAddress } from '@/lib/utils';

export function TopBar({ blockNumber, nextRunInSeconds }: { blockNumber?: bigint; nextRunInSeconds?: number }) {
  return (
    <header className="topbar glass-panel animate-fade-in" style={{ animationDelay: '0.1s' }}>
      <div className="topbar-content">
        <div className="topbar-left">
          <div className="brand">
            <span className="brand-subtitle">Ritual Network</span>
            <h1 className="brand-title">RITUAL / SENTINEL</h1>
          </div>
          <div className="divider"></div>
          <div className="status-indicator">
            <span className="pulse-dot"></span>
            <span>Chain ID {ritualChain.id}</span>
          </div>
        </div>

        <div className="topbar-right">
          <div className="info-block">
            <span className="info-label">Agent</span>
            <span className="info-value">{shortAddress(sentimentAgentAddress)}</span>
          </div>
          <div className="info-block">
            <span className="info-label">Next Run</span>
            <span className="info-value">{formatCountdown(nextRunInSeconds)}</span>
          </div>
          <div className="info-block">
            <span className="info-label">Last Block</span>
            <span className="info-value">{blockNumber ? blockNumber.toString() : '—'}</span>
          </div>
        </div>
      </div>
    </header>
  );
}
