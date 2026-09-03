"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider, createConfig, http } from "wagmi";
import { base, baseSepolia } from "wagmi/chains";
import { defineChain } from "viem";
import { useState } from "react";

/** Unichain Sepolia is newer than wagmi's bundled chain list, so define it locally. */
export const unichainSepolia = defineChain({
  id: 1301,
  name: "Unichain Sepolia",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: ["https://sepolia.unichain.org"] } },
  blockExplorers: { default: { name: "Uniscan", url: "https://sepolia.uniscan.xyz" } },
  testnet: true,
});

export const wagmiConfig = createConfig({
  chains: [unichainSepolia, baseSepolia, base],
  // Deliberately EMPTY. Connectors come from EIP-6963 discovery instead, which wagmi runs
  // by default. Declaring injected() here would register a connector bound to
  // `window.ethereum`, and with several wallets installed that slot is won by whichever
  // extension injected last. EIP-6963 sidesteps the race entirely: each wallet announces
  // itself with a unique RDNS, so MetaMask can be addressed by identity.
  connectors: [],
  multiInjectedProviderDiscovery: true,
  transports: {
    [unichainSepolia.id]: http(),
    [baseSepolia.id]: http(),
    [base.id]: http(),
  },
  ssr: true,
});

export default function Providers({ children }: { children: React.ReactNode }) {
  const [qc] = useState(() => new QueryClient());
  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    </WagmiProvider>
  );
}
