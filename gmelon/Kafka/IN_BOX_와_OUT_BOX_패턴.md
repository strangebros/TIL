## Outbox 패턴
> 출처: https://curiousjinan.tistory.com/entry/transactional-outbox-pattern-microservices-kafka

### 개요
* MSA에서 데이터베이스의 일관성과 메시지 발행의 신뢰성을 동시에 보장하기 위한 디자인 패턴
* 서비스의 데이터 변경을 반영하는 이벤트를 메시지 브로커(Kafka 등)에 안전하게 발행하면서, 트랜잭션의 일관성을 유지하고 장애 상황에서도 데이터 손실을 방지하는 데 중요한 역할

### Outbox 테이블
* 데이터베이스 변경사항과 관련된 메시지의 발행 상태를 관리하는 특별한 테이블

| 필드 이름         | 데이터 타입      | 설명                                                      |
|------------------|-----------------|----------------------------------------------------------|
| id               | BIGINT / UUID   | 기본 키, 각 레코드의 고유 식별자                          |
| aggregate_type   | VARCHAR(255)    | 이벤트가 발생한 도메인 객체의 유형 (예: "User")           |
| aggregate_id     | VARCHAR(255)    | 이벤트가 발생한 특정 도메인 객체의 ID (예: 사용자 ID)     |
| event_type       | VARCHAR(255)    | 발생한 이벤트의 유형 (예: "UserCreated", "UserModified") |
| payload          | TEXT / JSON     | 이벤트와 관련된 실제 데이터 (JSON 형식)                   |
| timestamp        | TIMESTAMP       | 이벤트가 Outbox 테이블에 기록된 시간                     |
| status           | VARCHAR(50)     | 메시지의 처리 상태 (READY_TO_PUBLISH, PUBLISHED, MESSAGE_CONSUME, FAILED) |

### 동작 방식 및 사용하는 이유
Outbox 테이블을 사용하면 애플리케이션 로직과, 이로 인해 수행되어야 하는 카프카 이벤트 등 비동기 로직을 동기화할 수 있다.

예를 들어 '유저 정보가 수정' 되었고, 이로 인해 발행되어야 하는 카프카 이벤트가 있는 상황이라고 가정했을 때 '유저 정보는 정상적으로 수정' 되었지만 이벤트 발행에는 실패할 수 있다. 이 경우 애플리케이션 입장에서는 이벤트를 통해 처리되어야 하는 로직들이 수행되지 않았음을 (최악의 경우) 모르게 될 수도 있다.

이를 방지하기 위해 Outbox 테이블을 사용할 수 있다. 즉, '유저 정보 수정' 과 'Outbox 테이블 insert' 두 작업을 하나의 트랜잭션에서 처리하고, 카프카 이벤트 발행은 새로운 (after transaction) 이벤트로 처리하거나 별도 배치를 통해 outbox 테이블에 저장된 데이터를 보고 수행할 수 있게 된다.

다만, 이렇게 됐을 때 남은 문제점은 해당 메시지가 중복 발송되거나, 컨슈머에서 중복으로 처리될 수 있다는 점이다. 이 부분은 Inbox 패턴으로 해결할 수 있고, 이는 아래에서 다시 살펴보자!

### 예제 코드
#### 서비스
```java
@RequiredArgsConstructor
@Service
@Transactional
public class UserService {
    
    private final UserRepository userRepository;
    private final OutboxRepository outboxRepository;
    private final ObjectMapper objectMapper;
    
    public void updateUser(Long userId, UserUpdateRequest request) {
        // 1. 유저 정보 수정
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new UserNotFoundException("User not found"));
        
        user.updateInfo(request.getName(), request.getEmail());
        userRepository.save(user);
        
        // 2. Outbox 테이블에 이벤트 기록 (같은 트랜잭션 내에서 처리)
        UserModifiedEvent event = new UserModifiedEvent(
                user.getId(), 
                user.getName(), 
                user.getEmail()
            );
            
            OutboxEvent outboxEvent = OutboxEvent.builder()
                .aggregateType("User")
                .aggregateId(userId.toString())
                .eventType("UserModified")
                .timestamp(LocalDateTime.now())
                .status(OutboxEvent.OutboxStatus.READY_TO_PUBLISH)
                .build();
                
            outboxRepository.save(outboxEvent);
        }
    }
}
```

#### kafka publisher
```java
@RequiredArgsConstructor
@Component
@Slf4j
public class OutboxEventPublisher {
    
    private final OutboxRepository outboxRepository;
    private final KafkaTemplate<String, String> kafkaTemplate;
    
    @Scheduled(fixedDelay = 5000) // 5초마다 실행
    @Transactional
    public void publishPendingEvents() {
        List<OutboxEvent> pendingEvents = outboxRepository
            .findByStatusOrderByTimestampAsc(OutboxEvent.OutboxStatus.READY_TO_PUBLISH);
            
        for (OutboxEvent event : pendingEvents) {
            try {
                // 카프카로 메시지 발행
                kafkaTemplate.send("user-events", event.getAggregateId(), event.getPayload())
                    .addCallback(
                        result -> {
                            // 발행 성공 시 상태 업데이트
                            event.setStatus(OutboxEvent.OutboxStatus.PUBLISHED);
                            outboxRepository.save(event);
                            log.info("Successfully published event: {}", event.getId());
                        },
                        failure -> {
                            // 발행 실패 시 상태 업데이트
                            event.setStatus(OutboxEvent.OutboxStatus.FAILED);
                            outboxRepository.save(event);
                            log.error("Failed to publish event: {}", event.getId(), failure);
                        }
                    );
                    
            } catch (Exception e) {
                event.setStatus(OutboxEvent.OutboxStatus.FAILED);
                outboxRepository.save(event);
                log.error("Error publishing event: {}", event.getId(), e);
            }
        }
    }
}
```

to be continued..

## Inbox 패턴
Outbox 패턴 말고 Inbox 패턴도 있다. 이건 메시지 중복 처리를 방지하고 멱등성을 보장하기 위한 디자인 패턴으로,Outbox 패턴과 함께 사용되어 이벤트 기반 아키텍처에서 발생할 수 있는 중복 메시지 문제를 해결할 수 있다.

메시지 컨슈머에서 이미 처리된 메시지를 식별하고 중복 처리를 방지하여 데이터 일관성을 유지하는 데 중요한 역할을 한다.

### 동작 방식 및 사용 이유
메시지는 근본적으로 네트워크 장애, 시스템 재시작, 카프카 리밸런싱 등의 이유로 동일한 메시지가 여러 번 전달될 수 있다. 예를 들어 '주문 생성' 이벤트가 중복으로 수신되면 동일한 주문이 여러 번 처리되어 데이터 불일치가 발생할 수 있다! (대박장애)

이를 방지하기 위해 Inbox 테이블을 사용하여 수신된 메시지의 식별자를 기록하고, 메시지를 처리하기 전에 Inbox 테이블을 확인하여 이미 처리된 메시지인지 판단하고, 처리된 메시지라면 무시하고, 처리되지 않은 메시지만 비즈니스 로직을 수행하도록 할 수 있다.
Outbox 패턴과 Inbox 패턴을 함께 사용하면 이벤트 기반 아키텍처에서 'Exactly Once Processing'에 가까운 신뢰성을 확보할 수 있게 된다.

### Inbox 테이블
Outbox 테이블과 유사하게, 수신된 메시지의 식별자와 처리 상태를 관리하는 테이블이다.

| 필드 이름         | 데이터 타입      | 설명                                                      |
|------------------|-----------------|----------------------------------------------------------|
| id               | BIGINT / UUID   | 기본 키, 각 레코드의 고유 식별자                          |
| message_id       | VARCHAR(255)    | 수신된 메시지의 고유 식별자 (중복 방지용)                |
| event_type       | VARCHAR(255)    | 수신한 이벤트의 유형 (예: "UserCreated", "OrderPlaced")  |
| payload          | TEXT / JSON     | 수신한 메시지의 실제 데이터 (JSON 형식)                   |
| timestamp        | TIMESTAMP       | 메시지가 수신된 시간                                     |
| status           | VARCHAR(50)     | 메시지의 처리 상태 (RECEIVED, PROCESSING, PROCESSED, FAILED) |
| processed_at     | TIMESTAMP       | 메시지가 처리 완료된 시간 (nullable)                     |

### 동작 플로우
실제로 Inbox 패턴을 적용하면 아래와 같은 플로우로 동작한다.

1. **메시지 수신**: 카프카 컨슈머가 메시지를 수신
2. **중복 체크**: Inbox 테이블에서 해당 `message_id`가 이미 존재하는지 확인
3. **처리 분기**:
   - 이미 처리된 메시지라면 → 무시하고 다음 메시지 처리
   - 처리되지 않은 메시지라면 → Inbox에 기록 후 비즈니스 로직 수행
4. **상태 업데이트**: 비즈니스 로직 처리 완료 후 상태를 `PROCESSED`로 변경

이때 핵심은 **2번과 3번이 하나의 트랜잭션**에서 처리되어야 한다는 점이다. 그래야 메시지 처리와 Inbox 기록이 원자적으로 수행되어 중복 처리를 확실히 방지할 수 있다.

### 메시지 ID 생성 전략
Inbox 패턴이 제대로 동작하려면 각 메시지마다 고유한 식별자가 있어야 한다. 이를 위한 몇 가지 방법이 있는데,

#### 1. Outbox 이벤트 ID 활용
가장 간단한 방법으로, Outbox 테이블의 ID를 그대로 메시지 ID로 사용하는 것이다.
```json
{
  "messageId": "outbox_123",  // Outbox 테이블의 ID
  "eventType": "UserModified",
  "payload": { /* 실제 데이터 */ }
}
```

#### 2. 비즈니스 키 + 이벤트 타입 조합
특정 도메인 객체와 이벤트 타입을 조합해서 만드는 방법이다.
```json
{
  "messageId": "user_123_modified_20241201120000",  
  "eventType": "UserModified",
  "payload": { /* 실제 데이터 */ }
}
```

#### 3. UUID 생성
메시지 발행 시점에 UUID를 생성해서 사용하는 방법도 있다.
```json
{
  "messageId": "550e8400-e29b-41d4-a716-446655440000",
  "eventType": "UserModified", 
  "payload": { /* 실제 데이터 */ }
}
```

개인적으로는 **1번 방법**이 가장 단순하면서도 확실한 것 같다. Outbox 테이블의 ID는 이미 고유성이 보장되어 있고, 메시지 추적도 쉬워진다.

### 실제로 고려해야 할 부분들
Inbox 패턴을 실제 프로덕션에 적용하면서 겪게 될 몇 가지 이슈들이 있다:

#### 1. Inbox 테이블 크기 관리
시간이 지나면서 Inbox 테이블이 계속 쌓이게 된다. 이를 해결하기 위해서는 아래 방법을 고려할 수 있다.
- 오래된 처리 완료 레코드를 주기적으로 삭제하는 배치 작업 필요
- 또는 파티셔닝을 통한 성능 최적화 고려

#### 2. 처리 실패한 메시지 재시도
`FAILED` 상태인 메시지들에 대한 재처리 로직이 필요하다. 단순히 재시도만 하면 무한 루프에 빠질 수 있으니, 최대 재시도 횟수나 데드레터 큐 같은 장치가 필요할 것 같다.

#### 3. 메시지 순서 보장
카프카에서는 동일한 파티션 내에서만 순서가 보장되는데, 비즈니스 로직에서 메시지 순서가 중요하다면 이 부분도 별도로 고려해야 한다.

#### 4. 성능 최적화
매번 Inbox 테이블을 조회하는 것이 부담될 수 있으니, 캐시를 활용하거나 배치 처리를 고려해볼 수도 있다.

## 결론
Outbox와 Inbox 패턴을 함께 사용하면 MSA 환경에서 데이터 일관성과 메시지 신뢰성을 모두 확보할 수 있다. 특히 금융이나 결제 같은 도메인에서는 이런 패턴들이 거의 필수적인 것 같다.

다만 패턴을 도입하면서 복잡성도 함께 증가하니까, 실제 프로젝트에서는 비즈니스 요구사항과 시스템 복잡성 사이의 트레이드오프를 잘 고려해서 적용해야 할 것 같다. 간단한 시스템에서는 오히려 과도한 엔지니어링이 될 수도 있으니까.

### 예제 코드