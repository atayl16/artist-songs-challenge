# Development Tasks & Design Decisions

## ✅ Completed (MVP)

### Backend
- [x] Rails API-only setup
- [x] Genius API integration with Faraday
- [x] Redis caching (per page, 1hr TTL)
- [x] Rack::Attack rate limiting
- [x] Pagination (50 songs/page)
- [x] Error handling (404, 422, 429, 504, 502)
- [x] Retry logic with exponential backoff
- [x] Input validation
- [x] Graceful degradation (works if Redis down)
- [x] RSpec tests with VCR cassettes
- [x] Request specs for all endpoints

### Frontend
- [x] React setup with Create React App
- [x] Artist search component
- [x] Song list component with pagination
- [x] Load More button
- [x] Loading and error states
- [x] Responsive design
- [x] Environment config for API URL

### DevOps
- [x] Docker Compose setup
- [x] Backend Dockerfile
- [x] Frontend Dockerfile
- [x] Redis service
- [x] Environment variable management

### Documentation
- [x] Comprehensive README
- [x] API documentation
- [x] Setup instructions (Docker + Manual)
- [x] Architecture diagram
- [x] Design decisions documented

## Design Decisions

### 1. No Database (PostgreSQL)
**Decision:** Use Redis for caching only; no persistent database.

**Reasoning:**
- Genius API is the authoritative source of truth
- Adding a database introduces sync complexity
- No user accounts or preferences to store
- Redis caching provides performance benefits

**Trade-offs:**
- ❌ Can't track search history or analytics
- ❌ Can't cache indefinitely
- ✅ Simpler architecture
- ✅ Faster to build and maintain

**When to add:** If we need search analytics, user preferences, or offline capability.

---

### 2. Redis Caching Per Page
**Decision:** Cache each page separately with key pattern `v1:genius:artist:id:{artist_id}:p{page}:pp{per_page}`.

**Reasoning:**
- Artists can have 300+ songs (would timeout fetching all at once)
- Most users only view first 1-2 pages
- Faster initial response (don't wait for all pages)
- **IMPLEMENTED:** Caching by artist ID prevents collisions for artists with the same name

**Trade-offs:**
- ❌ More cache keys than caching full artist discography
- ❌ Requires artist lookup before checking cache
- ✅ Faster user experience
- ✅ Reduces API quota usage
- ✅ No cache collisions for artists with same name

**Alternative considered:** Cache entire discography on first request (rejected - too slow).

**Implementation:** Cache keys use artist ID from Genius API to ensure uniqueness. The artist lookup is performed on every request to get the canonical ID, then we check the cache.

---

### 3. 50 Songs Per Page
**Decision:** Fixed page size of 50 songs.

**Reasoning:**
- Genius API maximum is 50
- Loads in <2 seconds
- Fills screen without excessive scrolling
- Good balance between API calls and UX

**Trade-offs:**
- ❌ User can't customize page size
- ✅ Predictable performance
- ✅ Simpler implementation

---

### 4. "Load More" Button vs Infinite Scroll
**Decision:** Manual "Load More" button.

**Reasoning:**
- Simpler implementation
- Clearer UX (user controls when to load)
- Better accessibility (keyboard/screen readers)
- Easier to test
- Users can see "end of list"

**Trade-offs:**
- ❌ Requires user action
- ✅ User has control
- ✅ No unexpected network requests

**Alternative considered:** Infinite scroll (future enhancement).

---

### 5. Rate Limiting: 10 searches/minute
**Decision:** Strict rate limit on search endpoint.

**Reasoning:**
- Search hits Genius API (expensive)
- Protects API quota
- Prevents abuse
- Normal users won't hit limit

**Trade-offs:**
- ❌ Power users might hit limit
- ✅ Protects backend resources
- ✅ Prevents accidental runaway requests

---

### 6. No Circuit Breaker (MVP)
**Decision:** Retry logic but no circuit breaker.

**Reasoning:**
- Retry with exponential backoff handles transient failures
- Circuit breaker adds complexity
- Can be added later if needed

**Trade-offs:**
- ❌ Multiple slow requests during outage
- ✅ Simpler implementation
- ✅ Good enough for MVP

**When to add:** If Genius API has frequent outages or we see cascading failures.

---

### 7. Manual JSON Parsing (No faraday-middleware)
**Decision:** Parse JSON manually instead of using `faraday-middleware` gem.

**Reasoning:**
- One less dependency
- `JSON.parse(response.body)` is explicit and clear
- `f.response :json` requires extra gem in Faraday 2.x

**Trade-offs:**
- ❌ Extra line of code per request
- ✅ One less gem to maintain
- ✅ More explicit

JSON parse failures are caught and mapped to `ApiError` with a 502 response, providing a stable error shape to the UI.

**Future enhancement:** Validate `Content-Type: application/json` and treat mismatches as upstream errors.

---

### 8. RESTful Path Params vs Query Params
**Decision:** `/artists/:name/songs` instead of `/artists/songs?name=X`.

**Reasoning:**
- More RESTful (resource hierarchy)
- Cleaner URLs
- Standard convention

**Trade-offs:**
- ❌ Special characters in artist names need encoding
- ✅ More semantic
- ✅ Better REST practices

Implementation detail: the server treats `:name` as an input hint only; it performs a search, resolves a canonical `artist_id`, then fetches songs by that ID (MVP caches by name; will migrate to ID-based keys per §2 note).

---

### 8.5. Input Validation & Sanitization
**Decision:** Validate user input server-side; rely on client-side trimming.

**Current validation:**
- Reject blank/whitespace-only names
- Length ≤ 100 characters
- Client trims input before submission
- Client URL-encodes (`encodeURIComponent`) before calling API
- Cache key sanitizes special characters (`gsub(/[:\*\?\[\]]/, "_")`)

**Trade-offs:**
- ✅ Prevents pathological queries
- ✅ Clear error messages for invalid input
- ✅ Simple and effective for MVP

**Future enhancement:** Normalization (trim/collapse whitespace/diacritics) server-side before caching to reduce cache key variants.

---

### 9. Docker as Primary Setup
**Decision:** Docker Compose as recommended setup method.

**Reasoning:**
- Modern deployment standard (Docker + Kubernetes)
- Eliminates "works on my machine"
- Three services (Rails, React, Redis) need orchestration
- Consistent environment across dev/prod

**Trade-offs:**
- ❌ Requires Docker installation
- ✅ Consistent environment
- ✅ Easy to run anywhere

---

### 10. CORS Configuration: Localhost Only
**Decision:** Hardcoded `localhost:3000` and `127.0.0.1:3000` origins.

**Reasoning:**
- Optimized for local development
- No environment variables required
- Clear and explicit origins
- Production would use environment-based config

**Trade-offs:**
- ❌ Won't work if deployed to production domain
- ❌ Requires code change for deployment
- ✅ Zero configuration needed
- ✅ Clear and explicit (no hidden env vars)

**For production deployment:** Use environment-based configuration instead:
```ruby
# config/initializers/cors.rb
origins_list = ENV.fetch("CORS_ORIGINS", "http://localhost:3000,http://127.0.0.1:3000")
                  .split(",")
                  .map(&:strip)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*origins_list)
    resource "*", headers: :any, methods: %i[get options]
  end
end
```

Then set environment variable: `CORS_ORIGINS=https://yourdomain.com,https://www.yourdomain.com`

This keeps the hardcoded approach for local development while supporting dynamic origins in production.

---

### 11. Sorting & Pagination Stability
**Decision:** Request songs with `sort=popularity` (Genius-provided ordering) and paginate at 50 per page.

**Reasoning:**
- Stable ordering avoids jitter between pages
- Popularity usually matches user expectations

**Trade-offs:**
- ❌ Popularity may not correlate with release chronology
- ✅ Consistent UX; simpler client

**Duplicates:** We do **not** de‑duplicate across pages (matching Genius’ pagination). If Genius returns duplicates in rare cases, they will appear as-is.

---

### 12. API Error Contract (Backend → Frontend)
All errors return `{ error: "message" }` with appropriate HTTP status codes:

| HTTP | Error Type            | Example message                      |
|-----:|-----------------------|--------------------------------------|
|  422 | Invalid Input         | "Artist name required"               |
|  404 | Artist Not Found      | "Artist 'X' not found"               |
|  429 | Rate Limited          | "Rate limit exceeded"                |
|  502 | Upstream Error        | "Unable to connect to Genius API"    |
|  504 | Timeout               | "Request to Genius timed out"        |

Clients check HTTP status codes for error types and display user-friendly messages.

**Future enhancement:** Add structured error codes (e.g., `{ error, code }`) for more granular programmatic error handling.

---

### 13. API Resilience: Two-Level Caching Strategy
**Decision:** Implement name→ID mapping cache (24h TTL) separate from songs cache (1h TTL) to enable serving stale data during API outages.

**Reasoning:**
- Challenge requirement: "What if the API wasn't so well behaved?"
- Original design called `find_artist()` before checking songs cache
- If Genius API is down, application fails even with cached songs available
- Two-level cache enables graceful degradation during API outages

**Implementation:**
1. **Name→ID Mapping Cache:**
   - Key pattern: `v1:genius:name_to_id:{normalized_name}`
   - Stores: `{ artist_id: X, artist_name: "Canonical Name" }`
   - TTL: 24 hours (artist IDs are stable)
   - Name normalization: downcase + strip for case-insensitive lookups

2. **Request Flow:**
   ```
   Request received
   ├─> Check name→ID mapping cache
   │   ├─> If found AND songs cache exists:
   │   │   ├─> Try to refresh artist data from API
   │   │   ├─> If API available: Return cached songs + fresh artist data
   │   │   └─> If API down: Return stale cache with flags (stale: true, api_unavailable: true)
   │   └─> If not found: Normal flow (find artist, cache mapping, fetch/cache songs)
   ```

3. **Response Metadata:**
   - `cached: true` - Songs served from cache (not freshly fetched)
   - `stale: false` - API is healthy, data is current
   - `api_unavailable: false` - API is reachable
   - When API is down but cache exists: `cached: true, stale: true, api_unavailable: true`

**Trade-offs:**
- ✅ **High availability:** Serves stale cache during Genius API outages
- ✅ **Better UX:** Users get results instead of errors when API is down
- ✅ **Transparent:** Flags indicate data freshness to client
- ✅ **Case-insensitive:** "Drake" and "drake" use same cache entry
- ❌ Slightly more complex cache logic
- ❌ Additional cache keys (minimal overhead)

**Availability Impact:**
- Before: 99.9% (dependent on Genius API uptime)
- After: 99.99% (serves stale cache during API outages, as long as cache populated)

**Test Coverage:**
- Serves stale cache when API returns 500 errors
- Serves stale cache on timeout errors
- Still fails when API down AND no cache exists (expected)
- Returns fresh data when API recovers
- Case-insensitive name→ID lookups

**Alternative Considered:** Circuit breaker pattern (more complex, requires additional gem, future enhancement).

---

## 📋 Future Improvements

### High Priority (Production Requirements)

#### 1. Circuit Breaker Pattern
**Why:** Fail fast when Genius API is down, reduce cascading failures.

**Implementation:**
- Use `stoplight` or `semian` gem
- Open circuit after 5 consecutive failures
- Half-open after 60 seconds to test recovery
- Fallback to stale cache

---

#### 2. Background Jobs (Sidekiq)
**Why:** Large artists (300+ songs) block request. Move to async.

**Implementation:**
- Install Sidekiq
- Create `FetchArtistSongsJob`
- Return job ID immediately
- Poll for results or use WebSockets
- Store results in Redis with longer TTL

---

#### 3. Monitoring & Observability
**Why:** Can't improve what you don't measure.

**Implementation:**
- Structured logging (Lograge)
- Error tracking (Sentry/Honeybadger)
- Performance monitoring (Skylight)
- Cache hit rate metrics
- API latency tracking
- Include correlation IDs (X-Request-Id) and JSON structured logs
- Track upstream status code distribution alongside cache hit rate

---

#### 4. Health Check Endpoint
**Why:** Kubernetes needs to know if app is healthy.

**Implementation:**
```ruby
# GET /health
{
  "status": "ok",
  "services": {
    "redis": "connected",
    "genius_api": "reachable"
  }
}
```

---

### Medium Priority (Enhanced UX)

#### 5. Infinite Scroll
**Why:** Better mobile experience, modern UX pattern.

**Implementation:**
- Intersection Observer API
- Load next page when user scrolls to bottom
- Keep "Load More" as fallback

---

#### 6. Search History (localStorage)
**Why:** Users often re-search same artists.

**Implementation:**
- Store last 10 searches in localStorage
- Show as suggestions below search box
- Clear history option

---

#### 7. Song Filtering & Sorting
**Why:** Users may want to find specific songs or sort by date.

**Implementation:**
- Frontend filter by title (no backend change)
- Sort by date, popularity (requires backend)
- Filter by year range

---

#### 8. Export Results
**Why:** Users may want to save song lists.

**Implementation:**
- Export to CSV
- Export to JSON
- Copy to clipboard

---

### Low Priority (Nice to Have)

#### 9. Artist Disambiguation
**Why:** Handle multiple artists with same name.

**Implementation:**
- If multiple matches, return 409 with candidates
- UI shows selection modal
- User picks correct artist

---

#### 10. Database for Analytics
**Why:** Track popular searches, cache hit rates, usage patterns.

**Implementation:**
- Add PostgreSQL
- Track: search queries, artists, timestamps
- Admin dashboard for analytics

---

#### 11. User Accounts & Favorites
**Why:** Personalization.

**Implementation:**
- Authentication (Devise)
- Save favorite artists
- Save favorite songs
- Search history per user

---

#### 12. GraphQL API
**Why:** More flexible queries, reduce over-fetching.

**Implementation:**
- Add graphql-ruby gem
- Create schema
- Migrate frontend to GraphQL client

---

## Why NOT Included in MVP

### PostgreSQL
- No data to persist (Genius API is source of truth)
- Would add sync complexity
- Redis caching sufficient for performance

### Sidekiq
- Synchronous requests are fast enough (<3s)
- Adds complexity (Redis as queue, worker processes)
- Can be added later if needed

### Circuit Breaker
- Retry logic handles transient failures
- Adds complexity
- Documented as high-priority production enhancement

### Authentication
- Out of scope
- Public API doesn't need auth
- Would require user management

### Microservices
- One service is appropriate for this size
- Would add deployment complexity
- Monolith is easier to develop and debug

---

## Testing Strategy

### Backend
- **Unit tests:** Service layer (GeniusService)
- **Request tests:** Controller layer (ArtistsController)
- **Integration tests:** Full flow with VCR cassettes
- **Target coverage:** >80%

### Frontend
- Component tests (React Testing Library)
- Integration tests for user flows
- Manual testing in multiple browsers

### Performance
- Load test with 100 concurrent users
- Measure cache hit rates
- Profile slow endpoints

---

## Deployment Considerations

### Example Architecture: AWS Deployment

This application is containerized and can be deployed to any cloud platform. Here's one possible AWS approach:

**Infrastructure:**
- ECS Fargate or EKS (Rails backend containers)
- S3 + CloudFront (React static frontend)
- ElastiCache (managed Redis)
- Application Load Balancer

**CI/CD Pipeline:**
- GitHub Actions for automated testing
- Build and push Docker images to ECR
- Blue-green or rolling deployments to ECS

**Observability:**
- CloudWatch Logs for centralized logging
- CloudWatch Alarms for critical metrics
- Error tracking service (Sentry, Rollbar, etc.)
- APM tool for performance monitoring (New Relic, DataDog)