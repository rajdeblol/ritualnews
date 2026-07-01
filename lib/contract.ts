import { createPublicClient, http } from 'viem';

export const ritualChain = {
  id: 1979,
  name: 'Ritual Testnet',
  nativeCurrency: {
    name: 'RITUAL',
    symbol: 'RITUAL',
    decimals: 18,
  },
  rpcUrls: {
    default: {
      http: ['https://rpc.ritualfoundation.org'],
    },
    public: {
      http: ['https://rpc.ritualfoundation.org'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Ritual Explorer',
      url: 'https://explorer.ritualfoundation.org',
    },
  },
  testnet: true,
} as const;

export const sentimentFeedAbi = [
  {
    type: 'function',
    stateMutability: 'view',
    name: 'getLatest',
    inputs: [],
    outputs: [
      {
        type: 'tuple',
        components: [
          { name: 'score', type: 'int8' },
          { name: 'signal', type: 'string' },
          { name: 'riskLevel', type: 'string' },
          { name: 'summary', type: 'string' },
          { name: 'topTokens', type: 'string[]' },
          { name: 'headlines', type: 'string[]' },
          { name: 'headlineSources', type: 'string[]' },
          { name: 'headlineSentiments', type: 'string[]' },
          { name: 'headlineUrls', type: 'string[]' },
          { name: 'timestamp', type: 'uint256' },
          { name: 'headlineCount', type: 'uint256' },
        ],
      },
    ],
  },
  {
    type: 'function',
    stateMutability: 'view',
    name: 'getSnapshot',
    inputs: [{ name: 'index', type: 'uint256' }],
    outputs: [
      {
        type: 'tuple',
        components: [
          { name: 'score', type: 'int8' },
          { name: 'signal', type: 'string' },
          { name: 'riskLevel', type: 'string' },
          { name: 'summary', type: 'string' },
          { name: 'topTokens', type: 'string[]' },
          { name: 'headlines', type: 'string[]' },
          { name: 'headlineSources', type: 'string[]' },
          { name: 'headlineSentiments', type: 'string[]' },
          { name: 'headlineUrls', type: 'string[]' },
          { name: 'timestamp', type: 'uint256' },
          { name: 'headlineCount', type: 'uint256' },
        ],
      },
    ],
  },
  {
    type: 'function',
    stateMutability: 'view',
    name: 'getRecentScores',
    inputs: [{ name: 'n', type: 'uint256' }],
    outputs: [
      { name: 'scores', type: 'int8[]' },
      { name: 'timestamps', type: 'uint256[]' },
    ],
  },
  {
    type: 'function',
    stateMutability: 'view',
    name: 'totalSnapshots',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
] as const;

export const rpcUrl = 'https://rpc.ritualfoundation.org';
export const explorerUrl = ritualChain.blockExplorers.default.url;
export const docsUrl = 'https://www.ritualfoundation.org';
export const discordUrl = 'https://www.ritualfoundation.org';

export const sentimentFeedAddress = '0x16534029323106CeC29C01431f46f53620CBA501' as `0x${string}`;
export const sentimentAgentAddress = '0xd277be9410fC1C0f2C704ea2e8E086AA1B50ab00' as `0x${string}`;

export const ritualPublicClient = createPublicClient({
  chain: ritualChain,
  transport: http(rpcUrl),
});
