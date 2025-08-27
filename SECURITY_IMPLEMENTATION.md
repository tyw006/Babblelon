# BabbleOn Security Implementation Guide

## 📋 Executive Summary

This document provides a comprehensive overview of the security measures implemented for the BabbleOn Thai language learning game. The implementation follows a **beta-first approach** - providing robust security while allowing full game access for testing, with advanced security features planned for production launch.

## 🎯 Security Strategy

### Beta Phase (Current Implementation)
- **Full Game Access**: Beta testers can access all features without artificial restrictions
- **Essential Security**: APIs and user data are protected from abuse and attacks
- **Generous Limits**: 100 API calls/hour rate limit allows extensive testing
- **Data Protection**: User authentication, input validation, and secure data handling

### Production Phase (Post-Beta)
- **Progressive Authentication**: Trial limits with smooth upgrade paths
- **Advanced Fraud Prevention**: Device fingerprinting and abuse detection
- **Cost Management**: Sophisticated rate limiting and usage controls
- **Enterprise Security**: Advanced monitoring, alerting, and compliance features

## 🔒 Implemented Security Features

### Backend API Security (`backend/`)

#### 1. JWT Authentication Service (`services/auth_service.py`)

**Capabilities:**
- Supabase JWT token validation with HS256 algorithm
- User information extraction (user_id, email, anonymous status)
- Development mode fallback for easier testing
- Integration with FastAPI dependency injection

**Implementation:**
```python
@app.post("/pronunciation/assess/")
async def pronunciation_assessment_endpoint(
    user_info: UserInfo = Depends(require_auth),
    # ... other parameters
):
    # Automatic JWT validation and user extraction
    check_rate_limit(user_info)  # Rate limiting per user
```

**Security Features:**
- Token expiration validation
- Audience verification ("authenticated")
- Graceful error handling for invalid tokens
- Optional authentication for development

#### 2. Input Validation Service (`services/validation_service.py`)

**Audio File Validation:**
- File size limits (10MB maximum)
- MIME type verification (audio/wav, audio/mp3, etc.)
- File extension validation (.wav, .mp3, .m4a, .webm, .ogg)
- Content header analysis with fallback detection
- Magic number validation (when python-magic available)

**Text Input Sanitization:**
- Length limits (10,000 characters maximum)
- Character pattern validation (Thai, English, punctuation)
- HTML/script tag removal
- Whitespace normalization

**Parameter Validation:**
- Language code validation (th, en, th-TH, en-US, en-GB)
- Complexity level validation (1-5)
- NPC ID validation (amara, somchai)

#### 3. Security Middleware (`services/security_service.py`)

**Security Headers:**
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Content-Security-Policy: default-src 'self'`
- Custom `Server: BabbleOn-API` header

**Request Logging:**
- Comprehensive request/response logging
- Performance timing tracking
- Client IP and User-Agent capture
- In-memory request history (last 1000 requests)

**CORS Configuration:**
- Environment-based origin control
- Development: `localhost`, `127.0.0.1`, Android emulator
- Staging: `staging.babblelon.app` + localhost
- Production: `babblelon.app`, `www.babblelon.app`

#### 4. Rate Limiting (`auth_service.py`)

**Beta Configuration:**
- 100 requests per hour per user
- Sliding window algorithm
- In-memory storage (suitable for single-server beta)
- Graceful error responses (HTTP 429)

**User Identification:**
- JWT user_id for authenticated users
- IP-based fallback for anonymous users
- Separate limits for anonymous vs authenticated

#### 5. Enhanced Main Application (`main.py`)

**Security Integration:**
- JWT authentication on critical endpoints
- Input validation on all user inputs
- Comprehensive error handling
- Security-aware health endpoint

**Protected Endpoints:**
- `/pronunciation/assess/` - Audio pronunciation assessment
- `/generate-npc-response/` - NPC conversation generation
- All endpoints requiring user context

**Public Endpoints:**
- `/health` - System health and security status
- `/` - Basic API information

### Frontend Security (`lib/services/`)

#### 1. API Authentication Service (`api_auth_service.dart`)

**JWT Token Management:**
- Automatic token extraction from Supabase session
- Authentication header injection for all API calls
- Token validation and expiration handling
- User authentication status tracking

**Request Authentication:**
```dart
// Automatic auth header injection
apiAuthService.addAuthToRequest(request);

// Headers added:
// Authorization: Bearer <jwt_token>
// User-Agent: BabbleOn-Mobile/1.0
```

#### 2. Enhanced API Service (`api_service.dart`)

**Authentication Integration:**
- JWT tokens sent with all API requests
- Proper error handling for authentication failures (401)
- Rate limiting awareness (429)
- Automatic retry logic for expired tokens

**Error Handling:**
- `401 Unauthorized`: "Authentication failed - please log in again"
- `429 Too Many Requests`: "Rate limit exceeded - please try again later"
- Structured error responses for specific failures

### Configuration Management

#### Environment Configuration (`.env.example`)

**Required Variables:**
```bash
# Supabase Authentication
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_JWT_SECRET=your-jwt-secret

# AI Service APIs
ELEVENLABS_API_KEY=your-elevenlabs-api-key
OPENAI_API_KEY=your-openai-api-key
GEMINI_API_KEY=your-gemini-api-key
AZURE_SPEECH_KEY=your-azure-speech-key
AZURE_SPEECH_REGION=your-azure-region

# Environment Control
ENVIRONMENT=development  # development, staging, production
```

**Security Configuration:**
```bash
# Rate Limiting
BETA_RATE_LIMIT_PER_HOUR=100
PRODUCTION_RATE_LIMIT_PER_HOUR=50

# CORS Origins
CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
```

## 🧪 Testing and Validation

### Security Test Suite (`backend/test_security.py`)

**Test Coverage:**
- Health endpoint security configuration
- CORS header validation
- Authentication requirement verification
- Invalid token rejection
- Rate limiting functionality
- Input validation testing

**Usage:**
```bash
cd backend
uv run test_security.py
```

**Expected Results:**
- JWT authentication properly configured
- Security headers present
- CORS origins restricted appropriately
- Input validation active
- Rate limiting functional

## 🚀 Deployment Checklist

### Pre-Beta Launch
- [x] ✅ Supabase anonymous authentication enabled
- [x] ✅ Environment variables configured
- [x] ✅ Security dependencies installed
- [x] ✅ Backend security services integrated
- [x] ✅ Frontend authentication headers implemented
- [x] ✅ Basic rate limiting active (100/hour)

### Beta Testing Phase
- [ ] 🔄 Monitor API usage patterns
- [ ] 🔄 Collect user feedback on authentication flow
- [ ] 🔄 Track rate limiting effectiveness
- [ ] 🔄 Analyze security logs for anomalies

### Production Readiness
- [ ] ⏳ Advanced rate limiting implementation
- [ ] ⏳ Device fingerprinting system
- [ ] ⏳ Progressive authentication triggers
- [ ] ⏳ Cost management dashboard
- [ ] ⏳ Advanced monitoring and alerting

## 📊 Security Metrics and Monitoring

### Current Monitoring
- Request/response logging with timing
- Authentication success/failure rates
- Rate limiting trigger frequency
- Input validation failure patterns

### Recommended Production Metrics
- API cost per user/session
- Authentication conversion rates
- Abuse detection accuracy
- System performance under load

## 🛡️ Post-Beta Security Roadmap

### Phase 1: Progressive Authentication (Weeks 1-2)
**Trial Management:**
```
Anonymous Users → 50 API calls → Soft prompt → Hard gate → Account creation
```

**Implementation Requirements:**
- Device fingerprinting service
- Trial usage tracking database
- Conversion funnel optimization
- A/B testing for prompt messaging

### Phase 2: Advanced Rate Limiting (Weeks 3-4)
**Sophisticated Limits:**
- User tier-based rates (free: 50/hour, premium: unlimited)
- API endpoint-specific limits
- Sliding window with burst allowance
- Geographic and usage pattern analysis

**Infrastructure Requirements:**
- Redis/database for distributed rate limiting
- Real-time usage dashboard
- Automatic scaling based on usage
- Cost prediction and alerting

### Phase 3: Fraud Detection & Prevention (Weeks 5-6)
**Detection Systems:**
- Multiple trial prevention (device + network fingerprinting)
- Automated abuse pattern recognition
- Suspicious activity flagging and blocking
- Advanced session validation

**Response Automation:**
- Automatic account suspension for abuse
- IP-based blocking for repeated violations
- Manual review workflow for edge cases
- User appeal and reinstatement process

### Phase 4: Enterprise Features (Weeks 7-8)
**Advanced Security:**
- SOC 2 compliance preparation
- Advanced audit logging
- API key management for enterprise users
- Single sign-on (SSO) integration

**Cost Optimization:**
- Intelligent caching for expensive operations
- API response compression
- Request deduplication
- Priority queuing for premium users

## 🔧 Development and Maintenance

### Code Organization
```
backend/
├── services/
│   ├── auth_service.py          # JWT authentication
│   ├── validation_service.py    # Input validation
│   ├── security_service.py      # Middleware & utilities
│   └── ...
├── main.py                      # FastAPI app with security
└── test_security.py            # Security test suite

lib/services/
├── api_auth_service.dart       # Flutter JWT management
└── api_service.dart            # Enhanced with auth
```

### Security Updates Process
1. **Regular Dependency Updates**: Monthly security patch reviews
2. **Vulnerability Scanning**: Automated scanning on CI/CD pipeline
3. **Penetration Testing**: Quarterly third-party security assessment
4. **Incident Response**: Documented procedure for security incidents

### Documentation Maintenance
- **Security Architecture Review**: Quarterly assessment
- **Threat Model Updates**: As new features are added
- **Compliance Documentation**: Annual review for legal requirements
- **Developer Training**: Security best practices workshops

## ⚠️ Known Limitations and Mitigations

### Current Limitations

1. **In-Memory Rate Limiting**
   - **Limitation**: Single server, resets on restart
   - **Mitigation**: Suitable for beta, will implement Redis for production
   - **Timeline**: Production Phase 2

2. **Basic Device Detection**
   - **Limitation**: No advanced fingerprinting
   - **Mitigation**: Sufficient for honest users, advanced detection planned
   - **Timeline**: Production Phase 3

3. **Limited Audit Trail**
   - **Limitation**: Basic request logging only
   - **Mitigation**: Comprehensive audit logging planned for compliance
   - **Timeline**: Production Phase 4

### Risk Assessment

**High Risk → Mitigated:**
- ✅ **API Abuse**: JWT authentication + rate limiting
- ✅ **Data Injection**: Input validation + sanitization
- ✅ **XSS/CSRF**: Security headers + CORS configuration
- ✅ **Unauthorized Access**: JWT validation on all endpoints

**Medium Risk → Monitoring:**
- 🔄 **Cost Escalation**: Basic rate limiting, advanced controls planned
- 🔄 **Trial Abuse**: Anonymous auth with usage tracking
- 🔄 **Performance Impact**: Security middleware optimized

**Low Risk → Acceptable:**
- ✅ **Token Replay**: JWT expiration handles this
- ✅ **Man-in-Middle**: HTTPS enforced (external to API)
- ✅ **Data Privacy**: Minimal data collection, COPPA compliance

## 📞 Security Contact and Escalation

### Security Incident Response
1. **Immediate**: Stop ongoing attack, preserve logs
2. **Assessment**: Evaluate impact and affected systems
3. **Communication**: Notify stakeholders and users as needed
4. **Recovery**: Implement fixes and restore normal operation
5. **Post-Mortem**: Document lessons learned and improvements

### Emergency Contacts
- **Development Team**: Primary response team
- **Infrastructure**: Hosting and database providers
- **Legal**: Privacy and compliance consultation
- **Communication**: User notification and PR management

---

## 📈 Success Metrics

### Beta Phase Success Criteria
- [ ] Zero security incidents or data breaches
- [ ] 99.9% API authentication success rate
- [ ] Rate limiting prevents abuse without hindering legitimate use
- [ ] Input validation blocks malicious requests effectively
- [ ] Positive user feedback on authentication experience

### Production Readiness Criteria
- [ ] Advanced security features implemented and tested
- [ ] Third-party security audit passed
- [ ] Compliance requirements met (COPPA, GDPR as applicable)
- [ ] Scalable infrastructure for anticipated user growth
- [ ] Documentation and training complete for operations team

---

**Last Updated**: August 8, 2025  
**Version**: 1.0 - Beta Implementation  
**Next Review**: Post-Beta Launch (estimated 4-6 weeks)

This security implementation provides a solid foundation for BabbleOn's beta launch while establishing clear pathways for production-grade security features. The approach balances user experience with robust protection, ensuring both user satisfaction and system integrity.