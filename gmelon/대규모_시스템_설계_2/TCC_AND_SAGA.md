

## Saga 패턴의 해결 방식

각 단계를 **독립적인 로컬 트랜잭션**으로 처리하고, 실패 시 **보상 트랜잭션(Compensating Transaction)** 실행.

### Choreography (이벤트 기반 - 병렬 가능)

```
[주문생성] --이벤트--> [결제서비스] --이벤트--> [재고서비스]
                              ↓ 실패 시
                    <--보상이벤트-- [결제취소]
```

**장점:**
- 서비스가 독립적으로 이벤트 소비 → **병렬 처리 가능**
- 느슨한 결합, 리소스 잠금 없음

### Orchestration (중앙 조정 - 직렬/병렬 혼합)

```java
// Orchestrator가 순서 제어
saga.step(orderService::create)
    .compensate(orderService::cancel)
    .step(paymentService::process)      // 직렬
    .compensate(paymentService::refund)
    .parallel(                           // 병렬
        inventoryService::reserve,
        shippingService::prepare
    )
    .build();
```

**장점:**
- 명시적 흐름 제어
- 필요에 따라 **직렬/병렬 선택** 가능
- 복잡한 보상 로직 관리 용이

---

## 비교 요약

| 항목 | TCC | Saga |
|------|-----|------|
| 처리 방식 | 동기/블로킹 | 비동기/논블로킹 |
| 리소스 잠금 | Try~Confirm 동안 유지 | 즉시 커밋, 잠금 없음 |
| 실행 방식 | 직렬 (순차 대기) | 직렬/병렬 선택 가능 |
| 롤백 방식 | Cancel로 예약 해제 | 보상 트랜잭션 실행 |
| 일관성 | 강한 일관성 | 최종 일관성 (Eventually) |
| 구현 복잡도 | Try/Confirm/Cancel 모두 구현 | Step + Compensate 구현 |

---

## 결론

TCC는 **강한 일관성**이 필요한 경우 유용하나, 동기식 처리와 리소스 잠금으로 인한 성능 저하가 단점.

Saga는 **최종 일관성**을 수용하는 대신, 비동기 처리와 유연한 실행 전략(병렬/직렬)으로 높은 처리량과 확장성 제공. 특히 MSA 환경에서는 Saga가 더 적합한 선택인 경우가 많음.