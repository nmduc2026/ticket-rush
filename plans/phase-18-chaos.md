# Phase 18 — Chaos engineering & Game Day

> Giai đoạn: **Kiến trúc** · Ước lượng: 1 tuần · Phụ thuộc: Phase 17

## Mục tiêu
Chủ động gây 10 sự cố ([overview §20.3](../docs/overview.md#203-kịch-bản-sự-cố-chaos-engineering)), đóng vai người trực sự cố, hoàn thiện runbook & postmortem.

## Kết quả cuối phase
- 10 kịch bản C1–C10, mỗi kịch bản có: kết quả, runbook, postmortem.
- Các lỗ hổng phát hiện được đã sửa (hoặc ghi backlog).

## Không làm trong phase này
- ❌ Tính năng mới

---

## Step 18.0 — Re-plan
- [ ] Đọc lại plan; chuẩn bị template Game Day (giả thuyết → thực hiện → quan sát → kết luận)

## Step 18.1 — Cài Chaos Mesh
- [ ] Cài, giới hạn quyền chỉ trong namespace `ticketrush`, `data`

**Kiểm tra:** chạy 1 PodChaos thử thành công.

## Step 18.2 — Sự cố dữ liệu: C1, C3, C4, C7
- [ ] Kill Postgres primary, kill Kafka broker, kill Redis, xoá nhầm dữ liệu — mỗi lần có JMeter chạy nền

**Kiểm tra:** mỗi kịch bản có postmortem.

## Step 18.3 — Sự cố phụ thuộc: C2, C10
- [ ] NetworkChaos làm chậm Stripe; poison pill message

**Kiểm tra:** postmortem + runbook cập nhật.

## Step 18.4 — Sự cố năng lực: C5, C8
- [ ] Spike tải; disk gần đầy / memory leak (StressChaos, heap dump)

**Kiểm tra:** postmortem + runbook cập nhật.

## Step 18.5 — Sự cố phát hành: C6, C9
- [ ] Bản lỗi (canary); cert sắp hết hạn

**Kiểm tra:** postmortem + runbook cập nhật.

## Step 18.6 — Tổng kết
- [ ] Bảng tổng hợp 10 kịch bản: kỳ vọng vs thực tế, việc đã sửa

**Kiểm tra:** `docs/postmortems/README.md` hoàn chỉnh.

---

## Checklist kết thúc phase
- [ ] Tag `phase-18-done`
