# Phase 10 — Load test & tuning

> Giai đoạn: **Vận hành** · Ước lượng: 1 tuần · Phụ thuộc: Phase 9 · Mốc AWS: **Lab 2 (~cuối 12/2026)**

## Mục tiêu
Đo khả năng chịu tải bằng JMeter, tìm điểm nghẽn, tối ưu có số liệu trước/sau; trải nghiệm scale-out/in trên AWS.

## Kết quả cuối phase
- Báo cáo JMeter cho 5 kịch bản ([overview §20.2](../docs/overview.md#202-load-test-jmeter)).
- Flash sale 500 user / 100 ghế: **đúng 100 vé, 0 trùng**.
- Bảng "trước / sau tối ưu" trong `docs/perf/`.
- Quan sát được ASG trên AWS tự thêm / bớt máy.

## Không làm trong phase này
- ❌ HPA / KEDA trên Kubernetes (Phase 16)
- ❌ Tách service để scale riêng (Phase 14)

---

## Step 10.0 — Re-plan
- [ ] Đọc lại plan, xem backlog; kiểm tra lịch AWS (README mục 5)

## Step 10.1 — Chuẩn bị JMeter
- [ ] Cài JMeter trên máy 16GB (máy bắn tải); máy 32GB chạy hệ thống
- [ ] Giải quyết đăng nhập cho user ảo: realm/client riêng cho test (bật direct access grant chỉ ở môi trường test) để lấy token và gọi thẳng app, **hoặc** script hoá luồng login qua Gateway — chọn 1, ghi ADR
- [ ] Sinh dữ liệu test: 500 user, sự kiện 100 ghế (CSV)
- [ ] Giới hạn CPU/RAM container app để tạo áp lực (vd. 1 CPU, 1GB)

**Kiểm tra:** 1 kịch bản 10 user chạy thành công bằng CLI, có HTML report.

## Step 10.2 — Viết & chạy kịch bản
- [ ] `load.jmx`, `flash-sale.jmx`, `spike.jmx`, `soak.jmx`, `stress.jmx` trong `load-tests/jmeter/`
- [ ] Chạy, lưu report + ảnh Grafana cùng thời điểm

**Kiểm tra:** có baseline cho cả 5 kịch bản; truy vấn bất biến oversell = 0 dòng.

## Step 10.3 — Tìm điểm nghẽn & tối ưu
- [ ] Dùng Grafana, Jaeger, `pg_stat_statements` tìm nguyên nhân chậm
- [ ] Tối ưu từng thứ một, đo lại sau mỗi thay đổi: index, N+1, Hikari pool size, heap JVM, cache
- [ ] Ghi `docs/perf/README.md`: thay đổi gì → số liệu trước / sau

**Kiểm tra:** ít nhất 1 cải thiện có số liệu chứng minh; SLO latency đạt ở 500 user.

## Step 10.4 — AWS Lab 2: scale-out/in mức VM
- [ ] Terraform `lab-02`: ALB + Auto Scaling Group (2–4 EC2 Spot chạy image app) + RDS + Redis (container trên 1 EC2)
- [ ] CloudWatch alarm / target tracking theo CPU
- [ ] 1 EC2 Spot chạy JMeter bắn vào ALB
- [ ] Quan sát scale-out khi tải tăng và scale-in khi hết tải; ghi lại timeline
- [ ] `destroy` → `verify-clean.sh` → kiểm tra chi phí hôm sau

**Kiểm tra:** ảnh chụp số instance tăng / giảm theo tải; AWS sạch.

---

## Checklist kết thúc phase
- [ ] Tag `phase-10-done`
