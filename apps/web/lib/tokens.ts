"use client";

import { useQuery } from "@tanstack/react-query";
import { CHAIN_ID } from "./knot";
import type { Address } from "./deployment";
import { publicClient } from "./rpc";
import { erc20Abi } from "./swap";

/**
 * Token symbols for a pair, shared by the direction picker and the swap panel so the
 * UI says kETH and kUSD instead of token0 and token1. Null until the read resolves.
 */
export function useTokenSymbols(input: Address | null, output: Address | null): {
  inSymbol: string | null;
  outSymbol: string | null;
} {
  const query = useQuery({
    queryKey: ["knot", CHAIN_ID, "tokens", input, output],
    queryFn: async () => {
      if (!input || !output) throw new Error("Token addresses are required");
      const [inSymbol, outSymbol] = await Promise.all([
        publicClient.readContract({ address: input, abi: erc20Abi, functionName: "symbol" }),
        publicClient.readContract({ address: output, abi: erc20Abi, functionName: "symbol" }),
      ]);
      return { inSymbol, outSymbol };
    },
    enabled: input !== null && output !== null,
    staleTime: 60_000,
  });
  return { inSymbol: query.data?.inSymbol ?? null, outSymbol: query.data?.outSymbol ?? null };
}
