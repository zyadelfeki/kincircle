#!/usr/bin/env python3
"""
Auto Portfolio Rebalancer for Trading Bot
Automatically converts altcoins to USDT when trading capacity is blocked

This module solves the issue where the trading bot stops executing trades
because most funds are held in altcoins rather than USDT. It automatically
sells profitable altcoin positions to maintain USDT reserves for trading.
"""

import logging
from typing import Dict, List, Tuple, Optional
from decimal import Decimal
import ccxt
import time
import asyncio

class AutoPortfolioRebalancer:
    """
    Automatically rebalances portfolio to maintain USDT trading capacity
    """
    
    def __init__(self, exchange: ccxt.Exchange, config: Dict):
        self.exchange = exchange
        self.config = config
        self.logger = logging.getLogger(__name__)
        
        # Configuration parameters
        self.min_usdt_balance = config.get('MIN_USDT_BALANCE', 1.50)
        self.target_usdt_ratio = config.get('TARGET_USDT_RATIO', 0.30)  # 30% in USDT
        self.min_conversion_profit = config.get('MIN_CONVERSION_PROFIT', 0.01)  # 1% minimum profit
        self.max_conversion_per_cycle = config.get('MAX_CONVERSION_PER_CYCLE', 0.50)  # Max 50% of position
        self.conversion_cooldown = config.get('CONVERSION_COOLDOWN', 300)  # 5 minutes between conversions
        
        self.last_conversion_time = {}  # Track conversion timing per symbol
        
    async def check_and_rebalance_portfolio(self) -> bool:
        """
        Main entry point - checks if rebalancing is needed and executes it
        
        Returns:
            bool: True if rebalancing was performed, False otherwise
        """
        try:
            # Get current portfolio state
            portfolio = await self.get_portfolio_balances()
            usdt_balance = portfolio.get('USDT', 0.0)
            total_equity = sum(portfolio.values())
            
            self.logger.info(f"💰 Portfolio Check - USDT: ${usdt_balance:.2f} | Total: ${total_equity:.2f}")
            
            # Check if rebalancing is needed
            if self.needs_rebalancing(usdt_balance, total_equity):
                self.logger.info("🔄 Auto-rebalancing triggered - insufficient USDT for trading")
                return await self.execute_rebalancing(portfolio)
            
            return False
            
        except Exception as e:
            self.logger.error(f"❌ Portfolio rebalancing error: {e}")
            return False
    
    def needs_rebalancing(self, usdt_balance: float, total_equity: float) -> bool:
        """
        Determine if portfolio rebalancing is needed
        
        Args:
            usdt_balance: Current USDT balance
            total_equity: Total portfolio value
            
        Returns:
            bool: True if rebalancing needed
        """
        # Check absolute minimum USDT requirement
        if usdt_balance < self.min_usdt_balance:
            return True
        
        # Check USDT ratio requirement
        usdt_ratio = usdt_balance / total_equity if total_equity > 0 else 0
        if usdt_ratio < self.target_usdt_ratio:
            return True
            
        return False
    
    async def execute_rebalancing(self, portfolio: Dict[str, float]) -> bool:
        """
        Execute portfolio rebalancing by converting altcoins to USDT
        
        Args:
            portfolio: Dictionary of symbol -> balance values
            
        Returns:
            bool: True if any conversions were made
        """
        conversions_made = False
        usdt_needed = self.calculate_usdt_needed(portfolio)
        
        # Get conversion candidates (profitable altcoin positions)
        conversion_candidates = await self.get_conversion_candidates(portfolio)
        
        self.logger.info(f"💡 Need ${usdt_needed:.2f} USDT | Found {len(conversion_candidates)} conversion candidates")
        
        # Execute conversions in order of profitability
        usdt_acquired = 0.0
        for candidate in conversion_candidates:
            if usdt_acquired >= usdt_needed:
                break
                
            conversion_amount = await self.execute_conversion(candidate, usdt_needed - usdt_acquired)
            if conversion_amount > 0:
                usdt_acquired += conversion_amount
                conversions_made = True
                
                self.logger.info(f"✅ Converted {candidate['symbol']}: +${conversion_amount:.2f} USDT")
                
                # Cooldown between conversions
                await self.apply_conversion_cooldown()
        
        if conversions_made:
            self.logger.info(f"🎯 Rebalancing complete: +${usdt_acquired:.2f} USDT acquired")
        else:
            self.logger.warning("⚠️ No profitable conversions available")
            
        return conversions_made
    
    def calculate_usdt_needed(self, portfolio: Dict[str, float]) -> float:
        """Calculate how much USDT is needed for optimal trading"""
        total_equity = sum(portfolio.values())
        current_usdt = portfolio.get('USDT', 0.0)
        target_usdt = total_equity * self.target_usdt_ratio
        
        return max(0, target_usdt - current_usdt, self.min_usdt_balance - current_usdt)
    
    async def get_conversion_candidates(self, portfolio: Dict[str, float]) -> List[Dict]:
        """
        Get altcoins that are good candidates for conversion to USDT
        
        Args:
            portfolio: Current portfolio balances
            
        Returns:
            List of conversion candidates sorted by profitability
        """
        candidates = []
        
        for symbol, balance in portfolio.items():
            if symbol == 'USDT' or balance <= 0:
                continue
                
            # Check if conversion cooldown is active
            if self.is_conversion_on_cooldown(symbol):
                continue
                
            # Get current market data
            market_data = await self.get_market_data(symbol)
            if not market_data:
                continue
                
            # Calculate profitability and conversion potential
            candidate = await self.evaluate_conversion_candidate(symbol, balance, market_data)
            if candidate and candidate['profit_pct'] >= self.min_conversion_profit:
                candidates.append(candidate)
        
        # Sort by profitability (highest first)
        candidates.sort(key=lambda x: x['profit_pct'], reverse=True)
        return candidates
    
    async def evaluate_conversion_candidate(self, symbol: str, balance: float, 
                                         market_data: Dict) -> Optional[Dict]:
        """
        Evaluate if a position is a good candidate for conversion
        
        Args:
            symbol: Trading symbol (e.g., 'BTC')
            balance: Current balance in the asset
            market_data: Current market price data
            
        Returns:
            Dict with conversion candidate info or None
        """
        try:
            current_price = market_data['price']
            current_value = balance * current_price
            
            # Get average purchase price (if available)
            avg_purchase_price = await self.get_average_purchase_price(symbol)
            if not avg_purchase_price:
                return None
                
            # Calculate profit/loss
            purchase_value = balance * avg_purchase_price
            profit_loss = current_value - purchase_value
            profit_pct = (profit_loss / purchase_value) * 100 if purchase_value > 0 else 0
            
            # Only consider profitable positions or small losses
            if profit_pct < -5.0:  # Don't sell at more than 5% loss
                return None
                
            return {
                'symbol': symbol,
                'balance': balance,
                'current_price': current_price,
                'current_value': current_value,
                'avg_purchase_price': avg_purchase_price,
                'profit_loss': profit_loss,
                'profit_pct': profit_pct,
                'convertible_amount': min(balance * self.max_conversion_per_cycle, balance)
            }
            
        except Exception as e:
            self.logger.error(f"❌ Error evaluating {symbol}: {e}")
            return None
    
    async def execute_conversion(self, candidate: Dict, max_usdt_needed: float) -> float:
        """
        Execute the actual conversion of altcoin to USDT
        
        Args:
            candidate: Conversion candidate info
            max_usdt_needed: Maximum USDT amount needed
            
        Returns:
            float: Amount of USDT acquired from conversion
        """
        try:
            symbol = candidate['symbol']
            current_price = candidate['current_price']
            max_convertible = candidate['convertible_amount']
            
            # Calculate optimal conversion amount
            usdt_from_max = max_convertible * current_price
            conversion_usdt = min(usdt_from_max, max_usdt_needed)
            conversion_amount = conversion_usdt / current_price
            
            # Execute the sell order
            self.logger.info(f"🔄 Converting {conversion_amount:.6f} {symbol} to USDT @ ${current_price:.2f}")
            
            order = await self.execute_market_sell(symbol, conversion_amount)
            if order and order.get('filled', 0) > 0:
                usdt_received = order['filled'] * order['average']
                
                # Record the conversion
                self.record_conversion(symbol, conversion_amount, usdt_received)
                return usdt_received
            
            return 0.0
            
        except Exception as e:
            self.logger.error(f"❌ Conversion execution error for {candidate['symbol']}: {e}")
            return 0.0
    
    async def execute_market_sell(self, symbol: str, amount: float) -> Optional[Dict]:
        """Execute a market sell order"""
        try:
            trading_pair = f"{symbol}/USDT"
            order = await self.exchange.create_market_sell_order(trading_pair, amount)
            
            # Wait a moment for order to be processed
            await asyncio.sleep(1)
            
            # Fetch order details
            order_status = await self.exchange.fetch_order(order['id'], trading_pair)
            return order_status
            
        except Exception as e:
            self.logger.error(f"❌ Market sell error for {symbol}: {e}")
            return None
    
    def record_conversion(self, symbol: str, amount_sold: float, usdt_received: float):
        """Record conversion details for tracking"""
        self.last_conversion_time[symbol] = time.time()
        
        self.logger.info(f"📊 CONVERSION RECORD: {symbol}")
        self.logger.info(f"   Amount Sold: {amount_sold:.6f} {symbol}")
        self.logger.info(f"   USDT Received: ${usdt_received:.2f}")
        self.logger.info(f"   Effective Price: ${usdt_received/amount_sold:.2f}")
    
    def is_conversion_on_cooldown(self, symbol: str) -> bool:
        """Check if a symbol is on conversion cooldown"""
        if symbol not in self.last_conversion_time:
            return False
            
        time_since_last = time.time() - self.last_conversion_time[symbol]
        return time_since_last < self.conversion_cooldown
    
    async def apply_conversion_cooldown(self):
        """Apply cooldown between conversions"""
        await asyncio.sleep(1)  # Brief pause between conversions
    
    # Helper methods (implementation stubs - integrate with your existing bot)
    
    async def get_portfolio_balances(self) -> Dict[str, float]:
        """Get current portfolio balances in USDT value"""
        try:
            balance = await self.exchange.fetch_balance()
            portfolio = {}
            
            for symbol, amounts in balance.items():
                if symbol == 'USDT':
                    portfolio[symbol] = amounts['free']
                elif amounts['total'] > 0:
                    # Convert to USDT value
                    market_data = await self.get_market_data(symbol)
                    if market_data:
                        portfolio[symbol] = amounts['total'] * market_data['price']
            
            return portfolio
            
        except Exception as e:
            self.logger.error(f"❌ Error fetching portfolio balances: {e}")
            return {}
    
    async def get_market_data(self, symbol: str) -> Optional[Dict]:
        """Get current market data for a symbol"""
        try:
            ticker = await self.exchange.fetch_ticker(f"{symbol}/USDT")
            return {'price': ticker['last']}
        except:
            return None
    
    async def get_average_purchase_price(self, symbol: str) -> Optional[float]:
        """Get average purchase price for a symbol (integrate with your tracking)"""
        # This should integrate with your existing position tracking
        # For now, using a simple fallback
        try:
            # Get recent trades to estimate average price
            trades = await self.exchange.fetch_my_trades(f"{symbol}/USDT", limit=50)
            if trades:
                buy_trades = [t for t in trades if t['side'] == 'buy']
                if buy_trades:
                    total_cost = sum(t['cost'] for t in buy_trades)
                    total_amount = sum(t['amount'] for t in buy_trades)
                    return total_cost / total_amount if total_amount > 0 else None
            return None
        except:
            return None


# Integration function for existing trading bot
async def integrate_auto_rebalancer(exchange, config, min_usdt_balance: float) -> bool:
    """
    Integration function to add auto-rebalancing to existing trading bot
    
    Usage:
        # Before executing any buy orders, check if rebalancing is needed
        if usdt_balance < MIN_BUY_USDT:
            rebalanced = await integrate_auto_rebalancer(exchange, config, MIN_BUY_USDT)
            if rebalanced:
                # Refresh balance and continue with trading logic
                usdt_balance = get_updated_usdt_balance()
    """
    rebalancer_config = {
        'MIN_USDT_BALANCE': min_usdt_balance,
        'TARGET_USDT_RATIO': 0.25,  # Keep 25% in USDT for trading
        'MIN_CONVERSION_PROFIT': 0.5,  # Only convert positions with 0.5%+ profit
        'MAX_CONVERSION_PER_CYCLE': 0.30,  # Max 30% of any position per cycle
        'CONVERSION_COOLDOWN': 180,  # 3 minutes between conversions
    }
    
    rebalancer = AutoPortfolioRebalancer(exchange, rebalancer_config)
    return await rebalancer.check_and_rebalance_portfolio()


if __name__ == "__main__":
    # Example usage
    logging.basicConfig(level=logging.INFO)
    
    # This would be integrated into your existing trading bot
    print("Auto Portfolio Rebalancer - Ready for integration")
    print("Features:")
    print("- Automatically converts profitable altcoins to USDT")
    print("- Maintains minimum USDT balance for continuous trading")
    print("- Configurable profit thresholds and conversion limits")
    print("- Full audit logging of all rebalancing activities")