# Phase 9 — Flash sale

> Giai đoạn: **Vận hành** · Ước lượng: 1.5 tuần · Phụ thuộc: Phase 8

## Mục tiêu
Trang bị cho hệ thống khả năng chịu "cơn lũ" mở bán: rate limit, cache, cập nhật ghế realtime, phòng chờ ảo, feature flag.

## Kết quả cuối phase
- Sơ đồ ghế cập nhật tức thì (SSE) thay vì polling.
- Sự kiện `high_demand`: người dùng xếp hàng, thấy vị trí realtime, được cho vào theo lượt.
- Bật/tắt phòng chờ từ dashboard Unleash không cần deploy.

## Không làm trong phase này
- ❌ Load test JMeter (Phase 10) — chỉ kiểm tra chức năng
- ❌ Autoscaling (Phase 10 trên AWS, Phase 16 trên K8s)
- ❌ Circuit breaker cho Stripe (Phase 11)

---

## Step 9.0 — Re-plan
- [ ] Đọc lại plan, xem backlog

## Step 9.1 — Rate limit
- [ ] Bucket4j + Redis ở Gateway: theo user và theo IP; cấu hình riêng cho `POST /bookings`
- [ ] Trả `429` + `Retry-After` (ProblemDetail); FE hiển thị thông báo
- [ ] Metric số request bị chặn

**Kiểm tra:** script gọi 50 request/giây → phần vượt ngưỡng nhận 429.

## Step 9.2 — Cache
- [ ] Spring Cache + Redis cho chi tiết / danh sách sự kiện; evict khi sửa
- [ ] TTL có jitter; chống stampede (1 request rebuild)
- [ ] Fail-open: Redis lỗi → đọc thẳng DB

**Kiểm tra:** Grafana: tỉ lệ cache hit; số query DB giảm khi xem lặp lại.

## Step 9.3 — Realtime trạng thái ghế (SSE)
- [ ] `GET /events/{id}/seats/stream` (`SseEmitter`, heartbeat 15s)
- [ ] Thay đổi ghế → publish Redis channel `seat-updates:{eventId}` → mọi instance đẩy xuống client
- [ ] FE: hook SSE thay thế polling của Phase 4, tự reconnect

**Kiểm tra:** chạy **2 instance app** → user nối instance 1 thấy ngay ghế bị giữ ở instance 2.

## Step 9.4 — Phòng chờ (BE)
- [ ] Module `queue`: join (ZSET), stream vị trí (SSE)
- [ ] Scheduler (ShedLock) cho vào N người/giây; admission token (JWT 15 phút)
- [ ] Semaphore giới hạn số người ở bước thanh toán
- [ ] Booking yêu cầu admission token khi sự kiện `high_demand`

**Kiểm tra:** integration test: 100 user join → được cho vào đúng thứ tự, đúng tốc độ.

## Step 9.5 — Phòng chờ (FE)
- [ ] Trang `/events/:id/queue`: vị trí, thời gian chờ ước tính, tự chuyển trang khi đến lượt
- [ ] Xử lý token hết hạn, mất kết nối

**Kiểm tra:** demo 3 trình duyệt xếp hàng và lần lượt được vào.

## Step 9.6 — Feature flag
- [ ] Unleash trong Compose (profile `platform`)
- [ ] Flag: `waiting-room`, `refunds`, `seat-sse` (tắt → quay lại polling)

**Kiểm tra:** tắt `refunds` trên dashboard → nút hoàn vé biến mất / API trả lỗi phù hợp trong vài giây.

---

## Checklist kết thúc phase
- [ ] Tag `phase-09-done`
