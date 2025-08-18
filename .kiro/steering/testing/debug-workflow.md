---
inclusion: fileMatch
fileMatchPattern: ['docs/v2_rewrite_implementation_plan/phase-3-web-ui-implementation/*.md']
---

# Debugging Workflow Patterns

## Overview

This rule documents systematic debugging approaches for CipherSwarm development, based on successful resolution of complex issues like SSE connection problems and frontend/backend integration issues.

## Development Environment Debugging

### Docker Service Health Monitoring

```bash
# ✅ CORRECT - Systematic service health checking
docker compose ps                    # Check all service status
docker compose logs backend --tail=20   # Check recent backend logs
docker compose logs frontend --tail=20  # Check recent frontend logs

# Look for service health indicators
# - backend: "healthy" status
# - frontend: "healthy" status  
# - database: "healthy" status

# Common service restart commands
docker compose restart frontend      # Restart specific service
docker compose restart backend      # Restart backend only
docker compose down && docker compose up -d  # Full restart
```

### Log Analysis Patterns

```bash
# ✅ CORRECT - Structured log analysis
# Backend API logs - look for:
docker compose logs backend | grep "SSE"        # SSE connection logs
docker compose logs backend | grep "401"        # Authentication failures
docker compose logs backend | grep "ERROR"      # Error messages
docker compose logs backend | grep "INFO"       # General info

# Frontend build logs - look for:
docker compose logs frontend | grep "ERROR"     # Build errors
docker compose logs frontend | grep "WARN"      # Build warnings
docker compose logs frontend | grep "Vite"      # Vite-specific issues
```

## Browser-Based Debugging

### Network Tab Analysis

```typescript
// ✅ CORRECT - Network debugging checklist
// 1. Check SSE connections (EventSource type)
// 2. Verify response headers: Content-Type: text/event-stream
// 3. Monitor connection duration (should be persistent)
// 4. Check for 401/403 authentication errors
// 5. Verify cookies are being sent with requests

// Common SSE debugging indicators:
// - Connection shows as "eventsource" type
// - Status should be 200 OK
// - Content-Type: text/event-stream; charset=utf-8
// - Connection remains open (not immediately closing)
```

### Console Error Patterns

```typescript
// ✅ CORRECT - Console error interpretation
// SSE Connection Errors:
"EventSource failed" → Check backend media type configuration
"401 Unauthorized" → Verify authentication cookies
"Connection closed" → Check for proper keep-alive implementation

// Frontend Build Errors:
"Module not found" → Check import paths and file extensions
"Vite build failed" → Check for syntax errors in components
"SvelteKit SSR error" → Check load function implementation
```

## Backend API Debugging

### SSE Endpoint Debugging

```python
# ✅ CORRECT - SSE debugging checklist
# 1. Verify media_type="text/event-stream" (not "text/plain")
# 2. Check authentication dependency injection
# 3. Verify event format: 'data: {json}\n\n'
# 4. Implement proper keep-alive pings
# 5. Handle client disconnections gracefully

# Debug SSE endpoint implementation:
@router.get("/live/campaigns")
async def get_campaign_events(current_user: User = Depends(get_current_user)):
    logger.info(f"User {current_user.id} connected to campaign events feed")
    return StreamingResponse(
        event_service.get_campaign_events(user_id=current_user.id),
        media_type="text/event-stream",  # Critical: Must be text/event-stream
    )
```

### Authentication Flow Debugging

```python
# ✅ CORRECT - Authentication debugging steps
# 1. Check session cookie presence and validity
# 2. Verify user exists and is active
# 3. Check project membership for scoped resources
# 4. Validate JWT token if using token auth

# Debug authentication in logs:
logger.info(f"Auth attempt for user: {email}")
logger.info(f"Session cookie: {request.cookies.get('sessionid')}")
logger.info(f"User authenticated: {user.id if user else 'None'}")
```

## Frontend Integration Debugging

### SvelteKit SSR Debugging

```typescript
// ✅ CORRECT - SSR debugging patterns
// Load function debugging:
export const load: PageServerLoad = async ({ cookies }) => {
    console.log('Load function called with cookies:', cookies.toString());
    
    try {
        const response = await serverApi.get('/api/v1/web/campaigns/', {
            headers: { Cookie: cookies.toString() }
        });
        console.log('API response status:', response.status);
        return { campaigns: response.data };
    } catch (error) {
        console.error('Load function error:', error.response?.status, error.message);
        throw error(500, 'Failed to load campaigns');
    }
};
```

### Store Integration Debugging

```typescript
// ✅ CORRECT - Store debugging patterns
export const campaignsStore = {
    async loadCampaigns() {
        console.log('Store: Loading campaigns...');
        this.setLoading(true);
        
        try {
            const response = await api.get('/api/v1/web/campaigns/');
            console.log('Store: API response received:', response.status);
            
            const data = CampaignListResponseSchema.parse(response.data);
            console.log('Store: Data parsed successfully:', data.items.length, 'campaigns');
            
            this.hydrate(data);
        } catch (error) {
            console.error('Store: Load campaigns error:', error);
            this.setError('Failed to load campaigns');
        }
    }
};
```

## Test Debugging Patterns

### E2E Test Debugging

```typescript
// ✅ CORRECT - E2E test debugging
test('dashboard loads with SSE connections', async ({ page }) => {
    // Enable console logging in tests
    page.on('console', msg => console.log('Browser:', msg.text()));
    
    // Monitor network requests
    page.on('request', request => {
        if (request.url().includes('/api/')) {
            console.log('API Request:', request.method(), request.url());
        }
    });
    
    page.on('response', response => {
        if (response.url().includes('/api/')) {
            console.log('API Response:', response.status(), response.url());
        }
    });
    
    await page.goto('/');
    // ... rest of test
});
```

### Mock API Debugging

```typescript
// ✅ CORRECT - Mock debugging patterns
test('dashboard with mocked API', async ({ page }) => {
    // Debug mock route handling
    await page.route('/api/v1/web/campaigns/', (route) => {
        console.log('Mock route intercepted:', route.request().url());
        route.fulfill({
            status: 200,
            contentType: 'application/json',
            body: JSON.stringify({ items: mockCampaigns, total_count: 5 })
        });
    });
    
    await page.goto('/');
    // Verify mock data is used
    await expect(page.locator('[data-testid="campaign-count"]')).toHaveText('5');
});
```

## Systematic Issue Resolution

### Problem Isolation Strategy

```markdown
# ✅ CORRECT - Systematic debugging approach
1. **Identify the scope**: Frontend, backend, or integration issue?
2. **Check service health**: Are all Docker services running properly?
3. **Review recent changes**: What was modified since last working state?
4. **Check logs systematically**: Backend → Frontend → Browser console
5. **Isolate variables**: Test with minimal configuration
6. **Verify assumptions**: Check actual vs. expected behavior
7. **Test incrementally**: Fix one issue at a time
```

### Common Issue Categories

#### SSE Connection Issues

```markdown
Symptoms: "Real-time updates disconnected", EventSource errors
Debugging Steps:
1. Check backend media type: must be "text/event-stream"
2. Verify authentication: cookies must be sent with SSE requests
3. Check connection duration: should persist, not immediately close
4. Monitor backend logs: confirm connections are established
5. Test keep-alive: verify ping messages every 30 seconds
```

#### Authentication Issues

```markdown
Symptoms: 401 errors, redirects to login, missing user data
Debugging Steps:
1. Check session cookies: verify presence and validity
2. Test login flow: confirm credentials and session creation
3. Verify API calls: ensure cookies sent with requests
4. Check user state: confirm user data loads correctly
5. Test project context: verify project-scoped data access
```

#### Frontend Build Issues

```markdown
Symptoms: Vite errors, module resolution failures, SSR errors
Debugging Steps:
1. Check file extensions: .svelte.ts for rune stores
2. Verify import paths: correct relative/absolute paths
3. Check syntax: valid TypeScript/Svelte syntax
4. Test incremental builds: isolate problematic files
5. Clear cache: restart frontend container if needed
```

## Debugging Tools and Commands

### Development Commands

```bash
# ✅ CORRECT - Debugging command toolkit
# Service management
just docker-dev-up-watch     # Start development environment
just docker-dev-down         # Clean shutdown
docker compose restart <service>  # Restart specific service

# Log monitoring
docker compose logs -f backend   # Follow backend logs
docker compose logs -f frontend  # Follow frontend logs
docker compose logs --tail=50 backend  # Recent backend logs

# Health checking
docker compose ps             # Service status
curl http://localhost:8000/health  # Backend health check
curl http://localhost:5173/   # Frontend health check
```

### Browser DevTools Usage

```markdown
# ✅ CORRECT - Browser debugging checklist
Network Tab:
- Check SSE connections (eventsource type)
- Verify response headers and status codes
- Monitor request/response timing
- Check authentication cookie transmission

Console Tab:
- Monitor JavaScript errors and warnings
- Check SSE connection status messages
- Verify API response data
- Look for authentication state changes

Application Tab:
- Check stored cookies and their values
- Verify localStorage/sessionStorage data
- Monitor service worker activity (if applicable)
```

## Prevention Strategies

### Code Quality Checks

```bash
# ✅ CORRECT - Preventive debugging measures
# Run before committing changes
just check                    # Linting and formatting
just test-backend            # Backend test suite
just frontend-test           # Frontend test suite
just ci-check               # Full CI validation

# Environment validation
docker compose config        # Validate compose configuration
docker compose ps           # Verify service health
```

### Monitoring Patterns

```typescript
// ✅ CORRECT - Production monitoring patterns
// Add structured logging for key operations
logger.info("SSE connection established", { 
    user_id: user.id, 
    endpoint: "/live/campaigns",
    timestamp: new Date().toISOString()
});

// Monitor connection health
const connectionHealth = {
    connected: sseService.connected,
    endpoints: Array.from(sseService.connectedEndpoints),
    reconnectAttempts: sseService.reconnectAttempts,
    lastError: sseService.lastError
};
```

## Best Practices Summary

### Debugging Approach

1. **Start with service health** - ensure all containers are running
2. **Check logs systematically** - backend first, then frontend
3. **Use browser DevTools** - Network and Console tabs are critical
4. **Isolate variables** - test one component at a time
5. **Document findings** - track what works and what doesn't

### Prevention

1. **Run checks before committing** - linting, tests, CI validation
2. **Monitor service health** - regular status checks
3. **Use structured logging** - consistent log formats
4. **Test incrementally** - small changes, frequent validation
5. **Maintain clean environments** - regular container restarts

### Documentation

1. **Record successful solutions** - document working configurations
2. **Track common issues** - build a troubleshooting knowledge base
3. **Share debugging patterns** - help team members with similar issues
4. **Update rules and guides** - keep documentation current

## Anti-Patterns to Avoid

### Debugging Mistakes

- Making multiple changes simultaneously
- Ignoring service health indicators
- Not checking browser DevTools
- Skipping log analysis
- Assuming rather than verifying

### Environment Issues

- Working with unhealthy containers
- Not restarting services when needed
- Ignoring Docker compose status
- Creating conflicting development instances
- Not cleaning up after debugging sessions
