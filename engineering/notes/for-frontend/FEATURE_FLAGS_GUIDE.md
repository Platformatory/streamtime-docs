# Feature Flags System Guide

## Overview

The centralized feature flag system allows you to show/hide features, routes, and navigation items based on configuration. This enables:

- **Environment-based features**: Enable features only in development/staging
- **Role-based features**: Show features only to specific user roles
- **Organization-based features**: Enable features for specific organizations
- **Beta features**: Mark features as beta and control access
- **A/B testing**: Enable features for specific user groups
- **Gradual rollouts**: Enable features incrementally

---

## Quick Start

### 1. Define Feature Flags

Edit `src/config/featureFlags.js`:

```javascript
export const featureFlags = {
  myFeature: {
    enabled: true,
    description: 'My new feature',
    environments: ['development', 'staging', 'production'],
    roles: ['Administrator'],
  },
};
```

### 2. Use in Components

```javascript
import { useFeatureFlag } from '../hooks/useFeatureFlag';

const MyComponent = () => {
  const { isEnabled } = useFeatureFlag();

  if (!isEnabled('myFeature')) {
    return <div>Feature not available</div>;
  }

  return <div>My Feature Content</div>;
};
```

### 3. Use FeatureFlag Component

```javascript
import { FeatureFlag } from '../components/FeatureFlag';

const MyComponent = () => {
  return (
    <FeatureFlag feature="myFeature" fallback={<div>Not available</div>}>
      <MyFeatureContent />
    </FeatureFlag>
  );
};
```

### 4. Add to Routes

In `src/config/routes.js`:

```javascript
{
  path: '/my-feature',
  component: MyFeaturePage,
  name: 'My Feature',
  roles: ['Administrator'],
  protected: true,
  featureFlag: 'myFeature', // Add this
  metadata: {
    title: 'My Feature',
    icon: 'MyIcon',
  },
}
```

---

## Configuration

### Feature Flag Structure

```javascript
{
  featureName: {
    enabled: boolean | function(organization, user) => boolean,
    description: string,
    environments: string[], // ['development', 'staging', 'production']
    roles: string[], // Roles that can access
    organizations: string[], // Organization IDs
    beta: boolean, // Mark as beta feature
    deprecated: boolean, // Mark as deprecated
  }
}
```

### Examples

#### Simple Boolean Flag

```javascript
darkMode: {
  enabled: true,
  description: 'Dark mode theme',
  environments: ['development', 'staging', 'production'],
  roles: [],
}
```

#### Role-Based Flag

```javascript
billing: {
  enabled: true,
  description: 'Billing management',
  environments: ['development', 'staging', 'production'],
  roles: ['Administrator', 'Billing Administrator'],
}
```

#### Environment-Specific Flag

```javascript
betaFeature: {
  enabled: true,
  description: 'Beta feature',
  environments: ['development', 'staging'], // Not in production
  roles: ['Administrator'],
  beta: true,
}
```

#### Function-Based Flag

```javascript
advancedFeature: {
  enabled: (organization, user) => {
    // Custom logic
    if (organization?.plan === 'enterprise') {
      return true;
    }
    return false;
  },
  description: 'Advanced feature for enterprise',
  environments: ['development', 'staging', 'production'],
  roles: ['Administrator'],
}
```

---

## Usage Patterns

### 1. Component-Level Feature Flags

```javascript
import { FeatureFlag } from '../components/FeatureFlag';

const Dashboard = () => {
  return (
    <div>
      <h1>Dashboard</h1>
      
      <FeatureFlag feature="betaFeature">
        <BetaFeatureComponent />
      </FeatureFlag>
      
      <FeatureFlag 
        feature="advancedFeature"
        fallback={<div>Upgrade to Enterprise to access</div>}
      >
        <AdvancedFeatureComponent />
      </FeatureFlag>
    </div>
  );
};
```

### 2. Hook-Based Feature Flags

```javascript
import { useFeatureFlag } from '../hooks/useFeatureFlag';

const MyComponent = () => {
  const { isEnabled, isBeta, getMetadata } = useFeatureFlag();

  if (!isEnabled('myFeature')) {
    return null;
  }

  const metadata = getMetadata('myFeature');
  
  return (
    <div>
      {isBeta('myFeature') && <Badge>Beta</Badge>}
      <h2>{metadata.description}</h2>
      <MyFeatureContent />
    </div>
  );
};
```

### 3. Route-Level Feature Flags

Routes are automatically filtered based on feature flags when using the route configuration system:

```javascript
// In src/config/routes.js
{
  path: '/my-feature',
  component: MyFeaturePage,
  featureFlag: 'myFeature', // Route hidden if feature disabled
  // ... other config
}
```

### 4. Navigation-Level Feature Flags

Navigation items are automatically filtered:

```javascript
import { generateNavigationItems } from '../utils/routeGenerator';
import { useFeatureFlag } from '../hooks/useFeatureFlag';

const Sidebar = () => {
  const { currentOrg } = useContext(AppContext);
  const { isEnabled } = useFeatureFlag();
  
  // Navigation items automatically filtered by feature flags
  const navItems = generateNavigationItems(currentOrg, isEnabled);
  
  return <SidebarNav items={navItems} />;
};
```

---

## Integration with App

### 1. Add FeatureFlagProvider

Update `src/App.js`:

```javascript
import { FeatureFlagProvider } from './context/FeatureFlagContext';

const App = () => {
  const { currentOrg, user } = useContext(AppContext);

  return (
    <FeatureFlagProvider organization={currentOrg} user={user}>
      {/* Your app content */}
    </FeatureFlagProvider>
  );
};
```

### 2. Update Router

Use the new router that supports feature flags:

```javascript
import PageRoutes from './components/Routers/PageRouters.new';

// Routes automatically filtered by feature flags
```

---

## API Reference

### `useFeatureFlag()` Hook

```javascript
const {
  isEnabled,        // (featureName) => boolean
  isBeta,           // (featureName) => boolean
  getMetadata,      // (featureName) => Object | null
  enabledFeatures,  // Array of enabled feature names
  disabledFeatures, // Array of disabled feature names
} = useFeatureFlag();
```

### `FeatureFlag` Component

```javascript
<FeatureFlag
  feature="featureName"      // Required: feature flag name
  fallback={null}            // Optional: component to show if disabled
  showBetaBadge={false}      // Optional: show beta badge
>
  {/* Children shown if feature enabled */}
</FeatureFlag>
```

### `isFeatureEnabled()` Function

```javascript
import { isFeatureEnabled } from '../config/featureFlags';

const enabled = isFeatureEnabled('myFeature', organization, user);
```

### Route Configuration

```javascript
{
  path: '/route',
  component: Component,
  featureFlag: 'featureName', // Optional: feature flag name
  // ... other config
}
```

---

## Best Practices

### 1. Naming Conventions

- Use camelCase: `kubernetesFleet`, `networkManagement`
- Be descriptive: `clusterHealthReports` not `health`
- Group related features: `billing.*`, `settings.*`

### 2. Default Values

- Set `enabled: false` for new features
- Enable in development first
- Gradually roll out to staging, then production

### 3. Documentation

- Always include `description`
- Document beta features
- Mark deprecated features

### 4. Testing

- Test with feature enabled
- Test with feature disabled
- Test role-based access
- Test environment-based access

### 5. Cleanup

- Remove deprecated feature flags
- Remove unused feature flags
- Update documentation when removing flags

---

## Examples

### Example 1: Hide Navigation Item

```javascript
// In routes.js
{
  path: '/beta-feature',
  name: 'Beta Feature',
  featureFlag: 'betaFeature', // Hidden if disabled
  // ...
}

// Navigation automatically hides this item if feature disabled
```

### Example 2: Conditional Component Rendering

```javascript
import { FeatureFlag } from '../components/FeatureFlag';

const Dashboard = () => {
  return (
    <div>
      <FeatureFlag feature="notifications">
        <NotificationsPanel />
      </FeatureFlag>
    </div>
  );
};
```

### Example 3: Role-Based Feature

```javascript
// In featureFlags.js
enterpriseFeature: {
  enabled: true,
  roles: ['Administrator', 'Enterprise Admin'],
  // ...
}

// Only users with these roles can access
```

### Example 4: Environment-Specific Feature

```javascript
// In featureFlags.js
devOnlyFeature: {
  enabled: true,
  environments: ['development'], // Only in dev
  // ...
}
```

---

## Troubleshooting

### Feature Not Showing

1. Check if feature flag is enabled
2. Check environment configuration
3. Check role requirements
4. Check organization requirements
5. Verify feature flag name matches

### Route Not Accessible

1. Check route has `featureFlag` property
2. Verify feature flag is enabled
3. Check role requirements
4. Verify route generator is using feature flags

### Navigation Item Missing

1. Check route has `featureFlag` property
2. Verify feature flag is enabled
3. Check `generateNavigationItems` is using feature flags
4. Verify navigation component is filtering correctly

---

## Migration Guide

### Step 1: Add Feature Flags

1. Define feature flags in `src/config/featureFlags.js`
2. Add `featureFlag` property to routes in `src/config/routes.js`

### Step 2: Integrate Provider

1. Wrap app with `FeatureFlagProvider` in `App.js`
2. Pass organization and user context

### Step 3: Update Components

1. Use `useFeatureFlag()` hook where needed
2. Use `FeatureFlag` component for conditional rendering
3. Update navigation to use feature flags

### Step 4: Test

1. Test with features enabled
2. Test with features disabled
3. Test role-based access
4. Test environment-based access

---

*For questions or issues, refer to the main design system documentation.*


