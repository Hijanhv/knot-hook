import { createPublicClient, defineChain, http } from "viem";
import { CHAIN } from "./contracts";

export const unichainSepolia = defineChain({
  id: CHAIN.id,
  name: CHAIN.name,
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: [CHAIN.rpc] } },
  blockExplorers: { default: { name: "Uniscan", url: CHAIN.explorer } },
  testnet: true,
});

/** One read-only client for the public deployment. No wallet is required or implied. */
export const publicClient = createPublicClient({
  chain: unichainSepolia,
  transport: http(process.env.NEXT_PUBLIC_RPC_URL ?? CHAIN.rpc, { retryCount: 2, timeout: 10_000 }),
  batch: { multicall: true },
});

export type ChainHead = {
  number: bigint;
  timestamp: bigint;
  observedAt: number;
};

/** Reads one concrete head so every contract read in a query can be pinned to the same block. */
export async function readChainHead(): Promise<ChainHead> {
  const block = await publicClient.getBlock();
  return { number: block.number, timestamp: block.timestamp, observedAt: Date.now() };
}

/** A delayed RPC must never be labelled live merely because it returned successfully. */
export function chainHeadAgeSeconds(head: ChainHead, now = Date.now()) {
  return Math.max(0, Math.floor(now / 1000 - Number(head.timestamp)));
}

export function isChainHeadStale(head: ChainHead, maximumAgeSeconds = 90, now = Date.now()) {
  return chainHeadAgeSeconds(head, now) > maximumAgeSeconds;
}
