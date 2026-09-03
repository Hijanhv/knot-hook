import { ACTIVE_DEPLOYMENT, DEPLOYMENT } from "./deployment";

/** Every chain and address consumer derives from the single validated deployment manifest. */
export const CHAIN = DEPLOYMENT.chain;
export const DEPLOYED = ACTIVE_DEPLOYMENT?.contracts ?? null;

export const CONTRACTS = DEPLOYED
  ? [
      {
        name: "KnotFederation",
        address: DEPLOYED.federation,
        poolId: null,
        role: "Authenticated per-member reserves plus the O(1) aggregate pair. Every quote is derived here.",
        reads: ["preview(address,bool,bool,uint256)", "reservesOf(address)", "aggregateReserve0()", "aggregateReserve1()", "memberCount()"],
      },
      {
        name: "KnotHook · deep",
        address: DEPLOYED.deep,
        poolId: ACTIVE_DEPLOYMENT?.pools.deep ?? null,
        role: "Balanced control member. Its own curve is more conservative, so the shared boundary stays inert.",
        reads: ["reserves()", "balanceOf(address)", "totalSupply()"],
      },
      {
        name: "KnotHook · shallow",
        address: DEPLOYED.shallow,
        poolId: ACTIVE_DEPLOYMENT?.pools.shallow ?? null,
        role: "Skewed demonstration member. Its generous local quote is clipped to the federation's virtual aggregate curve.",
        reads: ["reserves()", "balanceOf(address)", "totalSupply()"],
      },
      // The faucet is convenience infrastructure outside the hook trust boundary. It only
      // appears once its address is recorded in the release manifest.
      ...(ACTIVE_DEPLOYMENT?.faucet
        ? [
            {
              name: "KnotFaucet",
              address: ACTIVE_DEPLOYMENT.faucet.address,
              poolId: null,
              role: "Demo faucet. Pays test currencies behind a cooldown; it never mints, so exposure is capped by funding.",
              reads: ["drip()", "cooldownRemaining(address)", "claimsRemaining()"],
            },
          ]
        : []),
    ]
  : [];

// Not deployed separately: KnotMath is a library, inlined into both hooks at compile time.
export const POOL_MANAGER = DEPLOYMENT.dependencies.poolManager;
