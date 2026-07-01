// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SentimentFeed} from "../src/SentimentFeed.sol";
import {SentimentAgent} from "../src/SentimentAgent.sol";
import {IScheduler} from "../src/interfaces/IScheduler.sol";

/// @title SentimentAgentTest — Unit tests for the sovereign agent
/// @dev Uses vm.mockCall to simulate Ritual precompile responses
contract SentimentAgentTest is Test {
    SentimentFeed public feed;
    SentimentAgent public agent;

    address constant HTTP_PRECOMPILE = address(0x0801);
    address constant LLM_PRECOMPILE = 0x0000000000000000000000000000000000000802;
    address constant SCHEDULER = 0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B;

    address deployer = address(0xDEAD);

    // Sample LLM response — valid JSON matching the expected schema
    string constant VALID_LLM_RESPONSE =
        '{"score": 42, "signal": "BULLISH", "riskLevel": "MEDIUM", '
        '"summary": "Bitcoin rallied above 70k as ETF inflows surged. Ethereum followed with strong DeFi volume.", '
        '"topTokens": ["BTC", "ETH", "SOL"], '
        '"headlineSentiments": ['
        '{"headline": "BTC breaks 70k as ETF inflows surge", "source": "CryptoPanic", "sentiment": "bull"},'
        '{"headline": "BTC breaks 70k as ETF inflows surge", "source": "CryptoCompare", "sentiment": "bull"},'
        '{"headline": "BTC breaks 70k as ETF inflows surge", "source": "NewsAPI", "sentiment": "bull"}'
        ']}';

    // Invalid LLM response (bad JSON)
    string constant INVALID_LLM_RESPONSE = "This is not valid JSON at all";

    // Sample HTTP responses
    string constant SAMPLE_HTTP_RESPONSE = '{"results": [{"title": "BTC breaks 70k as ETF inflows surge"}]}';

    string constant VALID_LLM_RESPONSE_SINGLE =
        '{"score": 42, "signal": "BULLISH", "riskLevel": "MEDIUM", '
        '"summary": "Bitcoin rallied above 70k as ETF inflows surged. Ethereum followed with strong DeFi volume.", '
        '"topTokens": ["BTC", "ETH", "SOL"], '
        '"headlineSentiments": ['
        '{"headline": "BTC breaks 70k as ETF inflows surge", "source": "CryptoPanic", "sentiment": "bull"}'
        ']}';

    function setUp() public {
        vm.startPrank(deployer);

        // Deploy SentimentFeed with deployer as initial agent
        feed = new SentimentFeed(deployer);

        // Deploy SentimentAgent
        agent = new SentimentAgent(
            address(feed),
            "https://cryptopanic.com/api/v1/posts/?auth_token=TEST&filter=hot&public=true",
            "https://min-api.cryptocompare.com/data/v2/news/?lang=EN",
            "https://newsapi.org/v2/everything?q=crypto&apiKey=TEST",
            "zai-org/GLM-4.7-FP8"
        );

        // Transfer feed agent role to the SentimentAgent
        feed.setAgent(address(agent));

        // Fund the agent
        vm.deal(address(agent), 10 ether);

        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════
    //                       HELPER: BUILD LLM RETURN
    // ═══════════════════════════════════════════════════════════════════

    /// @dev Build ABI-encoded LLM precompile return data
    function _buildLLMReturn(bool hasError, string memory responseText, string memory errorMsg)
        internal
        pure
        returns (bytes memory)
    {
        SentimentAgent.ConvoHistory memory convo = SentimentAgent.ConvoHistory("", "", "");
        return abi.encode(hasError, bytes(responseText), bytes(""), errorMsg, convo);
    }

    // ══════════════════════════════════════════════════════════════
    //                    SENTIMENTFEED TESTS
    // ══════════════════════════════════════════════════════════════

    function test_Feed_Constructor() public view {
        assertEq(feed.agent(), address(agent));
    }

    function test_Feed_PushSnapshot() public {
        vm.prank(address(agent));

        string[] memory topTokens = new string[](2);
        topTokens[0] = "BTC";
        topTokens[1] = "ETH";

        string[] memory headlines = new string[](1);
        headlines[0] = "Bitcoin breaks 70k";

        string[] memory sources = new string[](1);
        sources[0] = "CryptoPanic";

        string[] memory sentiments = new string[](1);
        sentiments[0] = "bull";

        string[] memory urls = new string[](1);
        urls[0] = "url";

        feed.pushSnapshot(
            80,
            "BULLISH",
            "LOW",
            "Market is booming",
            topTokens,
            headlines,
            sources,
            sentiments,
            urls
        );

        assertEq(feed.totalSnapshots(), 1);
    }

    function test_Feed_RejectsUnauthorized() public {
        vm.prank(address(0xBAD));

        string[] memory empty = new string[](0);

        vm.expectRevert("not authorized agent");
        feed.pushSnapshot(0, "NEUTRAL", "LOW", "test", empty, empty, empty, empty, empty);
    }

    function test_Feed_GetLatest() public {
        vm.prank(address(agent));

        string[] memory topTokens = new string[](1);
        topTokens[0] = "BTC";

        string[] memory headlines = new string[](1);
        headlines[0] = "Test headline";

        string[] memory sources = new string[](1);
        sources[0] = "TestSource";

        string[] memory sentiments = new string[](1);
        sentiments[0] = "neut";

        string[] memory urls = new string[](1);
        urls[0] = "url";

        feed.pushSnapshot(-10, "BEARISH", "HIGH", "Market down", topTokens, headlines, sources, sentiments, urls);

        SentimentFeed.HourlySnapshot memory snap = feed.getLatest();
        assertEq(snap.score, -10);
        assertEq(keccak256(bytes(snap.signal)), keccak256(bytes("BEARISH")));
        assertEq(keccak256(bytes(snap.riskLevel)), keccak256(bytes("HIGH")));
        assertEq(snap.headlineCount, 1);
    }

    function test_Feed_GetLatest_RevertsEmpty() public {
        vm.expectRevert("no data yet");
        feed.getLatest();
    }

    function test_Feed_GetRecentScores() public {
        vm.startPrank(address(agent));

        string[] memory empty = new string[](0);

        // Push 3 snapshots
        feed.pushSnapshot(10, "BULLISH", "LOW", "s1", empty, empty, empty, empty, empty);
        feed.pushSnapshot(-20, "BEARISH", "HIGH", "s2", empty, empty, empty, empty, empty);
        feed.pushSnapshot(50, "BULLISH", "LOW", "s3", empty, empty, empty, empty, empty);

        vm.stopPrank();

        (int8[] memory scores, uint256[] memory timestamps) = feed.getRecentScores(2);
        assertEq(scores.length, 2);
        assertEq(scores[0], -20);
        assertEq(scores[1], 50);
        assertTrue(timestamps[0] > 0);
        assertTrue(timestamps[1] > 0);
    }

    function test_Feed_GetRecentScores_MoreThanAvailable() public {
        vm.prank(address(agent));
        string[] memory empty = new string[](0);
        feed.pushSnapshot(10, "BULLISH", "LOW", "s1", empty, empty, empty, empty, empty);

        (int8[] memory scores,) = feed.getRecentScores(100);
        assertEq(scores.length, 1);
        assertEq(scores[0], 10);
    }

    // ══════════════════════════════════════════════════════════════
    //                   SENTIMENTAGENT TESTS
    // ══════════════════════════════════════════════════════════════

    function test_Agent_Constructor() public view {
        assertEq(agent.owner(), deployer);
        assertEq(address(agent.sentimentFeed()), address(feed));
        assertFalse(agent.isActive());
        assertEq(agent.cycleCount(), 0);
    }

    function test_Agent_StartAgent() public {
        // Mock the Scheduler.schedule call
        vm.mockCall(
            SCHEDULER,
            abi.encodeWithSelector(IScheduler.schedule.selector),
            abi.encode(uint256(1))
        );

        vm.prank(deployer);
        agent.startAgent();

        assertTrue(agent.isActive());
        assertEq(agent.lastScheduleId(), 1);
    }

    function test_Agent_StartAgent_RejectsNonOwner() public {
        vm.prank(address(0xBAD));
        vm.expectRevert("SentimentAgent: not owner");
        agent.startAgent();
    }

    function test_Agent_StartAgent_RejectsDouble() public {
        vm.mockCall(
            SCHEDULER,
            abi.encodeWithSelector(IScheduler.schedule.selector),
            abi.encode(uint256(1))
        );

        vm.startPrank(deployer);
        agent.startAgent();

        vm.expectRevert("SentimentAgent: already active");
        agent.startAgent();
        vm.stopPrank();
    }

    function test_Agent_StopAgent() public {
        vm.mockCall(
            SCHEDULER,
            abi.encodeWithSelector(IScheduler.schedule.selector),
            abi.encode(uint256(1))
        );

        vm.startPrank(deployer);
        agent.startAgent();
        assertTrue(agent.isActive());

        agent.stopAgent();
        assertFalse(agent.isActive());
        vm.stopPrank();
    }

    function test_Agent_RunCycle_Success() public {
        _activateAgent();

        // Mock HTTP precompile — return sample news for all 3 sources
        vm.mockCall(
            HTTP_PRECOMPILE,
            bytes(""),  // match any call
            abi.encode(bytes(SAMPLE_HTTP_RESPONSE))
        );

        // Build a valid LLM response with proper ABI encoding
        bytes memory llmReturn = _buildLLMReturn(false, VALID_LLM_RESPONSE_SINGLE, "");
        vm.mockCall(LLM_PRECOMPILE, bytes(""), llmReturn);

        // Mock scheduler
        vm.mockCall(
            SCHEDULER,
            abi.encodeWithSelector(IScheduler.schedule.selector),
            abi.encode(uint256(42))
        );

        vm.prank(deployer);
        agent.runCycle(0);

        assertEq(agent.cycleCount(), 1);
        assertEq(agent.lastScheduleId(), 42);
        assertEq(feed.totalSnapshots(), 1);

        // Verify the snapshot was written correctly
        SentimentFeed.HourlySnapshot memory snap = feed.getLatest();
        assertEq(snap.score, 42);
        assertEq(keccak256(bytes(snap.signal)), keccak256(bytes("BULLISH")));
        assertEq(keccak256(bytes(snap.riskLevel)), keccak256(bytes("MEDIUM")));
    }

    function test_Agent_RunCycle_AllSourcesFail_SkipsButReschedules() public {
        _activateAgent();

        // Mock HTTP precompile to fail (return false)
        vm.mockCallRevert(HTTP_PRECOMPILE, bytes(""), bytes("HTTP failed"));

        // Mock scheduler — should still be called for reschedule
        vm.mockCall(
            SCHEDULER,
            abi.encodeWithSelector(IScheduler.schedule.selector),
            abi.encode(uint256(99))
        );

        vm.prank(deployer);
        agent.runCycle(0);

        // Cycle skipped but rescheduled
        assertEq(agent.cycleCount(), 1);
        assertEq(agent.lastScheduleId(), 99);
        assertEq(feed.totalSnapshots(), 0);  // No snapshot written
    }

    function test_Agent_RunCycle_LLMFails_RetriesAndSkips() public {
        _activateAgent();

        // Mock HTTP success
        vm.mockCall(
            HTTP_PRECOMPILE,
            bytes(""),
            abi.encode(bytes(SAMPLE_HTTP_RESPONSE))
        );

        // Mock LLM to return invalid response (hasError = true)
        bytes memory llmError = _buildLLMReturn(true, "", "model error");
        vm.mockCall(LLM_PRECOMPILE, bytes(""), llmError);

        // Mock scheduler
        vm.mockCall(
            SCHEDULER,
            abi.encodeWithSelector(IScheduler.schedule.selector),
            abi.encode(uint256(77))
        );

        vm.prank(deployer);
        agent.runCycle(0);

        // Should skip but still reschedule
        assertEq(agent.cycleCount(), 1);
        assertEq(agent.lastScheduleId(), 77);
        assertEq(feed.totalSnapshots(), 0);
    }

    function test_Agent_RunCycle_RejectsUnauthorized() public {
        vm.prank(address(0xBAD));
        vm.expectRevert("SentimentAgent: unauthorized");
        agent.runCycle(0);
    }

    // ══════════════════════════════════════════════════════════════
    //                     ADMIN FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════

    function test_Agent_SetUrls() public {
        vm.startPrank(deployer);

        agent.setCryptoPanicUrl("https://new-url.com/1");
        agent.setCryptoCompareUrl("https://new-url.com/2");
        agent.setNewsApiUrl("https://new-url.com/3");

        assertEq(keccak256(bytes(agent.cryptoPanicUrl())), keccak256(bytes("https://new-url.com/1")));
        assertEq(keccak256(bytes(agent.cryptoCompareUrl())), keccak256(bytes("https://new-url.com/2")));
        assertEq(keccak256(bytes(agent.newsApiUrl())), keccak256(bytes("https://new-url.com/3")));

        vm.stopPrank();
    }

    function test_Agent_SetLlmModel() public {
        vm.prank(deployer);
        agent.setLlmModel("new-model/v2");
        assertEq(keccak256(bytes(agent.llmModel())), keccak256(bytes("new-model/v2")));
    }

    function test_Agent_TransferOwnership() public {
        address newOwner = address(0xBEEF);

        vm.prank(deployer);
        agent.transferOwnership(newOwner);

        assertEq(agent.owner(), newOwner);
    }

    function test_Agent_TransferOwnership_RejectsZero() public {
        vm.prank(deployer);
        vm.expectRevert("SentimentAgent: zero address");
        agent.transferOwnership(address(0));
    }

    function test_Agent_WithdrawFunds() public {
        address payable recipient = payable(address(0xCAFE));
        uint256 initialBalance = address(agent).balance;

        vm.prank(deployer);
        agent.withdrawFunds(recipient, 1 ether);

        assertEq(recipient.balance, 1 ether);
        assertEq(address(agent).balance, initialBalance - 1 ether);
    }

    function test_Agent_GetStatus() public view {
        (
            bool active,
            uint256 cycles,
            uint256 lastSchedule,
            uint256 feedSnapshots,
            uint256 balance
        ) = agent.getStatus();

        assertFalse(active);
        assertEq(cycles, 0);
        assertEq(lastSchedule, 0);
        assertEq(feedSnapshots, 0);
        assertEq(balance, 10 ether);
    }

    // ══════════════════════════════════════════════════════════════
    //                  MULTIPLE CYCLE SIMULATION
    // ══════════════════════════════════════════════════════════════

    function test_Agent_MultipleCycles() public {
        _activateAgent();

        // Mock all precompiles
        vm.mockCall(HTTP_PRECOMPILE, bytes(""), abi.encode(bytes(SAMPLE_HTTP_RESPONSE)));

        bytes memory llmReturn = _buildLLMReturn(false, VALID_LLM_RESPONSE_SINGLE, "");
        vm.mockCall(LLM_PRECOMPILE, bytes(""), llmReturn);

        vm.mockCall(
            SCHEDULER,
            abi.encodeWithSelector(IScheduler.schedule.selector),
            abi.encode(uint256(1))
        );

        // Run 3 cycles
        vm.startPrank(deployer);
        agent.runCycle(0);
        agent.runCycle(0);
        agent.runCycle(0);
        vm.stopPrank();

        assertEq(agent.cycleCount(), 3);
        assertEq(feed.totalSnapshots(), 3);

        // Verify all snapshots are accessible
        for (uint256 i = 0; i < 3; i++) {
            SentimentFeed.HourlySnapshot memory snap = feed.getSnapshot(i);
            assertEq(snap.score, 42);
        }
    }

    function _activateAgent() internal {
        vm.mockCall(
            SCHEDULER,
            abi.encodeWithSelector(IScheduler.schedule.selector),
            abi.encode(uint256(123))
        );

        vm.prank(deployer);
        agent.startAgent();
    }
}
