# Auto Portfolio Rebalancer Integration Guide

## Overview

The Auto Portfolio Rebalancer solves the critical issue where your trading bot stops executing trades because most funds are held in altcoins rather than USDT. It automatically converts profitable altcoin positions back to USDT to maintain continuous trading operations.

## Problem Solved

**Before**: Bot shows "BUY skipped: $0.07 < $1.50" because USDT balance is insufficient, even when you have $10+ in BTC/other altcoins.

**After**: Bot automatically converts some profitable BTC (or other altcoins) to USDT when needed, then resumes normal trading operations.

## Quick Integration

### 1. Add to Your Existing Trading Bot

```python
# At the top of your trading bot file
from auto_portfolio_rebalancer import integrate_auto_rebalancer

# Before any buy logic in your main trading loop
async def main_trading_loop():
    # ... your existing code ...
    
    # Check USDT balance
    usdt_balance = get_usdt_balance()  # Your existing function
    
    # If insufficient USDT, trigger auto-rebalancing
    if usdt_balance < MIN_BUY_USDT:
        logger.info(f"🔄 USDT balance ${usdt_balance:.2f} < ${MIN_BUY_USDT:.2f} - checking for auto-rebalance")
        
        rebalanced = await integrate_auto_rebalancer(
            exchange=exchange,
            config=config,
            min_usdt_balance=MIN_BUY_USDT
        )
        
        if rebalanced:
            # Refresh balance after rebalancing
            usdt_balance = get_usdt_balance()
            logger.info(f"✅ Auto-rebalancing complete - new USDT balance: ${usdt_balance:.2f}")
    
    # Continue with your normal trading logic
    if usdt_balance >= MIN_BUY_USDT:
        # Execute buy orders as normal
        pass
    else:
        logger.info("⏭️ BUY skipped: insufficient USDT even after rebalancing attempt")
```

### 2. Configuration

Add these settings to your bot configuration:

```python
# Recommended settings for $10-50 accounts
REBALANCER_CONFIG = {
    'MIN_USDT_BALANCE': 1.50,        # Your existing MIN_BUY_USDT value
    'TARGET_USDT_RATIO': 0.25,       # Keep 25% in USDT for trading
    'MIN_CONVERSION_PROFIT': 0.5,    # Only convert positions with 0.5%+ profit
    'MAX_CONVERSION_PER_CYCLE': 0.30, # Max 30% of any position per cycle
    'CONVERSION_COOLDOWN': 180,      # 3 minutes between conversions
}

# For larger accounts ($100+)
REBALANCER_CONFIG_LARGE = {
    'MIN_USDT_BALANCE': 5.00,
    'TARGET_USDT_RATIO': 0.20,       # Keep 20% in USDT
    'MIN_CONVERSION_PROFIT': 1.0,    # Only convert positions with 1%+ profit
    'MAX_CONVERSION_PER_CYCLE': 0.25, # Max 25% of any position per cycle
    'CONVERSION_COOLDOWN': 300,      # 5 minutes between conversions
}
```

## How It Works

### Detection Phase
1. **Portfolio Analysis**: Scans all holdings and converts values to USDT equivalent
2. **USDT Ratio Check**: Determines if USDT percentage is below target (default: 25%)
3. **Minimum Balance Check**: Ensures absolute minimum USDT for next trade

### Conversion Phase
1. **Candidate Identification**: Finds altcoins with positive P&L that can be converted
2. **Profitability Ranking**: Sorts by profit percentage (highest first)
3. **Strategic Conversion**: Sells only what's needed to reach USDT targets
4. **Safety Limits**: Never sells at more than 5% loss, respects position size limits

### Execution Phase
1. **Market Orders**: Executes efficient market sells for immediate liquidity
2. **Audit Logging**: Records all conversions with detailed P&L tracking
3. **Cooldown Management**: Prevents excessive trading with configurable delays

## Example Scenario

**Your Portfolio**:
- USDT: $0.07 (insufficient for $1.50 minimum trade)
- BTC: $8.50 (purchased at $8.20, currently +3.7% profit)
- ETH: $2.30 (purchased at $2.35, currently -2.1% loss)

**Auto-Rebalancer Action**:
1. ✅ Identifies BTC as profitable conversion candidate (+3.7%)
2. ❌ Skips ETH (negative P&L)
3. 🔄 Converts $2.55 worth of BTC to USDT (30% of BTC position)
4. 📊 New balances: USDT $2.62, BTC $5.95, ETH $2.30
5. ▶️ Trading resumes with sufficient USDT

## Integration Examples

### Simple Integration (Minimal Changes)

```python
# Add this single check before your buy logic
if usdt_balance < MIN_BUY_USDT:
    rebalanced = await integrate_auto_rebalancer(exchange, config, MIN_BUY_USDT)
    if rebalanced:
        usdt_balance = get_updated_usdt_balance()
```

### Advanced Integration (Full Control)

```python
from auto_portfolio_rebalancer import AutoPortfolioRebalancer

# Initialize once
rebalancer = AutoPortfolioRebalancer(exchange, REBALANCER_CONFIG)

# In your trading loop
async def trading_cycle():
    # Check if rebalancing is needed
    rebalanced = await rebalancer.check_and_rebalance_portfolio()
    
    if rebalanced:
        # Portfolio was rebalanced, refresh all balances
        await refresh_portfolio_data()
    
    # Continue with normal trading logic
    await execute_trading_strategy()
```

## Configuration Tuning

### For Small Accounts ($10-30)
```python
'MIN_USDT_BALANCE': 0.50,         # Lower minimum for micro-trading
'TARGET_USDT_RATIO': 0.30,        # Keep more in USDT (30%)
'MIN_CONVERSION_PROFIT': 0.0,     # Convert even breakeven positions
'MAX_CONVERSION_PER_CYCLE': 0.40, # Allow larger conversions (40%)
```

### For Medium Accounts ($50-200)
```python
'MIN_USDT_BALANCE': 2.00,         # Standard minimum
'TARGET_USDT_RATIO': 0.25,        # Balanced approach (25%)
'MIN_CONVERSION_PROFIT': 0.5,     # Small profit requirement
'MAX_CONVERSION_PER_CYCLE': 0.30, # Conservative conversion (30%)
```

### For Large Accounts ($500+)
```python
'MIN_USDT_BALANCE': 10.00,        # Higher minimum
'TARGET_USDT_RATIO': 0.20,        # Less USDT needed (20%)
'MIN_CONVERSION_PROFIT': 1.0,     # Higher profit requirement
'MAX_CONVERSION_PER_CYCLE': 0.20, # Conservative conversion (20%)
```

## Monitoring and Logging

The rebalancer provides detailed logging:

```
💰 Portfolio Check - USDT: $0.07 | Total: $10.94
🔄 Auto-rebalancing triggered - insufficient USDT for trading
💡 Need $2.43 USDT | Found 2 conversion candidates
🔄 Converting 0.000024 BTC to USDT @ $107,360.97
✅ Converted BTC: +$2.58 USDT
🎯 Rebalancing complete: +$2.58 USDT acquired
```

## Safety Features

### Loss Protection
- **Never sells at significant loss**: Won't convert positions with more than 5% unrealized loss
- **Position size limits**: Maximum 50% of any position per conversion cycle
- **Profit requirements**: Only converts profitable or near-breakeven positions

### Trading Limits
- **Conversion cooldowns**: Prevents excessive trading with configurable delays
- **Market impact protection**: Uses market orders for immediate execution
- **Balance verification**: Double-checks all balances before and after conversions

### Error Handling
- **Exchange connectivity**: Graceful handling of API errors
- **Order execution**: Retry logic for failed orders
- **Balance tracking**: Maintains accurate portfolio state

## Troubleshooting

### "No profitable conversions available"
**Cause**: All altcoin positions are at a loss
**Solution**: Lower `MIN_CONVERSION_PROFIT` to 0.0 or wait for positions to recover

### "Conversion cooldown active"
**Cause**: Recent conversion within cooldown period
**Solution**: Reduce `CONVERSION_COOLDOWN` or wait for cooldown to expire

### "Insufficient balance for conversion"
**Cause**: Altcoin balances too small for minimum order sizes
**Solution**: Check exchange minimum order requirements, consider manual consolidation

### Bot still not trading after rebalancing
**Cause**: Market conditions changed or exchange issues
**Solution**: Verify exchange connectivity, check market hours, review trading logic

## Performance Impact

### Positive Effects
- **Eliminates trading downtime** when funds are locked in altcoins
- **Maintains liquidity** for opportunity capture
- **Realizes profits** from successful positions
- **Improves capital efficiency** through active management

### Potential Concerns
- **Additional trading fees**: Each conversion incurs exchange fees
- **Tax implications**: May trigger taxable events (consult tax advisor)
- **Market timing**: Converting during short-term dips

### Optimization Tips
1. **Tune profit thresholds** based on your trading frequency
2. **Adjust conversion percentages** based on position sizes
3. **Monitor conversion frequency** to balance fees vs. liquidity
4. **Track rebalancing performance** vs. manual management

## Next Steps

1. **Integration**: Add the rebalancer to your existing trading bot
2. **Testing**: Run in paper trading mode first to verify behavior
3. **Monitoring**: Watch logs for rebalancing frequency and effectiveness
4. **Tuning**: Adjust parameters based on your trading patterns
5. **Scaling**: Consider different configurations for different market conditions

## Support

The Auto Portfolio Rebalancer is designed to integrate seamlessly with your existing trading infrastructure. For additional customization or specific exchange integration needs, refer to the main module documentation or extend the base classes for your specific requirements.