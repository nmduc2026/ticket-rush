# Phase 8 — Observability

> Giai đoạn: **Vận hành** · Ước lượng: 1 tuần · Phụ thuộc: Phase 7

## Mục tiêu
Nhìn thấy hệ thống đang làm gì: metrics, logs (ELK), traces, alert về Telegram, SLO. Đây là điều kiện bắt buộc trước khi load test (Phase 10) — không đo được thì không tối ưu được.

## Kết quả cuối phase
- Grafana: dashboard kỹ thuật (JVM, HTTP, DB pool) + dashboard nghiệp vụ (vé bán/phút).
- Kibana: tìm mọi log của 1 request bằng `trace.id`.
- Jaeger: xem waterfall 1 request đặt vé.
- Tắt Postgres → Telegram nhận alert trong 2 phút.

## Không làm trong phase này
- ❌ Chạy monitoring trên Kubernetes (Phase 15) — chạy bằng Compose
- ❌ Load test (Phase 10)
- ❌ Elasticsearch cho tìm kiếm sự kiện (Phase 12) — ES ở đây chỉ dùng cho log

---

## Step 8.0 — Re-plan
- [ ] Đọc lại plan, xem backlog; kiểm tra RAM máy (có thể cần chuyển sang máy 32GB)

## Step 8.1 — Metrics
- [ ] Micrometer Prometheus registry, mở `/actuator/prometheus` (chỉ trong mạng nội bộ)
- [ ] Compose profile `observability`: Prometheus + Grafana (provisioning datasource & dashboard từ file)
- [ ] Dashboard: JVM, HTTP (RED), HikariCP, Redis

**Kiểm tra:** thao tác trên web → thấy số liệu thay đổi trên Grafana.

## Step 8.2 — Metric nghiệp vụ
- [ ] Counter/timer: booking tạo / hết hạn / xác nhận, thanh toán thất bại, vé bán theo hạng (tag ít giá trị)
- [ ] Dashboard nghiệp vụ

**Kiểm tra:** mua 3 vé → dashboard hiện đúng 3.

## Step 8.3 — Tracing
- [ ] OpenTelemetry (Gateway + app) → Jaeger trong Compose
- [ ] Đảm bảo `traceId` xuất hiện trong log và được truyền Gateway → app

**Kiểm tra:** 1 request đặt vé hiện đủ span: Gateway → controller → Redis → Postgres.

## Step 8.4 — Logs với ELK
- [ ] Compose: Elasticsearch + Kibana + Filebeat (đọc log container)
- [ ] Log ECS; mapping trường `trace.id`, `service.name`, `user.id`, `booking.id`
- [ ] ILM xoá index sau 7 ngày; giới hạn heap Elasticsearch
- [ ] Kibana: saved search "lỗi theo service", "theo trace.id"

**Kiểm tra:** từ trace trong Jaeger → copy `traceId` → tìm thấy đủ log trong Kibana.

## Step 8.5 — Alerting & SLO
- [ ] Alertmanager → Telegram bot
- [ ] Rule: tỉ lệ 5xx, p95 latency, HikariCP pending, job thất bại, instance down
- [ ] Recording rule cho SLO ([overview §16.2](../overview.md#162-slo)) + alert burn rate
- [ ] Mỗi alert có link runbook

**Kiểm tra:** `docker stop postgres` → Telegram nhận alert; bật lại → nhận "resolved".

## Step 8.6 — Giám sát từ bên ngoài & Frontend
- [ ] Blackbox exporter kiểm tra trang chủ và `/api/v1/events` mỗi phút
- [ ] Sentry cho FE + web-vitals

**Kiểm tra:** lỗi JS cố ý → hiện trên Sentry.

## Step 8.7 — Runbook đầu tiên
- [ ] `docs/runbooks/_template.md` + runbook cho từng alert ở Step 8.5

**Kiểm tra:** mỗi alert có runbook tương ứng.

---

## Checklist kết thúc phase
- [ ] Tag `phase-08-done`
