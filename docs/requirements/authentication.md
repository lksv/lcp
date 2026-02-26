# Authentication — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## Basic Authentication

- [x] Username / email + password authentication — built-in Devise mode or host app delegation
- [ ] New user registration (self-registration with email confirmation)
- [ ] Invitation system (admin invites user by email)
- [ ] Login with remember me (persistent session)
- [x] Logout (session / token invalidation)
- [ ] Automatic logout after inactivity (configurable timeout per role / per tenant)
- [ ] Forced logout of all sessions (admin action — on account compromise)

## Passwords and Password Policy

- [ ] Minimum password length (configurable)
- [ ] Complexity requirements (uppercase/lowercase, digits, special chars — configurable)
- [ ] Common password blacklist (dictionary attack prevention)
- [ ] Check against known breaches (Have I Been Pwned API)
- [ ] Password expiration (require change after X days — configurable, optional)
- [ ] Password history (cannot reuse last N passwords)
- [ ] Password reset via email (with time-limited token)
- [ ] Password reset via SMS / alternative channel
- [ ] Forced password change on first login
- [ ] Secure password hashing (bcrypt / Argon2 with configurable cost factor)

## Multi-Factor Authentication (MFA)

- [ ] TOTP (Google Authenticator, Authy — RFC 6238)
- [ ] SMS code as second factor
- [ ] Email code as second factor
- [ ] Hardware keys (WebAuthn / FIDO2 — YubiKey)
- [ ] Push notification for login approval
- [ ] Recovery codes (one-time backup codes on device loss)
- [ ] MFA required per role / per tenant (admin must have MFA, viewer doesn't)
- [ ] MFA bypass for trusted devices (remember device for X days)
- [ ] Configuration of allowed MFA methods per tenant
- [ ] Graceful enrollment (user sets up MFA on next login, not immediately)

## Single Sign-On (SSO)

- [ ] SAML 2.0 (integration with corporate IdP — AD FS, Okta, Azure AD...)
- [ ] OAuth2 / OpenID Connect (authorization code flow)
- [ ] Multiple IdP support per tenant (customer A has Azure AD, customer B has Okta)
- [ ] IdP-initiated SSO (login starts from corporate portal)
- [ ] SP-initiated SSO (login starts from our application)
- [ ] Just-In-Time provisioning (auto-create user on first SSO login)
- [ ] Group / role mapping from IdP (SAML attributes / OIDC claims → platform roles)
- [ ] Fallback to local authentication (when SSO unavailable)
- [ ] SSO logout (single logout — logging out from IdP logs out from our app)
- [ ] SSO configuration per tenant from admin UI (without developer intervention)

## Social Login

- [ ] Google login
- [ ] Microsoft / Azure AD login
- [ ] Apple login
- [ ] GitHub login
- [ ] Configurable — which social providers are allowed per tenant
- [ ] Linking social account with existing local account
- [ ] Unlinking social account (with local password setup)

## Session Management

- [ ] Server-side sessions (with Redis / DB storage)
- [ ] JWT tokens (stateless, for API access)
- [ ] Access token + refresh token (short-lived access, long-lived refresh)
- [ ] Configurable expiration per token type / per role
- [ ] Token revocation (blacklist — immediate token invalidation)
- [ ] Refresh token rotation (new refresh token on each refresh — theft detection)
- [ ] Concurrent session limit (max N active sessions per user)
- [ ] Session listing (user sees their active sessions — device, location, time)
- [ ] Remote session termination (user or admin terminates specific session)
- [ ] Fingerprint / session binding to device (session hijacking detection)

## Account Security

- [ ] Account lockout after N failed attempts (with configurable timeout)
- [ ] Progressive delay (increasing wait time between attempts)
- [ ] CAPTCHA after N failed attempts
- [ ] Notification to user on login from new device / location
- [ ] Notification on password / email change
- [ ] Notification on MFA add / remove
- [ ] IP-based anomaly detection (login from unusual location → require verification)
- [ ] Brute-force protection (rate limiting on login endpoint — per IP, per account)
- [ ] Account deactivation / suspension (admin action)
- [ ] Account deletion (GDPR right to erasure — with data anonymization)

## User Management

- [ ] Admin UI for user management (CRUD, filtering, searching)
- [ ] Bulk user import (CSV / XLSX)
- [ ] User synchronization from LDAP / AD (scheduled sync)
- [ ] SCIM provisioning (automatic provisioning / deprovisioning from IdP)
- [ ] User profile (name, email, avatar, contact details, preferences)
- [x] User groups / teams — Groups subsystem (YAML, DB, host adapter)
- [ ] Organizational hierarchy (supervisor / subordinate)
- [x] Role assignment to users (per module, per tenant, per project) — role_source: :model + group role mappings
- [ ] Permission delegation (temporary permission transfer during absence)
- [x] Impersonation (admin logs in "as" another user — for debugging and support)
- [ ] Invitation flow (email invitation → registration → role assignment)

## Multitenancy and Isolation

- [ ] Tenant-specific authentication settings (password policy, MFA requirements, SSO config)
- [ ] Tenant-specific login page (custom branding, logo, colors)
- [ ] Tenant discovery (by domain, subdomain, or selection at login)
- [ ] Cross-tenant access for superadmin (switching between tenants)
- [ ] User data isolation between tenants

## API Authentication

- [ ] API key authentication (per application / per integration)
- [ ] OAuth2 client credentials flow (machine-to-machine)
- [ ] Service accounts (system accounts without physical person assignment)
- [ ] Scoped tokens (token with limited permissions)
- [ ] API key lifecycle management (creation, rotation, expiration, revocation)
- [ ] API key audit (which key was used, when, from where)

## Audit and Compliance

- [ ] Logging all authentication events (login, logout, failed login, password change, MFA setup...)
- [ ] Logging IP address, user-agent, geolocation on login
- [ ] Failed login report (overview of failed attempts — per user, per IP)
- [ ] Login history per user (admin and self-service view)
- [ ] Compliance report (which users lack MFA, which have expired passwords...)
- [ ] GDPR data export (all user authentication data)
- [ ] Retention policy on authentication logs (automatic deletion after X months)

## Infrastructure Security

- [~] HTTPS only (HTTP → HTTPS redirect, HSTS header) — host app responsibility, engine doesn't enforce
- [~] Secure cookie flags (HttpOnly, Secure, SameSite) — Rails defaults apply
- [x] CSRF protection (token-based) — Rails built-in
- [ ] CORS configuration per tenant / per application
- [ ] CSP (Content Security Policy) headers
- [ ] Rate limiting on all authentication endpoints
- [~] Session fixation protection — Rails built-in `reset_session`
- [ ] Credential stuffing protection (detection of known breached credentials)
- [ ] Account enumeration protection (uniform response for existing and non-existing accounts)

---

## Key Points

- **SSO configuration from admin UI** — in enterprise environments each customer (tenant) has a different IdP. If configuration requires developer intervention, onboarding a new customer takes weeks instead of minutes.
- **Just-In-Time provisioning** — user logs in via SSO and their account is automatically created with mapped roles. Without this, admin must manually create accounts beforehand, which doesn't scale.
- **Refresh token rotation** — if an attacker steals a refresh token, the next rotation gives the legitimate user a new token and invalidates the attacker's. Without rotation, the attacker has permanent access.
- **Account enumeration protection** — login endpoint must return the same response for "wrong password" and "account doesn't exist". Otherwise an attacker can enumerate valid emails.
- **Impersonation with audit log** — support team needs to see the platform through the user's eyes. But every action under impersonation must be logged under the admin, not the user, otherwise it's a security hole.
- **SCIM provisioning** — in enterprise with thousands of users, manual account management is unsustainable. SCIM enables automatic provisioning/deprovisioning from central IdP — employee leaving the company = automatic account deactivation.
- **Concurrent session limit** — without this, one account is shared by an entire department. The limit forces each user to have their own account, which is important for audit trail.
- **Progressive delay and CAPTCHA** — account lockout is a blunt instrument (an attacker can deliberately lock out a legitimate user). Progressive delay + CAPTCHA is a more elegant solution.
