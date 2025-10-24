#!/usr/bin/env python3
"""
URGENT BOT PATCH - Fix Your Bot in 30 Seconds

YOUR CURRENT ISSUE (from logs):
- Bot balance: $11.00 USDT total 
- Available for trading: $0.07 USDT
- Bot error: "BUY skipped 0.07 1.50" (need $1.50 minimum)
- Bot running but can't execute any trades

ROOT CAUSE:
- Most of your $11 is tied up in BTC/other crypto positions
- Bot only has access to the "free" USDT balance ($0.07)
- Need to convert some profitable crypto back to USDT

THIS PATCH:
1. Finds your most profitable crypto position 
2. Converts just 10-20% of it to USDT
3. Gives bot $2-3 USDT to resume trading
4. Preserves 80%+ of your positions

USAGE:
1. Stop your current bot
2. Run: python URGENT_BOT_PATCH.py  
3. Restart your bot - it will work immediately
"""

import ccxt
import asyncio
import logging
import sys
from decimal import Decimal

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class UrgentBotPatcher:
    def __init__(self):
        # Add your Bitget API credentials here
        self.API_KEY = "your_api_key_here"        # 🔴 EDIT THIS
        self.API_SECRET = "your_api_secret_here"  # 🔴 EDIT THIS  
        self.API_PASSPHRASE = "your_passphrase"   # 🔴 EDIT THIS
        
        self.target_usdt = 2.50  # Convert enough to get this much USDT
        self.max_position_convert = 0.15  # Convert max 15% of any position
        
    async def patch_bot_now(self):
        """🆘 URGENT PATCH - Fix bot balance issue immediately"""
        
        logger.info("🆘 URGENT BOT PATCH - FIXING BALANCE ISSUE")
        logger.info("Problem: Bot has $11 total but only $0.07 USDT available for trading")
        logger.info("Solution: Converting profitable crypto to USDT\n")
        
        try:
            # Check API credentials
            if "your_api" in self.API_KEY:
                logger.error("❌ Please edit this file and add your real API credentials!")
                logger.error("   Lines 29-31: Add your Bitget API key, secret, and passphrase")
                return False
            
            # Initialize exchange
            exchange = ccxt.bitget({
                'apiKey': self.API_KEY,
                'secret': self.API_SECRET, 
                'password': self.API_PASSPHRASE,
                'sandbox': False,  # Production
                'enableRateLimit': True,
            })
            
            logger.info("✅ Connected to Bitget exchange")
            
            # Step 1: Analyze current situation
            logger.info("\n🔍 STEP 1: Analyzing your account...")
            balance = await exchange.fetch_balance()
            
            current_usdt = balance.get('USDT', {}).get('free', 0.0)
            total_usdt = balance.get('USDT', {}).get('total', 0.0)
            
            logger.info(f"Current USDT - Free: ${current_usdt:.2f}, Total: ${total_usdt:.2f}")
            
            if current_usdt >= 1.50:
                logger.info("✅ Your bot already has enough USDT to trade!")
                logger.info(f"Available: ${current_usdt:.2f} (need $1.50 minimum)")
                return True
            
            # Find positions to convert
            positions = await self.analyze_positions(exchange, balance)
            
            if not positions:
                logger.error("❌ No positions found to convert. May need to deposit more USDT.")
                return False
            
            logger.info(f"\n📊 Found {len(positions)} convertible positions:")
            for pos in positions[:3]:  # Show top 3
                logger.info(f"   {pos['symbol']}: ${pos['value']:.2f} ({pos['profit']:+.1f}% profit)")
            
            # Step 2: Execute conversion
            logger.info(f"\n🔄 STEP 2: Converting crypto to get ${self.target_usdt:.2f} USDT...")
            
            needed = self.target_usdt - current_usdt
            conversion_result = await self.execute_smart_conversion(exchange, positions, needed)
            
            if conversion_result['success']:
                logger.info("\n✅ URGENT PATCH SUCCESSFUL!")
                logger.info(f"   New USDT Balance: ${conversion_result['final_usdt']:.2f}")
                logger.info(f"   Converted: {conversion_result['converted_asset']}")
                logger.info(f"   Amount: ${conversion_result['usdt_gained']:.2f}")
                logger.info("\n💪 YOUR BOT CAN NOW TRADE!")
                logger.info("   Restart your trading bot - the balance issue is fixed.")
                return True
            else:
                logger.error(f"\n❌ Patch failed: {conversion_result.get('error')}")
                return False
                
        except Exception as e:
            logger.error(f"❌ Urgent patch failed: {e}")
            return False
    
    async def analyze_positions(self, exchange, balance):
        """Analyze positions and rank them for conversion"""
        
        positions = []
        
        for symbol, amounts in balance.items():
            if symbol == 'USDT' or amounts.get('total', 0) <= 0:
                continue
                
            try:
                # Get current price
                ticker = await exchange.fetch_ticker(f'{symbol}/USDT')
                current_price = ticker['last']
                balance_amount = amounts['total']
                value = balance_amount * current_price
                
                if value < 1.0:  # Skip dust
                    continue
                
                # Estimate profit (simplified)
                profit_pct = await self.estimate_position_profit(exchange, symbol, current_price)
                
                positions.append({
                    'symbol': symbol,
                    'balance': balance_amount,
                    'price': current_price,
                    'value': value,
                    'profit': profit_pct,
                    'convertible_value': value * self.max_position_convert,
                    'score': self.calculate_conversion_score(value, profit_pct)
                })
                
            except Exception as e:
                logger.debug(f"Could not analyze {symbol}: {e}")
                continue
        
        # Sort by score (best first)
        positions.sort(key=lambda x: x['score'], reverse=True)
        return positions
    
    async def estimate_position_profit(self, exchange, symbol, current_price):
        """Estimate profit for a position"""
        try:
            # Get recent trades
            trades = await exchange.fetch_my_trades(f'{symbol}/USDT', limit=30)
            buy_trades = [t for t in trades if t['side'] == 'buy']
            
            if not buy_trades:
                return 0.0
            
            # Calculate weighted average
            total_cost = sum(t['cost'] for t in buy_trades)
            total_amount = sum(t['amount'] for t in buy_trades)
            avg_price = total_cost / total_amount if total_amount > 0 else current_price
            
            return ((current_price - avg_price) / avg_price) * 100
            
        except:
            return 0.0  # Assume breakeven if can't calculate
    
    def calculate_conversion_score(self, value, profit_pct):
        """Score positions for conversion priority"""
        score = value  # Base score from position size
        
        # Profit bonus (prefer profitable positions)
        if profit_pct > 0:
            score += profit_pct * 5
        elif profit_pct < -3:  # Penalty for losses
            score *= 0.3
        
        return score
    
    async def execute_smart_conversion(self, exchange, positions, needed_usdt):
        """Execute the actual conversion"""
        
        if not positions:
            return {'success': False, 'error': 'No positions to convert'}
        
        best_position = positions[0]  # Highest scored position
        
        # Calculate conversion amount
        max_convertible = best_position['convertible_value']
        conversion_usdt_value = min(needed_usdt * 1.1, max_convertible)  # 10% buffer
        conversion_amount = conversion_usdt_value / best_position['price']
        
        logger.info(f"Converting {conversion_amount:.6f} {best_position['symbol']} to USDT...")
        logger.info(f"Expected: ~${conversion_usdt_value:.2f} USDT")
        
        try:
            # Execute market sell
            order = await exchange.create_market_sell_order(
                f"{best_position['symbol']}/USDT",
                conversion_amount
            )
            
            # Wait for execution
            await asyncio.sleep(3)
            
            # Check result
            order_status = await exchange.fetch_order(order['id'], f"{best_position['symbol']}/USDT")
            
            if order_status.get('status') == 'closed':
                filled = order_status['filled']
                avg_price = order_status['average']
                usdt_received = filled * avg_price
                
                # Get new balance
                new_balance = await exchange.fetch_balance()
                final_usdt = new_balance.get('USDT', {}).get('free', 0.0)
                
                return {
                    'success': True,
                    'converted_asset': best_position['symbol'],
                    'amount_converted': filled,
                    'usdt_gained': usdt_received,
                    'final_usdt': final_usdt
                }
            else:
                return {
                    'success': False,
                    'error': f"Order not filled: {order_status.get('status')}"
                }
                
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }


async def main():
    """🆘 Main function - run the urgent patch"""
    
    print("🆘 URGENT BOT PATCH - Fix Your Trading Bot Balance Issue")
    print("\n🔍 Your Problem (from logs):")
    print("   ❌ Bot balance: $11.00 total but only $0.07 available for trading")
    print("   ❌ Bot error: 'BUY skipped 0.07 1.50' - need $1.50 minimum")
    print("   ❌ Missing every trading opportunity")
    print("\n🔧 This Patch:")
    print("   ✅ Converts 10-15% of your most profitable crypto position")
    print("   ✅ Gives your bot $2-3 USDT to resume trading")
    print("   ✅ Preserves 85%+ of your profitable positions")
    print("\n" + "="*50)
    
    patcher = UrgentBotPatcher()
    
    # Check if API credentials are set
    if "your_api" in patcher.API_KEY:
        print("❌ SETUP REQUIRED:")
        print("   1. Edit this file (URGENT_BOT_PATCH.py)")
        print("   2. Add your Bitget API credentials on lines 29-31")
        print("   3. Run again: python URGENT_BOT_PATCH.py")
        print("\n   API_KEY = 'your_actual_api_key'")
        print("   API_SECRET = 'your_actual_api_secret'")
        print("   API_PASSPHRASE = 'your_actual_passphrase'")
        return
    
    # Run the patch
    success = await patcher.patch_bot_now()
    
    if success:
        print("\n🎉 SUCCESS! Your bot is now fixed and ready to trade!")
        print("\n💪 Next steps:")
        print("   1. Restart your trading bot")
        print("   2. It should now work without 'BUY skipped' errors")
        print("   3. Monitor the logs to confirm trading resumes")
    else:
        print("\n❌ Patch unsuccessful. Check the error messages above.")
        print("\nTroubleshooting:")
        print("   - Verify your API credentials are correct")
        print("   - Ensure API has trading permissions enabled")
        print("   - Check that you have crypto positions to convert")


if __name__ == "__main__":
    asyncio.run(main())