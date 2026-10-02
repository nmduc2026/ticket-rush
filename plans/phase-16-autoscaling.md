# Phase 16 — Autoscaling

> Giai đoạn: **Kiến trúc** · Ước lượng: 1 tuần · Phụ thuộc: Phase 15

## Mục tiêu
Hệ thống tự scale-out khi tải tăng, scale-in (kể cả về 0) khi rảnh, và scale sẵn trước giờ mở bán.

## Kết quả cuối phase
- JMeter spike 500 user → số pod tăng, latency giữ trong SLO.
- Không có message → notification-service về 0 pod.
- Có timeline "tải ↔ số pod" trong `docs/perf/`.

## Không làm trong phase này
- ❌ Canary deploy (Phase 17)
- ❌ Node autoscaling trên cloud (chỉ mô tả, không có cụm cloud)

---

## Step 16.0 — Re-plan
- [ ] Đọc lại plan, xem backlog (B2 k6 CI gate, B3 GraalVM / CRaC)

## Step 16.1 — Right-sizing
- [ ] VPA chế độ gợi ý; chỉnh `requests / limits` theo số liệu thật

**Kiểm tra:** bảng requests / limits trước / sau.

## Step 16.2 — HPA
- [ ] HPA theo CPU cho gateway, booking, catalog
- [ ] Prometheus Adapter: HPA theo request/giây

**Kiểm tra:** tăng tải → pod tăng; hết tải → pod giảm (quan sát cửa sổ ổn định).

## Step 16.3 — KEDA
- [ ] Scale consumer theo Kafka lag; notification scale-to-zero
- [ ] Cron scaler pre-warm trước `sale_starts_at`

**Kiểm tra:** để yên 10 phút → notification = 0 pod; mua vé → pod bật lên, email vẫn đến.

## Step 16.4 — Kết nối DB khi scale
- [ ] Scale booking lên 20 pod → xác nhận PgBouncer giữ số kết nối Postgres ổn định

**Kiểm tra:** `pg_stat_activity` không vượt ngưỡng.

## Step 16.5 — Spike test
- [ ] JMeter từ máy 16GB bắn spike qua LAN; ghi timeline tải ↔ số pod ↔ latency

**Kiểm tra:** báo cáo trong `docs/perf/`.

---

## Checklist kết thúc phase
- [ ] Tag `phase-16-done`
