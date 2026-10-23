# Plan: Reusable Package Version Configuration Component

## Overview

Create a reusable, schema-driven component for package version selection and Helm value preset management that can be used across different workload types without modifying UI code. The component will be driven by JSON Schema `ui:widget` hints and `ui:options` configuration.

## Goals

1. **Zero UI code changes** when adding new workload types that need package version configuration
2. **Schema-driven**: Backend controls component behavior through JSON Schema `ui:widget` and `ui:options`
3. **Reusable**: Same component works for fleet bootstrap, Kafka clusters, and any future workload types
4. **Maintainable**: Centralized configuration and logic
5. **Type-safe**: Proper TypeScript interfaces and validation

## Current State

### Problems
- `BOOTSTRAP_COMPONENT_PACKAGE_MAP` is hardcoded in `KubernetesFleetCreate.js`
- `BootstrapConfigEditor` has hardcoded component definitions
- Package loading logic is embedded in page components
- Adding new workloads requires UI code changes
- `bootstrap_config` is removed from schema and rendered separately

### Current Flow
1. Page component has hardcoded `BOOTSTRAP_COMPONENT_PACKAGE_MAP`
2. `loadPackageVersions()` iterates over map and fetches packages
3. `BootstrapConfigEditor` receives pre-loaded data as props
4. Component is rendered outside of RJSF form

## Target State

### Architecture
```
Backend Schema (JSON Schema + UI Schema)
    ↓
RJSF Form (react-jsonschema-form)
    ↓
Custom Widget (PackageVersionConfigWidget)
    ↓
PackageVersionConfigEditor (Reusable Component)
    ↓
usePackageVersionConfig Hook (Data Fetching Logic)
    ↓
Package Service API
```

### Flow
1. Backend returns JSON Schema with `bootstrap_config` field
2. Backend returns UI Schema with `ui:widget: "packageVersionConfig"` and `ui:options`
3. RJSF renders custom widget for `bootstrap_config` field
4. Widget extracts component definitions from `ui:options`
5. Hook fetches packages based on component definitions
6. Editor renders version dropdowns and Helm value editors

## Implementation Plan

### Phase 1: Create Reusable Components and Hooks

#### 1.1 Create Custom Hook (`usePackageVersionConfig`)

**File**: `fleet-manager-frontend/src/hooks/usePackageVersionConfig.js`

**Responsibilities**:
- Accept component definitions array
- Fetch packages for each component using `packageService.getPackages()`
- Resolve presets (tracked repo + package presets)
- Handle lazy loading for specific versions
- Return package versions, default values, and loading states

**Key Functions**:
```javascript
export function usePackageVersionConfig({
  components,        // Array of component definitions
  organization,      // Current org context
  onVersionChange,   // Callback for lazy preset loading
})
```

**Dependencies**:
- `packageService` - Package API service
- `AppContext` - Organization context
- Deep merge utility for preset resolution

#### 1.2 Create Reusable Editor Component

**File**: `fleet-manager-frontend/src/components/PackageVersionConfig/PackageVersionConfigEditor.js`

**Responsibilities**:
- Render version dropdowns for each component
- Render "Configure Values" buttons
- Open Helm values modal with resolved presets
- Handle version changes and trigger lazy preset loading
- Display customization indicators

**Props**:
```javascript
{
  components: Array<ComponentDefinition>,
  value: Object,              // Current form value
  onChange: Function,          // Form value change handler
  disabled: boolean,
  packageVersions: Object,     // From hook
  packageDefaultValues: Object, // From hook
  onVersionChange: Function,   // Lazy preset loader
}
```

**Component Definition Interface**:
```typescript
interface ComponentDefinition {
  key: string;                    // Component key (e.g., "strimzi")
  repository: string;             // Package repository name
  label: string;                  // Display label
  description?: string;           // Optional description
  artifact_type?: string;         // Default: "helm_chart"
  registry_url?: string;          // Optional: filter by registry
}
```

#### 1.3 Create RJSF Widget Wrapper

**File**: `fleet-manager-frontend/src/components/PackageVersionConfig/PackageVersionConfigWidget.js`

**Responsibilities**:
- Receive RJSF field props (`value`, `onChange`, `uiSchema`, etc.)
- Extract component definitions from `ui:options`
- Support multiple configuration sources:
  1. Direct: `ui:options.components` array
  2. Registry: `ui:options.workloadType` → frontend registry lookup
  3. API: `ui:options.workloadType` → backend API fetch
- Initialize hook with components
- Render `PackageVersionConfigEditor` with hook data

**Configuration Resolution Priority**:
1. `ui:options.components` (direct definition)
2. Frontend registry lookup (`getWorkloadPackageConfig(workloadType)`)
3. Backend API (`/organizations/{org}/workload-package-config/{workloadType}/`)

### Phase 2: Create Configuration Registry

#### 2.1 Frontend Registry

**File**: `fleet-manager-frontend/src/config/workloadPackageConfigs.js`

**Purpose**: Provide default component configurations for common workload types

**Structure**:
```javascript
export const WORKLOAD_PACKAGE_CONFIGS = {
  bootstrap: {
    components: [
      {
        key: 'strimzi',
        repository: 'strimzi-kafka-operator',
        label: 'Strimzi Operator',
        description: 'Apache Kafka operator for Kubernetes',
        artifact_type: 'helm_chart',
      },
      // ... more components
    ],
  },
  strimzi: {
    components: [
      {
        key: 'kafka',
        repository: 'strimzi-kafka-operator',
        label: 'Kafka',
        artifact_type: 'helm_chart',
      },
    ],
  },
};

export function getWorkloadPackageConfig(workloadType) {
  return WORKLOAD_PACKAGE_CONFIGS[workloadType] || null;
}
```

#### 2.2 Backend API Endpoint (Optional)

**File**: `fleet-manager-backend/core/views/fleet/config.py`

**Endpoint**: `GET /organizations/{org}/workload-package-config/{workload_type}/`

**Purpose**: Provide dynamic component configurations from backend

**Response**:
```json
{
  "components": [
    {
      "key": "strimzi",
      "repository": "strimzi-kafka-operator",
      "label": "Strimzi Operator",
      "artifact_type": "helm_chart"
    }
  ]
}
```

**Use Cases**:
- Dynamic configurations based on org settings
- Feature flags
- A/B testing different component sets

### Phase 3: Update Backend Schema Generation

#### 3.1 Update BYOK Provider

**File**: `fleet-manager-backend/fleet_provider/byok_provider.py`

**Changes**:
- Keep `bootstrap_config` in JSON Schema (don't remove it)
- Add `ui:widget: "packageVersionConfig"` to UI Schema
- Add `ui:options` with component definitions

**Example**:
```python
def get_advanced_configs(self, placement_config: Dict[str, Any]) -> Dict[str, Any]:
    json_schema = ByokAdvancedConfigSchema.model_json_schema()
    
    ui_schema = {
        "bootstrap_config": {
            "ui:widget": "packageVersionConfig",
            "ui:options": {
                "components": [
                    {
                        "key": "strimzi",
                        "repository": "strimzi-kafka-operator",
                        "label": "Strimzi Operator",
                        "description": "Apache Kafka operator for Kubernetes",
                        "artifact_type": "helm_chart",
                    },
                    {
                        "key": "cfk",
                        "repository": "confluent-for-kubernetes",
                        "label": "Confluent for Kubernetes",
                        "artifact_type": "helm_chart",
                    },
                    # ... more components
                ]
            }
        },
        # ... other ui schema fields
    }
    
    return {
        "json_schema": json_schema,
        "ui_schema": ui_schema
    }
```

#### 3.2 Alternative: Use Workload Type

If backend prefers to use workload type hint:

```python
ui_schema = {
    "bootstrap_config": {
        "ui:widget": "packageVersionConfig",
        "ui:options": {
            "workloadType": "bootstrap"  # Frontend looks up in registry
        }
    }
}
```

### Phase 4: Update Frontend Integration

#### 4.1 Register Widget in RJSF

**File**: `fleet-manager-frontend/src/pages/KubernetesFleetCreate.js`

**Changes**:
- Import `PackageVersionConfigWidget`
- Add to `widgets` object: `packageVersionConfig: PackageVersionConfigWidget`
- Remove `applyPackageVersionConstraints` function (no longer needed)
- Remove `BOOTSTRAP_COMPONENT_PACKAGE_MAP` constant
- Remove `loadPackageVersions` function
- Remove `fetchPackagePreset` function
- Remove `packageVersionOptions` and `packageDefaultValues` state
- Keep `bootstrap_config` in schema (don't delete it)

**Before**:
```javascript
const widgets = {
  customFileUpload: CustomFileUpload,
  range: CustomSliderInput,
};

// Schema manipulation
const applyPackageVersionConstraints = (schema) => {
  const clonedSchema = deepClone(schema);
  if (clonedSchema?.properties?.bootstrap_config) {
    delete clonedSchema.properties.bootstrap_config;  // Remove from schema
  }
  return clonedSchema;
};

// Render BootstrapConfigEditor separately
{advancedConfig && (
  <>
    <SchemaForm schema={applyPackageVersionConstraints(formSchema)} />
    <BootstrapConfigEditor ... />  {/* Separate component */}
  </>
)}
```

**After**:
```javascript
import PackageVersionConfigWidget from '../components/PackageVersionConfig/PackageVersionConfigWidget';

const widgets = {
  customFileUpload: CustomFileUpload,
  range: CustomSliderInput,
  packageVersionConfig: PackageVersionConfigWidget,  // Register widget
};

// Render everything through RJSF
{advancedConfig && (
  <SchemaForm
    schema={formSchema}  // Keep bootstrap_config in schema
    uiSchema={uiSchema}   // Contains ui:widget hint
    widgets={widgets}
  />
)}
```

#### 4.2 Update Other Pages (Future)

**Files**:
- `fleet-manager-frontend/src/pages/ClusterCreate.js` (if needed)
- Any other pages that need package version configuration

**Pattern**: Same as above - register widget, remove custom logic

### Phase 5: Testing

#### 5.1 Unit Tests

**Files**:
- `fleet-manager-frontend/src/hooks/__tests__/usePackageVersionConfig.test.js`
- `fleet-manager-frontend/src/components/PackageVersionConfig/__tests__/PackageVersionConfigWidget.test.js`
- `fleet-manager-frontend/src/components/PackageVersionConfig/__tests__/PackageVersionConfigEditor.test.js`

**Test Cases**:
- Hook fetches packages correctly for component definitions
- Hook resolves presets (tracked repo + package presets)
- Hook handles lazy loading for specific versions
- Widget extracts components from `ui:options` correctly
- Widget falls back to registry/API when needed
- Editor renders version dropdowns correctly
- Editor opens Helm values modal with correct defaults
- Editor handles version changes and triggers lazy loading

#### 5.2 Integration Tests

**Test Scenarios**:
1. BYOK fleet creation with bootstrap_config
2. Verify packages are fetched correctly
3. Verify presets are resolved correctly
4. Verify form submission includes bootstrap_config
5. Verify version changes trigger lazy preset loading

#### 5.3 Backend Tests

**Files**:
- `fleet-manager-backend/core/tests/test_fleet_config.py`

**Test Cases**:
- BYOK provider returns correct UI schema with `ui:widget`
- Component definitions are correct
- Workload package config API endpoint (if implemented)

### Phase 6: Migration and Cleanup

#### 6.1 Remove Old Code

**Files to Clean Up**:
- `fleet-manager-frontend/src/pages/KubernetesFleetCreate.js`:
  - Remove `BOOTSTRAP_COMPONENT_PACKAGE_MAP`
  - Remove `loadPackageVersions`
  - Remove `fetchPackagePreset`
  - Remove `packageVersionOptions` state
  - Remove `packageDefaultValues` state
  - Remove `applyPackageVersionConstraints`
  - Remove `BootstrapConfigEditor` import and usage

- `fleet-manager-frontend/src/components/BootstrapConfig/BootstrapConfigEditor.js`:
  - Can be deprecated or removed if fully replaced
  - Or refactored to use new hook internally

#### 6.2 Update Documentation

**Files**:
- Update component documentation
- Update API documentation for workload package config endpoint
- Add examples of how to add new workload types

## File Structure

```
fleet-manager-frontend/
├── src/
│   ├── components/
│   │   └── PackageVersionConfig/
│   │       ├── PackageVersionConfigWidget.js      # RJSF widget wrapper
│   │       ├── PackageVersionConfigEditor.js       # Main editor component
│   │       ├── HelmValuesModal.js                  # (Existing, reuse)
│   │       └── __tests__/
│   │           ├── PackageVersionConfigWidget.test.js
│   │           └── PackageVersionConfigEditor.test.js
│   ├── hooks/
│   │   ├── usePackageVersionConfig.js              # Data fetching hook
│   │   └── __tests__/
│   │       └── usePackageVersionConfig.test.js
│   └── config/
│       └── workloadPackageConfigs.js              # Frontend registry

fleet-manager-backend/
├── core/
│   ├── views/
│   │   └── fleet/
│   │       └── config.py                           # (Update existing)
│   └── schemas/
│       └── fleet_config_schema.py                  # (Update existing)
└── fleet_provider/
    └── byok_provider.py                            # (Update existing)
```

## Implementation Order

1. **Phase 1**: Create hook and editor component (can test independently)
2. **Phase 2**: Create configuration registry
3. **Phase 3**: Create RJSF widget wrapper
4. **Phase 4**: Update backend to return UI schema with widget hint
5. **Phase 5**: Update frontend to register widget and remove old code
6. **Phase 6**: Testing and cleanup

## Success Criteria

- [ ] BYOK fleet creation works with new component
- [ ] No hardcoded component maps in page components
- [ ] Adding new workload type requires only backend schema change
- [ ] Component is reusable across different pages/workloads
- [ ] Preset resolution works correctly (tracked repo + package presets)
- [ ] Lazy loading works for specific versions
- [ ] All tests pass
- [ ] Documentation updated

## Future Enhancements

1. **Backend API Endpoint**: Implement `/workload-package-config/{workload_type}/` for dynamic configs
2. **Caching**: Cache package versions and presets to reduce API calls
3. **Validation**: Add schema validation for component definitions
4. **TypeScript**: Convert to TypeScript for better type safety
5. **Error Handling**: Enhanced error states and retry logic
6. **Loading States**: Skeleton loaders and progressive enhancement
7. **Accessibility**: ARIA labels and keyboard navigation

## Risks and Mitigations

### Risk 1: Breaking Existing Functionality
**Mitigation**: 
- Keep old code until new component is fully tested
- Feature flag to switch between old/new implementation
- Comprehensive integration tests

### Risk 2: Performance Issues
**Mitigation**:
- Lazy load presets only when version changes
- Cache package versions
- Debounce API calls

### Risk 3: Schema Complexity
**Mitigation**:
- Clear documentation of `ui:options` structure
- Validation in widget component
- Fallback to registry if schema invalid

## Dependencies

- React 18
- Material-UI v6
- react-jsonschema-form (@rjsf/core, @rjsf/mui)
- Existing `packageService` API
- Existing preset resolution logic

## Timeline Estimate

- **Phase 1**: 2-3 days (Hook + Editor component)
- **Phase 2**: 1 day (Registry)
- **Phase 3**: 1 day (Widget wrapper)
- **Phase 4**: 1 day (Backend updates)
- **Phase 5**: 1-2 days (Frontend integration)
- **Phase 6**: 2 days (Testing + Cleanup)

**Total**: ~8-10 days

## Notes

- This plan maintains backward compatibility during migration
- The component can be gradually adopted across different pages
- Backend can choose to provide components directly or use workload type hints
- Frontend registry provides sensible defaults for common cases

