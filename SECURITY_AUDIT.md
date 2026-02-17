# Security Audit Report: Atlos Platform

**Date:** 2026-02-17
**Scope:** Full Elixir/Phoenix codebase (`/platform`)
**Methodology:** Manual source code review of authentication, authorization, input handling, cryptography, configuration, and data exposure

---

## Summary

| Severity | Count | Description |
|----------|-------|-------------|
| Critical | 1 | Server-Side Request Forgery (SSRF) in archiver |
| High | 3 | Insecure PRNG for invite codes, plaintext API tokens, recovery code logging |
| Medium | 4 | Path traversal, no rate limiting, unrestricted file upload types, no MFA brute-force protection |

All findings below have been verified against the source code. False positives from initial scanning (e.g., password reset not invalidating sessions -- it does) have been eliminated.

---

## Critical Severity

### 1. Server-Side Request Forgery (SSRF) in Archiver

**Files:**
- `lib/platform/workers/archiver.ex:14-26` (`download_file/2`)
- `lib/platform/workers/archiver.ex:79-80` (URL passed to `archive.py`)

**Description:**
User-supplied URLs stored in `MediaVersion.source_url` are passed directly to `curl` and to the Python `archive.py` script without any validation or blocklist filtering.

```elixir
# archiver.ex:14-26 -- fetches arbitrary URLs via curl
defp download_file(from_url, into_file) do
  {_, 0} =
    System.cmd("curl", ["-L", from_url, "-o", into_file], into: IO.stream())
end

# archiver.ex:79-80 -- user source_url passed to external script
"--url",
version.source_url
```

**Impact:**
An attacker with media creation access can:
- Access cloud metadata services (e.g., `http://169.254.169.254/latest/meta-data/iam/security-credentials/`) to steal IAM credentials
- Scan internal network services
- Access internal APIs bound to localhost
- Exfiltrate data from internal systems via archive artifacts

**Recommendation:**
Implement a URL validation function that:
- Resolves the hostname and rejects private/reserved IP ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8, 169.254.0.0/16, ::1)
- Restricts to http/https schemes only
- Validates after DNS resolution to prevent DNS rebinding
- Consider running the archiver in a network-isolated environment

---

## High Severity

### 2. Invite Codes Generated with Non-Cryptographic PRNG

**Files:**
- `lib/platform/invites/invite.ex:31-33`
- `lib/platform/utils.ex:25-27`

**Description:**
Invite codes used for account registration and project access are generated using `Enum.random/1`, which uses Erlang's `:rand` module (Xorshift116+ algorithm). This is not cryptographically secure and is predictable if the internal state can be inferred.

```elixir
# invite.ex:31-33
def generate_random_code do
  Utils.generate_random_sequence(16)
end

# utils.ex:25-27
def generate_random_sequence(length) do
  for _ <- 1..length, into: "", do: <<Enum.random(~c"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")>>
end
```

Notably, API tokens use the correct approach (`utils.ex:29-31`):
```elixir
def generate_secure_code() do
  :crypto.strong_rand_bytes(32) |> Base.url_encode64()
end
```

**Impact:**
An attacker who can observe several invite codes may be able to predict future codes, granting unauthorized access to the platform or specific projects with elevated roles (since invite codes can confer project membership roles).

**Recommendation:**
Replace `Enum.random()` with `:crypto.strong_rand_bytes/1` for invite code generation, similar to how `generate_secure_code/0` is already implemented.

---

### 3. API Tokens Stored in Plaintext in Database

**Files:**
- `lib/platform/api/api_token.ex:13` (schema definition)
- `lib/platform/api.ex:59` (lookup by raw value)

**Description:**
API token values are stored as plaintext strings in the database and looked up via direct equality comparison.

```elixir
# api_token.ex:13
field :value, :string

# api.ex:59
def get_api_token_by_value(value), do: Repo.get_by(APIToken, value: value)
```

**Impact:**
If the database is compromised (backup leak, SQL injection, insider threat), all API tokens are immediately usable. There is no defense-in-depth. In contrast, password reset tokens and session tokens ARE properly hashed (`user_token.ex:84-95`).

**Recommendation:**
Hash API tokens before storage using SHA-256 (similar to the existing `UserToken` pattern). Show the raw token only once at creation time. Look up tokens by their hash.

---

### 4. MFA Recovery Codes Logged in Plaintext

**File:** `lib/platform/accounts.ex:280-283`

**Description:**
When a user authenticates with an MFA recovery code instead of TOTP, the actual recovery code value is logged via the Auditor (which persists to logs and may forward to Slack).

```elixir
Platform.Auditor.log(:mfa_recovery_code_used, %{
  email: user.email,
  used_code: attrs["current_otp_code"]   # <-- actual recovery code value
})
```

**Impact:**
Recovery codes in logs could be used by anyone with log access to authenticate as that user (unless the code has been consumed). Even consumed codes in logs represent a data privacy concern.

**Recommendation:**
Remove the `used_code` field from the log entry. Log only that a recovery code was used, not the code itself:
```elixir
Platform.Auditor.log(:mfa_recovery_code_used, %{email: user.email})
```

---

## Medium Severity

### 5. Path Traversal in Archiver Metadata Processing

**File:** `lib/platform/workers/archiver.ex:92`

**Description:**
The archiver reads artifact file paths from a JSON metadata file produced by the external `archive.py` script and uses them in `Path.join/2` without validating that the result stays within the temp directory.

```elixir
# archiver.ex:92
loc = Path.join(temp_dir, artifact["file"])
```

If `artifact["file"]` contains path traversal sequences like `../../etc/passwd`, the resolved path will escape the temp directory.

**Impact:**
If the external archive script is compromised, or if an archived web page can influence the metadata JSON, an attacker could read or write files outside the intended directory.

**Recommendation:**
Validate that the resolved path is within `temp_dir`:
```elixir
loc = Path.join(temp_dir, artifact["file"])
unless String.starts_with?(Path.expand(loc), Path.expand(temp_dir)) do
  raise "Path traversal detected"
end
```

---

### 6. No Rate Limiting on Authentication and API Endpoints

**Files:**
- `lib/platform_web/controllers/accounts/user_session_controller.ex:13` (login)
- `lib/platform_web/controllers/accounts/user_session_controller.ex:48` (MFA)
- `lib/platform_web/controllers/accounts/user_reset_password_controller.ex:13` (password reset)
- `lib/platform_web/controllers/api/` (all API endpoints)

**Description:**
No rate limiting middleware is configured anywhere in the application. While login and registration have hCaptcha protection, the following are unprotected:

- MFA code verification (6-digit TOTP = 1,000,000 possible codes, 30-second window)
- API endpoints (no per-token or per-IP throttling)
- Password reset requests (email flooding)

**Impact:**
- MFA brute force: An attacker who has a user's password can brute-force the 6-digit TOTP code
- API abuse: Automated data scraping or denial of service via API
- Password reset spam: Flooding a user's email with reset requests

**Recommendation:**
Implement rate limiting using a library like `PlugAttack` or `Hammer`:
- Login: 5 attempts per minute per IP
- MFA: 5 attempts per minute per session
- Password reset: 3 requests per hour per email
- API: Configurable per-token limits

---

### 7. Unrestricted File Upload Types for Source Material

**File:** `lib/platform_web/live/media_live/upload_version_live.ex:13-20`

**Description:**
Media version uploads accept any file type with no restriction:

```elixir
|> allow_upload(:media_upload,
  accept: :any,           # <-- No file type restriction
  max_entries: 1,
  max_file_size: 250_000_000,
  ...
)
```

Other upload endpoints correctly restrict file types:
- Avatars: `.jpg .jpeg .png` (`profile_component.ex`)
- Comment attachments: `.png .jpg .jpeg .pdf .gif .mp4` (`comment_box.ex`)
- Bulk imports: `.csv` (`bulk_upload_live.ex`)

**Impact:**
Users can upload HTML files with embedded JavaScript, SVG files with script payloads, or other dangerous file types. While files are served via S3 presigned URLs (not from the application domain), they could still be used for phishing or as a malware distribution vector.

**Recommendation:**
Implement an allowlist of acceptable file types for source material uploads (images, videos, PDFs, WACZ archives) rather than accepting all types.

---

### 8. Unauthenticated Static File Serving for Uploads (Local Storage)

**File:** `lib/platform_web/endpoint.ex:32-45`

**Description:**
Three `Plug.Static` entries serve uploaded files without any authentication:

```elixir
plug(Plug.Static, at: "/artifacts", from: "artifacts")
plug(Plug.Static, at: "/avatars", from: "avatars")
plug(Plug.Static, at: "/attachments", from: "attachments")
```

**Impact:**
When using local storage (non-S3 mode, typically in development or self-hosted deployments), any uploaded artifact, avatar, or attachment is accessible to unauthenticated users who know or guess the file path. In S3 mode (production), files are served via presigned URLs instead, mitigating this for hosted deployments.

**Recommendation:**
Remove these `Plug.Static` entries or add authentication middleware. For local storage mode, serve files through an authenticated controller endpoint.

---

## Eliminated False Positives

The following findings from initial scanning were investigated and determined to be non-issues:

1. **"Password reset doesn't invalidate sessions"** -- FALSE. `Accounts.reset_user_password/2` at `accounts.ex:550-553` calls `Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))`, which deletes ALL session tokens.

2. **"Cookie HttpOnly flag missing"** -- FALSE. Phoenix's `Plug.Session.COOKIE` store sets `http_only: true` by default.

3. **"XSS via `raw()` in templates"** -- FALSE. All instances of `raw()` either operate on server-generated content (QR codes) or on user content that has been sanitized through `HtmlSanitizeEx` with a strict custom scrubber (`Platform.Security.UgcSanitizer`).

4. **"SQL injection via Ecto fragments"** -- FALSE. All `fragment()` calls in queries use parameterized inputs via the `^` binding operator. The `text_search` function at `utils.ex:332-359` properly parameterizes search terms.

5. **"TOCTOU race in media version authorization"** -- LOW RISK. LiveView socket state is maintained per-process and reliable within the LiveView lifecycle. The pattern of fetching then checking is standard for Phoenix and the authorization check is always performed before any mutation.

---

## Informational Notes

These are not vulnerabilities but are worth noting for defense-in-depth:

- **CSP includes `unsafe-eval`** (`router.ex:21`): Required by dependencies (Mapbox, Stripe, hCaptcha) but weakens XSS protections. Consider removing if dependencies support strict CSP.
- **`force_ssl` not configured** (`prod.exs:51-57`): SSL enforcement may be handled at the infrastructure level (reverse proxy/load balancer), but application-level enforcement provides defense-in-depth.
- **Database SSL verification disabled** (`runtime.exs:34-36`): `ssl_opts: [verify: :verify_none]` is used due to Azure PostgreSQL not providing a verifiable CA certificate. Acceptable if the database is in a private network.
- **Session cookie not encrypted** (`endpoint.ex:6`): Sessions are signed but not encrypted. Session data is visible (but not tamperable) to users. Consider adding `encryption_salt` if sensitive data is stored in sessions.
