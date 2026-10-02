# Ghi chú công nghệ — TicketRush

> Giải thích ngắn gọn từng khái niệm / công nghệ trong [overview.md](overview.md), kèm ví dụ dùng trong dự án.
> Mỗi mục gồm: **là gì** → **dùng ở đâu trong TicketRush** → **ví dụ**.
> Code chỉ mang tính minh hoạ ý tưởng, không phải code hoàn chỉnh.

## Mục lục

- [A. Khái niệm kiến trúc](#a-khái-niệm-kiến-trúc)
- [B. Backend — Spring](#b-backend--spring)
- [C. Dữ liệu](#c-dữ-liệu)
- [D. Redis](#d-redis)
- [E. Kafka & Event](#e-kafka--event)
- [F. Bảo mật](#f-bảo-mật)
- [G. Tích hợp bên ngoài](#g-tích-hợp-bên-ngoài)
- [H. Resilience](#h-resilience)
- [I. Realtime](#i-realtime)
- [J. Frontend](#j-frontend)
- [K. Observability](#k-observability)
- [L. Kiểm thử](#l-kiểm-thử)
- [M. Container & Kubernetes](#m-container--kubernetes)
- [N. Scaling](#n-scaling)
- [O. Vận hành dữ liệu & sự cố](#o-vận-hành-dữ-liệu--sự-cố)
- [P. CI/CD, IaC & bảo mật hạ tầng](#p-cicd-iac--bảo-mật-hạ-tầng)
- [Q. AWS](#q-aws)

---

## A. Khái niệm kiến trúc

### Modular Monolith
> **1 ứng dụng** duy nhất nhưng chia thành các **module có ranh giới rõ ràng**, module này không được đụng vào "nội tạng" của module kia. Giống một toà nhà có nhiều căn hộ: chung toà nhưng mỗi nhà một cửa.

**Trong TicketRush:** giai đoạn đầu `catalog`, `booking`, `payment`… là các package trong 1 app. Khi cần tách thành microservice thì "bê" cả căn hộ ra, không phải đập tường.

```
com.ticketrush
├── catalog/      ← module (chỉ lộ ra API công khai)
│   └── internal/ ← module khác KHÔNG được import
├── booking/
└── payment/
```

### Microservices & Database per service
> Mỗi service là 1 ứng dụng riêng, deploy riêng, **có database riêng**. Service A muốn dữ liệu của B thì phải hỏi B (API) hoặc nghe event của B — không được chui vào DB của B.

**Trong TicketRush:** Payment cần biết số tiền của booking → không query DB Booking, mà nghe event `BookingCreated` rồi lưu bản sao vào bảng `payable_bookings`.

### Event-driven
> Service **thông báo "chuyện gì đã xảy ra"** (event) thay vì **ra lệnh** cho service khác. Ai quan tâm thì tự nghe.

```
Ra lệnh (REST):   Payment → "Ticket ơi, sinh vé đi!" → "Notification ơi, gửi mail đi!"
Event:            Payment → "Thanh toán xong rồi nhé" (PaymentSucceeded)
                  Ticket tự nghe → sinh vé.  Notification tự nghe → gửi mail.
```

### Saga
> Một giao dịch nghiệp vụ trải qua **nhiều service**, mỗi bước là 1 transaction riêng. Nếu một bước hỏng → chạy **bước bù trừ** (compensation) để hoàn tác các bước trước. Không có "rollback tổng" như trong 1 DB.

**Trong TicketRush:** Giữ ghế → Thanh toán → Xác nhận → Xuất vé. Nếu thanh toán thành công mà ghế đã mất → bù trừ bằng **hoàn tiền tự động**.

### Transactional Outbox
> Vấn đề: lưu DB thành công nhưng gửi Kafka thất bại (hoặc ngược lại) → dữ liệu lệch. Giải pháp: ghi event vào **bảng `outbox` trong cùng transaction** với dữ liệu nghiệp vụ. Một tiến trình khác (Debezium) đọc bảng outbox và đẩy lên Kafka.

```java
@Transactional
public Booking create(CreateBookingCommand cmd) {
    Booking booking = bookingRepo.save(Booking.pending(cmd));
    outboxRepo.save(OutboxEvent.of("Booking", booking.getId(), "BookingCreated", toJson(booking)));
    return booking;   // cả 2 cùng commit hoặc cùng rollback
}
```

### Idempotency (tính luỹ đẳng)
> Gọi 1 lần hay gọi 10 lần thì **kết quả như nhau**. Cực kỳ quan trọng vì mạng có thể lỗi → client gửi lại → không được tạo 2 đơn / trừ tiền 2 lần.

**Trong TicketRush:** FE gửi header `Idempotency-Key`; BE lưu key, nếu gặp lại key cũ → trả lại kết quả cũ, không tạo booking mới.

```http
POST /api/v1/bookings
Idempotency-Key: 7b1e9c2a-...      ← FE sinh 1 lần, bấm lại vẫn dùng key này
```

### Optimistic Locking
> Mỗi dòng có cột `version`. Khi update, kèm điều kiện `version = giá trị lúc đọc`. Nếu ai đó đã sửa trước → version đã đổi → update thất bại → biết là có xung đột. "Lạc quan" vì giả định ít khi đụng nhau, không khoá trước.

```java
@Entity
class Event {
    @Id UUID id;
    String title;
    @Version long version;   // Hibernate tự thêm "WHERE version = ?" khi update
}
// 2 organizer cùng sửa → người lưu sau nhận OptimisticLockException
```

### BFF (Backend For Frontend)
> Một lớp backend đứng ngay sau frontend, **giữ hộ token** và chỉ đưa cho browser 1 cookie session. Browser không bao giờ thấy access token → hacker chèn được JS (XSS) cũng không lấy được token.

**Trong TicketRush:** Spring Cloud Gateway làm BFF.

### Projection (bản sao đọc)
> Dữ liệu được **sao chép sang dạng tối ưu cho việc đọc** bằng cách nghe event. Nguồn sự thật vẫn ở service gốc.

**Trong TicketRush:** Catalog lưu sự kiện trong Postgres (nguồn sự thật) → phát event → Elasticsearch index lại để tìm kiếm nhanh.

### Fail-closed vs Fail-open
> Khi hệ thống phụ trợ hỏng: **fail-open** = cứ cho qua; **fail-closed** = chặn lại cho an toàn.

**Trong TicketRush:** Redis chết → **fail-closed** cho việc bán vé (thà ngừng bán còn hơn bán trùng ghế); nhưng **fail-open** cho cache (không có cache thì đọc thẳng DB).

### Virtual Threads (Java 21)
> Thread "ảo" siêu nhẹ do JVM quản lý. Khi thread chờ IO (DB, HTTP), JVM tạm "cất" nó đi và dùng CPU cho việc khác. Tạo hàng triệu cái cũng được.

```yaml
# application.yml — bật cho toàn bộ Spring Boot
spring.threads.virtual.enabled: true
```

⚠️ Java 21: tránh `synchronized` bao quanh code gọi IO (gây "pinning"), dùng `ReentrantLock`.

### UUIDv7
> UUID có **phần đầu là timestamp** → các ID sinh sau luôn "lớn hơn" ID trước → insert vào index B-tree nhanh, sắp xếp theo thời gian được. UUIDv4 thì ngẫu nhiên hoàn toàn → index bị phân mảnh.

### Tiền dạng số nguyên (minor units)
> Không bao giờ dùng `double` cho tiền (`0.1 + 0.2 = 0.30000000000000004`). Lưu theo đơn vị nhỏ nhất: 50.00 USD → `5000` (cent). VND không có đơn vị lẻ nên 50.000đ → `50000`.

```java
record Money(long amountMinor, String currency) {}
new Money(5000, "USD");  // = $50.00
```

---

## B. Backend — Spring

### Spring Boot
> Framework Java phổ biến nhất để làm backend. "Boot" = tự cấu hình sẵn mọi thứ, chỉ cần thêm dependency là chạy.

### Spring MVC (REST API)
> Module của Spring để viết API. Mỗi `@RestController` là một nhóm endpoint, trả về JSON.

```java
@RestController
@RequestMapping("/api/v1/events")
class EventController {
    @GetMapping("/{id}")
    EventDto get(@PathVariable UUID id) {
        return eventService.get(id);       // tự chuyển thành JSON
    }
}
```

### Spring Modulith
> Hỗ trợ làm Modular Monolith: **kiểm tra ranh giới module** bằng test, và cho các module nói chuyện với nhau qua **event nội bộ**.

```java
// Test: fail nếu module booking import class nội bộ của payment
@Test
void verifyModules() {
    ApplicationModules.of(TicketRushApplication.class).verify();
}

// Module booking phát event
events.publishEvent(new BookingCreated(bookingId, amount));

// Module payment nghe event (chạy sau khi transaction commit)
@ApplicationModuleListener
void on(BookingCreated event) { ... }
```

### Maven (multi-module)
> Công cụ build Java. Multi-module = 1 project cha chứa nhiều project con, dùng chung version thư viện.

```bash
mvn -pl booking-service -am package    # build booking-service và các module nó phụ thuộc
```

### Bean Validation
> Kiểm tra dữ liệu đầu vào bằng annotation.

```java
record CreateBookingRequest(
    @NotNull UUID eventId,
    @NotEmpty @Size(max = 6) List<UUID> seatIds      // BR-02: tối đa 6 ghế
) {}

@PostMapping
BookingDto create(@Valid @RequestBody CreateBookingRequest req) { ... }   // sai → 400
```

### MapStruct
> Tự sinh code chuyển đổi Entity ↔ DTO lúc compile (không dùng reflection → nhanh).

```java
@Mapper(componentModel = "spring")
interface EventMapper {
    EventDto toDto(Event event);       // MapStruct tự viết phần thân
}
```

### springdoc-openapi
> Tự sinh tài liệu API (OpenAPI/Swagger) từ code. Mở `/swagger-ui.html` để xem và gọi thử. File OpenAPI này còn được FE dùng để sinh code gọi API.

### Problem Details (RFC 9457)
> Chuẩn format lỗi JSON thống nhất cho mọi API.

```java
@ExceptionHandler(SeatUnavailableException.class)
ProblemDetail handle(SeatUnavailableException ex) {
    ProblemDetail pd = ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.getMessage());
    pd.setProperty("code", "SEAT_UNAVAILABLE");
    return pd;
}
```
```json
{ "status": 409, "title": "Conflict", "detail": "Ghế A5 đã có người giữ", "code": "SEAT_UNAVAILABLE" }
```

### Spring Cloud Gateway
> Cổng vào duy nhất của hệ thống: nhận mọi request rồi **định tuyến** đến service phù hợp, kèm xử lý chung (đăng nhập, rate limit…).

```yaml
spring.cloud.gateway.server.webmvc.routes:
  - id: booking
    uri: http://booking-service:8080
    predicates: [ "Path=/api/v1/bookings/**" ]
    filters: [ "TokenRelay=" ]          # gắn access token của user khi chuyển tiếp
```

### Spring Session (Redis)
> Lưu session đăng nhập vào **Redis** thay vì RAM của server → có 5 pod Gateway thì pod nào cũng đọc được session → scale tự do. Chỉ cần thêm dependency `spring-session-data-redis`.

### ShedLock
> Khi chạy 5 pod, `@Scheduled` sẽ chạy **5 lần**. ShedLock đảm bảo mỗi lượt chỉ **1 pod** chạy (khoá qua DB/Redis).

```java
@Scheduled(fixedDelay = 30_000)
@SchedulerLock(name = "expireBookings", lockAtMostFor = "PT1M")
void expireBookings() {
    // nhả ghế của các booking quá 10 phút chưa thanh toán
}
```

### Hibernate Envers
> Tự động lưu **lịch sử thay đổi** của entity (ai sửa, sửa gì, lúc nào) vào bảng `_aud`.

```java
@Entity @Audited
class PlatformFeeConfig { ... }    // mọi lần Admin đổi phí đều được ghi lại
```

---

## C. Dữ liệu

### PostgreSQL
> Database quan hệ mã nguồn mở mạnh nhất hiện nay. Là **nguồn sự thật** của mọi dữ liệu quan trọng.

### Spring Data JPA / Hibernate
> Thao tác DB bằng object Java thay vì viết SQL. Mạnh ở CRUD.

```java
interface BookingRepository extends JpaRepository<Booking, UUID> {
    // Spring tự sinh SQL từ tên method
    List<Booking> findByStatusAndExpiresAtBefore(BookingStatus status, Instant time);
}
```

### jOOQ
> Viết SQL bằng Java, **type-safe** (sai tên cột → lỗi compile). Mạnh ở truy vấn phức tạp mà JPA viết khổ.

**Trong TicketRush:** dashboard doanh thu.

```java
ctx.select(TICKET_TIERS.NAME, sum(BOOKING_ITEMS.PRICE_MINOR), count())
   .from(BOOKING_ITEMS).join(TICKET_TIERS).on(BOOKING_ITEMS.TIER_ID.eq(TICKET_TIERS.ID))
   .where(BOOKING_ITEMS.EVENT_ID.eq(eventId))
   .groupBy(TICKET_TIERS.NAME)
   .fetch();
```

### Flyway
> Quản lý thay đổi schema DB bằng các file SQL có đánh số. App khởi động → Flyway tự chạy các file chưa chạy. Schema DB được "version hoá" như code.

```
db/migration/
├── V1__create_events.sql
├── V2__create_bookings.sql
└── V3__add_high_demand_to_events.sql
```

### HikariCP
> **Connection pool** trong app: giữ sẵn vài kết nối DB mở, request mượn rồi trả, không phải mở/đóng mỗi lần (rất tốn). Có sẵn trong Spring Boot.

```yaml
spring.datasource.hikari:
  maximum-pool-size: 10
  connection-timeout: 3000     # chờ mượn kết nối quá 3s → báo lỗi, không treo mãi
```

### PgBouncer
> Connection pool **đứng trước Postgres**. Gom hàng trăm kết nối từ nhiều pod thành vài chục kết nối thật.

```
20 pod × 10 kết nối = 200  ──▶ PgBouncer ──▶ 30 kết nối thật ──▶ Postgres
```
```ini
pool_mode = transaction      ; trả kết nối ngay khi transaction xong
default_pool_size = 30
```

### Elasticsearch
> Database chuyên **tìm kiếm full-text**: gõ "rock sai gon" vẫn ra "Đêm nhạc Rock Sài Gòn", có chấm điểm độ liên quan, lọc, gợi ý.

```java
@Document(indexName = "events")
record EventDocument(@Id String id, String title, String city, Instant startsAt) {}

interface EventSearchRepository extends ElasticsearchRepository<EventDocument, String> {
    List<EventDocument> findByTitleAndCity(String title, String city);
}
```

### MinIO / S3
> Kho lưu **file** (ảnh banner, file backup). MinIO là bản chạy local tương thích 100% API của AWS S3 → code giống hệt khi lên cloud.

```java
s3.putObject(
    PutObjectRequest.builder().bucket("event-banners").key(eventId + ".jpg").build(),
    RequestBody.fromBytes(imageBytes));
```

---

## D. Redis

### Redis
> Database **trong RAM**, cực nhanh (~0.1ms/lệnh). Dùng cho dữ liệu tạm, cần tốc độ: cache, session, khoá, hàng đợi, đếm.

```bash
SET seat:{evt1}:A5 booking-123 PX 600000 NX   # giữ ghế A5 trong 10 phút, chỉ khi chưa ai giữ
GET seat:{evt1}:A5                            # → "booking-123"
```

### Lua script trong Redis
> Gửi một đoạn script để Redis chạy **nguyên khối (atomic)** — không lệnh nào chen vào giữa. Dùng để "kiểm tra rồi ghi" nhiều key cùng lúc.

```java
DefaultRedisScript<Long> holdSeats = new DefaultRedisScript<>(LUA_HOLD_SEATS, Long.class);
Long ok = redis.execute(holdSeats, seatKeys, bookingId, "600000");
// ok == 1 → giữ được tất cả ghế; 0 → có ghế đã bị giữ, không giữ ghế nào
```

### Redisson
> Thư viện Java cung cấp "đồ nghề phân tán" trên Redis — dùng chung giữa nhiều pod.

```java
// Lock: chỉ 1 người được sửa sơ đồ ghế tại 1 thời điểm (trên mọi pod)
RLock lock = redisson.getLock("lock:seatmap:" + eventId);
if (lock.tryLock(5, TimeUnit.SECONDS)) {
    try { updateSeatMap(); } finally { lock.unlock(); }
}

// Semaphore: tối đa 500 người cùng ở bước thanh toán
RSemaphore sem = redisson.getSemaphore("sem:checkout:" + eventId);
if (sem.tryAcquire()) { /* cho vào */ }

// ZSET: hàng chờ, score = thời điểm vào
RScoredSortedSet<String> queue = redisson.getScoredSortedSet("queue:{" + eventId + "}:waiting");
queue.add(System.currentTimeMillis(), userId);
Integer position = queue.rank(userId);         // vị trí trong hàng (0-based)
```

### Bucket4j (rate limit)
> Giới hạn số request theo thuật toán **token bucket**: mỗi user có 1 "xô" 20 token, mỗi giây được bơm lại 20; mỗi request lấy 1 token; hết token → bị chặn (429).

```java
Bucket bucket = Bucket.builder()
    .addLimit(limit -> limit.capacity(20).refillGreedy(20, Duration.ofSeconds(1)))
    .build();
if (!bucket.tryConsume(1)) throw new TooManyRequestsException();
// Khi chạy nhiều pod: lưu bucket trong Redis (bucket4j-redis) để dùng chung
```

### Spring Cache
> Cache kết quả method bằng annotation.

```java
@Cacheable(value = "events", key = "#id")      // lần 2 trở đi lấy từ Redis
EventDto get(UUID id) { ... }

@CacheEvict(value = "events", key = "#id")     // sửa sự kiện → xoá cache
void update(UUID id, UpdateEventRequest req) { ... }
```

### Redis Pub/Sub
> Kênh phát thanh: 1 nơi publish, mọi nơi đang subscribe đều nhận.

**Trong TicketRush:** ghế A5 vừa bị giữ ở pod 3 → publish → pod 1, 2, 4, 5 nhận → đẩy SSE xuống các user đang xem sơ đồ.

### Cache stampede
> Cache của sự kiện hot hết hạn → 5.000 request cùng lúc thấy "không có cache" → cùng lao vào DB → DB sập. Cách chống: TTL có **jitter** (ngẫu nhiên lệch vài giây) + chỉ **1 request** được build lại cache.

---

## E. Kafka & Event

### Apache Kafka
> Hệ thống truyền event dạng **nhật ký chỉ ghi thêm**. Producer ghi vào, consumer đọc theo tốc độ của mình, message được lưu lại (không mất khi consumer chết).

| Khái niệm | Giải thích |
|---|---|
| **Topic** | "Kênh" chứa một loại event, vd. `payment.events.v1` |
| **Partition** | Topic chia nhỏ thành nhiều phần để xử lý song song. Cùng **key** → cùng partition → **đúng thứ tự** |
| **Offset** | Số thứ tự message trong partition — consumer nhớ "đã đọc đến đâu" |
| **Consumer group** | Nhóm consumer chia nhau đọc; mỗi partition chỉ do 1 consumer trong nhóm đọc |
| **Broker** | Một server Kafka. Cluster có nhiều broker để chịu lỗi |
| **KRaft** | Chế độ mới của Kafka, không cần ZooKeeper nữa |

```java
// Producer
kafkaTemplate.send("payment.events.v1", bookingId.toString(), new PaymentSucceeded(...));

// Consumer
@KafkaListener(topics = "payment.events.v1", groupId = "booking-service")
void on(PaymentSucceeded event) {
    bookingService.confirm(event.bookingId());
}
```

### Retry topic & DLT (Dead Letter Topic)
> Message xử lý lỗi → thử lại sau 1s, 2s, 4s… vẫn lỗi → đẩy vào **DLT** ("thùng thư chết") để không chặn các message phía sau. Có alert để người xem xét.

```java
@RetryableTopic(attempts = "4", backoff = @Backoff(delay = 1000, multiplier = 2))
@KafkaListener(topics = "booking.events.v1", groupId = "ticket-service")
void on(BookingConfirmed event) { ticketService.issue(event); }

@DltHandler
void onDlt(BookingConfirmed event) { log.error("Không xuất được vé: {}", event); }
```

### Idempotent consumer
> Kafka đảm bảo "ít nhất 1 lần" → có thể nhận trùng. Consumer ghi lại `eventId` đã xử lý để bỏ qua lần sau.

```java
@Transactional
void on(PaymentSucceeded e) {
    if (processedEvents.existsById(e.eventId())) return;   // đã xử lý rồi
    processedEvents.save(new ProcessedEvent(e.eventId()));
    bookingService.confirm(e.bookingId());
}
```

### Avro + Schema Registry
> **Avro**: định dạng dữ liệu nhị phân có **schema** (gọn hơn JSON). **Schema Registry**: nơi lưu các phiên bản schema, **chặn** producer gửi event sai format hoặc thay đổi phá vỡ consumer cũ.

```json
{
  "type": "record", "name": "PaymentSucceeded", "namespace": "com.ticketrush.payment",
  "fields": [
    { "name": "bookingId",   "type": "string" },
    { "name": "amountMinor", "type": "long" },
    { "name": "currency",    "type": "string" },
    { "name": "method",      "type": ["null", "string"], "default": null }
  ]
}
```
> Thêm field mới **có default** → tương thích ngược ✅. Xoá field bắt buộc → Registry từ chối ❌.

### Debezium (CDC)
> **Change Data Capture**: đọc **nhật ký thay đổi (WAL)** của Postgres, mỗi khi có dòng mới trong bảng `outbox` → tự đẩy lên Kafka. App không cần tự gửi Kafka.

```json
{
  "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
  "table.include.list": "booking.outbox",
  "transforms": "outbox",
  "transforms.outbox.type": "io.debezium.transforms.outbox.EventRouter"
}
```

---

## F. Bảo mật

### OAuth2 / OpenID Connect (OIDC)
> **OAuth2**: chuẩn để cấp quyền truy cập (access token). **OIDC**: lớp bên trên OAuth2 để **đăng nhập** (biết user là ai).

```
1. User bấm "Đăng nhập" → Gateway chuyển sang trang Keycloak
2. User nhập mật khẩu ở Keycloak (app không bao giờ thấy mật khẩu)
3. Keycloak trả "code" về Gateway
4. Gateway đổi code lấy access token + refresh token (PKCE chống đánh cắp code)
5. Gateway giữ token, đưa browser cookie SESSION
```

### Keycloak
> Server quản lý đăng nhập (Identity Provider) mã nguồn mở: user, mật khẩu, role, đăng nhập Google, MFA… — có UI quản trị sẵn. App không phải tự làm phần đăng ký/đăng nhập.

### JWT (JSON Web Token)
> Token dạng `header.payload.signature`, payload chứa thông tin user, **có chữ ký** → service tự kiểm tra được mà không cần hỏi Keycloak.

```json
// payload đã decode
{ "sub": "user-123", "realm_access": { "roles": ["CUSTOMER"] }, "exp": 1759400000, "iss": "https://auth.ticketrush.dev/realms/ticketrush" }
```

### Spring Security + OAuth2 Resource Server
> Bảo vệ API: mọi request phải có JWT hợp lệ (đúng chữ ký, đúng issuer, chưa hết hạn).

```java
@Bean
SecurityFilterChain api(HttpSecurity http) throws Exception {
    return http
        .authorizeHttpRequests(a -> a
            .requestMatchers(HttpMethod.GET, "/api/v1/events/**").permitAll()
            .anyRequest().authenticated())
        .oauth2ResourceServer(o -> o.jwt(Customizer.withDefaults()))
        .build();
}

@PreAuthorize("hasRole('ORGANIZER')")                      // RBAC: theo role
@PreAuthorize("@eventGuard.isOwner(#eventId, authentication)")  // ownership: đúng chủ sự kiện
```

### IDOR (lỗ hổng truy cập object của người khác)
> User A đổi URL `/bookings/123` thành `/bookings/124` và xem được đơn của user B. Chống bằng **kiểm tra quyền sở hữu** ở backend, không tin ID từ client.

### CSRF
> Trang web độc hại lừa browser của bạn gửi request kèm cookie đăng nhập. Vì BFF dùng cookie nên phải chống CSRF: server phát token, FE gửi kèm header `X-XSRF-TOKEN`, trang độc hại không đọc được token này.

### Ký QR bằng ECDSA (Nimbus JOSE+JWT)
> Nội dung QR là 1 JWT ký bằng **private key** (chỉ server có). Máy quét dùng **public key** để kiểm tra → làm giả QR là không thể, kiểm tra được cả khi offline.

```java
JWTClaimsSet claims = new JWTClaimsSet.Builder()
    .subject(ticketId.toString())
    .claim("eventId", eventId.toString())
    .claim("seat", "A5")
    .issueTime(new Date())
    .build();
SignedJWT jwt = new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.ES256).keyID(kid).build(), claims);
jwt.sign(new ECDSASigner(privateKey));
String qrContent = jwt.serialize();     // → đưa vào ZXing để vẽ QR
```

### Vault
> "Két sắt" lưu secret (mật khẩu DB, Stripe key, private key ký vé). App lấy secret lúc khởi động, secret không nằm trong code hay Git. Hỗ trợ xoay vòng (rotate) secret.

```bash
vault kv put secret/ticketrush/payment stripe.api-key=sk_test_xxx
# Spring Cloud Vault tự nạp → dùng như property bình thường: @Value("${stripe.api-key}")
```

### gitleaks
> Quét code trước khi commit, phát hiện secret (AWS key, Stripe key…) bị lỡ tay đưa vào → chặn commit.

```bash
gitleaks protect --staged      # chạy trong pre-commit hook
```

---

## G. Tích hợp bên ngoài

### Stripe
> Cổng thanh toán. Ở **test mode** miễn phí hoàn toàn, dùng thẻ test `4242 4242 4242 4242`.

| Khái niệm | Giải thích |
|---|---|
| **PaymentIntent** | "Ý định thanh toán" — đại diện cho 1 lần thu tiền, đi qua các trạng thái |
| **clientSecret** | Chìa khoá để FE hoàn tất thanh toán với Stripe (thẻ đi thẳng FE → Stripe, server không chạm số thẻ) |
| **Webhook** | Stripe gọi ngược về server báo kết quả (thành công / thất bại / hoàn tiền) |
| **Connect** | Marketplace: tiền chảy về tài khoản organizer, nền tảng giữ lại phí (`application_fee`) |
| **Idempotency key** | Gửi lại cùng key → Stripe không tạo giao dịch mới |

```java
PaymentIntentCreateParams params = PaymentIntentCreateParams.builder()
    .setAmount(5000L).setCurrency("usd")                         // $50.00
    .setApplicationFeeAmount(250L)                               // phí nền tảng 5%
    .setTransferData(PaymentIntentCreateParams.TransferData.builder()
        .setDestination(organizerStripeAccountId).build())       // tiền về organizer
    .putMetadata("bookingId", bookingId.toString())
    .build();
RequestOptions opts = RequestOptions.builder().setIdempotencyKey("booking-" + bookingId).build();
PaymentIntent pi = PaymentIntent.create(params, opts);
return pi.getClientSecret();

// Webhook: verify chữ ký, sai → SignatureVerificationException
Event event = Webhook.constructEvent(payload, signatureHeader, webhookSecret);
```
```bash
stripe listen --forward-to localhost:8080/api/v1/webhooks/stripe   # nhận webhook ở máy local
```

### Spring Mail + Thymeleaf + Mailpit
> Gửi email từ template HTML. **Mailpit** là "hộp thư giả" ở local: bắt mọi email app gửi đi, xem tại `http://localhost:8025` — không gửi thật ra ngoài.

### ZXing
> Thư viện tạo/đọc mã QR.

```java
BitMatrix matrix = new QRCodeWriter().encode(qrContent, BarcodeFormat.QR_CODE, 300, 300);
MatrixToImageWriter.writeToStream(matrix, "PNG", outputStream);
```

---

## H. Resilience

### Resilience4j
> Bộ thư viện bảo vệ khi gọi dịch vụ ngoài. Dùng bằng annotation, cấu hình trong YAML.

```java
@CircuitBreaker(name = "stripe", fallbackMethod = "paymentUnavailable")
@Retry(name = "stripe")
@Bulkhead(name = "stripe")
public String createPaymentIntent(Booking booking) { ... }

String paymentUnavailable(Booking booking, Throwable t) {
    throw new PaymentTemporarilyUnavailableException();   // báo lỗi ngay, không bắt user chờ
}
```
```yaml
resilience4j:
  circuitbreaker.instances.stripe:
    sliding-window-size: 20
    failure-rate-threshold: 50          # ≥ 50% lỗi trong 20 lần gần nhất → ngắt mạch
    wait-duration-in-open-state: 30s
  retry.instances.stripe:
    max-attempts: 3
    wait-duration: 200ms
    enable-exponential-backoff: true
  bulkhead.instances.stripe:
    max-concurrent-calls: 20
```

| Cơ chế | Ví von | Tác dụng |
|---|---|---|
| **Timeout** | Hẹn 3s không thấy thì đi | Không treo vô hạn |
| **Retry** | Gọi lại khi máy bận | Vượt qua lỗi thoáng qua |
| **Circuit Breaker** | Cầu dao điện tự nhảy | Dịch vụ chết → ngừng gọi, báo lỗi ngay |
| **Bulkhead** | Vách ngăn khoang tàu | 1 dịch vụ chậm không kéo chết cả hệ thống |

### Unleash (Feature Flag)
> Công tắc bật/tắt tính năng **lúc đang chạy**, điều khiển từ dashboard, không cần deploy.

```java
if (unleash.isEnabled("waiting-room")) {
    return queueService.enqueue(userId, eventId);
}
return bookingService.directBooking(userId, eventId);
```

### Load shedding
> Khi quá tải, **chủ động từ chối bớt** request (trả `503 Retry-After: 10`) để phần còn lại chạy ổn, thay vì để tất cả cùng chậm rồi sập.

### Graceful shutdown
> Khi pod bị tắt (deploy mới, scale-in): ngừng nhận request mới, **làm xong** request đang chạy rồi mới tắt.

```yaml
server.shutdown: graceful
spring.lifecycle.timeout-per-shutdown-phase: 30s
```

---

## I. Realtime

### SSE (Server-Sent Events)
> Server **đẩy dữ liệu xuống** browser qua 1 kết nối HTTP giữ mở. Một chiều, đơn giản, browser có sẵn `EventSource` và tự kết nối lại.

```java
// Backend
@GetMapping(path = "/api/v1/queue/{eventId}/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
SseEmitter stream(@PathVariable UUID eventId, @AuthenticationPrincipal Jwt jwt) {
    SseEmitter emitter = new SseEmitter(0L);              // không tự timeout
    queueNotifier.register(eventId, jwt.getSubject(), emitter);
    return emitter;
}
// Ở chỗ khác, khi vị trí thay đổi:
emitter.send(SseEmitter.event().name("position").data(new QueuePosition(1234)));
```
```ts
// Frontend
useEffect(() => {
  const es = new EventSource(`/api/v1/queue/${eventId}/stream`)
  es.addEventListener('position', (e) => setPosition(JSON.parse(e.data).position))
  es.addEventListener('admitted', () => navigate({ to: '/events/$id/seats', params: { id: eventId } }))
  return () => es.close()
}, [eventId])
```

| | SSE | WebSocket | Socket.IO |
|---|---|---|---|
| Chiều | Server → Client | 2 chiều | 2 chiều |
| Độ phức tạp | Thấp | Trung bình | Thư viện Node.js |
| Dùng khi | Thông báo, cập nhật trạng thái | Chat, game | Ứng dụng Node.js |

---

## J. Frontend

### React + TypeScript + Vite
> **React**: thư viện xây UI bằng component. **TypeScript**: JavaScript có kiểu dữ liệu → bắt lỗi sớm. **Vite**: công cụ chạy dev/build siêu nhanh.

```bash
npm create vite@latest frontend -- --template react-ts
npm run dev     # chạy dev server, sửa code → trình duyệt cập nhật ngay
```

### npm
> Trình quản lý package đi kèm Node.js, dùng để cài thư viện và chạy script (`npm run dev`, `npm run build`).

### shadcn/ui
> Bộ component đẹp (Button, Dialog, Table…) dựa trên Radix. Điểm đặc biệt: **copy code vào project của bạn** chứ không cài như thư viện → tuỳ biến thoải mái.

```bash
npx shadcn@latest add button dialog table
# → sinh file vào src/components/ui/button.tsx ... bạn sở hữu và sửa trực tiếp
```
```tsx
<Button variant="destructive" onClick={cancelBooking}>Huỷ đơn</Button>
```

### Tailwind CSS
> Viết CSS bằng class tiện ích ngay trong JSX.

```tsx
<div className="flex items-center gap-2 rounded-lg border p-4 hover:bg-muted">...</div>
```

### TanStack Router
> Định tuyến trang, **type-safe** (sai tên route/params → lỗi compile). Có `beforeLoad` để chặn theo quyền.

```tsx
export const Route = createFileRoute('/organizer/events')({
  beforeLoad: ({ context }) => {
    if (!context.auth.hasRole('ORGANIZER')) throw redirect({ to: '/' })
  },
  component: OrganizerEventsPage,
})
```

### TanStack Query
> Quản lý **dữ liệu từ server**: tự cache, tự gọi lại, trạng thái loading/error, làm mới khi cần.

```tsx
const { data: event, isLoading } = useQuery({
  queryKey: ['event', id],
  queryFn: () => api.getEvent(id),
})
if (isLoading) return <Skeleton />
```

### Orval
> Đọc file OpenAPI của backend → **sinh tự động** hàm gọi API + hook TanStack Query + kiểu TypeScript. Không phải viết tay `fetch`.

```bash
npx orval     # sinh vào src/api/generated
```
```tsx
const { data } = useGetEvent(id)           // hook do Orval sinh, kiểu dữ liệu chuẩn theo BE
const createBooking = useCreateBooking()
createBooking.mutate({ data: { eventId, seatIds } })
```

### Zustand
> Lưu **state phía client** (không đến từ server) — đơn giản hơn Redux rất nhiều.

```ts
const useSeatStore = create<SeatState>((set) => ({
  selected: [],
  toggle: (seatId) => set((s) => ({
    selected: s.selected.includes(seatId)
      ? s.selected.filter((id) => id !== seatId)
      : [...s.selected, seatId],
  })),
}))
```

### React Hook Form + Zod
> **RHF**: quản lý form hiệu năng cao. **Zod**: khai báo luật kiểm tra dữ liệu, dùng chung để validate form.

```tsx
const schema = z.object({
  title: z.string().min(3, 'Tên tối thiểu 3 ký tự'),
  startsAt: z.date(),
  price: z.number().positive(),
})
const form = useForm<z.infer<typeof schema>>({ resolver: zodResolver(schema) })
```

### TanStack Table & Recharts
> **TanStack Table**: bảng dữ liệu có sort, lọc, phân trang (dùng qua shadcn Data Table). **Recharts**: vẽ biểu đồ (dùng qua shadcn Charts) — dashboard doanh thu.

### react-konva
> Vẽ đồ hoạ trên **canvas** bằng component React. Phù hợp sơ đồ hàng nghìn ghế, có zoom/kéo.

```tsx
<Stage width={900} height={600} draggable>
  <Layer>
    {seats.map((s) => (
      <Circle key={s.id} x={s.x} y={s.y} radius={8}
              fill={colorOf(s.status)} onClick={() => toggle(s.id)} />
    ))}
  </Layer>
</Stage>
```

### Stripe Elements (React)
> Form nhập thẻ do Stripe cung cấp, chạy trong iframe của Stripe → số thẻ không đi qua server của bạn (không phải lo chuẩn PCI).

```tsx
<Elements stripe={stripePromise} options={{ clientSecret }}>
  <PaymentElement />
  <Button onClick={() => stripe.confirmPayment({
    elements, confirmParams: { return_url: `${location.origin}/me/tickets` },
  })}>Thanh toán</Button>
</Elements>
```

### Thư viện nhỏ khác

| Thư viện | Dùng để | Ví dụ |
|---|---|---|
| lucide-react | Icon | `<Ticket className="size-4" />` |
| sonner | Thông báo nổi (toast) | `toast.success('Đặt vé thành công')` |
| qrcode.react | Hiển thị QR | `<QRCodeSVG value={ticket.qrToken} size={240} />` |
| @yudiel/react-qr-scanner | Quét QR bằng camera | `<Scanner onScan={(r) => checkIn(r[0].rawValue)} />` |
| date-fns | Xử lý ngày giờ | `format(startsAt, 'dd/MM/yyyy HH:mm')` |
| react-i18next | Đa ngôn ngữ vi/en | `t('booking.holdExpired')` |
| Sentry | Bắt lỗi JS ở browser | `Sentry.init({ dsn })` |
| ESLint / Prettier | Kiểm tra lỗi code / định dạng code | `npm run lint` |
| Husky + lint-staged | Chạy lint trước khi commit | tự động |

---

## K. Observability

### Ba trụ cột: Logs — Metrics — Traces
| | Trả lời câu hỏi | Ví dụ |
|---|---|---|
| **Logs** | Chuyện **gì** đã xảy ra? | `ERROR Không giữ được ghế A5 cho booking-123` |
| **Metrics** | **Bao nhiêu**, xu hướng ra sao? | 230 request/s, p95 = 180ms, CPU 70% |
| **Traces** | Request đi qua **đâu**, chậm ở **đâu**? | Gateway 5ms → Booking 20ms → Redis 1ms → Postgres **850ms** ← thủ phạm |

### Micrometer + Actuator
> **Actuator**: các endpoint quản trị có sẵn (`/actuator/health`, `/actuator/prometheus`). **Micrometer**: thư viện đo metric (giống SLF4J nhưng cho metric).

```java
Counter.builder("tickets.sold").tag("tier", tierName).register(registry).increment();
```
> ⚠️ Không dùng tag có quá nhiều giá trị (`userId`, `bookingId`) → làm nổ bộ nhớ Prometheus.

### Prometheus
> Database lưu **metric theo thời gian**. Cứ 15s đi "cào" (scrape) `/actuator/prometheus` của mọi service. Truy vấn bằng **PromQL**.

```promql
# p95 latency của API đặt vé trong 5 phút gần nhất
histogram_quantile(0.95,
  sum by (le) (rate(http_server_requests_seconds_bucket{uri="/api/v1/bookings"}[5m])))
```

### Grafana
> Vẽ **dashboard** từ Prometheus (và nhiều nguồn khác): biểu đồ request/s, latency, lỗi, vé bán/phút…

### Alertmanager
> Nhận cảnh báo từ Prometheus → gom nhóm, chống spam → gửi Telegram/Discord/email.

```yaml
- alert: DbConnectionPoolExhausted
  expr: hikaricp_connections_pending > 5
  for: 2m
  labels: { severity: critical }
  annotations:
    summary: "Pool kết nối DB cạn ở {{ $labels.pod }}"
    runbook: "docs/runbooks/db-pool-exhausted.md"
```

### ELK (Elasticsearch + Logstash/Filebeat + Kibana)
> **Filebeat** thu log từ container → (**Logstash** xử lý, tuỳ chọn) → **Elasticsearch** lưu & index → **Kibana** tìm kiếm, lọc, vẽ biểu đồ log.

```yaml
# Spring Boot ghi log JSON theo chuẩn ECS (Elastic Common Schema) — có sẵn từ Boot 3.4
logging.structured.format.console: ecs
```
```
# Tìm trong Kibana (KQL): mọi log lỗi của 1 request
service.name : "booking-service" and log.level : "ERROR" and trace.id : "4bf92f35..."
```
> **ILM** (Index Lifecycle Management): tự xoá index log cũ hơn 7 ngày → không đầy ổ.

### OpenTelemetry + Jaeger
> **OpenTelemetry (OTel)**: chuẩn chung để thu thập trace/metric/log, không phụ thuộc nhà cung cấp. **Jaeger**: giao diện xem trace dạng thác nước (waterfall).

> Spring Boot + OTel tự gắn `traceId` vào mọi log và tự truyền qua HTTP header / Kafka header → nối được hành trình 1 request qua nhiều service.

### SLI / SLO / Error budget
| Thuật ngữ | Nghĩa | Ví dụ |
|---|---|---|
| **SLI** (Indicator) | Chỉ số đo được | % request không lỗi 5xx |
| **SLO** (Objective) | Mục tiêu cho chỉ số đó | ≥ 99.5% trong 30 ngày |
| **Error budget** | Lượng lỗi "được phép" | 0.5% × 30 ngày ≈ **3.6 giờ** lỗi/tháng |
| **Burn rate** | Tốc độ tiêu budget | Đốt 2% budget trong 1 giờ → cảnh báo ngay |

> Còn budget → được deploy tính năng mới mạnh tay. Hết budget → tập trung sửa ổn định.

### Golden Signals / RED / USE
| Bộ chỉ số | Áp dụng cho | Gồm |
|---|---|---|
| **4 Golden Signals** | Mọi hệ thống | Latency, Traffic, Errors, Saturation |
| **RED** | Service / API | Rate, Errors, Duration |
| **USE** | Tài nguyên (CPU, disk, pool) | Utilization, Saturation, Errors |

### Blackbox exporter (synthetic monitoring)
> Giả làm người dùng, gọi thử endpoint từ bên ngoài mỗi phút → phát hiện "web sập" kể cả khi metric bên trong trông bình thường.

---

## L. Kiểm thử

### JUnit + AssertJ + Mockito
> **JUnit**: chạy test. **AssertJ**: viết kiểm tra dễ đọc. **Mockito**: giả lập dependency.

```java
@Test
void shouldExpireBookingAfterHoldTime() {
    Booking booking = Booking.pending(eventId, seats, now.minusMinutes(11));
    booking.expireIfOverdue(now);
    assertThat(booking.status()).isEqualTo(BookingStatus.EXPIRED);
}
```

### Testcontainers
> Chạy **Postgres/Redis/Kafka thật** trong Docker khi test → test sát thực tế, không dùng DB giả.

```java
@SpringBootTest
@Testcontainers
class BookingIntegrationTest {
    @Container @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:17");

    @Container @ServiceConnection
    static RedisContainer redis = new RedisContainer("redis:7");
}
```

### Awaitility
> Test code **bất đồng bộ** (Kafka): "chờ tối đa 10s cho đến khi điều kiện đúng".

```java
await().atMost(Duration.ofSeconds(10))
       .until(() -> ticketRepo.countByBookingId(bookingId) == 2);
```

### WireMock
> Giả lập API bên ngoài (Stripe) để test các tình huống: thành công, lỗi 500, chậm 5s…

```java
stubFor(post("/v1/payment_intents")
    .willReturn(aResponse().withStatus(500).withFixedDelay(5000)));   // test circuit breaker
```

### Pact (Contract testing)
> Consumer ghi lại "tôi mong đợi API/event của bạn trông như thế này" → Producer chạy kiểm tra hợp đồng đó trong CI → đổi API làm hỏng consumer là biết ngay, không cần chạy cả hệ thống.

### ArchUnit
> Viết test cho **kiến trúc**.

```java
noClasses().that().resideInAPackage("..booking..")
    .should().dependOnClassesThat().resideInAPackage("..payment.internal..")
    .check(classes);
```

### Instancio
> Tự sinh object test với dữ liệu ngẫu nhiên.

```java
Event event = Instancio.of(Event.class).set(field(Event::status), EventStatus.ON_SALE).create();
```

### Vitest + React Testing Library + MSW
> **Vitest**: chạy test FE. **RTL**: test component theo cách user dùng. **MSW**: giả lập API ở tầng network.

```ts
server.use(http.get('/api/v1/events/:id', () => HttpResponse.json({ id: '1', title: 'Rock Night' })))
render(<EventDetail id="1" />)
expect(await screen.findByText('Rock Night')).toBeInTheDocument()
```

### Playwright (E2E)
> Điều khiển trình duyệt thật, chạy cả luồng như user.

```ts
test('mua vé thành công', async ({ page }) => {
  await page.goto('/events/rock-night')
  await page.getByRole('button', { name: 'Chọn ghế' }).click()
  // ... chọn ghế, nhập thẻ test 4242..., thanh toán
  await expect(page.getByText('Đặt vé thành công')).toBeVisible()
})
```

### Apache JMeter (load test)
> Giả lập nhiều user cùng truy cập để đo hệ thống chịu tải.

| Khái niệm JMeter | Ý nghĩa |
|---|---|
| Thread Group | Nhóm user ảo: số lượng (500), thời gian tăng dần (ramp-up 10s), số vòng lặp |
| HTTP Request Sampler | 1 request cần gửi |
| CSV Data Set Config | Đọc danh sách user/ghế từ file để mỗi user ảo dùng dữ liệu khác nhau |
| Assertion | Kiểm tra response đúng |
| Listener / Report | Xem kết quả: latency, throughput, % lỗi |

```bash
# Thiết kế bằng GUI, chạy thật bằng CLI:
jmeter -n -t load-tests/jmeter/flash-sale.jmx -l result.jtl -e -o report/
```

### Chaos Mesh
> Chủ động **gây sự cố** trong K8s (kill pod, làm chậm mạng, đầy CPU…) để kiểm tra hệ thống có chịu được không.

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata: { name: kill-db-primary }
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces: [ticketrush]
    labelSelectors: { cnpg.io/instanceRole: primary }   # giết đúng DB primary
```

---

## M. Container & Kubernetes

### Docker
> Đóng gói app + môi trường chạy thành **image**; chạy ở đâu cũng giống nhau. **Multi-stage build**: stage 1 build, stage 2 chỉ chứa thứ cần để chạy → image nhỏ, ít lỗ hổng.

```dockerfile
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY . .
RUN ./mvnw -q -pl booking-service -am package -DskipTests

FROM eclipse-temurin:21-jre
COPY --from=build /src/booking-service/target/*.jar /app.jar
USER 1000                                   # không chạy bằng root
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

### Docker Compose (profiles)
> Chạy nhiều container cùng lúc bằng 1 file. **Profile** = bật nhóm container theo nhu cầu.

```yaml
services:
  postgres: { image: postgres:17, profiles: ["core"] }
  redis:    { image: redis:7,     profiles: ["core"] }
  kafka:    { image: apache/kafka, profiles: ["kafka"] }
```
```bash
docker compose --profile core --profile kafka up -d
```

### Kubernetes (K8s)
> "Hệ điều hành" cho cụm máy chủ: tự chạy container, tự khởi động lại khi chết, tự chia tải, tự scale.

| Khái niệm | Giải thích |
|---|---|
| **Pod** | Đơn vị chạy nhỏ nhất (1 container app) |
| **Deployment** | "Tôi muốn luôn có 3 pod booking chạy bản v1.2" → K8s tự duy trì |
| **Service** | Địa chỉ ổn định để gọi tới nhóm pod (pod chết/mới thì IP đổi, Service không đổi) |
| **ConfigMap / Secret** | Cấu hình / dữ liệu nhạy cảm truyền vào pod |
| **Namespace** | Chia cụm thành các "phòng" riêng (ticketrush, monitoring…) |
| **Operator** | Chương trình tự động vận hành 1 phần mềm phức tạp (vd. Postgres) như một người quản trị |

### Probes
```yaml
startupProbe:   { httpGet: { path: /actuator/health/liveness,  port: 8080 }, failureThreshold: 30, periodSeconds: 2 }  # chờ JVM khởi động
readinessProbe: { httpGet: { path: /actuator/health/readiness, port: 8080 } }  # chưa sẵn sàng → không nhận traffic
livenessProbe:  { httpGet: { path: /actuator/health/liveness,  port: 8080 } }  # treo → K8s restart pod
```

### PodDisruptionBudget
> "Lúc nào cũng phải còn ít nhất 1 pod booking" — K8s sẽ không tắt pod cuối cùng khi bảo trì / scale-in.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec: { minAvailable: 1, selector: { matchLabels: { app: booking } } }
```

### k3d / k3s
> **k3s**: bản Kubernetes gọn nhẹ (chạy được trên máy yếu, VPS rẻ). **k3d**: chạy k3s **bên trong Docker** → có cụm K8s nhiều node ngay trên laptop.

```bash
k3d cluster create ticketrush --agents 2      # 1 server + 2 worker node
```

### Helm
> "Trình quản lý package" cho K8s: đóng gói các file YAML thành **chart** có tham số, cài bằng 1 lệnh, mỗi môi trường 1 file values.

```bash
helm upgrade --install booking ./infra/helm/booking -f values-staging.yaml
```
```yaml
# values-staging.yaml
replicaCount: 2
image: { repository: ghcr.io/you/booking, tag: "1.4.0" }
resources: { limits: { cpu: "500m", memory: 512Mi } }
```

### ArgoCD (GitOps)
> Git là **nguồn sự thật** của hạ tầng. ArgoCD liên tục so sánh cụm K8s với Git → khác nhau thì tự đồng bộ. Muốn deploy = sửa Git, muốn rollback = revert commit.

### Argo Rollouts (Canary)
> Deploy bản mới **từ từ**: 10% traffic → theo dõi → 50% → 100%. Metric xấu → **tự rollback**.

```yaml
strategy:
  canary:
    steps:
      - setWeight: 10
      - pause: { duration: 5m }      # trong lúc này phân tích error rate từ Prometheus
      - setWeight: 50
      - pause: { duration: 5m }
```

### Gateway API + Envoy Gateway
> Cách chuẩn mới để đưa traffic từ Internet vào K8s (thay cho Ingress). **Envoy Gateway** là phần mềm thực thi.

```yaml
kind: HTTPRoute
spec:
  parentRefs: [{ name: public-gateway }]
  rules:
    - matches: [{ path: { type: PathPrefix, value: /api } }]
      backendRefs: [{ name: gateway, port: 8080 }]
    - matches: [{ path: { type: PathPrefix, value: / } }]
      backendRefs: [{ name: frontend, port: 80 }]
```

### cert-manager
> Tự xin và **tự gia hạn** chứng chỉ HTTPS (Let's Encrypt, miễn phí) trong K8s.

---

## N. Scaling

### Scale-out / Scale-in / Scale-up
| Thuật ngữ | Nghĩa |
|---|---|
| **Scale-out** (ngang) | Thêm **số lượng** pod/máy |
| **Scale-in** | Bớt số lượng khi rảnh → tiết kiệm |
| **Scale-up** (dọc) | Tăng **sức mạnh** 1 máy (thêm CPU/RAM) |

### HPA (Horizontal Pod Autoscaler)
> Tự tăng/giảm số pod theo CPU hoặc metric tuỳ chỉnh.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: booking }
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource: { name: cpu, target: { type: Utilization, averageUtilization: 70 } }
```

### KEDA
> Autoscale theo **sự kiện**: độ trễ Kafka, độ dài hàng đợi, lịch cron… và scale được **về 0**.

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
spec:
  scaleTargetRef: { name: notification }
  minReplicaCount: 0                  # không có message → 0 pod
  maxReplicaCount: 6                  # = số partition
  triggers:
    - type: kafka
      metadata: { bootstrapServers: kafka:9092, consumerGroup: notification, topic: ticket.events.v1, lagThreshold: "100" }
    - type: cron                      # scale sẵn trước giờ mở bán
      metadata: { timezone: Asia/Ho_Chi_Minh, start: "45 19 * * *", end: "0 22 * * *", desiredReplicas: "6" }
```

### VPA (Vertical Pod Autoscaler)
> Theo dõi pod thực dùng bao nhiêu CPU/RAM và **gợi ý** mức `requests/limits` hợp lý (chế độ `Off` = chỉ gợi ý, không tự sửa).

### Cluster Autoscaler / Karpenter
> HPA thêm pod nhưng hết máy để chạy → **thêm máy (node)**; rảnh → bớt máy. Chỉ có ý nghĩa trên cloud.

### Pre-warming
> Scale **trước** khi tải đến (biết giờ mở bán), vì JVM cần vài chục giây để khởi động & "nóng máy" — đợi tải đến mới scale là muộn.

---

## O. Vận hành dữ liệu & sự cố

### Replication & Failover
> **Replication**: Postgres primary liên tục sao chép dữ liệu sang replica. **Failover**: primary chết → 1 replica được **nâng cấp** thành primary mới, tự động.

### CloudNativePG (CNPG)
> Operator chạy Postgres trên K8s: HA, failover tự động, backup lên S3, PITR, PgBouncer đi kèm — khai báo bằng YAML.

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata: { name: booking-db }
spec:
  instances: 3                   # 1 primary + 2 replica
  storage: { size: 5Gi }
  # + cấu hình backup lên S3/MinIO
```

### Strimzi
> Operator chạy Kafka trên K8s. Tạo topic bằng YAML.

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata: { name: payment.events.v1, labels: { strimzi.io/cluster: ticketrush } }
spec: { partitions: 6, replicas: 3, config: { min.insync.replicas: 2 } }
```

### Redis Sentinel
> Theo dõi Redis master; master chết → tự bầu replica lên làm master mới.

### Backup, PITR
> **Base backup**: bản chụp toàn bộ DB hằng ngày. **WAL archive**: nhật ký mọi thay đổi, liên tục. Ghép lại → **PITR** (Point-In-Time Recovery): khôi phục DB về **đúng thời điểm** bất kỳ, vd. 14:32:05 — ngay trước khi lỡ tay `DELETE`.

### RPO / RTO
| | Câu hỏi | Mục tiêu TicketRush |
|---|---|---|
| **RPO** (Recovery Point Objective) | Chấp nhận **mất tối đa bao nhiêu dữ liệu**? | ≤ 5 phút |
| **RTO** (Recovery Time Objective) | Chấp nhận **sập tối đa bao lâu**? | ≤ 15 phút |

### Velero
> Backup toàn bộ cấu hình K8s (+ volume) → dựng lại cả cụm khi mất.

```bash
velero backup create daily --include-namespaces ticketrush
```

### Expand / Contract (migration không downtime)
> Đổi tên cột `name` → `title` mà không sập:
```
1. Expand:   thêm cột title (bản cũ vẫn chạy bình thường)
2. Deploy:   code mới ghi cả name và title
3. Backfill: UPDATE events SET title = name WHERE title IS NULL
4. Deploy:   code chỉ đọc/ghi title
5. Contract: xoá cột name (ở lần deploy sau)
```

### Runbook & Postmortem
> **Runbook**: hướng dẫn từng bước khi gặp 1 alert ("DB pool cạn → kiểm tra A → làm B"). **Postmortem**: báo cáo sau sự cố — timeline, nguyên nhân gốc, việc cần làm để không tái diễn. **Blameless**: tìm lỗi hệ thống, không đổ lỗi cho người.

---

## P. CI/CD, IaC & bảo mật hạ tầng

### GitHub Actions
> Tự động chạy build/test/scan/deploy mỗi khi push code.

```yaml
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: 21, cache: maven }
      - run: ./mvnw -B verify          # build + test (Testcontainers chạy được trên runner)
```

### GHCR (GitHub Container Registry)
> Nơi lưu Docker image, miễn phí với repo public. `ghcr.io/<user>/booking:1.4.0`.

### Terraform
> Khai báo hạ tầng cloud bằng code → tạo/xoá bằng lệnh, xem trước thay đổi, không click tay.

```hcl
provider "aws" {
  region = "ap-southeast-1"
  default_tags { tags = { Project = "ticketrush", Lab = "lab-01" } }
}

resource "aws_s3_bucket" "frontend" {
  bucket = "ticketrush-frontend-abc123"
}
```
```bash
terraform plan      # xem sẽ tạo/sửa/xoá gì
terraform apply     # thực hiện
terraform destroy   # xoá sạch
```

### Renovate
> Bot tự tạo PR cập nhật version thư viện khi có bản mới → không bị tụt hậu, vá lỗ hổng sớm.

### SonarCloud
> Phân tích chất lượng code: bug tiềm ẩn, code smell, trùng lặp, độ phủ test. Miễn phí với repo public.

### Spotless / Error Prone / JaCoCo
| Công cụ | Dùng để |
|---|---|
| Spotless | Tự định dạng code Java thống nhất |
| Error Prone | Bắt lỗi phổ biến lúc compile |
| JaCoCo | Đo độ phủ test (coverage) |

### Trivy
> Quét lỗ hổng bảo mật trong Docker image và thư viện.

```bash
trivy image ghcr.io/you/booking:1.4.0     # liệt kê CVE theo mức độ nghiêm trọng
```

### Falco
> Giám sát hành vi **lúc runtime** trong K8s: ai đó mở shell trong container, đọc `/etc/shadow`… → cảnh báo.

### NetworkPolicy
> Tường lửa giữa các pod: mặc định chặn hết, chỉ mở những đường cần thiết.

```yaml
# Chỉ booking-service được kết nối tới booking-db
spec:
  podSelector: { matchLabels: { cnpg.io/cluster: booking-db } }
  ingress:
    - from: [{ podSelector: { matchLabels: { app: booking } } }]
```

### External Secrets Operator
> Đồng bộ secret từ Vault / AWS SSM vào K8s Secret tự động.

### OpenCost
> Đo chi phí theo namespace / service trong K8s → biết service nào "ngốn tiền".

---

## Q. AWS

| Dịch vụ | Là gì | Dùng trong TicketRush |
|---|---|---|
| **S3** | Kho lưu file không giới hạn | Host file build FE, ảnh banner, backup DB |
| **CloudFront** | CDN — phân phối nội dung từ máy chủ gần người dùng | Phục vụ FE nhanh + HTTPS |
| **SES** | Dịch vụ gửi email | Gửi email vé |
| **EC2** | Máy ảo | Chạy app, k3s |
| **EC2 Spot** | Máy ảo "hàng tồn" giá rẻ 60–90%, có thể bị thu hồi | Máy lab, máy chạy JMeter |
| **RDS** | Postgres được AWS quản lý (backup, vá lỗi tự động) | Lab deploy MVP |
| **RDS Multi-AZ** | RDS có bản dự phòng ở trung tâm dữ liệu khác, tự failover | Lab "DB sập" |
| **ALB** | Load balancer tầng HTTP | Chia tải cho nhóm EC2 |
| **Auto Scaling Group** | Nhóm EC2 tự tăng/giảm số máy | Lab scale-out/in mức VM |
| **CloudWatch** | Metric, log, alarm của AWS | Alarm CPU cao → ASG thêm máy |
| **SNS** | Gửi thông báo (email, SMS…) | Nhận alarm |
| **SSM Parameter Store** | Lưu cấu hình / secret (bản standard miễn phí) | Stripe key khi chạy trên AWS |
| **IAM Identity Center** | Đăng nhập tập trung, cấp credentials tạm thời | Thay cho access key dài hạn |
| **AWS Budgets** | Ngân sách + cảnh báo + hành động tự động | Chặn phát sinh chi phí |
| **EventBridge Scheduler** | Hẹn giờ chạy tác vụ | Tự stop EC2 lúc 23h |

Ví dụ lệnh hay dùng:

```bash
aws sso login --profile ticketrush                                   # đăng nhập, nhận credentials tạm thời
aws ssm get-parameter --name /ticketrush/stripe-key --with-decryption
aws rds reboot-db-instance --db-instance-identifier ticketrush-db --force-failover   # ép failover (lab)
aws ec2 describe-instances --filters "Name=tag:Project,Values=ticketrush"           # tìm resource còn sót
```

### aws-nuke
> Công cụ **xoá sạch mọi resource** trong tài khoản AWS. Dùng lúc kết thúc để chắc chắn không còn gì tính tiền. Luôn chạy **dry-run** trước để xem danh sách sẽ xoá.

### Oracle Cloud Always Free & Cloudflare Tunnel
> **Oracle Always Free**: máy ảo ARM 4 core + 24GB RAM miễn phí vĩnh viễn → chạy k3s lâu dài. **Cloudflare Tunnel**: đưa app đang chạy ở máy nhà ra Internet có HTTPS, không cần mở port router, miễn phí.
