#!/usr/bin/env python3
"""
Advanced Bot Integration Module
Seamless integration for existing trading bots with real-time auto-conversion

This module provides drop-in integration for any existing trading bot,
automatically solving USDT shortage issues without requiring code changes.

Usage:
    # Single line integration
    from bot_integration_module import ensure_trading_liquidity
    
    # In your trading loop
    usdt_available = await ensure_trading_liquidity(exchange, min_needed=1.50)
    if usdt_available >= 1.50:
        # Execute your buy logic
        pass
"""

import asyncio
import logging
from typing import Dict, Any, Optional
from datetime import datetime
from smart_portfolio_manager import SmartPortfolioManager, ConversionStrategy


class BotIntegrationModule:
    """
    Advanced integration module for seamless auto-conversion
    Designed for zero-friction integration with existing trading bots
    """
    
    _instance = None
    _initialized = False
    
    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self, exchange=None, config: Dict = None):
        if self._initialized:
            return
            
        self.exchange = exchange
        self.config = config or {}
        self.logger = logging.getLogger(__name__)
        
        # Integration settings
        self.auto_conversion_enabled = True
        self.monitoring_enabled = True
        self.performance_tracking = True
        
        # Performance metrics
        self.total_conversions = 0
        self.total_usdt_converted = 0.0
        self.total_fees_paid = 0.0
        self.successful_integrations = 0
        self.failed_integrations = 0
        
        # Smart portfolio manager instance
        self.portfolio_manager = None
        
        self._initialized = True
    
    async def initialize(self, exchange, config: Dict = None):
        """Initialize the integration module"""
        self.exchange = exchange
        if config:
            self.config.update(config)
        
        # Initialize smart portfolio manager
        enhanced_config = self._build_enhanced_config()
        self.portfolio_manager = SmartPortfolioManager(exchange, enhanced_config)
        await self.portfolio_manager.initialize()
        
        self.logger.info("🤖 Bot Integration Module initialized - Auto-conversion active")
    
    def _build_enhanced_config(self) -> Dict:
        """Build enhanced configuration for optimal performance"""
        return {
            'MIN_USDT_THRESHOLD': self.config.get('MIN_BUY_USDT', 1.50),
            'TARGET_USDT_RATIO': 0.20,  # Keep 20% in USDT (optimized for small accounts)
            'EMERGENCY_THRESHOLD': 0.30,  # Emergency when USDT < $0.30
            'MAX_POSITION_CONVERSION': 0.30,  # Max 30% per conversion
            'CONVERSION_COOLDOWN': 30,  # 30 second cooldown for rapid response
            'FEE_FACTOR': 0.001,
            # Enable all dark gray features for maximum performance
            'PREDICTIVE_CONVERSION': True,
            'WHALE_FOLLOWING': False,  # Disabled by default
            'ARBITRAGE_CAPTURE': True,
            'FLASH_LOAN': False,  # Requires additional setup
        }


# ================== MAIN INTEGRATION FUNCTIONS ==================

async def ensure_trading_liquidity(
    exchange,
    min_needed: float = 1.50,
    force_conversion: bool = False,
    enable_dark_features: bool = True
) -> float:
    """
    🎯 MAIN INTEGRATION FUNCTION - SOLVES USDT SHORTAGE AUTOMATICALLY
    
    This is the primary function to integrate with your existing trading bot.
    Call this before any buy operations to ensure sufficient USDT availability.
    
    Args:
        exchange: Your CCXT exchange instance
        min_needed: Minimum USDT required for trading
        force_conversion: Force conversion even if balance seems sufficient
        enable_dark_features: Enable advanced optimization features
        
    Returns:
        float: Available USDT balance after any necessary conversions
        
    Example Usage:
        # In your existing trading bot loop
        usdt_balance = await ensure_trading_liquidity(exchange, min_needed=1.50)
        
        if usdt_balance >= 1.50:
            # Execute your buy logic here
            await execute_buy_order()
        else:
            logging.info(f"Still insufficient USDT: {usdt_balance}")
    """
    
    # Get or create integration module instance
    integration = BotIntegrationModule()
    
    if not integration._initialized or not integration.portfolio_manager:
        # Initialize if not already done
        config = {'MIN_BUY_USDT': min_needed}
        await integration.initialize(exchange, config)
    
    try:
        start_time = time.time()
        
        # Get current USDT balance
        balance_data = await exchange.fetch_balance()
        current_usdt = balance_data.get('USDT', {}).get('free', 0.0)
        
        integration.logger.info(f"🔍 Liquidity Check: Current USDT ${current_usdt:.2f} | Need ${min_needed:.2f}")
        
        # If sufficient USDT available, return immediately
        if current_usdt >= min_needed and not force_conversion:
            integration.successful_integrations += 1
            return current_usdt
        
        # Insufficient USDT - trigger auto-conversion
        integration.logger.warning(f"⚡ USDT SHORTAGE DETECTED: ${current_usdt:.2f} < ${min_needed:.2f}")
        
        # Determine conversion strategy based on shortage severity
        shortage_pct = (min_needed - current_usdt) / min_needed
        
        if shortage_pct > 0.8:  # >80% shortage
            strategy = ConversionStrategy.EMERGENCY
        elif shortage_pct > 0.5:  # >50% shortage
            strategy = ConversionStrategy.AGGRESSIVE
        else:
            strategy = ConversionStrategy.BALANCED
        
        # Execute conversion
        conversion_result = await integration.portfolio_manager.check_and_execute_conversion(strategy)
        
        if conversion_result:
            # Get updated balance
            updated_balance = await exchange.fetch_balance()
            final_usdt = updated_balance.get('USDT', {}).get('free', 0.0)
            
            # Update performance metrics
            integration.total_conversions += 1
            integration.successful_integrations += 1
            
            execution_time = time.time() - start_time
            integration.logger.info(f"✅ Auto-conversion successful: ${current_usdt:.2f} → ${final_usdt:.2f} in {execution_time:.2f}s")
            
            return final_usdt
        else:
            integration.failed_integrations += 1
            integration.logger.error("❌ Auto-conversion failed - no viable positions to convert")
            return current_usdt
            
    except Exception as e:
        integration.failed_integrations += 1
        integration.logger.error(f"❌ Liquidity management error: {e}")
        return 0.0


async def emergency_usdt_injection(
    exchange,
    target_amount: float,
    ignore_profit_loss: bool = False
) -> Dict:
    """
    🆘 EMERGENCY FUNCTION - IMMEDIATE USDT CONVERSION
    
    For critical trading opportunities that require immediate liquidity.
    Will convert positions regardless of profit/loss if ignore_profit_loss=True.
    
    Args:
        exchange: CCXT exchange instance
        target_amount: Target USDT amount needed immediately
        ignore_profit_loss: Convert even losing positions if necessary
        
    Returns:
        Dict: Emergency conversion results
        
    Example Usage:
        # For critical trading opportunities
        result = await emergency_usdt_injection(exchange, target_amount=5.00)
        if result['success']:
            print(f"Emergency injection: {result['usdt_acquired']} USDT")
    """
    
    integration = BotIntegrationModule()
    
    if not integration.portfolio_manager:
        # Quick initialization for emergency
        config = {'MIN_BUY_USDT': target_amount}
        await integration.initialize(exchange, config)
    
    start_time = time.time()
    
    try:
        # Execute emergency liquidity injection
        success = await integration.portfolio_manager.emergency_liquidity_injection(target_amount)
        
        # Get final balance
        balance_data = await exchange.fetch_balance()
        final_usdt = balance_data.get('USDT', {}).get('free', 0.0)
        
        execution_time = time.time() - start_time
        
        result = {
            'success': success,
            'target_amount': target_amount,
            'usdt_acquired': final_usdt,
            'execution_time': execution_time,
            'timestamp': datetime.now()
        }
        
        if success:
            integration.logger.critical(f"🆘 EMERGENCY SUCCESS: ${final_usdt:.2f} USDT in {execution_time:.2f}s")
        else:
            integration.logger.error(f"❌ EMERGENCY FAILED: Only ${final_usdt:.2f} USDT available")
        
        return result
        
    except Exception as e:
        return {
            'success': False,
            'error': str(e),
            'target_amount': target_amount,
            'usdt_acquired': 0.0,
            'execution_time': time.time() - start_time
        }


async def get_portfolio_health_report(exchange) -> Dict:
    """
    📈 DIAGNOSTIC FUNCTION - COMPREHENSIVE PORTFOLIO ANALYSIS
    
    Provides detailed analysis of portfolio health and conversion potential.
    Useful for debugging and optimization.
    
    Args:
        exchange: CCXT exchange instance
        
    Returns:
        Dict: Comprehensive portfolio health report
    """
    
    integration = BotIntegrationModule()
    
    try:
        if not integration.portfolio_manager:
            await integration.initialize(exchange)
        
        # Get real-time portfolio
        portfolio = await integration.portfolio_manager._get_real_time_portfolio()
        
        # Analyze portfolio composition
        usdt_balance = portfolio.get('USDT', 0.0)
        positions = {k: v for k, v in portfolio.items() if k != 'USDT'}
        total_altcoin_value = sum(pos.current_value for pos in positions.values())
        total_equity = usdt_balance + total_altcoin_value
        
        # Analyze profit/loss distribution
        profitable_positions = {k: v for k, v in positions.items() if v.unrealized_pnl_pct > 0}
        losing_positions = {k: v for k, v in positions.items() if v.unrealized_pnl_pct < 0}
        
        profitable_value = sum(pos.current_value for pos in profitable_positions.values())
        losing_value = sum(pos.current_value for pos in losing_positions.values())
        
        # Calculate conversion potential
        convertible_value = sum(
            pos.current_value * 0.3 for pos in profitable_positions.values()
            if pos.unrealized_pnl_pct > 0.5  # Only convert profitable positions
        )
        
        # Trading capacity analysis
        current_trading_capacity = usdt_balance
        potential_trading_capacity = usdt_balance + convertible_value
        
        report = {
            'timestamp': datetime.now(),
            'portfolio_composition': {
                'usdt_balance': usdt_balance,
                'usdt_ratio': usdt_balance / total_equity * 100 if total_equity > 0 else 0,
                'altcoin_count': len(positions),
                'altcoin_value': total_altcoin_value,
                'total_equity': total_equity
            },
            'profit_analysis': {
                'profitable_positions': len(profitable_positions),
                'losing_positions': len(losing_positions),
                'profitable_value': profitable_value,
                'losing_value': losing_value,
                'net_unrealized_pnl': sum(pos.unrealized_pnl for pos in positions.values())
            },
            'trading_capacity': {
                'current_capacity': current_trading_capacity,
                'potential_capacity': potential_trading_capacity,
                'convertible_value': convertible_value,
                'capacity_increase_potential': potential_trading_capacity - current_trading_capacity
            },
            'conversion_readiness': {
                'can_convert_immediately': convertible_value > 0,
                'emergency_conversion_possible': total_altcoin_value > 0,
                'recommended_strategy': integration.portfolio_manager._determine_conversion_strategy(usdt_balance, total_equity).value if integration.portfolio_manager else 'balanced'
            },
            'performance_metrics': {
                'total_conversions': integration.total_conversions,
                'successful_integrations': integration.successful_integrations,
                'failed_integrations': integration.failed_integrations,
                'success_rate': integration.successful_integrations / max(1, integration.successful_integrations + integration.failed_integrations) * 100
            }
        }
        
        # Generate recommendations
        recommendations = []
        
        if usdt_balance < 1.0:
            recommendations.append("⚡ CRITICAL: USDT balance critically low - immediate conversion recommended")
        
        if len(profitable_positions) > 0 and convertible_value > 2.0:
            recommendations.append(f"💰 OPPORTUNITY: ${convertible_value:.2f} available for profitable conversion")
        
        if report['portfolio_composition']['usdt_ratio'] < 15:
            recommendations.append("📊 OPTIMIZATION: Consider maintaining 15-25% USDT ratio for optimal trading")
        
        if len(positions) > 5:
            recommendations.append("🎯 SIMPLIFICATION: Consider consolidating positions to improve liquidity management")
        
        report['recommendations'] = recommendations
        
        return report
        
    except Exception as e:
        return {
            'error': str(e),
            'timestamp': datetime.now(),
            'status': 'ERROR - Unable to generate portfolio health report'
        }


# ================== SIMPLE INTEGRATION FUNCTIONS ==================

async def solve_usdt_shortage(exchange, min_usdt: float = 1.50) -> bool:
    """
    🎯 SIMPLE SOLUTION - ONE FUNCTION TO SOLVE EVERYTHING
    
    Call this function whenever your bot shows "BUY skipped" due to insufficient USDT.
    It will automatically convert profitable positions and return True if successful.
    
    Args:
        exchange: Your CCXT exchange instance  
        min_usdt: Minimum USDT needed
        
    Returns:
        bool: True if USDT shortage was resolved
        
    Usage:
        if usdt_balance < MIN_BUY_USDT:
            if await solve_usdt_shortage(exchange, MIN_BUY_USDT):
                # Refresh balance and continue trading
                usdt_balance = get_fresh_usdt_balance()
    """
    
    result_balance = await ensure_trading_liquidity(exchange, min_usdt)
    return result_balance >= min_usdt


async def smart_balance_check(exchange, min_usdt: float = 1.50) -> Dict:
    """
    📈 SMART BALANCE CHECK - COMPREHENSIVE LIQUIDITY ANALYSIS
    
    Performs intelligent balance check with conversion recommendations.
    More detailed than simple liquidity check.
    
    Args:
        exchange: CCXT exchange instance
        min_usdt: Minimum USDT required
        
    Returns:
        Dict: Comprehensive balance analysis with recommendations
    """
    
    integration = BotIntegrationModule()
    if not integration._initialized:
        await integration.initialize(exchange)
    
    # Get current balance state
    balance_data = await exchange.fetch_balance()
    current_usdt = balance_data.get('USDT', {}).get('free', 0.0)
    
    # Generate health report
    health_report = await get_portfolio_health_report(exchange)
    
    # Determine action needed
    action_needed = "NONE"
    if current_usdt < min_usdt * 0.3:
        action_needed = "EMERGENCY_CONVERSION"
    elif current_usdt < min_usdt:
        action_needed = "AUTO_CONVERSION"
    elif health_report.get('portfolio_composition', {}).get('usdt_ratio', 0) < 15:
        action_needed = "REBALANCING"
    
    return {
        'current_usdt': current_usdt,
        'required_usdt': min_usdt,
        'shortage_amount': max(0, min_usdt - current_usdt),
        'action_needed': action_needed,
        'can_auto_convert': health_report.get('conversion_readiness', {}).get('can_convert_immediately', False),
        'potential_usdt_from_conversion': health_report.get('trading_capacity', {}).get('capacity_increase_potential', 0),
        'health_report': health_report,
        'timestamp': datetime.now()
    }


async def monitor_and_maintain_liquidity(
    exchange,
    min_usdt: float = 1.50,
    check_interval: int = 300  # 5 minutes
):
    """
    🔄 BACKGROUND MONITORING - CONTINUOUS LIQUIDITY MANAGEMENT
    
    Runs in background to continuously monitor and maintain USDT liquidity.
    Perfect for long-running trading bots that need autonomous operation.
    
    Args:
        exchange: CCXT exchange instance
        min_usdt: Minimum USDT to maintain
        check_interval: Seconds between checks
        
    Usage:
        # Start background monitoring
        asyncio.create_task(monitor_and_maintain_liquidity(exchange, 1.50))
        
        # Your trading bot continues normally
        while True:
            # Your existing trading logic
            pass
    """
    
    integration = BotIntegrationModule()
    await integration.initialize(exchange)
    
    integration.logger.info(f"🔄 Starting background liquidity monitoring - checking every {check_interval}s")
    
    while integration.monitoring_enabled:
        try:
            # Check and maintain liquidity
            current_usdt = await ensure_trading_liquidity(exchange, min_usdt)
            
            if current_usdt < min_usdt:
                integration.logger.warning(f"⚠️ Background monitoring: USDT still low after conversion attempt")
            else:
                integration.logger.info(f"✅ Background monitoring: Liquidity maintained at ${current_usdt:.2f}")
            
            await asyncio.sleep(check_interval)
            
        except Exception as e:
            integration.logger.error(f"❌ Background monitoring error: {e}")
            await asyncio.sleep(check_interval * 2)  # Longer delay on error


def get_integration_performance() -> Dict:
    """
    📊 PERFORMANCE ANALYTICS - INTEGRATION SUCCESS METRICS
    
    Returns detailed performance metrics for the integration module.
    Useful for optimization and troubleshooting.
    
    Returns:
        Dict: Performance metrics and statistics
    """
    
    integration = BotIntegrationModule()
    
    total_attempts = integration.successful_integrations + integration.failed_integrations
    success_rate = integration.successful_integrations / max(1, total_attempts) * 100
    
    return {
        'total_conversions_executed': integration.total_conversions,
        'total_usdt_converted': integration.total_usdt_converted,
        'total_fees_paid': integration.total_fees_paid,
        'successful_integrations': integration.successful_integrations,
        'failed_integrations': integration.failed_integrations,
        'success_rate_percent': success_rate,
        'average_usdt_per_conversion': integration.total_usdt_converted / max(1, integration.total_conversions),
        'average_fee_per_conversion': integration.total_fees_paid / max(1, integration.total_conversions),
        'net_usdt_efficiency': integration.total_usdt_converted - integration.total_fees_paid,
        'module_status': 'ACTIVE' if integration.monitoring_enabled else 'INACTIVE',
        'last_updated': datetime.now()
    }


# ================== ADVANCED FEATURES ==================

async def enable_predictive_liquidity_management(exchange, config: Dict = None):
    """
    🔮 PREDICTIVE FEATURE - PREVENT FUTURE SHORTAGES
    
    Enables predictive conversion that anticipates future USDT needs
    based on trading patterns and market conditions.
    
    Dark gray feature for advanced users.
    """
    
    integration = BotIntegrationModule()
    
    enhanced_config = config or {}
    enhanced_config.update({
        'PREDICTIVE_CONVERSION': True,
        'WHALE_FOLLOWING': False,
        'ARBITRAGE_CAPTURE': True
    })
    
    await integration.initialize(exchange, enhanced_config)
    
    integration.logger.info("🔮 Predictive liquidity management enabled")


if __name__ == "__main__":
    print("🤖 Advanced Bot Integration Module")
    print("\n🎯 Main Functions:")
    print("  • ensure_trading_liquidity() - Auto-solve USDT shortages")
    print("  • emergency_usdt_injection() - Immediate liquidity for opportunities")
    print("  • smart_balance_check() - Comprehensive liquidity analysis")
    print("  • monitor_and_maintain_liquidity() - Background automation")
    print("\n🕸️ Dark Gray Features:")
    print("  • Predictive conversion to prevent future shortages")
    print("  • Whale following for optimal timing")
    print("  • Arbitrage capture during conversions")
    print("  • Advanced profit protection algorithms")
    print("\nReady for seamless integration with any trading bot.")