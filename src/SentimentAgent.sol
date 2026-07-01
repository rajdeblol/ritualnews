// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IScheduler} from "./interfaces/IScheduler.sol";
import {ISentimentFeed} from "./interfaces/ISentimentFeed.sol";

contract SentimentAgent {
    struct ConvoHistory {
        string platform;
        string path;
        string keyRef;
    }

    struct LLMEnvelope {
        bool hasError;
        bytes response;
        bytes proof;
        string error;
        ConvoHistory convoHistory;
    }

    struct HeadlineSentiment {
        string headline;
        string source;
        string sentiment;
    }

    address constant HTTP_PRECOMPILE = address(0x0801);
    address constant LLM_PRECOMPILE = 0x0000000000000000000000000000000000000802;
    IScheduler constant SCHEDULER = IScheduler(0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B);

    uint256 public constant CYCLE_INTERVAL = 3600;
    uint256 public constant BLOCKS_PER_HOUR = 300;
    uint256 public constant CYCLE_GAS_LIMIT = 1_200_000;
    uint256 public constant MAX_HEADLINES = 15;
    uint256 public constant MAX_HEADLINES_PER_SOURCE = 5;
    uint256 public constant MAX_LLM_RETRIES = 1;
    uint256 public constant SCHEDULE_TTL_BLOCKS = 100;

    ISentimentFeed public sentimentFeed;
    address public owner;
    uint256 public cycleCount;
    uint256 public lastScheduleId;
    string public cryptoPanicUrl;
    string public cryptoCompareUrl;
    string public newsApiUrl;
    string public llmModel;
    bool public isActive;

    uint256 public cycleState; // 0 = fetch, 1 = analyze
    string[] public currentHeadlines;
    string[] public currentSources;

    event CycleCompleted(uint256 indexed cycle, int8 score, string signal, uint256 timestamp);
    event CycleSkipped(uint256 indexed cycle, string reason);
    event Rescheduled(uint256 scheduleId, uint256 targetBlock);
    event SourceFetched(string indexed source, uint256 headlineCount);
    event SourceFailed(string indexed source);
    event LLMRetry(uint256 indexed cycle, uint256 attempt);
    event AgentStarted(uint256 initialScheduleId);
    event AgentStopped();

    modifier onlyOwner() {
        require(msg.sender == owner, "SentimentAgent: not owner");
        _;
    }

    modifier onlyOwnerOrScheduler() {
        require(
            msg.sender == owner || msg.sender == address(SCHEDULER) || msg.sender == address(this),
            "SentimentAgent: unauthorized"
        );
        _;
    }

    constructor(
        address _sentimentFeed,
        string memory _cryptoPanicUrl,
        string memory _cryptoCompareUrl,
        string memory _newsApiUrl,
        string memory _llmModel
    ) {
        owner = msg.sender;
        sentimentFeed = ISentimentFeed(_sentimentFeed);
        cryptoPanicUrl = _cryptoPanicUrl;
        cryptoCompareUrl = _cryptoCompareUrl;
        newsApiUrl = _newsApiUrl;
        llmModel = _llmModel;
    }

    receive() external payable {
        address RITUAL_WALLET = 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948;
        (bool success, ) = RITUAL_WALLET.call{value: msg.value}(abi.encodeWithSignature("deposit(uint256)", 50000));
        require(success, "RitualWallet deposit failed");
    }

    function runCycle(uint256 executionIndex) external onlyOwnerOrScheduler {
        if (cycleState == 0) {
            cycleCount++;
            uint256 currentCycle = cycleCount;

            (string[] memory headlines, string[] memory sources, bool anySourceSucceeded) = _fetchAllNews();

            if (!anySourceSucceeded || headlines.length == 0) {
                emit CycleSkipped(currentCycle, "all news sources failed or returned 0 headlines");
                _reschedule(BLOCKS_PER_HOUR);
                return;
            }

            delete currentHeadlines;
            delete currentSources;
            for (uint i = 0; i < headlines.length; i++) {
                currentHeadlines.push(headlines[i]);
                currentSources.push(sources[i]);
            }
            cycleState = 1;

            _reschedule(1); // schedule analysis for next block
        } else {
            uint256 currentCycle = cycleCount;
            
            (
                bool llmSuccess,
                int8 score,
                string memory signal,
                string memory riskLevel,
                string memory summary,
                string[] memory topTokens,
                string[] memory headlineSentiments
            ) = _analyzeWithLLM(currentHeadlines, currentSources, false);

            if (!llmSuccess) {
                emit LLMRetry(currentCycle, 1);
                (
                    llmSuccess,
                    score,
                    signal,
                    riskLevel,
                    summary,
                    topTokens,
                    headlineSentiments
                ) = _analyzeWithLLM(currentHeadlines, currentSources, true);
            }

            if (!llmSuccess) {
                emit CycleSkipped(currentCycle, "LLM analysis failed after retry");
            } else {
                require(score >= -100 && score <= 100, "score out of range");
                sentimentFeed.pushSnapshot(score, signal, riskLevel, summary, topTokens, currentHeadlines, currentSources, headlineSentiments);
                emit CycleCompleted(currentCycle, score, signal, block.timestamp);
            }
            
            delete currentHeadlines;
            delete currentSources;
            cycleState = 0;
            
            _reschedule(BLOCKS_PER_HOUR);
        }
    }

    function _fetchAllNews()
        internal
        returns (string[] memory headlines, string[] memory sources, bool anySuccess)
    {
        string[] memory workingHeadlines = new string[](MAX_HEADLINES);
        string[] memory workingSources = new string[](MAX_HEADLINES);
        uint256 totalCount;

        totalCount = _appendSourceHeadlines(
            newsApiUrl,
            "NewsAPI",
            workingHeadlines,
            workingSources,
            totalCount,
            anySuccess
        );
        anySuccess = anySuccess || totalCount > 0;

        headlines = _trimArray(workingHeadlines, totalCount);
        sources = _trimArray(workingSources, totalCount);
    }

    function _appendSourceHeadlines(
        string memory url,
        string memory sourceName,
        string[] memory allHeadlines,
        string[] memory allSources,
        uint256 totalCount,
        bool /* anySuccess */
    ) internal returns (uint256) {
        (bool success, string[] memory parsedHeadlines) = _fetchFromSource(url, sourceName);
        if (!success || parsedHeadlines.length == 0) {
            return totalCount;
        }

        uint256 addedCount;
        for (uint256 i = 0; i < parsedHeadlines.length && totalCount < MAX_HEADLINES; i++) {
            if (_isDuplicateHeadline(allHeadlines, totalCount, parsedHeadlines[i])) {
                continue;
            }
            allHeadlines[totalCount] = parsedHeadlines[i];
            allSources[totalCount] = sourceName;
            totalCount++;
            addedCount++;
        }

        if (addedCount > 0) {
            emit SourceFetched(sourceName, addedCount);
        } else {
            emit SourceFailed(sourceName);
        }

        return totalCount;
    }

    function _fetchFromSource(string memory url, string memory sourceName)
        internal
        returns (bool success, string[] memory headlines)
    {
        string[] memory headerKeys = new string[](2);
        string[] memory headerValues = new string[](2);
        headerKeys[0] = "Accept";
        headerValues[0] = "application/json";
        headerKeys[1] = "User-Agent";
        headerValues[1] = "RitualSentimentAgent/1.0";

        bytes memory payload = abi.encode(url, "GET", headerKeys, headerValues, bytes(""));
        (bool callSuccess, bytes memory response) = HTTP_PRECOMPILE.staticcall(payload);
        if (!callSuccess || response.length == 0) {
            emit SourceFailed(sourceName);
            return (false, new string[](0));
        }

        bytes memory body = _decodeHttpBody(response);
        if (body.length == 0) {
            body = response;
        }

        headlines = _extractHeadlinesFromJson(body, sourceName);
        success = headlines.length > 0;
        if (!success) {
            emit SourceFailed(sourceName);
        }
    }

    function _analyzeWithLLM(string[] memory headlines, string[] memory sources, bool strictMode)
        internal
        view
        returns (
            bool success,
            int8 score,
            string memory signal,
            string memory riskLevel,
            string memory summary,
            string[] memory topTokens,
            string[] memory headlineSentiments
        )
    {
        string memory prompt = _buildPrompt(headlines, sources, strictMode);
        bytes memory payload = _buildLLMPayload(prompt);
        (bool callSuccess, bytes memory response) = LLM_PRECOMPILE.staticcall(payload);
        if (!callSuccess || response.length == 0) {
            return (false, 0, "", "", "", new string[](0), new string[](0));
        }

        string memory llmText = _decodeLLMResponse(response);
        return _parseLLMResponse(llmText, headlines, sources);
    }

    function _buildPrompt(string[] memory headlines, string[] memory sources, bool strictMode)
        internal
        pure
        returns (string memory)
    {
        string memory headlinesJson = _buildHeadlinesJson(headlines, sources);
        string memory base = string.concat(
            "Given these crypto news headlines: ",
            headlinesJson,
            " Return ONLY valid JSON with this exact shape: ",
            '{',
            '"score": <int -100 to 100>,',
            '"signal": "BULLISH" | "BEARISH" | "NEUTRAL",',
            '"riskLevel": "LOW" | "MEDIUM" | "HIGH",',
            '"summary": "<2-3 sentence summary, no markdown>",',
            '"topTokens": ["BTC","ETH"] (max 5, most mentioned),',
            '"headlineSentiments": [',
            '{"headline": "...", "source": "...", "sentiment": "bull"|"bear"|"neut"}',
            ']',
            '}'
        );

        if (!strictMode) {
            return base;
        }

        return string.concat(
            base,
            " No prose, no code fences, no explanation, no trailing characters. Every headlineSentiments item must correspond to one provided headline."
        );
    }

    function _buildHeadlinesJson(string[] memory headlines, string[] memory sources)
        internal
        pure
        returns (string memory)
    {
        bytes memory out = "[";
        for (uint256 i = 0; i < headlines.length; i++) {
            if (i > 0) {
                out = abi.encodePacked(out, ",");
            }
            out = abi.encodePacked(
                out,
                '{"headline":"',
                _escapeJson(headlines[i]),
                '","source":"',
                _escapeJson(sources[i]),
                '"}'
            );
        }
        out = abi.encodePacked(out, "]");
        return string(out);
    }

    function _buildLLMPayload(string memory prompt) internal view returns (bytes memory) {
        string memory messagesJson = string.concat(
            '[{"role":"system","content":"You are a crypto sentiment analyst. Output strict JSON only."},',
            '{"role":"user","content":"',
            _escapeJson(prompt),
            '"}]'
        );
        return abi.encode(messagesJson, llmModel, int256(700), uint256(2048), false);
    }

    function _parseLLMResponse(
        string memory response,
        string[] memory headlines,
        string[] memory sources
    )
        internal
        pure
        returns (
            bool success,
            int8 score,
            string memory signal,
            string memory riskLevel,
            string memory summary,
            string[] memory topTokens,
            string[] memory headlineSentiments
        )
    {
        bytes memory responseBytes = _sliceJsonObject(bytes(response));
        if (responseBytes.length == 0) {
            return (false, 0, "", "", "", new string[](0), new string[](0));
        }

        (bool scoreFound, int8 parsedScore) = _extractScore(responseBytes);
        if (!scoreFound || parsedScore < -100 || parsedScore > 100) {
            return (false, 0, "", "", "", new string[](0), new string[](0));
        }

        string memory parsedSignal = _extractStringField(responseBytes, '"signal"');
        if (!_isValidSignal(parsedSignal)) {
            return (false, 0, "", "", "", new string[](0), new string[](0));
        }

        string memory parsedRisk = _extractStringField(responseBytes, '"riskLevel"');
        if (!_isValidRisk(parsedRisk)) {
            return (false, 0, "", "", "", new string[](0), new string[](0));
        }

        string memory parsedSummary = _extractStringField(responseBytes, '"summary"');
        if (bytes(parsedSummary).length == 0) {
            return (false, 0, "", "", "", new string[](0), new string[](0));
        }

        topTokens = _extractStringArrayField(responseBytes, '"topTokens"', 5);
        if (topTokens.length == 0) {
            return (false, 0, "", "", "", new string[](0), new string[](0));
        }

        headlineSentiments = _extractHeadlineSentiments(responseBytes, headlines, sources);
        if (headlineSentiments.length != headlines.length) {
            return (false, 0, "", "", "", new string[](0), new string[](0));
        }

        return (true, parsedScore, parsedSignal, parsedRisk, parsedSummary, topTokens, headlineSentiments);
    }

    function _reschedule(uint256 delayBlocks) internal {
        if (!isActive) {
            return;
        }

        bytes memory callData = abi.encodeWithSelector(this.runCycle.selector, uint256(0));
        uint32 targetBlock = uint32(block.number) + uint32(delayBlocks);
        lastScheduleId = SCHEDULER.schedule(
            callData,
            uint32(CYCLE_GAS_LIMIT),
            targetBlock,
            1,
            uint32(SCHEDULE_TTL_BLOCKS), // frequency
            uint32(SCHEDULE_TTL_BLOCKS), // ttl
            tx.gasprice, // maxFeePerGas
            0,
            0,
            address(this)
        );

        emit Rescheduled(lastScheduleId, targetBlock);
    }

    function startAgent() external onlyOwner {
        require(!isActive, "SentimentAgent: already active");
        isActive = true;
        _reschedule(1);
        emit AgentStarted(lastScheduleId);
    }

    function stopAgent() external onlyOwner {
        isActive = false;
        emit AgentStopped();
    }

    function setCryptoPanicUrl(string calldata _url) external onlyOwner { cryptoPanicUrl = _url; }
    function setCryptoCompareUrl(string calldata _url) external onlyOwner { cryptoCompareUrl = _url; }
    function setNewsApiUrl(string calldata _url) external onlyOwner { newsApiUrl = _url; }
    function setLlmModel(string calldata _model) external onlyOwner { llmModel = _model; }
    function setSentimentFeed(address _feed) external onlyOwner { sentimentFeed = ISentimentFeed(_feed); }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "SentimentAgent: zero address");
        owner = _newOwner;
    }

    function withdrawFunds(address payable _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "SentimentAgent: zero address");
        (bool sent,) = _to.call{value: _amount}("");
        require(sent, "SentimentAgent: withdraw failed");
    }

    function getStatus()
        external
        view
        returns (bool active, uint256 cycles, uint256 lastSchedule, uint256 feedSnapshots, uint256 balance)
    {
        return (isActive, cycleCount, lastScheduleId, sentimentFeed.totalSnapshots(), address(this).balance);
    }

    function _trimArray(string[] memory arr, uint256 len) internal pure returns (string[] memory trimmed) {
        trimmed = new string[](len);
        for (uint256 i = 0; i < len; i++) {
            trimmed[i] = arr[i];
        }
    }

    function _escapeJson(string memory input) internal pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        uint256 extraChars;
        for (uint256 i = 0; i < inputBytes.length; i++) {
            bytes1 ch = inputBytes[i];
            if (ch == '"' || ch == '\\') {
                extraChars++;
            }
        }
        if (extraChars == 0) return input;

        bytes memory output = new bytes(inputBytes.length + extraChars);
        uint256 j;
        for (uint256 i = 0; i < inputBytes.length; i++) {
            bytes1 ch = inputBytes[i];
            if (ch == '"' || ch == '\\') {
                output[j++] = '\\';
            }
            output[j++] = ch;
        }
        return string(output);
    }

    function _decodeHttpBody(bytes memory response) internal view returns (bytes memory body) {
        if (response.length > 0 && response[0] == '{') {
            return response;
        }
        if (response.length > 0 && response[0] == '[') {
            return response;
        }

        try this.__decodeBytes(response) returns (bytes memory decoded) {
            return decoded;
        } catch {
            return bytes("");
        }
    }

    function __decodeBytes(bytes memory data) external view returns (bytes memory) {
        require(msg.sender == address(this), "self only");
        return abi.decode(data, (bytes));
    }

    function _decodeLLMResponse(bytes memory response) internal view returns (string memory) {
        if (response.length == 0) {
            return "";
        }

        if (response[0] == '{') {
            return string(response);
        }

        try this.__decodeLlmEnvelope(response) returns (bool hasError, string memory text, string memory err) {
            if (hasError || bytes(text).length == 0) {
                return err;
            }
            return text;
        } catch {
            return string(response);
        }
    }

    function __decodeLlmEnvelope(bytes memory data) external view returns (bool, string memory, string memory) {
        require(msg.sender == address(this), "self only");
        LLMEnvelope memory env = abi.decode(data, (LLMEnvelope));
        return (env.hasError, string(env.response), env.error);
    }

    function _extractHeadlinesFromJson(bytes memory body, string memory sourceName)
        internal
        pure
        returns (string[] memory)
    {
        bytes memory key = _headlineKeyForSource(sourceName);
        uint256 searchFrom;
        string[] memory found = new string[](MAX_HEADLINES_PER_SOURCE);
        uint256 count;

        while (count < MAX_HEADLINES_PER_SOURCE) {
            uint256 keyPos = _findBytes(body, key, searchFrom);
            if (keyPos == type(uint256).max) {
                break;
            }
            string memory headline = _extractQuotedValueAfterKey(body, keyPos + key.length);
            if (bytes(headline).length > 0) {
                found[count] = headline;
                count++;
            }
            searchFrom = keyPos + key.length;
        }

        return _trimArray(found, count);
    }

    function _headlineKeyForSource(string memory sourceName) internal pure returns (bytes memory) {
        bytes32 sourceHash = keccak256(bytes(sourceName));
        if (sourceHash == keccak256("CryptoPanic")) {
            return bytes('"title"');
        }
        if (sourceHash == keccak256("CryptoCompare")) {
            return bytes('"title"');
        }
        return bytes('"title"');
    }

    function _extractQuotedValueAfterKey(bytes memory data, uint256 start) internal pure returns (string memory) {
        uint256 colonPos = _findByte(data, ':', start);
        if (colonPos == type(uint256).max) return "";
        uint256 openQuote = _findByte(data, '"', colonPos + 1);
        if (openQuote == type(uint256).max) return "";

        bytes memory out = new bytes(data.length - openQuote - 1);
        uint256 len;
        bool escaped;
        for (uint256 i = openQuote + 1; i < data.length; i++) {
            bytes1 ch = data[i];
            if (escaped) {
                out[len++] = ch;
                escaped = false;
                continue;
            }
            if (ch == '\\') {
                escaped = true;
                continue;
            }
            if (ch == '"') {
                break;
            }
            out[len++] = ch;
        }

        bytes memory trimmed = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            trimmed[i] = out[i];
        }
        return string(trimmed);
    }

    function _extractStringArrayField(bytes memory data, bytes memory key, uint256 maxItems)
        internal
        pure
        returns (string[] memory)
    {
        uint256 keyPos = _findBytes(data, key, 0);
        if (keyPos == type(uint256).max) return new string[](0);
        uint256 colonPos = _findByte(data, ':', keyPos + key.length);
        if (colonPos == type(uint256).max) return new string[](0);
        uint256 openBracket = _findByte(data, '[', colonPos + 1);
        if (openBracket == type(uint256).max) return new string[](0);
        uint256 closeBracket = _findMatchingBracket(data, openBracket);
        if (closeBracket == type(uint256).max) return new string[](0);

        string[] memory items = new string[](maxItems);
        uint256 count;
        uint256 cursor = openBracket + 1;
        while (cursor < closeBracket && count < maxItems) {
            uint256 openQuote = _findByte(data, '"', cursor);
            if (openQuote == type(uint256).max || openQuote >= closeBracket) break;
            uint256 endQuote = _findStringEnd(data, openQuote + 1);
            if (endQuote == type(uint256).max || endQuote > closeBracket) break;
            bytes memory value = new bytes(endQuote - openQuote - 1);
            for (uint256 i = 0; i < value.length; i++) {
                value[i] = data[openQuote + 1 + i];
            }
            items[count] = string(value);
            count++;
            cursor = endQuote + 1;
        }

        return _trimArray(items, count);
    }

    function _extractHeadlineSentiments(bytes memory data, string[] memory headlines, string[] memory sources)
        internal
        pure
        returns (string[] memory sentiments)
    {
        uint256 keyPos = _findBytes(data, bytes('"headlineSentiments"'), 0);
        if (keyPos == type(uint256).max) return new string[](0);
        uint256 colonPos = _findByte(data, ':', keyPos + bytes('"headlineSentiments"').length);
        if (colonPos == type(uint256).max) return new string[](0);
        uint256 openBracket = _findByte(data, '[', colonPos + 1);
        if (openBracket == type(uint256).max) return new string[](0);
        uint256 closeBracket = _findMatchingBracket(data, openBracket);
        if (closeBracket == type(uint256).max) return new string[](0);

        sentiments = new string[](headlines.length);
        uint256 cursor = openBracket + 1;
        uint256 matchedCount;
        while (cursor < closeBracket) {
            uint256 objOpen = _findByte(data, '{', cursor);
            if (objOpen == type(uint256).max || objOpen >= closeBracket) break;
            uint256 objClose = _findMatchingBrace(data, objOpen);
            if (objClose == type(uint256).max || objClose > closeBracket) break;

            bytes memory entry = _sliceBytes(data, objOpen, objClose + 1);
            string memory headline = _extractStringField(entry, bytes('"headline"'));
            string memory source = _extractStringField(entry, bytes('"source"'));
            string memory sentiment = _extractStringField(entry, bytes('"sentiment"'));

            if (!_isValidHeadlineSentiment(sentiment)) {
                return new string[](0);
            }

            bool matched;
            for (uint256 i = 0; i < headlines.length; i++) {
                if (
                    keccak256(bytes(headlines[i])) == keccak256(bytes(headline))
                        && keccak256(bytes(sources[i])) == keccak256(bytes(source))
                        && bytes(sentiments[i]).length == 0
                ) {
                    sentiments[i] = sentiment;
                    matched = true;
                    matchedCount++;
                    break;
                }
            }

            if (!matched) {
                return new string[](0);
            }

            cursor = objClose + 1;
        }

        if (matchedCount != headlines.length) {
            return new string[](0);
        }
    }

    function _sliceJsonObject(bytes memory data) internal pure returns (bytes memory) {
        uint256 start;
        while (start < data.length && data[start] != '{') {
            start++;
        }
        if (start == data.length) return bytes("");

        uint256 depth;
        bool inString;
        bool escaped;
        for (uint256 i = start; i < data.length; i++) {
            bytes1 ch = data[i];
            if (inString) {
                if (escaped) {
                    escaped = false;
                } else if (ch == '\\') {
                    escaped = true;
                } else if (ch == '"') {
                    inString = false;
                }
                continue;
            }

            if (ch == '"') {
                inString = true;
            } else if (ch == '{') {
                depth++;
            } else if (ch == '}') {
                depth--;
                if (depth == 0) {
                    return _sliceBytes(data, start, i + 1);
                }
            }
        }
        return bytes("");
    }

    function _sliceBytes(bytes memory data, uint256 start, uint256 end) internal pure returns (bytes memory out) {
        out = new bytes(end - start);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = data[start + i];
        }
    }

    function _extractScore(bytes memory data) internal pure returns (bool found, int8 score) {
        bytes memory scoreKey = bytes('"score"');
        uint256 keyPos = _findBytes(data, scoreKey, 0);
        if (keyPos == type(uint256).max) return (false, 0);
        uint256 colonPos = _findByte(data, ':', keyPos + scoreKey.length);
        if (colonPos == type(uint256).max) return (false, 0);
        return _parseInt8(data, colonPos + 1);
    }

    function _extractStringField(bytes memory data, bytes memory key) internal pure returns (string memory) {
        uint256 keyPos = _findBytes(data, key, 0);
        if (keyPos == type(uint256).max) return "";
        uint256 colonPos = _findByte(data, ':', keyPos + key.length);
        if (colonPos == type(uint256).max) return "";
        uint256 openQuote = _findByte(data, '"', colonPos + 1);
        if (openQuote == type(uint256).max) return "";
        uint256 closeQuote = _findStringEnd(data, openQuote + 1);
        if (closeQuote == type(uint256).max) return "";

        bytes memory value = new bytes(closeQuote - openQuote - 1);
        for (uint256 i = 0; i < value.length; i++) {
            value[i] = data[openQuote + 1 + i];
        }
        return string(value);
    }

    function _isValidSignal(string memory s) internal pure returns (bool) {
        bytes32 h = keccak256(bytes(s));
        return h == keccak256("BULLISH") || h == keccak256("BEARISH") || h == keccak256("NEUTRAL");
    }

    function _isValidRisk(string memory s) internal pure returns (bool) {
        bytes32 h = keccak256(bytes(s));
        return h == keccak256("LOW") || h == keccak256("MEDIUM") || h == keccak256("HIGH");
    }

    function _isValidHeadlineSentiment(string memory s) internal pure returns (bool) {
        bytes32 h = keccak256(bytes(s));
        return h == keccak256("bull") || h == keccak256("bear") || h == keccak256("neut");
    }

    function _findBytes(bytes memory data, bytes memory target, uint256 start) internal pure returns (uint256) {
        if (target.length == 0 || data.length < target.length + start) return type(uint256).max;
        for (uint256 i = start; i <= data.length - target.length; i++) {
            bool matched = true;
            for (uint256 j = 0; j < target.length; j++) {
                if (data[i + j] != target[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) return i;
        }
        return type(uint256).max;
    }

    function _findByte(bytes memory data, bytes1 target, uint256 start) internal pure returns (uint256) {
        for (uint256 i = start; i < data.length; i++) {
            if (data[i] == target) {
                return i;
            }
        }
        return type(uint256).max;
    }

    function _findStringEnd(bytes memory data, uint256 start) internal pure returns (uint256) {
        bool escaped;
        for (uint256 i = start; i < data.length; i++) {
            if (escaped) {
                escaped = false;
                continue;
            }
            if (data[i] == '\\') {
                escaped = true;
                continue;
            }
            if (data[i] == '"') {
                return i;
            }
        }
        return type(uint256).max;
    }

    function _findMatchingBracket(bytes memory data, uint256 openPos) internal pure returns (uint256) {
        uint256 depth;
        bool inString;
        bool escaped;
        for (uint256 i = openPos; i < data.length; i++) {
            bytes1 ch = data[i];
            if (inString) {
                if (escaped) {
                    escaped = false;
                } else if (ch == '\\') {
                    escaped = true;
                } else if (ch == '"') {
                    inString = false;
                }
                continue;
            }
            if (ch == '"') {
                inString = true;
            } else if (ch == '[') {
                depth++;
            } else if (ch == ']') {
                depth--;
                if (depth == 0) return i;
            }
        }
        return type(uint256).max;
    }

    function _findMatchingBrace(bytes memory data, uint256 openPos) internal pure returns (uint256) {
        uint256 depth;
        bool inString;
        bool escaped;
        for (uint256 i = openPos; i < data.length; i++) {
            bytes1 ch = data[i];
            if (inString) {
                if (escaped) {
                    escaped = false;
                } else if (ch == '\\') {
                    escaped = true;
                } else if (ch == '"') {
                    inString = false;
                }
                continue;
            }
            if (ch == '"') {
                inString = true;
            } else if (ch == '{') {
                depth++;
            } else if (ch == '}') {
                depth--;
                if (depth == 0) return i;
            }
        }
        return type(uint256).max;
    }

    function _isDuplicateHeadline(string[] memory existingHeadlines, uint256 existingCount, string memory candidate)
        internal
        pure
        returns (bool)
    {
        bytes32 candidateHash = keccak256(bytes(_normalizeHeadline(candidate)));
        for (uint256 i = 0; i < existingCount; i++) {
            if (keccak256(bytes(_normalizeHeadline(existingHeadlines[i]))) == candidateHash) {
                return true;
            }
        }
        return false;
    }

    function _normalizeHeadline(string memory value) internal pure returns (string memory) {
        bytes memory data = bytes(value);
        bytes memory out = new bytes(data.length);
        uint256 count;
        bool lastWasSpace = true;
        for (uint256 i = 0; i < data.length; i++) {
            bytes1 ch = data[i];
            if (ch >= 0x41 && ch <= 0x5A) {
                ch = bytes1(uint8(ch) + 32);
            }
            bool isAlphaNum = (ch >= 0x61 && ch <= 0x7A) || (ch >= 0x30 && ch <= 0x39);
            if (isAlphaNum) {
                out[count++] = ch;
                lastWasSpace = false;
            } else if (!lastWasSpace) {
                out[count++] = 0x20;
                lastWasSpace = true;
            }
        }
        if (count > 0 && out[count - 1] == 0x20) {
            count--;
        }
        bytes memory trimmed = new bytes(count);
        for (uint256 i = 0; i < count; i++) {
            trimmed[i] = out[i];
        }
        return string(trimmed);
    }

    function _parseInt8(bytes memory data, uint256 start) internal pure returns (bool found, int8 value) {
        while (start < data.length && (data[start] == 0x20 || data[start] == 0x0A || data[start] == 0x0D || data[start] == 0x09)) {
            start++;
        }
        if (start >= data.length) return (false, 0);

        bool negative;
        if (data[start] == '-') {
            negative = true;
            start++;
        }

        if (start >= data.length || data[start] < '0' || data[start] > '9') {
            return (false, 0);
        }

        int256 parsed;
        while (start < data.length && data[start] >= '0' && data[start] <= '9') {
            parsed = parsed * 10 + int256(uint256(uint8(data[start]) - uint8(bytes1('0'))));
            start++;
        }

        if (negative) {
            parsed = -parsed;
        }

        if (parsed < type(int8).min || parsed > type(int8).max) {
            return (false, 0);
        }

        return (true, int8(parsed));
    }
}
