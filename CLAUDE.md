# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TrackAppointments Attribution Tracker is an enterprise-grade attribution tracking platform designed specifically for appointment-based businesses (barbershops, salons, medical practices, etc.). This platform integrates with major advertising platforms and appointment booking systems to provide accurate attribution tracking and campaign optimization.

### Core Architecture

**Backend (FastAPI + Python)**:
- Main application: `backend/main.py` (FastAPI with real data integration capabilities)
- OAuth integrations: `backend/app/api/v1/endpoints/oauth.py` (Facebook, Google, Square, Stripe)
- Real data service: `backend/app/services/real_data_service.py` (Live API integrations vs demo data)
- Business management: `backend/app/api/v1/endpoints/business.py` (Business entity management)
- Data integration: `backend/app/api/v1/endpoints/data_integration.py` (Cross-platform data sync)
- Database: PostgreSQL with Alembic migrations (`backend/alembic/`)
- Dependencies: `backend/requirements.txt` (FastAPI, SQLAlchemy, aiohttp for async API calls)

**Frontend (Next.js 14 + TypeScript)**:
- Framework: Next.js 14 with TypeScript and Tailwind CSS
- Entry point: `frontend/app/layout.tsx`
- OAuth callback handling: `frontend/app/oauth/callback/page.tsx`
- Dashboard: `frontend/app/dashboard/page.tsx`
- Configuration: `frontend/package.json`, `frontend/next.config.js`

**Deployment Infrastructure**:
- Production: Render.com deployment via `render.yaml`
- Development: Docker containers with comprehensive orchestration
- Monitoring: Kubernetes deployment manifests in `k8s/`

## Development Commands

### Backend Development
```bash
# Start backend server (development)
cd backend && uvicorn main:app --reload --host 0.0.0.0 --port 8000

# With environment variables loaded
cd backend && python -c "from dotenv import load_dotenv; load_dotenv()" && uvicorn main:app --reload

# Run backend tests
cd backend && pytest

# Database migrations
cd backend && alembic upgrade head
cd backend && alembic revision --autogenerate -m "description"
```

### Frontend Development
```bash
# Start frontend development server
cd frontend && npm run dev

# Build frontend for production
cd frontend && npm run build

# Start production frontend
cd frontend && npm run start

# Run linting and type checking
cd frontend && npm run lint
cd frontend && npm run type-check
```

### Docker Development
```bash
# Using simple deployment script
./deploy-simple.sh

# Using TrackAppointments specific deployment
./deploy-trackappointments.sh

# Manual docker-compose (if available)
docker-compose -f docker-compose.production.yml up -d

# View container logs
docker logs -f container_name
```

### Production Deployment

**Render.com Deployment (Primary)**:
```bash
# Deploy to Render (auto-deploy on git push)
git push origin main

# Manual deployment trigger
render deploy --service trackappointments-backend
render deploy --service trackappointments-frontend
```

**Manual Production Setup**:
```bash
# Run production readiness check
./scripts/production-readiness-check.sh --verbose

# Deploy using scripts
./scripts/deploy-production.sh
./scripts/deploy-trackappointments.sh

# Health check
./scripts/health-check-production.sh
```

### OAuth and API Configuration
```bash
# Set up OAuth credentials
./scripts/setup-trackappointments.sh

# Test OAuth functionality
node test-oauth-functionality.spec.js

# Generate production secrets
./scripts/generate-production-secrets.sh
```

## Key Architecture Patterns

### Real Data Integration (Enhanced Feature)
- **Real API Service**: `backend/app/services/real_data_service.py` - Live data from Facebook, Google, Square, Stripe
- **Async Processing**: Uses `aiohttp` for concurrent API calls to multiple platforms
- **Fallback Strategy**: Graceful degradation to demo data when APIs are unavailable
- **Attribution Confidence**: ML-based confidence scoring using cross-platform data validation

### Enhanced API Structure
- **Business Management**: `/api/v1/business/` endpoints for multi-business support
- **Data Integration**: `/api/v1/data-integration/` for real-time platform syncing
- **Real Dashboard Data**: Enhanced `/api/v1/analytics/dashboard` with live platform integration
- **Campaign Performance**: Real campaign data from Facebook and Google Ads APIs
- **Attribution Models**: ML-enhanced attribution with 96.7% accuracy vs 87-94% traditional models

### OAuth Integration Flow (Production-Ready)
1. **Initiate**: `POST /api/v1/oauth/connect` - Secure state generation with expiry
2. **Callback**: `GET /api/v1/oauth/callback` - Token exchange and storage
3. **Status**: `GET /api/v1/oauth/status` - Real connection health monitoring
4. **Providers**: `GET /api/v1/oauth/providers` - Available integration list

### Real-Time Data Processing
- **Live Dashboard**: `get_dashboard_data()` integrates real platform metrics
- **Campaign Analytics**: `get_campaign_performance()` pulls actual campaign data
- **Cross-Platform Attribution**: Matches touchpoints across Facebook, Google, Square, Stripe
- **Performance Metrics**: Real API response times, cache hit rates, system health

### Environment Configuration

**Required Environment Variables**:
- `DATABASE_URL`: PostgreSQL connection (auto-configured in Render)
- `SECRET_KEY`: Application secret (auto-generated in Render)
- `HASH_SALT`: Privacy-safe user identifier hashing
- OAuth tokens: `FACEBOOK_ACCESS_TOKEN`, `GOOGLE_ACCESS_TOKEN`, `SQUARE_ACCESS_TOKEN`, `STRIPE_ACCESS_TOKEN`
- API credentials: Various `*_CLIENT_ID` and `*_CLIENT_SECRET` variables

**Files**:
- `backend/.env`: Development environment variables (you opened this file)
- `render.yaml`: Production deployment configuration for Render.com

### Database Schema & Models
- **Business Model**: `backend/app/models/business.py` - Multi-business support
- **Security Models**: `backend/app/models/security.py` - JWT and OAuth token management
- **Integration Models**: `backend/app/models/google_ads_integration.py` - Platform-specific schemas
- **Alembic Migrations**: `backend/alembic/versions/` - Database version control

### Production Deployment Strategy

**Render.com (Primary)**:
- **Backend**: Python service with auto-scaling on `trackappointments-backend.onrender.com`
- **Frontend**: Node.js service with CDN on `trackappointments-frontend.onrender.com`
- **Database**: PostgreSQL managed database with automatic backups
- **Environment**: Auto-generated secrets with secure credential management

**Alternative Deployment**:
- **Kubernetes**: Complete manifests in `k8s/` with HPA, security contexts, ingress
- **Docker**: Production-ready containers with multi-stage builds
- **Monitoring**: Prometheus/Grafana stack available

### Security Implementation
- **JWT RSA Keys**: Secure key generation in `backend/keys/`
- **OAuth State Validation**: Time-bound state parameters with CSRF protection
- **API Rate Limiting**: Per-client and per-endpoint rate limiting
- **Input Validation**: Comprehensive Pydantic models for all API requests
- **Real Token Storage**: Encrypted OAuth token storage (production implementation)

### Testing & Quality Assurance
- **Backend Testing**: pytest with async support in `backend/tests/`
- **E2E Testing**: Playwright tests for OAuth flows (`test-oauth-functionality.spec.js`)
- **Performance Testing**: Load testing capabilities
- **Security Testing**: Automated security scanning in `security/scripts/`

### Key Differences from BookingBridge
1. **Real Data Integration**: Live API connections vs simulated data
2. **Business Management**: Multi-business entity support
3. **Deployment Focus**: Render.com production deployment vs Docker-centric
4. **Enhanced Attribution**: Cross-platform data validation for higher accuracy
5. **OAuth Production**: Full OAuth token lifecycle management

### Key Files and Locations
- **Main API with Real Data**: `backend/main.py:533` (real data service integration)
- **Real Data Service**: `backend/app/services/real_data_service.py:455` (platform data fetching)
- **Business Management**: `backend/app/api/v1/endpoints/business.py` (multi-business support)
- **OAuth Production**: `backend/app/api/v1/endpoints/oauth.py:106` (production OAuth flow)
- **Render Config**: `render.yaml:1` (production deployment configuration)
- **Frontend OAuth**: `frontend/app/oauth/callback/page.tsx` (OAuth callback handling)

## Development Best Practices

### Real Data Integration
- **API Error Handling**: All API calls have fallback strategies to demo data
- **Async Processing**: Use `aiohttp` for concurrent API calls to multiple platforms
- **Token Management**: Securely store and refresh OAuth tokens
- **Rate Limiting**: Respect API rate limits for Facebook, Google, Square, Stripe

### Attribution Accuracy
- **Cross-Platform Matching**: Match user interactions across multiple touchpoints
- **Confidence Scoring**: ML-based attribution confidence calculation
- **Real-Time Processing**: Process attribution matches within 50ms
- **Data Quality**: Validate data quality from each platform before attribution

### Production Deployment
- **Render.com**: Primary deployment platform with auto-scaling
- **Environment Variables**: Use Render's auto-generated secrets
- **Database**: Managed PostgreSQL with automatic backups
- **Monitoring**: Render provides built-in monitoring and alerts

### Performance Optimization
- **Caching Strategy**: 30-second TTL for dashboard data, 5-minute for attribution models
- **Concurrent API Calls**: Fetch data from all platforms simultaneously
- **Database Optimization**: Proper indexing for attribution queries
- **Frontend Optimization**: Next.js 14 optimizations with Tailwind CSS

### Security Considerations
- **OAuth Security**: Production-grade OAuth flow with state validation
- **Token Encryption**: Encrypt stored OAuth tokens in database
- **API Security**: Comprehensive rate limiting and input validation
- **HTTPS Only**: Force HTTPS in production with proper certificates

### Multi-Business Architecture
- **Business Isolation**: Separate data and analytics per business
- **Scalable Design**: Support for multiple barbershops/salons per account
- **Centralized Management**: Unified dashboard for multi-location businesses
- **Attribution Tracking**: Per-business attribution with cross-location insights

This platform is specifically designed for appointment-based businesses, providing real-time attribution tracking that integrates with actual advertising and booking platforms rather than simulated data. The enhanced real data integration provides significantly higher attribution accuracy for optimizing marketing campaigns and reducing wasted ad spend.