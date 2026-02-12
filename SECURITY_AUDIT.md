# Atlos Platform Security Audit Report

**Date:** 2026-02-12
**Scope:** Full codebase security review of the Atlos platform (`/platform`)
**Stack:** Elixir/Phoenix 1.7, PostgreSQL+PostGIS, Waffle (S3), Oban, LiveView

---

## Executive Summary

This audit identified **8 Critical**, **10 High**, **9 Medium**, and **7 Low** severity findings across the Atlos platform. The most impactful issues involve missing rate limiting on all authentication and API endpoints, plaintext API token storage, Server-Side Request Forgery (SSRF) through unrestricted URL fetching, potential command injection via FFmpeg filename interpolation, and the V1 API exposing data across all projects without scoping.

The codebase demonstrates several strong security practices including parameterized SQL queries via Ecto, HTML sanitization for user-generated markdown content, timing-safe password comparison, session renewal on login, and audit logging. However, the identified gaps present meaningful risk, particularly in combination.

---

## Critical Findings

### C1. No Rate Limiting on Any Endpoint

**Affected:** All authentication, API, and export endpoints
**Files:** Entire codebase (no `rate_limit`, `Hammer`, `PlugAttack`, or `throttle` patterns found)

No rate limiting library or mechanism exists anywhere in the application. This affects:

- **Login** (`POST /users/log_in`): Unlimited brute-force password attempts
- **MFA** (`POST /users/log_in/mfa`): Unlimited brute-force of 6-digit TOTP codes
- **Password reset** (`POST /users/reset_password`): Unlimited reset email flooding
- **Registration** (`POST /users/register`): Unlimited account creation
- **API endpoints** (`/api/v1/*`, `/api/v2/*`): Unlimited data extraction and writes
- **File uploads**: Unlimited upload volume

**Impact:** This is the single most impactful finding. Combined with MFA brute-force (see C2) and the disabled-by-default captchas (see H3), there is no anti-automation protection.

**Recommendation:** Implement rate limiting via `Hammer` or `PlugAttack`. Prioritize login, MFA, password reset, and API endpoints.

---

### C2. MFA Brute-Force Feasible (No Rate Limit + Double Time Window)

**File:** `lib/platform/accounts/user.ex:174-179`

```elixir
def verify_otp_code(secret, code) do
  time = System.os_time(:second)
  NimbleTOTP.valid?(secret, code, time: time) or
    NimbleTOTP.valid?(secret, code, time: time - 30)
end
```

The TOTP verification accepts codes from both the current and previous 30-second windows (60 seconds total). A 6-digit TOTP has 1,000,000 possible values. Without rate limiting, at even moderate request rates (~17K req/sec), an attacker who knows the password can brute-force the MFA code within the 60-second window.

**Impact:** MFA is effectively bypassable via brute-force for attackers who have obtained the password.

**Recommendation:** Add strict rate limiting (e.g., 5 attempts per minute) on the MFA endpoint. Consider account lockout after repeated failures.

---

### C3. API Tokens Stored in Plaintext

**File:** `lib/platform/api/api_token.ex:13,67`
**File:** `lib/platform/api.ex:59`

```elixir
# api_token.ex:67
|> put_change(:value, Platform.Utils.generate_secure_code())

# api.ex:59
def get_api_token_by_value(value), do: Repo.get_by(APIToken, value: value)
```

API tokens are generated with `:crypto.strong_rand_bytes(32)` (good entropy) but stored as plaintext in the database and looked up via direct equality comparison. A database compromise (SQL injection, backup leak, admin access) immediately yields all valid API tokens. Notably, session tokens (`UserToken`) and email reset tokens are properly hashed with SHA-256 before storage -- API tokens are the outlier.

**Recommendation:** Hash tokens with SHA-256 before storage. Show the raw token once at creation time. Compare hashes on lookup.

---

### C4. V1 API Exposes All Data Across Projects (No Tenant Scoping)

**File:** `lib/platform_web/controllers/api/api_v1_controller.ex:61-79`

```elixir
def media_versions(conn, params) do
  pagination_api(conn, params, fn opts ->
    Material.query_media_versions_paginated(
      Material.MediaVersion |> Ecto.Query.order_by(desc: :inserted_at), opts)
  end)
end
```

The V1 API endpoints (`/api/v1/media_versions`, `/api/v1/media`) query **all records in the database** with no project-level filtering. Any legacy API token can read every media item and version across every project. This is a severe cross-tenant data exposure.

**Recommendation:** Deprecate and remove the V1 API, or add mandatory project scoping. At minimum, filter results by the projects the token has access to.

---

### C5. Deactivated API Tokens Pass Authentication

**File:** `lib/platform_web/controllers/api/api_auth.ex:7-17`

```elixir
def check_api_token(conn, _opts) do
  with ["Bearer " <> provided] <- get_req_header(conn, "authorization"),
       token when not is_nil(token) <- API.get_api_token_by_value(provided) do
    conn |> assign(:token, token)
  ...
```

The `check_api_token` plug only verifies a token exists -- it does not check `token.is_active`. Deactivated tokens pass authentication. While downstream permission checks in `permissions.ex` do check `is_active`, the authentication layer itself is permissive. Any endpoint that omits a permission check will accept deactivated tokens.

**Recommendation:** Add `token.is_active == true` to the `check_api_token` guard clause.

---

### C6. Server-Side Request Forgery (SSRF) -- No URL Validation

**Files:**
- `lib/platform/workers/archiver.ex:14-26` (curl with user URL)
- `lib/platform/workers/archiver.ex:62-83` (Python script with user URL)
- `lib/platform_web/controllers/api/api_v2_controller.ex:172-195` (URL accepted from API)
- `lib/platform_web/controllers/media/http_download.ex:2-27` (HTTPoison fetch)

User-supplied `source_url` values are passed directly to `curl -L` and an external Python archival script with no validation against internal/private network ranges. The URL validation in `media.ex:292-311` only checks that a scheme and host exist and the host contains a dot -- it does not restrict schemes or block private IPs.

An attacker can provide URLs like `http://169.254.169.254/latest/meta-data/` (cloud metadata), `http://127.0.0.1:PORT/` (internal services), or `file:///etc/passwd` to probe the internal network or access cloud credentials.

**Recommendation:** Implement a URL validation module that resolves hostnames, blocks RFC 1918/link-local/loopback ranges, restricts to `http`/`https` schemes, and validates after redirect resolution.

---

### C7. Potential Command Injection via FFmpeg Filename Interpolation

**File:** `lib/platform/uploads.ex:49,81`

```elixir
# uploads.ex:49 (WatermarkedMediaVersion)
"-i #{input} -f apng #{output}"

# uploads.ex:81 (MediaVersionArtifact)
"-i #{input} -f apng #{output}"
```

Waffle upload transforms build FFmpeg command strings via string interpolation. The filename construction at `uploads.ex:57,96` incorporates the original user-supplied `file.file_name`:

```elixir
def filename(version, {file, _scope}) do
  "#{file.file_name}-#{version}"
end
```

If Waffle passes these interpolated strings through a shell (rather than as argument lists), a crafted filename containing shell metacharacters could achieve command injection. The severity depends on Waffle's internal implementation of `{:ffmpeg, fn ...}` transforms.

**Recommendation:** Sanitize filenames to alphanumerics/hyphens/underscores/dots. Use UUID-based filenames for storage. If possible, use `System.cmd` with argument lists rather than shell-interpolated strings for FFmpeg invocations.

---

### C8. Insecure Default Cookie Signing Salt

**File:** `lib/platform_web/endpoint.ex:11`

```elixir
signing_salt: System.get_env("COOKIE_SIGNING_SALT", "change this in production")
```

The default fallback is the literal string `"change this in production"`. If `COOKIE_SIGNING_SALT` is not set in production, session cookies can be forged by anyone who knows this default.

**Recommendation:** Remove the default value. Require the environment variable and raise on nil (matching how `SECRET_KEY_BASE` is handled in `runtime.exs`).

---

## High Findings

### H1. Session Cookie Not Encrypted, Missing Secure Flags

**File:** `lib/platform_web/endpoint.ex:7-12`

```elixir
@session_options [
  store: :cookie,
  max_age: 24 * 60 * 60 * 30,
  key: "_platform_key",
  signing_salt: System.get_env("COOKIE_SIGNING_SALT", "change this in production")
]
```

- **No `encryption_salt`**: Cookie is signed but not encrypted. Contents (including session token) can be read in transit.
- **No `secure: true`**: Cookie can be sent over plain HTTP.
- **No `same_site`**: Defaults vary by browser; should be explicitly `"Lax"` or `"Strict"`.
- **30-day max_age**: Long window for session theft exploitation.

**Recommendation:** Add `encryption_salt`, `secure: true`, and `same_site: "Lax"` to session options.

---

### H2. force_ssl / HSTS Not Enabled

**File:** `config/prod.exs:51-55` (commented out)

```elixir
#     config :platform, PlatformWeb.Endpoint,
#       force_ssl: [hsts: true]
```

No application-level HTTPS enforcement or HSTS header. Users are vulnerable to protocol downgrade/SSL stripping attacks unless the load balancer enforces this externally.

**Recommendation:** Enable `force_ssl: [hsts: true]` or verify infrastructure enforcement.

---

### H3. Captchas Disabled by Default

**File:** `lib/platform/utils.ex:140-161`

```elixir
if System.get_env("ENABLE_CAPTCHAS", "false") == "false" do
  true
else
  ...
end
```

The default for `ENABLE_CAPTCHAS` is `"false"`. Combined with no rate limiting (C1), there is zero anti-automation protection by default.

**Recommendation:** Enable captchas by default in production, or implement rate limiting as the primary anti-automation control.

---

### H4. Password Complexity Checks Commented Out

**File:** `lib/platform/accounts/user.ex:149-157`

```elixir
|> validate_length(:password, min: 12, max: 72)
# |> validate_format(:password, ~r/[a-z]/, ...)
# |> validate_format(:password, ~r/[A-Z]/, ...)
# |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, ...)
```

All complexity validations are commented out. Only a 12-72 character length check remains. Passwords like `"aaaaaaaaaaaa"` are accepted. No breach-database checking exists.

**Recommendation:** Consider adding a check against common/breached passwords (e.g., HaveIBeenPwned API or local dictionary). The 12-character minimum is reasonable per NIST SP 800-63B.

---

### H5. Database SSL Certificate Verification Disabled

**File:** `config/runtime.exs:34-36`

```elixir
ssl: System.get_env("AZURE_POSTGRESQL_SSL", "false") == "true",
ssl_opts: [verify: :verify_none],
```

TLS certificate validation is completely disabled for the production database connection, making it vulnerable to MITM attacks. The comment acknowledges: *"Azure does not provide a CA certificate that we can verify against."*

**Recommendation:** Pin the Azure PostgreSQL CA certificate and enable `verify: :verify_peer`.

---

### H6. Unrestricted File Upload (No Type or Content Validation)

**Files:**
- `lib/platform_web/controllers/api/api_v2_controller.ex:225-291` (API)
- `lib/platform_web/live/media_live/upload_version_live.ex:13-14` (LiveView: `accept: :any`)

No file type validation exists on any upload path. MIME type is determined solely from the user-provided file extension via `MIME.from_path()`, not by inspecting file content (magic bytes). Attackers can upload `.html`, `.svg`, `.exe`, or polyglot files.

**Recommendation:** Implement allowlisted MIME type validation based on magic byte detection, not just file extension.

---

### H7. Unsafe Static File Serving of User-Uploaded Content

**File:** `lib/platform_web/endpoint.ex:32-40`

```elixir
plug(Plug.Static, at: "/artifacts", from: "artifacts")
plug(Plug.Static, at: "/avatars", from: "avatars")
```

User-uploaded content in `artifacts/` and `avatars/` is served directly by `Plug.Static` with no `Content-Disposition: attachment` header, no `X-Content-Type-Options: nosniff`, and no file type filtering. HTML/SVG files would be served inline, enabling stored XSS.

**Recommendation:** Remove these plugs if S3 is always used in production. If they must remain, add security headers and serve user content with `Content-Disposition: attachment`.

---

### H8. IP Spoofing via Unconditionally Trusted Header

**File:** `lib/platform_web/plugs/remote_ip.ex:9-19`

The `fly-client-ip` header is trusted unconditionally. Any client can set this header to spoof their IP address unless the upstream proxy strips it. This affects audit logs and login notification emails.

**Recommendation:** Only trust `fly-client-ip` when behind Fly.io infrastructure. Configure the existing `remote_ip` library dependency for proper trusted proxy handling.

---

### H9. Unlimited Pagination (No Maximum Limit)

**File:** `lib/platform/repo.ex:7`

```elixir
use Quarto, maximum_limit: :infinity
```

No server-side limit on records per query page. An API consumer can request millions of records in a single query, causing memory exhaustion or database overload.

**Recommendation:** Set a reasonable `maximum_limit` (e.g., 1000).

---

### H10. WebSocket Timeout Set to Infinity

**File:** `lib/platform_web/endpoint.ex:17`

```elixir
websocket: [timeout: :infinity]
```

LiveView WebSocket connections never time out, enabling resource exhaustion via idle connection accumulation and making it impossible to enforce session expiration for LiveView users.

**Recommendation:** Set a reasonable timeout (e.g., 60,000ms, the Phoenix default).

---

## Medium Findings

### M1. MFA Pre-Auth State Not Expired or Session-Renewed

**File:** `lib/platform_web/controllers/accounts/user_session_controller.ex:19-22`

After password verification, the username is stored in session (`prelim_authed_username`) for MFA, but:
- Session is not renewed between password and MFA steps
- No timestamp/expiry on the pre-auth state
- State persists indefinitely until consumed

---

### M2. 60-Day Session Validity with No Idle Timeout

**File:** `lib/platform/accounts/user_token.ex:13` (`@session_validity_in_days 60`)
**File:** `lib/platform_web/endpoint.ex:9` (`max_age: 24 * 60 * 60 * 30` -- 30 days)

Session tokens are valid for 60 days in the database (though the cookie expires after 30 days). No idle timeout mechanism exists. For a platform handling sensitive investigative data, this is excessively long.

---

### M3. Suspended User Sessions Not Invalidated Server-Side

**File:** `lib/platform_web/controllers/accounts/user_auth.ex:156-160`

When a suspended user is detected, the browser session is cleared but `Accounts.delete_session_token/1` is not called. The server-side token remains valid. Other active sessions or LiveView connections are not disconnected.

---

### M4. "Disabled" Remember-Me Feature Still Activatable

**File:** `lib/platform_web/controllers/accounts/user_auth.ex:58-61`

The `maybe_write_remember_me_cookie` function is commented as unused, but the code actively writes a 60-day cookie when `remember_me: "true"` is present in login params. The `ensure_user_token` function at lines 120-132 actively reads this cookie.

---

### M5. Path Traversal via Archiver Artifact Filenames

**File:** `lib/platform/workers/archiver.ex:92,150`

```elixir
loc = Path.join(temp_dir, artifact["file"])
```

The `artifact["file"]` value from the Python script's `metadata.json` is used in `Path.join` without validation. An absolute path (`/etc/passwd`) or traversal sequence (`../../`) could escape the temp directory.

**Recommendation:** Validate that the resolved path starts with `temp_dir` after `Path.expand/1`.

---

### M6. Unrestricted Metadata Namespace Injection

**File:** `lib/platform_web/controllers/api/api_v2_controller.ex:198-222`

The `set_media_version_metadata` endpoint accepts arbitrary `namespace` and `metadata` JSON values with no validation, allowing overwrite of any metadata namespace or injection of very large payloads.

---

### M7. API Token Value Regenerated on Every Update

**File:** `lib/platform/api/api_token.ex:67`

The `changeset/2` function unconditionally generates a new token value via `put_change(:value, ...)`. This function is used for both creation and updates. Any metadata change (name, description, deactivation) silently rotates the token, breaking integrations.

---

### M8. Email Confirmation Not Enforced for Access

**File:** `lib/platform_web/controllers/accounts/user_auth.ex:153-178`

The `require_authenticated_user` plug checks for suspension and security mode but does NOT check `confirmed_at`. Users can register with any email and immediately access the application. The code contains a comment acknowledging this is the intended place for such a check.

---

### M9. Insecure Temporary File Handling

**File:** `lib/platform/workers/archiver.ex:286-294`

The archiver runs `tmpreaper -m 5m /tmp` (cleans all files older than 5 minutes from `/tmp`), which can interfere with concurrent archival jobs and other system processes.

---

## Low Findings

### L1. Content Security Policy Allows `unsafe-eval`

**File:** `lib/platform_web/router.ex:20-21`

CSP includes `'unsafe-eval'` in `script-src`, lacks `default-src`, and whitelists broad CDN domains (`unpkg.com`). A TODO comment acknowledges this needs tightening.

---

### L2. LiveView Signing Salt Hardcoded

**File:** `config/config.exs:24`

```elixir
live_view: [signing_salt: "ZesKOiEA"]
```

Hardcoded in the base config loaded in all environments including production.

---

### L3. LiveDashboard RequestLogger Active in Production

**File:** `lib/platform_web/endpoint.ex:51-54`

The `Phoenix.LiveDashboard.RequestLogger` plug runs in all environments, not guarded by `if code_reloading?`.

---

### L4. Admin MFA Disable Lacks Re-Authentication

**File:** `lib/platform_web/live/profiles_live/edit_component.ex:81-97`

Admins can disable any user's MFA without providing their own password or MFA code as confirmation. A compromised admin session could disable MFA for targeted accounts.

---

### L5. Pagination Errors Return HTTP 200

**File:** `lib/platform_web/controllers/api/api_v2_controller.ex:63`
**File:** `lib/platform_web/controllers/api/api_v1_controller.ex:57`

Failed pagination cursor verification returns `json(conn, %{error: message})` with HTTP 200 status.

---

### L6. Outdated GitHub Actions Versions

**File:** `.github/workflows/build-and-deploy.yml`, `.github/workflows/sync-deployments.yml`

Multiple Actions use outdated major versions (e.g., `actions/checkout@v2`, `docker/build-push-action@v3`). Outdated actions may contain vulnerabilities and lack security fixes.

---

### L7. Curl Piped to Bash in Dockerfile

**File:** `platform/Dockerfile:28`

```dockerfile
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -
```

Supply chain risk from piping remote script to bash during Docker build. Node.js 18 is also end-of-life.

---

## Positive Security Observations

The audit identified several well-implemented security practices:

1. **Parameterized queries**: All database queries use Ecto's parameterized query DSL. No raw SQL injection vectors found.
2. **HTML sanitization**: User markdown rendered via `Earmark` + `HtmlSanitizeEx` with a strict custom `UgcSanitizer` that only allows safe tags and `http`/`https`/`mailto` schemes.
3. **Timing-safe password comparison**: `Bcrypt.no_user_verify/0` prevents user enumeration via timing.
4. **Session fixation protection**: `renew_session/1` correctly renews session ID on login.
5. **Email/session tokens hashed**: `UserToken` stores SHA-256 hashes, not raw values.
6. **Password change invalidates sessions**: Both `update_user_password` and `reset_user_password` delete all tokens.
7. **CSRF protection**: The browser pipeline includes `:protect_from_forgery`.
8. **Login notification emails**: Users notified on login with remote IP.
9. **Audit logging**: Auth events logged via `Platform.Auditor`.
10. **Non-enumerable error messages**: Login/reset endpoints return generic messages regardless of email existence.
11. **Invite-based registration**: Account creation requires a valid invite code.
12. **CSV formula injection prevention**: Export uses `escape_formulas: true`.
13. **Sensitive field redaction**: User schema marks passwords, OTP secrets, and recovery codes with `redact: true`.
14. **JSON encoder restricted**: User JSON serialization excludes sensitive fields.

---

## Priority Remediation Order

| Priority | Finding | Effort |
|----------|---------|--------|
| 1 | C1: Add rate limiting (login, MFA, API) | Medium |
| 2 | C5: Check `is_active` in `check_api_token` | Low |
| 3 | C4: Add project scoping to V1 API or deprecate it | Low-Medium |
| 4 | C8: Remove insecure default cookie signing salt | Low |
| 5 | C3: Hash API tokens at rest | Medium |
| 6 | C6: Implement URL validation for SSRF prevention | Medium |
| 7 | H1: Add encryption_salt and secure flag to session | Low |
| 8 | C7: Sanitize filenames before FFmpeg processing | Low |
| 9 | H2: Enable force_ssl/HSTS | Low |
| 10 | H6: Add file type validation on uploads | Medium |
| 11 | H5: Enable database SSL certificate verification | Low-Medium |
| 12 | H9: Set pagination maximum_limit | Low |
| 13 | H10: Set WebSocket timeout | Low |
| 14 | H7: Add security headers to static file serving | Low |
