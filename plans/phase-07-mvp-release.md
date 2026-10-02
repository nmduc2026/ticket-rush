# Phase 7 — Đóng gói & phát hành MVP

> Giai đoạn: **MVP** · Ước lượng: 1 tuần · Phụ thuộc: Phase 6 · Mốc AWS: **Lab 1 (~cuối 11/2026)**

## Mục tiêu
Biến code thành sản phẩm chạy được ở bất kỳ đâu: test E2E, Docker image, chạy trên máy 32GB, deploy thử lên AWS. Kết thúc giai đoạn MVP.

## Kết quả cuối phase
- Máy 32GB: `docker compose up` → toàn bộ hệ thống chạy từ image.
- Link demo công khai trên AWS hoạt động (sau đó destroy).
- README đủ để người khác tự chạy dự án.

## Không làm trong phase này
- ❌ Monitoring / ELK (Phase 8)
- ❌ Kubernetes (Phase 15)
- ❌ Auto scaling (Phase 10 / 16)

---

## Step 7.0 — Re-plan
- [ ] Đọc lại plan, xem backlog; liệt kê nợ kỹ thuật từ Phase 1–6

## Step 7.0a — AWS Lab 0 (hoãn từ Phase 0, làm TRƯỚC mọi thứ dùng AWS)
> Credits hết hạn ~10/01/2027 — làm bước này sớm trong Phase 7, không để sát Lab 1.
- [ ] Xem loại tài khoản (Free plan / Paid plan) và **ngày hết hạn credits** chính xác → ghi vào [README](README.md) mục 5
- [ ] Bật MFA cho root, đăng xuất root
- [ ] Bật IAM Identity Center, tạo user làm việc có MFA, permission set AdministratorAccess (chỉ cho lab cá nhân)
- [ ] `aws configure sso` → `aws sso login --profile ticketrush`; region cố định `ap-southeast-1`
- [ ] AWS Budgets: zero-spend budget + monthly budget 5$/20$/50$ (actual + forecast)
- [ ] Budget Action ở mức 50$: stop EC2/RDS + gắn IAM deny policy
- [ ] Bật Cost Anomaly Detection, Free Tier usage alerts
- [ ] Chạy `infra/terraform/aws/lab-00`: `terraform apply -var expires_at=...` → kiểm tra console → `terraform destroy` → `verify-clean.sh`

**Kiểm tra:** nhận email xác nhận budget; `aws sts get-caller-identity --profile ticketrush` trả về user SSO (không phải root); `verify-clean.sh` báo "sạch"; hôm sau Cost Explorer = 0$.

## Step 7.1 — Hoàn thiện nhỏ cho Organizer
- [ ] Trang danh sách đơn / vé đã bán của 1 sự kiện (truy vấn đơn giản — biểu đồ & jOOQ để Phase 12)

**Kiểm tra:** organizer xem được ai đã mua ghế nào.

## Step 7.2 — Test E2E
- [ ] Playwright: luồng mua vé thành công (thẻ test Stripe), luồng ghế bị người khác giữ, luồng hoàn vé
- [ ] Chạy E2E trong CI (Compose dựng môi trường)

**Kiểm tra:** 3 kịch bản E2E xanh trên CI.

## Step 7.3 — Docker image
- [ ] Dockerfile multi-stage cho `app`, `gateway` (JRE, non-root, layered jar); `frontend` (build → nginx)
- [ ] Cấu hình hoàn toàn qua biến môi trường
- [ ] CI build & push image lên GHCR khi merge vào `main`

**Kiểm tra:** image chạy được với `docker run`; kích thước image hợp lý (< 300MB cho JVM).

## Step 7.4 — Chạy trên máy 32GB ("staging" tạm)
- [ ] Compose profile `app` chạy toàn bộ từ image GHCR
- [ ] Script seed dữ liệu demo (địa điểm, sự kiện, user)
- [ ] Truy cập từ máy 16GB qua LAN

**Kiểm tra:** máy 32GB "sạch" (chỉ có Docker) → clone repo → 1 lệnh → dùng được trên máy 16GB.

## Step 7.5 — AWS Lab 1: deploy MVP
- [ ] Terraform `lab-01`: EC2 (Docker Compose: gateway, app, Keycloak, Redis, Mailpit), RDS PostgreSQL free tier, S3 + CloudFront cho FE
- [ ] CloudFront: `/` → S3, `/api/*`, `/oauth2/*`, `/login*`, `/logout` → EC2 (cùng domain cho cookie)
- [ ] Đăng ký webhook Stripe trỏ về URL CloudFront
- [ ] Làm xong → `terraform destroy` → `verify-clean.sh` → hôm sau xem Cost Explorer

**Kiểm tra:** mua vé thành công trên link công khai; sau destroy không còn resource; chi phí đúng dự kiến.

## Step 7.6 — Tài liệu & tổng kết MVP
- [ ] README: giới thiệu, kiến trúc, cách chạy, ảnh chụp màn hình
- [ ] Cập nhật overview cho mọi điểm khác thiết kế; hoàn thiện ADR
- [ ] Retrospective: điều gì tốt / chưa tốt / thay đổi cho giai đoạn 2 → ghi vào `docs/`

**Kiểm tra:** tag `v0.1.0-mvp` + `phase-07-done`.

---

## Checklist kết thúc phase
- [ ] 🎉 MVP hoàn thành
- [ ] Tag `v0.1.0-mvp`, `phase-07-done`
