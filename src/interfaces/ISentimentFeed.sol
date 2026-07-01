// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ISentimentFeed — Interface for the SentimentFeed storage contract
/// @notice Used by SentimentAgent to push hourly snapshots on-chain
interface ISentimentFeed {
    struct HourlySnapshot {
        int8 score;
        string signal;
        string riskLevel;
        string summary;
        string[] topTokens;
        string[] headlines;
        string[] headlineSources;
        string[] headlineSentiments;
        uint256 timestamp;
        uint256 headlineCount;
    }

    function pushSnapshot(
        int8 _score,
        string calldata _signal,
        string calldata _riskLevel,
        string calldata _summary,
        string[] calldata _topTokens,
        string[] calldata _headlines,
        string[] calldata _headlineSources,
        string[] calldata _headlineSentiments
    ) external;

    function getLatest() external view returns (HourlySnapshot memory);

    function getSnapshot(uint256 index) external view returns (HourlySnapshot memory);

    function getRecentScores(uint256 n) external view returns (int8[] memory scores, uint256[] memory timestamps);

    function totalSnapshots() external view returns (uint256);

    function setAgent(address _newAgent) external;

    function agent() external view returns (address);
}
