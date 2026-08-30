"use client";
import { useChainId, useAccount } from "wagmi";
import { CHAIN_ID } from "@/lib/knot";

/**
 * States the reader needs to distinguish at a glance: reading the live chain, reading the
 * fallback because no wallet is attached, or attached to the wrong network. Ambiguity here is
 * what makes a demo look broken when it is merely disconnected.
 */
export default function LiveBadge({ live }: { live: boolean }) {
  const { isConnected } = useAccount();
  const chainId = useChainId();
  const wrongNet = isConnected && chainId !== CHAIN_ID;

  const [dot, text] = wrongNet
    ? ["bg-amber", "wrong network"]
    : live
      ? ["bg-accent animate-pulse", "live · unichain sepolia"]
      : ["bg-faint", "reference values"];

  return (
    <span className="pill">
      <span className={`inline-block h-1.5 w-1.5 rounded-full ${dot}`} />
      {text}
    </span>
  );
}
