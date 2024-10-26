# Synthetic Asset Smart Contract

## About
This Clarity smart contract implements a fully-functional synthetic asset protocol on the Stacks blockchain. It allows users to mint, burn, and trade synthetic assets backed by STX collateral. The system includes price oracle integration, collateral management, and liquidation mechanisms to maintain system stability.

## Key Features
- 🏦 Collateralized minting of synthetic assets
- 💱 Asset transfer functionality
- 🔥 Token burning mechanism
- 📊 Price oracle integration
- 💰 Collateral management system
- ⚡ Liquidation functionality
- 🔒 Robust security controls

## Core Parameters
| Parameter | Value | Description |
|-----------|-------|-------------|
| Required Collateral Ratio | 150% | Minimum collateral required to mint tokens |
| Liquidation Threshold | 120% | Position can be liquidated below this ratio |
| Price Validity Period | 900 blocks | Oracle price expiry (~15 minutes) |
| Minimum Mint Amount | 100,000,000 | Minimum amount to mint (1.00 tokens with 8 decimals) |

## Functions

### Public Functions

#### Minting and Burning
```clarity
(define-public (mint-synthetic-tokens (token-amount uint)))
(define-public (burn-synthetic-tokens (token-amount uint)))
```
- `mint-synthetic-tokens`: Creates new synthetic tokens by locking collateral
- `burn-synthetic-tokens`: Burns synthetic tokens to reclaim collateral

#### Token Operations
```clarity
(define-public (transfer-synthetic-tokens (recipient-address principal) (transfer-amount uint)))
```
- Transfers synthetic tokens between addresses

#### Collateral Management
```clarity
(define-public (deposit-additional-collateral (collateral-amount uint)))
```
- Allows users to add more collateral to their position

#### Liquidation
```clarity
(define-public (liquidate-undercollateralized-vault (vault-owner principal)))
```
- Enables liquidation of positions below the minimum collateral ratio

#### Price Oracle
```clarity
(define-public (update-oracle-price (new-asset-price uint)))
```
- Updates the price feed (restricted to contract administrator)

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Unauthorized access |
| u101 | Insufficient token balance |
| u102 | Invalid token amount |
| u103 | Oracle price expired |
| u104 | Insufficient collateral deposit |
| u105 | Below minimum collateral threshold |

## Security Considerations

1. **Price Oracle Security**
   - Oracle prices expire after 900 blocks
   - Only contract administrator can update prices
   - Price checks before all critical operations

2. **Collateral Safety**
   - 150% minimum collateral ratio
   - Automatic liquidation below 120%
   - Safe arithmetic operations

3. **Access Controls**
   - Administrator-only functions properly gated
   - Balance checks before transfers
   - Vault ownership verification

## Integration Guidelines

### Contract Deployment
1. Deploy the contract to the Stacks blockchain
2. Initialize the price oracle with the first price feed
3. Verify all read-only functions are accessible

### Interacting with the Contract
1. Ensure sufficient STX balance for collateral
2. Calculate required collateral based on current prices
3. Monitor position health regularly
4. Keep track of oracle price updates

## Best Practices

1. **For Users**
   - Maintain healthy collateral ratios (>200% recommended)
   - Monitor oracle prices regularly
   - Have a plan for price volatility

2. **For Integrators**
   - Implement price feed monitoring
   - Add collateral ratio alerts
   - Include liquidation protection mechanisms

## Testing

To test the contract:
1. Deploy to testnet
2. Test all public functions
3. Verify error conditions
4. Test liquidation scenarios
5. Validate oracle integration

## Development Dependencies
- Clarity CLI
- Stacks blockchain
- Clarity VS Code extension (recommended)