const { execSync } = require('child_process');

const BULLISH_WORDS = [
    'surge', 'rally', 'pump', 'gain', 'high', 'bull', 'buy', 
    'adoption', 'launch', 'partnership', 'upgrade', 'approve', 
    'inflow', 'record', 'growth', 'rise', 'up', 'positive',
    'breakout', 'recover', 'accumulate', 'etf', 'institutional'
];
  
const BEARISH_WORDS = [
    'crash', 'dump', 'drop', 'fall', 'bear', 'sell', 'hack',
    'ban', 'sue', 'fraud', 'loss', 'low', 'down', 'negative',
    'outflow', 'fear', 'risk', 'warning', 'collapse', 'liquidat',
    'scam', 'ponzi', 'investigation', 'fine', 'penalty'
];

const TOKEN_MAP = {
    'bitcoin': 'BTC', 'ethereum': 'ETH', 'solana': 'SOL', 'binance': 'BNB', 'ripple': 'XRP',
    'btc': 'BTC', 'eth': 'ETH', 'sol': 'SOL', 'bnb': 'BNB', 'xrp': 'XRP', 'arb': 'ARB',
    'op': 'OP', 'matic': 'MATIC', 'avax': 'AVAX', 'doge': 'DOGE'
};

const NEWS_API_KEY = process.env.NEWSAPI_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.SENTIMENT_FEED_ADDRESS;
const RPC_URL = process.env.RPC_URL || "https://rpc.ritualfoundation.org";
const INTERVAL_MS = parseInt(process.env.FETCH_INTERVAL_MS || "3600000", 10);

function logInfo(msg) { console.log(`[INFO] ${new Date().toISOString()} - ${msg}`); }
function logError(msg) { console.error(`[ERROR] ${new Date().toISOString()} - ${msg}`); }

async function fetchNews() {
    if (!NEWS_API_KEY) throw new Error("NEWSAPI_KEY is missing");
    
    const url = `https://newsapi.org/v2/everything?q=crypto+OR+bitcoin+OR+ethereum&sortBy=publishedAt&pageSize=15&apiKey=${NEWS_API_KEY}`;
    
    // Implement simple retry
    for (let i = 0; i < 3; i++) {
        try {
            logInfo(`Fetching news (Attempt ${i + 1}/3)...`);
            const res = await fetch(url);
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            const data = await res.json();
            return data.articles || [];
        } catch (err) {
            logError(`Fetch failed: ${err.message}`);
            if (i === 2) throw err;
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
    }
    return [];
}

function analyzeSentiment(articles) {
    const headlines = [];
    const sources = [];
    const headlineSentiments = [];
    const urls = [];
    let totalScore = 0;
    let isHighRisk = false;
    const tokenCounts = {};

    for (const post of articles) {
        if (!post.title || !post.source?.name || !post.url) continue;

        const title = post.title.replace(/"/g, "'").replace(/\n/g, " ");
        const source = post.source.name.replace(/"/g, "'");
        headlines.push(title);
        sources.push(source);
        urls.push(post.url);

        let titleScore = 0;
        for (const word of BULLISH_WORDS) {
            if (new RegExp(`\\b${word}\\b`, 'i').test(title)) titleScore += 5;
        }
        for (const word of BEARISH_WORDS) {
            if (new RegExp(`\\b${word}\\b`, 'i').test(title)) titleScore -= 5;
        }

        let sentiment = "neut";
        if (titleScore > 0) sentiment = "bull";
        else if (titleScore < 0) sentiment = "bear";
        headlineSentiments.push(sentiment);

        totalScore += titleScore;

        if (sentiment === "bear" && /hack|ban|crash|fraud/i.test(title)) {
            isHighRisk = true;
        }

        for (const [key, ticker] of Object.entries(TOKEN_MAP)) {
            if (new RegExp(`\\b${key}\\b`, 'i').test(title)) {
                tokenCounts[ticker] = (tokenCounts[ticker] || 0) + 1;
            }
        }
    }

    totalScore = Math.max(-100, Math.min(100, totalScore));

    let signal = "NEUTRAL";
    if (totalScore > 20) signal = "BULLISH";
    else if (totalScore < -20) signal = "BEARISH";

    let riskLevel = "MEDIUM";
    if (isHighRisk) riskLevel = "HIGH";
    else if (totalScore > 40) riskLevel = "LOW";

    const sortedTokens = Object.entries(tokenCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(e => e[0]);

    const theme = totalScore > 0 
        ? "Market shows positive momentum with bullish keywords detected"
        : (totalScore < 0 ? "Market shows caution with bearish keywords detected" : "Market appears mixed and neutral");

    const summary = `${headlines.length} headlines analyzed this hour. Market sentiment is ${signal} with a score of ${totalScore}. Top mentioned assets: ${sortedTokens.join(", ") || "None"}. ${theme}.`;

    return {
        score: totalScore,
        signal,
        riskLevel,
        summary,
        topTokens: sortedTokens,
        headlines,
        sources,
        headlineSentiments,
        urls
    };
}

function pushToContract(analysis) {
    if (!PRIVATE_KEY) throw new Error("PRIVATE_KEY is missing.");
    if (!CONTRACT_ADDRESS) throw new Error("SENTIMENT_FEED_ADDRESS is missing.");

    const escapeBashString = (str) => {
        return "'" + str.replace(/'/g, "'\\''") + "'";
    };

    const topTokensStr = escapeBashString(`[${analysis.topTokens.map(t => `"${t}"`).join(",")}]`);
    const headlinesStr = escapeBashString(`[${analysis.headlines.map(h => `"${h.replace(/"/g, '\\"')}"`).join(",")}]`);
    const sourcesStr = escapeBashString(`[${analysis.sources.map(s => `"${s.replace(/"/g, '\\"')}"`).join(",")}]`);
    const sentimentsStr = escapeBashString(`[${analysis.headlineSentiments.map(s => `"${s}"`).join(",")}]`);

    const summaryStr = escapeBashString(analysis.summary);

    const castCommand = `cast send ${CONTRACT_ADDRESS} "pushSnapshot(int8,string,string,string,string[],string[],string[],string[])" ` +
        `${analysis.score} "${analysis.signal}" "${analysis.riskLevel}" ${summaryStr} ` +
        `${topTokensStr} ${headlinesStr} ${sourcesStr} ${sentimentsStr} ` +
        `--rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY}`;

    logInfo("Executing cast send...");
    
    // Implement simple retry for cast send
    for (let i = 0; i < 3; i++) {
        try {
            const output = execSync(castCommand, { encoding: 'utf-8', stdio: 'pipe' });
            const txHashMatch = output.match(/transactionHash\s+(0x[a-fA-F0-9]+)/);
            if (txHashMatch) {
                logInfo(`SUCCESS! Tx Hash: ${txHashMatch[1]}`);
                return;
            } else {
                logInfo("Push completed, but couldn't parse tx hash from output.");
                return;
            }
        } catch (err) {
            logError(`Cast send failed (Attempt ${i + 1}/3): ${err.message}`);
            if (i === 2) throw err;
            // Wait 5 seconds before retrying RPC interaction
            execSync('sleep 5');
        }
    }
}

async function runCycle() {
    logInfo("--- STARTING NEW SENTIMENT CYCLE ---");
    try {
        const articles = await fetchNews();
        if (articles.length === 0) {
            logInfo("No articles found, skipping cycle.");
            return;
        }

        logInfo(`Fetched ${articles.length} articles.`);
        const analysis = analyzeSentiment(articles);
        
        logInfo(`Analysis Result -> Score: ${analysis.score}, Signal: ${analysis.signal}`);
        pushToContract(analysis);
        
    } catch (error) {
        logError(`Cycle aborted: ${error.message}`);
    }
    logInfo("--- CYCLE COMPLETE ---");
}

// Ensure requirements are met
if (!NEWS_API_KEY || !PRIVATE_KEY || !CONTRACT_ADDRESS) {
    logError("Missing required environment variables. Please check .env file.");
    process.exit(1);
}

// Run immediately, then interval
runCycle();
setInterval(runCycle, INTERVAL_MS);
