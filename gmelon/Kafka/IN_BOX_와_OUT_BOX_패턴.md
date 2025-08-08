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

이걸 어떻게 하냐면,,