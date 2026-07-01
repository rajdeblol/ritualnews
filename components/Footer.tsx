import { discordUrl, docsUrl, explorerUrl, sentimentAgentAddress } from '@/lib/contract';
import { shortAddress } from '@/lib/utils';

export function Footer() {
  return (
    <footer className="footer">
      <div className="footer-content">
        <p className="footer-text">
          Powered by Ritual Chain · Agent <span className="highlight-text">{shortAddress(sentimentAgentAddress)}</span> · Runs autonomously forever
        </p>
        <div className="footer-links">
          <a href={explorerUrl} target="_blank" rel="noreferrer" className="footer-link">
            Explorer
          </a>
          <a href={docsUrl} target="_blank" rel="noreferrer" className="footer-link">
            Docs
          </a>
          <a href={discordUrl} target="_blank" rel="noreferrer" className="footer-link">
            Discord
          </a>
        </div>
      </div>
    </footer>
  );
}
