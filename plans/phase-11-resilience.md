# Phase 11 — Resilience & sự cố cơ bản

> Giai đoạn: **Vận hành** · Ước lượng: 1 tuần · Phụ thuộc: Phase 10 · Mốc AWS: **Lab 3 (~đầu 01/2027)** + **dọn sạch AWS (trước 05/01/2027)**

## Mục tiêu
Hệ thống "chết từng phần chứ không chết toàn bộ": bảo vệ lời gọi Stripe, xử lý khi Redis/DB sập, backup & khôi phục. Thực hành failover DB trên AWS rồi đóng AWS.

## Kết quả cuối phase
- Stripe chậm 5s → circuit breaker mở, người dùng nhận thông báo ngay.
- Redis sập → bán vé tạm dừng (fail-closed), xem sự kiện vẫn chạy.
- Khôi phục DB từ backup thành công, có số đo RTO.
- AWS: đo downtime khi RDS failover; tài khoản sạch.

## Không làm trong phase này
- ❌ Chaos Mesh & Game Day bài bản (Phase 18) — ở đây gây lỗi thủ công bằng `docker stop`
- ❌ PITR với CloudNativePG (Phase 17)

---

## Step 11.0 — Re-plan
- [ ] Đọc lại plan, xem backlog

## Step 11.1 — Resilience4j cho Stripe
- [ ] Timeout, retry (chỉ với idempotency key), circuit breaker, bulkhead theo [overview §15.1](../docs/overview.md#151-cấu-hình-resilience4j-khi-gọi-stripe)
- [ ] Metric trạng thái circuit breaker lên Grafana
- [ ] Test bằng WireMock: lỗi 500, chậm 5s, lỗi thoáng qua

**Kiểm tra:** test 3 tình huống pass; dashboard thấy circuit chuyển OPEN → HALF_OPEN → CLOSED.

## Step 11.2 — Suy giảm có kiểm soát
- [ ] Redis lỗi → chế độ "tạm dừng bán vé" (fail-closed), cache bỏ qua (fail-open)
- [ ] Graceful shutdown (`server.shutdown=graceful`)
- [ ] Load shedding ở Gateway khi quá ngưỡng → `503 + Retry-After`
- [ ] FE: trang/banner bảo trì thân thiện

**Kiểm tra:** `docker stop redis` khi đang dùng → đúng hành vi như [ma trận §15.2](../docs/overview.md#152-ma-trận-suy-giảm-khi-một-thành-phần-chết).

## Step 11.3 — Gây sự cố thủ công khi đang có tải
- [ ] JMeter chạy nền + lần lượt: stop Redis, stop Postgres, restart app
- [ ] Ghi nhận: alert có kêu không, hệ thống phản ứng thế nào, phục hồi mất bao lâu
- [ ] Viết 1 postmortem mẫu `docs/postmortems/`

**Kiểm tra:** mỗi sự cố có ghi nhận; runbook được cập nhật theo thực tế.

## Step 11.4 — Backup & khôi phục (Compose)
- [ ] Backup Postgres định kỳ (pg_dump) lên MinIO
- [ ] Diễn tập: xoá dữ liệu → khôi phục → đo RTO

**Kiểm tra:** khôi phục thành công, ghi số đo RTO.

## Step 11.5 — AWS Lab 3: RDS Multi-AZ failover
- [ ] Terraform `lab-03`: EC2 (app) + RDS Multi-AZ
- [ ] JMeter chạy nền → `aws rds reboot-db-instance --force-failover`
- [ ] Đo thời gian lỗi, quan sát Hikari reconnect; tinh chỉnh cấu hình nếu cần
- [ ] `destroy` → `verify-clean.sh`

**Kiểm tra:** có số đo downtime khi failover; AWS sạch.

## Step 11.6 — Đóng AWS (mốc cố định, trước 05/01/2027)
- [ ] Lưu ảnh chụp / số liệu cần cho portfolio
- [ ] `aws-nuke` dry-run → chạy thật → `verify-clean.sh` mọi region
- [ ] Xử lý tài khoản theo loại plan (README mục 5)

**Kiểm tra:** Cost Explorer = 0 trong 3 ngày liên tiếp.

---

## Checklist kết thúc phase
- [ ] Tag `phase-11-done` — **kết thúc giai đoạn Vận hành**
