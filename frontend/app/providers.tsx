"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider, createConfig, http } from "wagmi";
import { base, baseSepolia } from "wagmi/chains";
import { defineChain } from "viem";
import { injected } from "wagmi/connectors";
import { useState } from "react";

/** Unichain Sepolia is newer than wagmi 2.12.7's bundled chain list, so define it locally. */
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
  // MetaMask only. `target: "metaMask"` pins the connector to the MetaMask provider rather
  // than any injected wallet, so a browser with several wallets installed cannot silently
  // connect through the wrong one.
  connectors: [injected({ target: "metaMask" })],
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
