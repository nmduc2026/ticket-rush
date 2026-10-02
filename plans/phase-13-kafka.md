# Phase 13 — Kafka & event-driven

> Giai đoạn: **Kiến trúc** · Ước lượng: 1.5 tuần · Phụ thuộc: Phase 12

## Mục tiêu
Chuyển giao tiếp giữa các module từ event nội bộ sang **Kafka** — vẫn trong monolith — để chuẩn bị tách service ở Phase 14.

## Kết quả cuối phase
- Mọi event liên module ([overview §8.1](../overview.md#81-topics)) đi qua Kafka với Avro + Schema Registry.
- Consumer idempotent; message lỗi vào DLT và có alert.
- Trace nối liền qua Kafka trong Jaeger.

## Không làm trong phase này
- ❌ Tách service / tách database (Phase 14)
- ❌ Debezium (Phase 14) — outbox dùng Spring Modulith event externalization
- ❌ Kafka trên K8s / Strimzi (Phase 15)

---

## Step 13.0 — Re-plan
- [ ] Đọc lại plan, xem backlog; chốt danh sách event đi qua Kafka

## Step 13.1 — Hạ tầng Kafka
- [ ] Compose profile `kafka`: Kafka (KRaft, 1 broker), Schema Registry, Kafka UI
- [ ] Tạo topic theo thiết kế (6 partition)

**Kiểm tra:** Kafka UI thấy topic; produce / consume thử bằng CLI.

## Step 13.2 — Hợp đồng event (Avro)
- [ ] Module `backend/contracts`: schema `.avsc`, envelope chung, sinh class bằng `avro-maven-plugin`
- [ ] Quy tắc tương thích `BACKWARD` trên Schema Registry

**Kiểm tra:** thử đổi schema phá tương thích → bị Registry từ chối.

## Step 13.3 — Phát event ra Kafka
- [ ] Spring Modulith event externalization (`@Externalized`) → topic + key theo thiết kế
- [ ] Event publication registry: đảm bảo không mất event khi Kafka sập (outbox của Modulith)

**Kiểm tra:** stop Kafka → đặt vé → start Kafka → event được gửi bù.

## Step 13.4 — Consumer qua Kafka
- [ ] Chuyển các listener liên module sang `@KafkaListener`
- [ ] Bảng `processed_events` (idempotent consumer)
- [ ] `@RetryableTopic` + DLT; alert khi DLT có message; công cụ replay từ DLT

**Kiểm tra:** gửi trùng event → xử lý 1 lần; event lỗi → DLT → alert → sửa → replay thành công.

## Step 13.5 — Giám sát Kafka
- [ ] Trace qua Kafka header (Jaeger)
- [ ] Metric consumer lag lên Grafana + alert lag tăng

**Kiểm tra:** 1 trace từ thanh toán → xác nhận → vé → email hiển thị liền mạch.

## Step 13.6 — Kiểm thử
- [ ] Testcontainers Kafka + Awaitility cho luồng Saga đầy đủ
- [ ] Chạy lại JMeter flash sale → so sánh với Phase 10

**Kiểm tra:** E2E vẫn xanh; số liệu so sánh ghi vào `docs/perf/`.

---

## Checklist kết thúc phase
- [ ] Tag `phase-13-done`
