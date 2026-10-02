# Phase 1 — Walking skeleton

> Giai đoạn: **MVP** · Ước lượng: 1 tuần · Phụ thuộc: Phase 0

## Mục tiêu
Dựng "bộ xương" chạy được **xuyên suốt** FE → BE → DB với 1 endpoint đơn giản, cùng toàn bộ nền móng chung (cấu trúc module, xử lý lỗi, log, test, CI). Các phase sau chỉ việc "đắp thịt".

## Kết quả cuối phase
- Trang chủ React gọi API Spring Boot, API đọc từ Postgres, hiển thị kết quả.
- Đổi DTO ở BE → FE báo lỗi compile (nhờ Orval).
- GitHub Actions xanh.

## Không làm trong phase này
- ❌ Đăng nhập / Keycloak / Gateway (Phase 2)
- ❌ Bất kỳ entity nghiệp vụ nào (event, booking…) (Phase 3+)
- ❌ Redis, Kafka, Elasticsearch, monitoring (phase sau)
- ❌ Dockerfile cho app (Phase 7)

---

## Step 1.0 — Re-plan
- [ ] Đọc lại plan, đối chiếu kết quả Phase 0, xem [backlog](backlog.md)

## Step 1.1 — Maven project
- [ ] `backend/pom.xml` (parent, Java 21, quản lý version) + module `backend/app` (modular monolith)
- [ ] Maven Wrapper (`mvnw`)
- [ ] Dependencies: web, actuator, validation, data-jpa, flyway, postgresql, spring-modulith, springdoc-openapi
- [ ] `spring.threads.virtual.enabled=true`
- [ ] Spotless (format code)

**Kiểm tra:** `./mvnw verify` xanh; app khởi động (tạm thời chưa cần DB thì tắt datasource ở profile test).

## Step 1.2 — Docker Compose dev + Postgres
- [ ] `infra/docker-compose/compose.yml` với profile `core`: chỉ **Postgres**
- [ ] Profile Spring: `local`, `test`; cấu hình datasource qua biến môi trường
- [ ] Flyway `V1__baseline.sql`; mỗi module 1 schema (`catalog`, `booking`, `payment`, `ticket`, `notification`)

**Kiểm tra:** `docker compose --profile core up -d` → chạy app → `GET /actuator/health` trả `UP` kèm `db`.

## Step 1.3 — Cấu trúc module & nền móng chung
- [ ] Package `com.ticketrush.{catalog,booking,payment,ticket,notification,shared}` + `package-info.java` khai báo module
- [ ] Test `ApplicationModules.of(...).verify()`
- [ ] `shared`: sinh UUIDv7, kiểu `Money`, bean `Clock` (để test thời gian)
- [ ] Xử lý lỗi toàn cục → `ProblemDetail` (RFC 9457) có field `code`
- [ ] Log JSON chuẩn ECS (`logging.structured.format.console: ecs`) — profile local có thể để dạng text dễ đọc

**Kiểm tra:** test module pass; gọi endpoint không tồn tại → trả `application/problem+json`.

## Step 1.4 — Hạ tầng test
- [ ] Testcontainers Postgres + `@ServiceConnection`, class base cho integration test
- [ ] Instancio, AssertJ
- [ ] 1 integration test mẫu (Flyway chạy được trên container)

**Kiểm tra:** `./mvnw verify` chạy cả unit + integration test, xanh.

## Step 1.5 — Frontend skeleton
- [ ] `pnpm create vite frontend --template react-ts`, TypeScript strict
- [ ] Tailwind v4, `shadcn init`, thêm vài component cơ bản (button, card, skeleton, sonner)
- [ ] TanStack Router (file-based) + TanStack Query
- [ ] Layout chung: header, footer, chế độ sáng/tối
- [ ] ESLint, Prettier, Vitest + RTL (1 test mẫu)
- [ ] Cấu trúc thư mục feature-based theo [overview §14.3](../overview.md#143-cấu-trúc-thư-mục-feature-based)

**Kiểm tra:** `pnpm dev` hiển thị layout; `pnpm lint && pnpm test && pnpm build` xanh.

## Step 1.6 — Thông đường FE ↔ BE qua OpenAPI
- [ ] BE: `GET /api/v1/system/info` (version, thời gian server, đọc 1 giá trị từ DB)
- [ ] Xuất `openapi.json` (springdoc) vào `backend/contracts/` khi build
- [ ] FE: cấu hình Orval → sinh `src/api/generated`, custom fetch (chuẩn bị chỗ gắn CSRF header ở Phase 2)
- [ ] Vite proxy `/api` → `localhost:8080`
- [ ] Trang chủ hiển thị dữ liệu từ hook do Orval sinh

**Kiểm tra:** trang chủ hiện thông tin server; thử đổi tên field trong DTO → chạy lại Orval → FE lỗi compile.

## Step 1.7 — CI v1
- [ ] GitHub Actions: job BE (`./mvnw -B verify`), job FE (`pnpm lint`, `pnpm test`, `pnpm build`)
- [ ] gitleaks trong CI

**Kiểm tra:** PR thử → cả 3 job xanh.

---

## Checklist kết thúc phase
- [ ] Demo: trang chủ ↔ API ↔ DB
- [ ] Ghi lại những gì khác so với plan (nếu có)
- [ ] Tag `phase-01-done`
