# Mechanism

## Constant-product quote

For input `a`, input reserve `x`, output reserve `y`, and fee multiplier `f`:

```text
netInput = floor(a * f)
output   = floor(y * netInput / (x + netInput))
```

For requested output `b`:

```text
netInput   = ceil(x * b / (y - b))
grossInput = ceil(netInput / f)
```

The deployed example uses `f = 997 / 1000`, or a 30 bps fee.

## Two reserve views

Each swap reads:

- local reserves `(xL, yL)` for the chosen member; and
- aggregate reserves `(xA, yA)` for the complete bounded federation.

Exact input calculates both outputs and returns the smaller:

```text
qL = amountOut(a, xL, yL)
qA = amountOut(a, xA, yA)
qK = min(qL, qA)
```

Exact output calculates both input requirements and returns the larger:

```text
qL = amountIn(b, xL, yL)
qA = amountIn(b, xA, yA)
qK = max(qL, qA)
```

## Reserve update

The selected gross input and output update the chosen member and the aggregate:

```text
reserveIn  += grossInput
reserveOut -= output
```

The full input enters reserves. The quote discounts it by the fee before calculating output, so the fee increases LP-owned reserves.

## Worked example

Pool A starts at `1,000 A / 1,500 B`. Pool B starts at `1,000 A / 500 B`. The aggregate is `2,000 A / 2,000 B`.

For an exact input of `10 A` at 30 bps:

```text
Pool A output:     about 14.81 B
Aggregate output:  about  9.92 B
Knot output:       about  9.92 B
```

The local pool keeps roughly `4.89 B` that its isolated stale quote would have leaked. The trader still receives an immediate deterministic quote.

## What the aggregate means

The aggregate curve is a reserve-weighted internal boundary. It is not a promise that the pair's external fair price equals the aggregate ratio.

If all member pools share the same price, the smaller local pool usually remains the limiting curve because its price impact is larger. Knot then behaves like the local AMM.

If one member is unusually generous relative to the combined state, the aggregate curve clips it. If the local curve is already more conservative, Knot leaves it unchanged.

## Coalition boundary

A registered pool can influence the aggregate by changing genuine reserves. Proportional additions prevent arbitrary ratio changes after a pool is seeded, but a coordinated member and trader may still weaken protection. This version treats authenticated membership and visible reserves as a bounded trust model, not a universal anti-collusion proof.
