# Phase 19 — Bảo mật nâng cao & hosting lâu dài

> Giai đoạn: **Kiến trúc** · Ước lượng: 1 tuần · Phụ thuộc: Phase 18

## Mục tiêu
Rà soát bảo mật toàn diện, đưa dự án lên môi trường chạy lâu dài với chi phí 0$, hoàn thiện portfolio.

## Kết quả cuối phase
- CI chặn image có lỗ hổng nghiêm trọng; Falco cảnh báo hành vi lạ.
- Link demo công khai chạy lâu dài, 0$.
- README + sơ đồ C4 + số liệu hiệu năng + bài viết.

## Không làm trong phase này
- ❌ Tính năng mới — đưa vào backlog cho vòng sau

---

## Step 19.0 — Re-plan
- [ ] Đọc lại plan, xem backlog

## Step 19.1 — Bảo mật chuỗi cung ứng
- [ ] Trivy trong CI (fail khi CRITICAL) + Trivy Operator trên cụm
- [ ] SonarCloud, OWASP Dependency-Check, Renovate

**Kiểm tra:** PR đưa thư viện có CVE nghiêm trọng → CI fail.

## Step 19.2 — Bảo mật runtime
- [ ] Falco; Pod Security (non-root, read-only filesystem, drop capabilities); rà soát NetworkPolicy

**Kiểm tra:** `kubectl exec` mở shell trong container → Falco cảnh báo.

## Step 19.3 — Rà soát ứng dụng
- [ ] Checklist OWASP Top 10 cho từng API; CSP chặt chẽ; kiểm tra IDOR toàn bộ endpoint

**Kiểm tra:** checklist hoàn thành, lỗi phát hiện đã sửa.

## Step 19.4 — Hosting lâu dài (0$)
- [ ] Chọn: Oracle Cloud Always Free (k3s) **hoặc** máy 32GB + Cloudflare Tunnel — ghi ADR
- [ ] Terraform / script dựng môi trường; OpenCost

**Kiểm tra:** link công khai hoạt động ổn định 1 tuần.

## Step 19.5 — Portfolio
- [ ] README hoàn chỉnh, sơ đồ C4, số liệu hiệu năng, danh sách ADR / runbook / postmortem
- [ ] Bài viết tổng kết (blog)

**Kiểm tra:** tag `v1.0.0`.

---

## Checklist kết thúc phase
- [ ] 🎉 Tag `v1.0.0`, `phase-19-done`
