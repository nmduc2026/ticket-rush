# Phase 2 — Xác thực & phân quyền

> Giai đoạn: **MVP** · Ước lượng: 1 tuần · Phụ thuộc: Phase 1

## Mục tiêu
Đăng nhập qua Keycloak theo **BFF pattern**: browser chỉ có cookie session, Gateway giữ token, app kiểm tra JWT và phân quyền theo 3 role.

## Kết quả cuối phase
- 3 user test (customer / organizer / admin) đăng nhập thấy menu khác nhau.
- Customer vào `/admin` bị chặn ở cả FE lẫn BE.
- DevTools: không có access token nào trong browser (chỉ cookie `SESSION`, `XSRF-TOKEN`).

## Không làm trong phase này
- ❌ Đăng ký organizer / duyệt organizer (Phase 3)
- ❌ Rate limit ở Gateway (Phase 9)
- ❌ Vault (Phase 15) — secret để trong `.env`

---

## Step 2.0 — Re-plan
- [ ] Đọc lại plan, xem backlog

## Step 2.1 — Keycloak
- [ ] Thêm Keycloak vào Compose profile `core` (dùng Postgres làm DB của Keycloak)
- [ ] Realm `ticketrush`: roles `CUSTOMER` (mặc định), `ORGANIZER`, `ADMIN`; client `ticketrush-bff` (confidential, Authorization Code + PKCE)
- [ ] 3 user test
- [ ] Export realm JSON vào `infra/keycloak/` → Compose tự import khi khởi động

**Kiểm tra:** xoá container, chạy lại → realm + user tự có lại.

## Step 2.2 — Gateway (BFF)
- [ ] Module `backend/gateway`: Spring Cloud Gateway Server MVC + OAuth2 Client
- [ ] Route `/api/**` → app (`localhost:8080`), filter `TokenRelay`
- [ ] Thêm **Redis** vào Compose `core` + Spring Session Data Redis
- [ ] Login / logout (OIDC RP-initiated logout), cookie `HttpOnly`, `Secure` (khi HTTPS), `SameSite=Lax`
- [ ] CSRF: cookie `XSRF-TOKEN`

**Kiểm tra:** mở `localhost:8081/api/v1/system/info` khi chưa đăng nhập → chuyển sang Keycloak → đăng nhập → quay lại thấy dữ liệu; restart Gateway vẫn còn đăng nhập (session ở Redis).

## Step 2.3 — App là Resource Server
- [ ] Spring Security + OAuth2 Resource Server (kiểm tra issuer, audience, hạn)
- [ ] Converter: realm roles của Keycloak → `ROLE_*` của Spring
- [ ] Quy tắc: `GET /api/v1/events/**` public, còn lại cần đăng nhập; bật `@PreAuthorize`
- [ ] `GET /api/v1/me` → id, tên, email, roles
- [ ] Test bằng `spring-security-test` (`jwt()` giả lập token với từng role)

**Kiểm tra:** test 401 (không token), 403 (sai role), 200 (đúng role) đều pass.

## Step 2.4 — Frontend xác thực
- [ ] Vite proxy `/api`, `/oauth2`, `/login`, `/logout` → Gateway (FE và API cùng origin → cookie hoạt động)
- [ ] Hook `useMe()`; nút đăng nhập / đăng xuất; hiển thị tên + role
- [ ] Custom fetch của Orval: gửi kèm `X-XSRF-TOKEN` cho request ghi (POST/PUT/DELETE)
- [ ] Route guard bằng `beforeLoad` theo role; trang 403 / 404
- [ ] Khung menu theo role: Customer / Organizer / Admin (trang trống)

**Kiểm tra:** đăng nhập lần lượt 3 user, mỗi user chỉ thấy đúng khu vực của mình; gõ URL `/admin` bằng user customer → trang 403.

## Step 2.5 — Rà soát bảo mật phase
- [ ] Kiểm tra không có token trong localStorage / sessionStorage / response body
- [ ] Security headers cơ bản ở Gateway (X-Content-Type-Options, Referrer-Policy, frame-ancestors)
- [ ] Ghi chú lại luồng đăng nhập thực tế vào overview §13 nếu khác thiết kế

**Kiểm tra:** checklist trên đạt; tag `phase-02-done`.

---

## Checklist kết thúc phase
- [ ] Demo 3 user, 3 giao diện
- [ ] Tag `phase-02-done`
