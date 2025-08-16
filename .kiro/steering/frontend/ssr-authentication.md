---
inclusion: manual
---
# SSR Authentication Implementation Guide

## Overview
This rule documents the authentication implementation requirements for CipherSwarm's SSR migration. The current blocker is that SSR pages attempt authenticated API calls but no SSR authentication flow exists.

## Current State Analysis

### Problem Identification
- **Issue**: SSR load functions make authenticated API calls to FastAPI backend but no session handling exists
- **Symptom**: E2E tests fail because frontend service health check fails (401 responses)
- **Root Cause**: Migration from SPA to SSR completed without implementing server-side authentication

### Working Components
- ✅ Three-tier testing architecture with Docker infrastructure
- ✅ E2E data seeding with service layer delegation
- ✅ Frontend and backend containers build successfully
- ✅ SSR routes and form actions implemented
- ❌ **Missing**: Session-based authentication for SSR load functions

## Required Authentication Implementation

### 1. Session Cookie Handling

**SvelteKit Side** (`hooks.server.js`):
```javascript
// Handle authentication cookies and session management
export async function handle({ event, resolve }) {
    // Extract session cookie from request
    const sessionCookie = event.cookies.get('sessionid');
    
    // Set user context for load functions
    if (sessionCookie) {
        event.locals.session = sessionCookie;
        event.locals.user = await validateSession(sessionCookie);
    }
    
    return resolve(event);
}
```

**SSR Load Functions Pattern**:
```typescript
// In +page.server.ts files
export const load: PageServerLoad = async ({ cookies, locals }) => {
    // Use session from hooks.server.js
    const sessionCookie = cookies.get('sessionid') || locals.session;
    
    if (!sessionCookie) {
        throw redirect(302, '/login');
    }
    
    try {
        const response = await serverApi.get('/api/v1/web/campaigns/', {
            headers: { 
                'Cookie': `sessionid=${sessionCookie}`,
                'X-Requested-With': 'XMLHttpRequest'
            }
        });
        return { campaigns: response.data };
    } catch (error) {
        if (error.response?.status === 401) {
            throw redirect(302, '/login');
        }
        throw error(500, 'Failed to load data');
    }
};
```

### 2. Authentication State Management

**Server-Side API Client** ([lib/server/api.js](mdc:CipherSwarm/CipherSwarm/frontend/src/lib/server/api.js)):
```typescript
import type { Cookies } from '@sveltejs/kit';

export class ServerApiClient {
    private baseURL: string;
    
    constructor(baseURL: string) {
        this.baseURL = baseURL;
    }
    
    async authenticatedRequest(
        endpoint: string, 
        options: RequestInit,
        cookies: Cookies
    ) {
        const sessionCookie = cookies.get('sessionid');
        
        if (!sessionCookie) {
            throw new Error('No session cookie found');
        }
        
        return fetch(`${this.baseURL}${endpoint}`, {
            ...options,
            headers: {
                ...options.headers,
                'Cookie': `sessionid=${sessionCookie}`,
                'X-Requested-With': 'XMLHttpRequest'
            }
        });
    }
}
```

### 3. Login Form Implementation

**Login Route** (`/login/+page.server.ts`):
```typescript
export const actions: Actions = {
    default: async ({ request, cookies }) => {
        const form = await superValidate(request, zod(loginSchema));
        
        if (!form.valid) {
            return fail(400, { form });
        }
        
        try {
            // Authenticate with FastAPI
            const response = await fetch(`${API_BASE_URL}/api/v1/web/auth/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(form.data)
            });
            
            if (!response.ok) {
                return fail(401, { form, message: 'Invalid credentials' });
            }
            
            // Extract session cookie from response
            const setCookieHeader = response.headers.get('set-cookie');
            const sessionMatch = setCookieHeader?.match(/sessionid=([^;]+)/);
            
            if (sessionMatch) {
                cookies.set('sessionid', sessionMatch[1], {
                    httpOnly: true,
                    secure: true,
                    sameSite: 'strict',
                    maxAge: 60 * 60 * 24 * 7 // 7 days
                });
            }
            
            throw redirect(303, '/');
        } catch (error) {
            return fail(500, { form, message: 'Login failed' });
        }
    }
};
```

### 4. Environment Detection for Tests

**Test Environment Bypass**:
```typescript
// In SSR load functions
export const load: PageServerLoad = async ({ cookies }) => {
    // Bypass authentication in test environments
    if (process.env.NODE_ENV === 'test' || 
        process.env.PLAYWRIGHT_TEST || 
        process.env.CI) {
        return {
            campaigns: mockCampaignData,
            user: mockUserData
        };
    }
    
    // Normal authentication flow
    return authenticatedLoad(cookies);
};
```

## Implementation Strategy

### Phase 1: Core Authentication Setup
1. **Create `hooks.server.js`** for session handling
2. **Implement server-side API client** with cookie management
3. **Create login/logout routes** with proper form actions
4. **Update environment configuration** for API endpoints

### Phase 2: Load Function Updates
1. **Update all `+page.server.ts` files** to use authenticated API calls
2. **Implement proper error handling** for 401/403 responses
3. **Add test environment detection** for E2E tests
4. **Ensure cookie forwarding** in all API requests

### Phase 3: Testing Integration
1. **Update E2E seed data** to include user sessions
2. **Modify Docker health checks** to use authenticated endpoints
3. **Implement login flow in E2E tests** 
4. **Test session persistence** across page navigation

## FastAPI Backend Requirements

### Session Endpoint Compatibility
Ensure FastAPI backend supports:
- Session-based authentication (not just JWT)
- Cookie-based session management
- Proper CORS configuration for SvelteKit frontend
- Health check endpoints that work without authentication

### Required Backend Updates
```python
# If session-based auth doesn't exist, may need to implement
@app.post("/api/v1/web/auth/login")
async def login(credentials: LoginRequest, response: Response):
    # Validate credentials
    user = authenticate_user(credentials.email, credentials.password)
    if not user:
        raise HTTPException(401, "Invalid credentials")
    
    # Create session
    session_id = create_user_session(user.id)
    
    # Set cookie
    response.set_cookie(
        "sessionid", 
        session_id,
        httponly=True,
        secure=True,
        samesite="strict"
    )
    
    return {"success": True, "user": user}
```

## File References
- Session handling: [hooks.server.js](mdc:CipherSwarm/CipherSwarm/frontend/src/hooks.server.js) (to be created)
- Server API client: [lib/server/api.js](mdc:CipherSwarm/CipherSwarm/frontend/src/lib/server/api.js) (to be updated)
- Login routes: [routes/login/+page.server.ts](mdc:CipherSwarm/CipherSwarm/frontend/src/routes/login/+page.server.ts) (to be created)
- E2E setup: [tests/global-setup.e2e.ts](mdc:CipherSwarm/CipherSwarm/frontend/tests/global-setup.e2e.ts)
- Migration plan: [spa_to_ssr.md](mdc:CipherSwarm/CipherSwarm/docs/v2_rewrite_implementation_plan/side_quests/spa_to_ssr.md)

## Success Criteria
- [ ] All SSR load functions can make authenticated API calls
- [ ] E2E tests pass with Docker backend authentication
- [ ] Session persistence works across page navigation
- [ ] Proper login/logout flow implemented
- [ ] Test environment detection bypasses authentication
- [ ] Health checks work without breaking Docker startup

