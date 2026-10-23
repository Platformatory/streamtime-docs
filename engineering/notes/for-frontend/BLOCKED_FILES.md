# Blocked Files Security Configuration

## Overview

Blocks security-prone files from public folder. Uses environment-specific protection with three layers:
- **Development**: `src/setupProxy.js` (webpack-dev-server middleware)
- **Production**: `nginx-config/blocked-files.conf` (Nginx location blocks)
- **Fallback**: `src/App.js` (React Router protection)

## Environment Separation

| Environment | Server | Protection File |
|------------|--------|-----------------|
| **Development** | webpack-dev-server | `src/setupProxy.js` |
| **Production** | Nginx | `nginx-config/blocked-files.conf` |
| **Fallback** | React Router | `src/App.js` |

**All three layers are required** - they protect different environments and provide defense in depth.

## Blocked Files

- `/env-config.js` - Sensitive environment variables
- `/service-worker.js` - Application logic
- `*.env` files - Environment files
- `*.map` files - Source maps

## Implementation

### Centralized Configuration

**File**: `src/config/blockedFiles.js` (single source of truth)

This file defines the list of blocked files that all protection layers reference.

### Development Protection

**File**: `src/setupProxy.js`

Middleware blocks files when running `npm run start` (webpack-dev-server).

### Production Protection

**File**: `nginx-config/blocked-files.conf`

Nginx location blocks that prevent access to blocked files when serving built files.

```nginx
location = /env-config.js { return 404; access_log off; log_not_found off; }
location = /service-worker.js { return 404; access_log off; log_not_found off; }
location ~ /\.env { return 404; access_log off; log_not_found off; }
location ~ \.map$ { return 404; access_log off; log_not_found off; }
```

**Include in Nginx config**: `include /etc/nginx/conf.d/blocked-files.conf;`

### Fallback Protection

**File**: `src/App.js`

React Router redirects blocked paths to `/404` as a final layer of protection.

## Testing

```bash
# Development
curl -I http://localhost:3000/env-config.js  # Expected: 404

# Production
curl -I https://your-domain.com/env-config.js  # Expected: 404
```

## Adding New Blocked Files

1. Update `src/config/blockedFiles.js` (centralized config)
2. Update `src/setupProxy.js` (development)
3. Update `nginx-config/blocked-files.conf` (production)
4. Update `src/App.js` (fallback)
5. Test in both development and production environments

## References

- **Centralized Config**: `src/config/blockedFiles.js`
- **Development**: `src/setupProxy.js`
- **Production**: `nginx-config/blocked-files.conf`
- **Fallback**: `src/App.js`
