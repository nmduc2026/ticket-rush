# Phase 17 — Deploy an toàn & khôi phục thảm hoạ

> Giai đoạn: **Kiến trúc** · Ước lượng: 1 tuần · Phụ thuộc: Phase 16

## Mục tiêu
Deploy không sợ: canary tự rollback. Mất dữ liệu không sợ: PITR, backup cụm, migration không downtime.

## Kết quả cuối phase
- Bản lỗi cố ý bị tự rollback.
- Khôi phục DB về đúng thời điểm trước lệnh `DELETE`, đạt RPO ≤ 5 phút, RTO ≤ 15 phút.
- Dựng lại cụm từ Velero backup.

## Không làm trong phase này
- ❌ Chaos Mesh (Phase 18)

---

## Step 17.0 — Re-plan
- [ ] Đọc lại plan, xem backlog

## Step 17.1 — Canary với Argo Rollouts
- [ ] Chuyển Deployment → Rollout cho service chính
- [ ] AnalysisTemplate: error rate + p95 từ Prometheus
- [ ] Deploy bản có bug cố ý

**Kiểm tra:** bản lỗi tự rollback, không ảnh hưởng quá 10% traffic.

## Step 17.2 — Backup & PITR
- [ ] CNPG backup liên tục (WAL) + base backup hằng ngày lên MinIO
- [ ] Diễn tập: `DELETE` nhầm → khôi phục về thời điểm trước đó

**Kiểm tra:** đo RPO / RTO thực tế, ghi vào runbook.

## Step 17.3 — Backup cụm
- [ ] Velero backup namespace + volume
- [ ] Diễn tập: xoá cụm → tạo cụm mới → restore

**Kiểm tra:** hệ thống chạy lại đầy đủ.

## Step 17.4 — Migration không downtime
- [ ] Thực hành expand / contract: đổi tên 1 cột trong khi JMeter chạy nền

**Kiểm tra:** 0 lỗi trong suốt quá trình.

---

## Checklist kết thúc phase
- [ ] Tag `phase-17-done`
