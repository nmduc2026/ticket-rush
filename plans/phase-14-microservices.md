# Phase 14 — Tách microservices

> Giai đoạn: **Kiến trúc** · Ước lượng: 2 tuần · Phụ thuộc: Phase 13

## Mục tiêu
Tách monolith thành các service độc lập theo [overview §5](../overview.md#5-services--quyền-sở-hữu-dữ-liệu) bằng **strangler pattern**: tách từng service một, hệ thống luôn chạy được sau mỗi step.

## Kết quả cuối phase
- 6 service + Gateway, mỗi service 1 database.
- Outbox qua Debezium.
- Contract test (Pact) trong CI; E2E vẫn xanh.

## Không làm trong phase này
- ❌ Kubernetes (Phase 15) — chạy bằng Compose (máy 32GB)
- ❌ Autoscaling (Phase 16)

---

## Step 14.0 — Re-plan
- [ ] Đọc lại plan; vẽ sơ đồ phụ thuộc hiện tại giữa các module; chốt thứ tự tách

## Step 14.1 — Thư viện dùng chung
- [ ] Tách `platform-*` (web, security, kafka, observability) thành Maven module
- [ ] App monolith dùng lại các module này (chưa tách service)

**Kiểm tra:** build & test vẫn xanh.

## Step 14.2 — Tách notification-service
- [ ] Service đầu tiên (chỉ consume, ít rủi ro): project riêng, DB riêng, Dockerfile
- [ ] Xoá module notification khỏi monolith

**Kiểm tra:** mua vé → email vẫn đến; trace hiện service mới.

## Step 14.3 — Tách ticket-service
- [ ] DB riêng, migrate dữ liệu vé; Gateway route `/api/v1/me/tickets`, `/checkins`, `/tickets/keys`

**Kiểm tra:** check-in vẫn hoạt động.

## Step 14.4 — Tách payment-service
- [ ] DB riêng; webhook Stripe route qua Gateway tới service mới

**Kiểm tra:** thanh toán + hoàn tiền vẫn hoạt động.

## Step 14.5 — Tách booking, queue, catalog
- [ ] Mỗi service DB riêng; projection thay cho mọi chỗ còn đọc chéo dữ liệu
- [ ] Monolith biến mất

**Kiểm tra:** không còn service nào truy cập DB của service khác (kiểm tra bằng user DB riêng).

## Step 14.6 — Debezium outbox
- [ ] Kafka Connect + Debezium trong Compose; bảng `outbox` mỗi service; EventRouter
- [ ] Thay Spring Modulith externalization

**Kiểm tra:** stop Kafka Connect → thao tác → start lại → event được gửi đủ.

## Step 14.7 — Contract test & kiểm tra tổng
- [ ] Pact cho các API sync và event chính; chạy trong CI
- [ ] E2E + JMeter flash sale → so sánh

**Kiểm tra:** đổi field event phá hợp đồng → CI fail.

---

## Checklist kết thúc phase
- [ ] Cập nhật overview (§4.3 hình thái triển khai)
- [ ] Tag `phase-14-done`
