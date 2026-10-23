# Fleet Selection Strategy Design

## Overview

The Fleet Selection Strategy system provides a pluggable, configurable approach for selecting fleet for Kafka clusters. The system supports multiple selection strategies with configurable primary and fallback strategies via environment variables.

## Architecture

### Core Components

1. **FleetSelectionStrategy** - Abstract base class for all strategies
2. **FleetSelectionService** - Central service managing strategy execution
3. **Strategy Registry** - Dynamic strategy registration and discovery
4. **Configuration System** - Environment-based strategy configuration

### Strategy Types

#### First Fit Strategy
- **Purpose**: Quick placement by selecting the first suitable fleet
- **Use Case**: When speed of placement is more important than optimization
- **Selection Criteria**: First fleet with sufficient capacity
- **Performance**: O(n) where n is the number of available fleet

#### Best Fit Strategy
- **Purpose**: Optimal placement considering multiple factors
- **Use Case**: When cost optimization and performance are important
- **Selection Criteria**: 
  - 40% weight on utilization (prefer less utilized fleet)
  - 30% weight on cost (prefer lower cost)
  - 20% weight on performance (prefer higher performance)
  - 10% weight on load (prefer lower load)
- **Performance**: O(n) where n is the number of available fleet

#### Load Balanced Strategy
- **Purpose**: Even distribution of load across fleet
- **Use Case**: When maintaining balanced fleet utilization is critical
- **Selection Criteria**: Fleet with the lowest current load
- **Fallback**: Uses utilization metrics when load metrics are unavailable
- **Performance**: O(n) where n is the number of available fleet

## Configuration

### Environment Variables

The system supports configuration via environment variables in `docker-compose.yaml`:

```yaml
environment:
  # Primary strategy (required)
  FLEET_SELECTION_PRIMARY_STRATEGY: "best_fit"
  
  # Fallback strategy (optional, defaults to first_fit)
  FLEET_SELECTION_FALLBACK_STRATEGY: "first_fit"
  
  # Enable strategy fallback on failure (default: true)
  FLEET_SELECTION_ENABLE_FALLBACK: "true"
  
  # Log strategy selection decisions (default: false)
  FLEET_SELECTION_DEBUG_LOGGING: "false"
```

### Strategy Configuration

Strategies can be configured with custom parameters:

```yaml
environment:
  # Best fit strategy weights (optional)
  FLEET_SELECTION_BEST_FIT_UTILIZATION_WEIGHT: "0.4"
  FLEET_SELECTION_BEST_FIT_COST_WEIGHT: "0.3"
  FLEET_SELECTION_BEST_FIT_PERFORMANCE_WEIGHT: "0.2"
  FLEET_SELECTION_BEST_FIT_LOAD_WEIGHT: "0.1"
  
  # Load balanced strategy time windows (optional)
  FLEET_SELECTION_LOAD_1H_WEIGHT: "0.5"
  FLEET_SELECTION_LOAD_24H_WEIGHT: "0.2"
  FLEET_SELECTION_LOAD_1W_WEIGHT: "0.1"
  FLEET_SELECTION_LOAD_TENANT_WEIGHT: "0.15"
  FLEET_SELECTION_LOAD_NOISY_WEIGHT: "0.05"
```

## Adding New Strategies

### Step 1: Create Strategy Class

Create a new strategy class in `fleet-manager-backend/core/fleet_selection.py`:

```python
class CustomStrategy(FleetSelectionStrategy):
    """Custom strategy implementation."""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config or {}
        self.custom_weight = self.config.get('custom_weight', 0.5)
    
    def select_fleet(
        self,
        candidates: List[FleetCandidate],
        cluster_requirements: Dict[str, Any]
    ) -> FleetCandidate:
        """Select fleet using custom logic."""
        suitable = self._filter_suitable_candidates(candidates, cluster_requirements)
        
        if not suitable:
            available_infra = [c.fleet.identifier for c in candidates]
            hints = self._generate_hints(cluster_requirements, available_infra)
            raise NoSuitableFleetError(cluster_requirements, available_infra, hints)
        
        # Custom selection logic here
        return self._custom_selection_logic(suitable, cluster_requirements)
    
    def _custom_selection_logic(self, candidates: List[FleetCandidate], requirements: Dict[str, Any]) -> FleetCandidate:
        """Implement custom selection logic."""
        # Your custom logic here
        pass
```

### Step 2: Register Strategy

Add the strategy to the registry in `FleetSelectionService`:

```python
class FleetSelectionService:
    def __init__(self):
        self._strategies = {
            FleetSelectionStrategyType.FIRST_FIT: FirstFitStrategy(),
            FleetSelectionStrategyType.BEST_FIT: BestFitStrategy(),
            FleetSelectionStrategyType.LOAD_BALANCED: LoadBalancedStrategy(),
            FleetSelectionStrategyType.CUSTOM: CustomStrategy(),  # Add your strategy
        }
```

### Step 3: Add Strategy Type

Add the new strategy type to the enum:

```python
class FleetSelectionStrategyType(str, Enum):
    """Available fleet selection strategies."""
    FIRST_FIT = "first_fit"
    BEST_FIT = "best_fit"
    LOAD_BALANCED = "load_balanced"
    CUSTOM = "custom"  # Add your strategy type
```

### Step 4: Add Configuration Support

Update the configuration system to support your strategy:

```python
def _get_strategy_config(self, strategy_type: FleetSelectionStrategyType) -> Dict[str, Any]:
    """Get configuration for a specific strategy."""
    config = {}
    
    if strategy_type == FleetSelectionStrategyType.CUSTOM:
        config = {
            'custom_weight': float(os.getenv('FLEET_SELECTION_CUSTOM_WEIGHT', '0.5')),
            'custom_threshold': float(os.getenv('FLEET_SELECTION_CUSTOM_THRESHOLD', '0.8')),
        }
    
    return config
```

### Step 5: Add Tests

Create comprehensive tests for your strategy:

```python
class TestCustomStrategy(TestCase):
    """Test CustomStrategy implementation."""
    
    def setUp(self):
        self.strategy = CustomStrategy({'custom_weight': 0.7})
    
    def test_select_fleet_success(self):
        """Test successful fleet selection."""
        # Your test logic here
        pass
    
    def test_select_fleet_no_candidates(self):
        """Test error handling when no suitable candidates."""
        # Your test logic here
        pass
```

### Step 6: Update Documentation

1. Add strategy description to `fleet-manager-backend/README.md`
2. Add configuration options to `docs/fleet-selection-strategy-design.md`
3. Add usage examples

## Error Handling

### Strategy Fallback

The system supports automatic fallback to a secondary strategy when the primary strategy fails:

1. **Primary Strategy Failure**: If the primary strategy raises an exception
2. **No Suitable Fleet**: If no fleet meets the requirements
3. **Configuration Error**: If strategy configuration is invalid

### Error Types

- **NoSuitableFleetError**: No fleet meets requirements
- **StrategyConfigurationError**: Invalid strategy configuration
- **StrategyExecutionError**: Strategy execution failed

### Error Recovery

1. **Log Error**: Log the failure with context
2. **Try Fallback**: Attempt fallback strategy if enabled
3. **Return Error**: Return descriptive error with hints

## Performance Considerations

### Strategy Selection

- **First Fit**: Fastest selection, minimal computation
- **Best Fit**: Moderate computation, good optimization
- **Load Balanced**: Requires load metrics, may be slower

### Caching

Strategies can implement caching for expensive operations:

```python
class CachedStrategy(FleetSelectionStrategy):
    def __init__(self):
        self._cache = {}
        self._cache_ttl = 300  # 5 minutes
    
    def _get_cached_result(self, key: str) -> Optional[Any]:
        """Get cached result if still valid."""
        if key in self._cache:
            result, timestamp = self._cache[key]
            if time.time() - timestamp < self._cache_ttl:
                return result
            else:
                del self._cache[key]
        return None
```

## Monitoring and Observability

### Metrics

The system provides metrics for monitoring:

- `fleet_selection_requests_total`: Total selection requests
- `fleet_selection_duration_seconds`: Selection duration
- `fleet_selection_strategy_usage`: Strategy usage counts
- `fleet_selection_fallback_usage`: Fallback usage counts

### Logging

Enable debug logging for detailed strategy decisions:

```yaml
environment:
  FLEET_SELECTION_DEBUG_LOGGING: "true"
```

### Health Checks

The system provides health check endpoints:

- `/health/fleet-selection`: Overall system health
- `/health/fleet-selection/strategies`: Strategy availability
- `/health/fleet-selection/config`: Configuration validation

## Security Considerations

### Input Validation

All strategy inputs are validated:

- **Cluster Requirements**: Validated against schema
- **Fleet Candidates**: Sanitized and validated
- **Configuration**: Validated on startup

### Access Control

Strategy selection respects existing access controls:

- **Organization Scoping**: Only fleet in the same organization
- **Permission Checks**: Respects user permissions
- **Audit Logging**: All selections are logged

## Migration Guide

### From Inline Logic

1. **Identify Current Logic**: Find existing fleet selection code
2. **Extract to Strategy**: Move logic to a custom strategy class
3. **Update Service Calls**: Replace inline logic with service calls
4. **Test Thoroughly**: Ensure behavior is preserved
5. **Deploy Gradually**: Use feature flags for gradual rollout

### Configuration Migration

1. **Set Defaults**: Ensure sensible defaults for all strategies
2. **Document Changes**: Update configuration documentation
3. **Provide Examples**: Include configuration examples
4. **Test Configurations**: Validate all configuration combinations

## Troubleshooting

### Common Issues

1. **Strategy Not Found**: Check strategy registration and configuration
2. **Configuration Invalid**: Validate environment variables
3. **Performance Issues**: Check strategy complexity and caching
4. **Memory Usage**: Monitor strategy object lifecycle

### Debug Commands

```bash
# Check strategy configuration
docker exec backend python manage.py shell -c "
from core.fleet_selection import FleetSelectionService
service = FleetSelectionService()
print('Available strategies:', list(service._strategies.keys()))
print('Primary strategy:', service.get_primary_strategy())
print('Fallback strategy:', service.get_fallback_strategy())
"

# Test strategy selection
docker exec backend python manage.py shell -c "
from core.fleet_selection import FleetSelectionService, FleetSelectionStrategyType
from core.models import Fleet, Organization
service = FleetSelectionService()
# Test your strategy here
"
```

## Future Enhancements

### Planned Features

1. **Machine Learning**: ML-based strategy optimization
2. **Real-time Metrics**: Integration with monitoring systems
3. **Custom Scoring**: User-defined scoring functions
4. **Multi-objective**: Advanced optimization algorithms
5. **A/B Testing**: Strategy performance comparison

### Extension Points

1. **Custom Data Sources**: Pluggable data providers
2. **Custom Metrics**: User-defined performance metrics
3. **Custom Constraints**: Additional selection constraints
4. **Custom Hints**: Custom error message generation
