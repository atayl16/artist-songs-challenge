# Artist Song Search

A Rails + React application that searches for songs by artist using the Genius API.

## Features

- 🔍 Search for any artist
- 📃 Paginated song results (50 per page)
- ⚡ Redis caching (1 hour TTL)
- 🛡️ Rate limiting (10 searches/min per IP)
- 🔄 Automatic retry with exponential backoff
- ✅ Comprehensive error handling
- 🐳 Docker-ready
- 🧪 Full test coverage

## Quick Start (Docker - Recommended)
```bash
# 1. Clone and setup
git clone <your-repo-url>
cd artist-songs-challenge
cp .env.example .env
# Edit .env and add your GENIUS_API_KEY from https://genius.com/api-clients

# 2. Start everything
docker-compose up

# 3. Open your browser
# Frontend: http://localhost:3000
# Backend API: http://localhost:3001
```

That's it! The application will:
- Start Redis
- Install Ruby gems
- Install Node modules
- Start Rails backend (port 3001)
- Start React frontend (port 3000)

### Docker Commands
```bash
# Rebuild containers
docker-compose down
docker-compose up --build

# Run backend tests
docker-compose exec backend bundle exec rspec

# Stop everything
docker-compose down

# Remove all data (including Redis cache)
docker-compose down -v
```

## Manual Setup (Without Docker)

### Prerequisites
- Ruby 3.3.4
- Node.js 18+
- Redis
- Genius API key

### Backend Setup
```bash
cd backend

# Install dependencies
bundle install

# Setup environment
cp .env.example .env
# Edit .env and add your GENIUS_API_KEY

# Start Redis (in separate terminal)
redis-server

# Start Rails
bundle exec rails s -p 3001
```

### Frontend Setup
```bash
cd frontend

# Install dependencies
npm install

# Setup environment
cp .env.example .env.local
# Edit .env.local if needed (default: http://localhost:3001)

# Start React
npm start
```

### Run Tests
```bash
# Backend tests
cd backend
bundle exec rspec

# With detailed output
bundle exec rspec --format documentation

# Frontend tests
cd frontend
npm test
```

## Architecture

### Tech Stack
- **Backend:** Rails 8.1.1 (API-only)
- **Frontend:** React 18
- **Cache:** Redis 7
- **HTTP Client:** Faraday with retry middleware
- **Rate Limiting:** Rack::Attack
- **Testing:** RSpec, WebMock, VCR

### System Design
```
User Browser (localhost:3000)
    ↓
React Frontend
    ↓ HTTP GET
Rails API (localhost:3001)
    ↓
Rack::Attack (rate limiting)
    ↓
ArtistsController
    ↓
GeniusService
    ↓
Redis Cache? → [HIT] Return cached page
    ↓ [MISS]
Genius API (with retries)
    ↓
Cache result (1hr TTL) → Return to user
```

### File Structure
```
artist-songs-challenge/
├── docker-compose.yml
├── README.md
├── TASKS.md
│
├── backend/                   # Rails API
│   ├── app/
│   │   ├── controllers/api/v1/artists_controller.rb
│   │   └── services/genius_service.rb
│   ├── config/initializers/
│   │   ├── cors.rb
│   │   └── rack_attack.rb
│   ├── spec/
│   └── Gemfile
│
└── frontend/                  # React App
    ├── src/
    │   ├── components/
    │   │   ├── ArtistSearch.js
    │   │   └── SongList.js
    │   └── App.js
    └── package.json
```

## API Documentation

### Endpoint
```
GET /api/v1/artists/:name/songs
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| name | string | required | Artist name (URL-encoded) |
| page | integer | 1 | Page number (starts at 1) |
| per_page | integer | 50 | Results per page (max 50) |

### Example Request
```bash
curl "http://localhost:3001/api/v1/artists/Taylor%20Swift/songs?page=1&per_page=50"
```

### Success Response (200)
```json
{
  "artist": {
    "name": "Taylor Swift",
    "id": 1177
  },
  "songs": [
    {
      "id": 12345,
      "title": "Shake It Off",
      "url": "https://genius.com/...",
      "release_date": "2014"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 50,
    "has_next": true
  },
  "meta": {
    "fetched_at": "2024-10-31T12:00:00Z",
    "cached": false,
    "stale": false,
    "api_unavailable": false
  }
}
```

**Metadata Fields:**
- `cached`: `true` if songs were served from cache (not freshly fetched from Genius API)
- `stale`: `true` if data is being served from cache during an API outage (normally `false`)
- `api_unavailable`: `true` if Genius API is currently unreachable but cached data was available (normally `false`)

When the Genius API is down but cached data exists, responses will have `cached: true, stale: true, api_unavailable: true`. This allows clients to display a warning to users while still providing results.

### Error Responses

| Status | Error | Description |
|--------|-------|-------------|
| 400 | Bad Request | Missing or invalid parameters |
| 404 | Not Found | Artist not found |
| 422 | Unprocessable Entity | Invalid input (blank name, etc.) |
| 429 | Too Many Requests | Rate limit exceeded |
| 502 | Bad Gateway | Genius API error |
| 504 | Gateway Timeout | Request timed out |

## Design Decisions

### Why No Database?
The Genius API is the authoritative source. Adding a database would introduce sync complexity without clear benefit for this use case. Redis caching provides performance benefits without the overhead.

**When to add:** If we need search analytics, user preferences, or offline capability.

### Why Redis Caching Per Page?
Large artists (300+ songs) would timeout if fetching all at once. Paginated caching gives fast responses and better UX.

**Cache key pattern:** `v1:genius:artist:id:{artist_id}:p{page}:pp{per_page}`

### Why 50 Songs Per Page?
Balance between API calls and UX. Loads in <2 seconds and fills the screen. This is also the Genius API maximum.

### Why "Load More" vs Infinite Scroll?
Simpler implementation, clearer UX, better accessibility, easier to test.

### Why Rate Limiting at 10/min?
Protects Genius API quota. Search is an expensive operation. Normal users won't hit this limit.

## Production Considerations

This MVP demonstrates production-ready patterns but would need these additions for true production deployment:

### High Priority
- [ ] Circuit breaker pattern (fail fast when API down)
- [ ] Background jobs (Sidekiq) for large fetches
- [ ] Monitoring (error tracking, performance metrics)
- [ ] Health check endpoint
- [ ] Structured logging (Lograge)

### Medium Priority
- [ ] Database for search analytics
- [ ] Longer cache TTL for established artists
- [ ] API response compression
- [ ] Feature flags (Flipper)
- [ ] CI/CD pipeline (GitHub Actions)

### See [TASKS.md](TASKS.md) for complete list

## Troubleshooting

### Redis Connection Error
```bash
# Start Redis
redis-server

# Or use Docker
docker run -d -p 6379:6379 redis:7-alpine
```

### CORS Issues
Make sure backend CORS is configured for your frontend URL:
```ruby
# backend/config/initializers/cors.rb
origins 'localhost:3000', '127.0.0.1:3000'
```

### Tests Failing
```bash
# Delete VCR cassettes and regenerate
rm -rf spec/vcr_cassettes
bundle exec rspec
```

### Port Already in Use
```bash
# Find and kill process on port 3000 or 3001
lsof -ti:3000 | xargs kill -9
lsof -ti:3001 | xargs kill -9
```
