# Phase 0 — Chuẩn bị môi trường & tài khoản

> Giai đoạn: **MVP** · Ước lượng: 0.5 tuần · Phụ thuộc: —

## Mục tiêu
Máy dev sẵn sàng, repo có cấu trúc chuẩn, tài khoản AWS được khoá chặt chi phí, các câu hỏi mở trong thiết kế đã được chốt.

## Kết quả cuối phase
- `git log` có commit đầu tiên, repo đã push lên GitHub.
- Có sẵn code Terraform hello world + `verify-clean.sh` (đã validate).
- ⏸ Email AWS Budgets và `terraform apply`/`destroy` thật: hoãn sang Step 7.0a.

## Không làm trong phase này
- ❌ Chưa tạo project Spring Boot / React (Phase 1)
- ❌ Chưa viết Docker Compose (Phase 1)
- ❌ Chưa dựng bất kỳ server nào trên AWS (Phase 7)

---

## Step 0.1 — Cài công cụ trên máy dev (16GB)
- [x] JDK 21 (Eclipse Temurin)
- [x] Node.js LTS (kèm npm)
- [x] Docker Desktop (WSL2 backend) + tạo `C:\Users\<user>\.wslconfig` giới hạn `memory=10GB`
- [x] Git, IntelliJ IDEA / VS Code
- [x] Stripe CLI, AWS CLI v2, Terraform
- [ ] Cài tương tự trên máy 32GB (`memory=24GB`) — có thể để đến Phase 7

**Kiểm tra:** `java -version`, `node -v`, `npm -v`, `docker run hello-world`, `stripe version`, `aws --version`, `terraform -version` đều chạy.

## Step 0.2 — Khởi tạo repository
- [x] Chốt thư mục gốc repo (`ticket-rush/`) và tên repo GitHub (`ticket-rush`)
- [x] `git init`, tạo `.gitignore` (Java, Node, IDE, `.env`, `*.tfstate`), `.editorconfig`
- [x] `.gitattributes` với `* text=auto eol=lf` (tránh lỗi xuống dòng CRLF trên Windows với file `.sh`)
- [x] Tạo khung thư mục: `backend/`, `frontend/`, `infra/`, `load-tests/`, `docs/adr/`, `docs/runbooks/`
- [x] Chuyển `overview.md` → `docs/overview.md`, đã cập nhật link
- [x] Tạo repo GitHub (public → GitHub Actions & SonarCloud miễn phí), push

**Kiểm tra:** repo trên GitHub có đúng cấu trúc, không có file rác.

## Step 0.3 — Chặn secret ngay từ đầu
- [x] Cài **gitleaks** + pre-commit hook tự viết (`.githooks/pre-commit`, bật bằng `git config core.hooksPath .githooks`)
- [x] Tạo `.env.example` (mẫu), `.env` nằm trong `.gitignore`

**Kiểm tra:** thử commit một file chứa chuỗi giống AWS key giả → bị chặn.

## Step 0.4 — AWS Lab 0: khoá chặt tài khoản
> ⏸ **Hoãn sang Step 7.0a** (làm ngay trước khi dùng AWS lần đầu). Không chạy `terraform apply` khi chưa xong bước này.
- [ ] Xem loại tài khoản (Free plan / Paid plan) và **ngày hết hạn credits** chính xác → ghi vào [README](README.md) mục 5
- [ ] Bật MFA cho root, đăng xuất root
- [ ] Bật IAM Identity Center, tạo user làm việc có MFA, permission set AdministratorAccess (chỉ cho lab cá nhân)
- [ ] Cấu hình `aws configure sso` → `aws sso login --profile ticketrush`
- [ ] Chọn region cố định `ap-southeast-1`
- [ ] AWS Budgets: zero-spend budget + monthly budget 5$/20$/50$ (actual + forecast)
- [ ] Budget Action ở mức 50$: stop EC2/RDS + gắn IAM deny policy
- [ ] Bật Cost Anomaly Detection, Free Tier usage alerts

**Kiểm tra:** nhận email xác nhận budget; `aws sts get-caller-identity --profile ticketrush` trả về user SSO (không phải root).

## Step 0.5 — Terraform "hello world" + script kiểm tra sạch
- [x] `infra/terraform/aws/lab-00/`: provider với `default_tags`, 1 bucket S3
- [x] Viết `infra/terraform/aws/verify-clean.sh`: quét EC2, EBS, snapshot, EIP, ELB, NAT, RDS, RDS snapshot theo region
- [ ] ⏸ Hoãn sang Step 7.0a: `apply` → kiểm tra trên console → `destroy` → chạy `verify-clean.sh`

**Kiểm tra:** `terraform validate` + `bash -n verify-clean.sh` chạy được. (Chạy thật `apply`/`destroy` + "sạch" + Cost Explorer = 0$ kiểm tra ở Step 7.0a.)

## Step 0.6 — Tài khoản dịch vụ ngoài & chốt câu hỏi mở
- [x] Trả lời **Q1–Q4** trong [overview.md §25](../docs/overview.md#25-câu-hỏi-mở), cập nhật overview
- [ ] ⏸ Hoãn đến Phase 5: tạo tài khoản Stripe (test mode) theo quốc gia đã chốt ở Q1, cài `stripe login`; thử tạo PaymentIntent VND để xác nhận tài khoản charge được VND
- [ ] (Chưa cần) Cloudflare, SonarCloud, Sentry — tạo khi tới phase dùng

**Kiểm tra:** overview §25 không còn câu hỏi bỏ ngỏ. (`stripe login` kiểm tra ở Phase 5.)

## Step 0.7 — Quy ước làm việc
- [x] `docs/adr/0000-template.md` (mẫu ADR); 14 ADR cũ giữ dạng bảng trong overview §24, ADR mới (từ ADR-15) viết thành file riêng
- [x] Thống nhất quy ước commit message: Conventional Commits (R5 trong [README](README.md))

**Kiểm tra:** commit + tag `phase-00-done`.

---

## Checklist kết thúc phase
- [ ] Tất cả step đã tick (trừ các mục ⏸ đã hoãn sang Phase 5 / Phase 7)
- [ ] Không còn việc dở dang; ý tưởng phát sinh đã ghi vào backlog
- [ ] Tag `phase-00-done`
