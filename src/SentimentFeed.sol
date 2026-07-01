// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SentimentFeed — On-chain crypto sentiment storage
/// @notice Stores hourly sentiment snapshots pushed by an authorized agent
/// @dev Deployed on Ritual testnet (Chain ID 1979)
contract SentimentFeed {
    address public agent;

    struct HourlySnapshot {
        int8 score;            // -100 to +100
        string signal;         // BULLISH / BEARISH / NEUTRAL
        string riskLevel;      // LOW / MEDIUM / HIGH
        string summary;        // one-paragraph summary
        string[] topTokens;    // top mentioned tokens this hour
        string[] headlines;    // raw headlines (max 10 per hour)
        string[] headlineSources;
        string[] headlineSentiments; // bull/bear/neut per headline
        string[] headlineUrls; // full news URLs
        uint256 timestamp;
        uint256 headlineCount;
    }

    HourlySnapshot[] public history;
    mapping(uint256 => uint256) public hourIndexByTimestamp;

    event NewSnapshot(int8 score, string signal, uint256 timestamp, uint256 index);

    modifier onlyAgent() {
        require(msg.sender == agent, "not authorized agent");
        _;
    }

    constructor(address _agent) {
        agent = _agent;
    }

    function pushSnapshot(
        int8 _score,
        string calldata _signal,
        string calldata _riskLevel,
        string calldata _summary,
        string[] calldata _topTokens,
        string[] calldata _headlines,
        string[] calldata _headlineSources,
        string[] calldata _headlineSentiments,
        string[] calldata _headlineUrls
    ) external onlyAgent {
        HourlySnapshot storage snap = history.push();
        snap.score = _score;
        snap.signal = _signal;
        snap.riskLevel = _riskLevel;
        snap.summary = _summary;
        snap.topTokens = _topTokens;
        snap.headlines = _headlines;
        snap.headlineSources = _headlineSources;
        snap.headlineSentiments = _headlineSentiments;
        snap.headlineUrls = _headlineUrls;
        snap.timestamp = block.timestamp;
        snap.headlineCount = _headlines.length;

        emit NewSnapshot(_score, _signal, block.timestamp, history.length - 1);
    }

    function getLatest() external view returns (HourlySnapshot memory) {
        require(history.length > 0, "no data yet");
        return history[history.length - 1];
    }

    function getSnapshot(uint256 index) external view returns (HourlySnapshot memory) {
        return history[index];
    }

    function getRecentScores(uint256 n) external view returns (int8[] memory scores, uint256[] memory timestamps) {
        uint256 len = history.length;
        uint256 count = n > len ? len : n;
        scores = new int8[](count);
        timestamps = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            HourlySnapshot storage s = history[len - count + i];
            scores[i] = s.score;
            timestamps[i] = s.timestamp;
        }
    }

    function totalSnapshots() external view returns (uint256) {
        return history.length;
    }

    function setAgent(address _newAgent) external onlyAgent {
        agent = _newAgent;
    }
}
