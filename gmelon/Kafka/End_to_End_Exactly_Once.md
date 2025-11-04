Flink의 End-to-End Exactly-Once 처리
문제 상황
카프카에서 데이터를 읽어서 → Flink로 처리하고 → 다시 카프카에 쓰는 파이프라인을 생각해보자.
중간에 장애가 발생하면:

Flink 내부에서만 exactly-once를 보장해도 소용없음
카프카에 쓰는 과정에서도 exactly-once가 보장되어야 함

이게 바로 End-to-End Exactly-Once의 의미임.
Flink의 체크포인트 메커니즘
체크포인트란?
체크포인트 = 애플리케이션 전체 상태의 스냅샷
- 현재 처리 중인 상태값들
- 입력 스트림의 어디까지 읽었는지 (오프셋)
```

주기적으로 S3, HDFS 같은 영구 저장소에 저장됨. 장애 발생 시 마지막 체크포인트부터 재시작하면 됨.

문제는 **외부 시스템(카프카 등)에 쓴 데이터는 Flink가 직접 제어할 수 없다**는 점임.

## Two-Phase Commit 프로토콜

분산 시스템에서 모든 컴포넌트가 "커밋할지 롤백할지"를 함께 합의하는 방법.

### Phase 1: Pre-Commit (준비 단계)
```
1. 체크포인트 시작
   └─> JobManager가 checkpoint barrier를 데이터 스트림에 삽입
   
2. Barrier가 각 연산자를 통과하며 스냅샷 생성
   ├─ Source: 카프카 오프셋 저장
   ├─ 중간 연산자: 내부 상태 저장 (윈도우 집계 결과 등)
   └─ Sink: 카프카에 데이터 쓰기 + 트랜잭션 pre-commit
   
3. 모든 연산자가 pre-commit 완료
```

여기서 핵심은 **Sink가 카프카에 데이터를 쓰지만 아직 커밋하지 않음**. 임시로만 저장함.

### Phase 2: Commit (확정 단계)
```
1. 모든 연산자의 pre-commit 성공 확인
   
2. JobManager가 모든 연산자에게 "checkpoint 성공" 알림
   
3. Sink가 카프카 트랜잭션을 최종 커밋
   └─> 이제 데이터가 실제로 보임
```

### 실패 시나리오
```
Pre-commit 중 하나라도 실패하면?
└─> 모두 abort하고 이전 체크포인트로 롤백

Commit 중 실패하면?
└─> Flink 재시작하고 commit 재시도
    (commit은 반드시 성공해야 함)
실제 구현: TwoPhaseCommitSinkFunction
Flink가 제공하는 추상 클래스. 4개 메서드만 구현하면 됨:
java// 예: 파일 시스템에 exactly-once로 쓰기

1. beginTransaction()
   - 임시 디렉토리에 임시 파일 생성
   - 이 파일에 데이터 쓰기

2. preCommit()
   - 파일 flush & close
   - 더 이상 쓰지 않음

3. commit()
   - 임시 파일을 실제 목적지로 atomic move
   - 이 순간부터 데이터가 실제로 보임

4. abort()
   - 임시 파일 삭제
카프카와의 통합
카프카 0.11부터 트랜잭션 지원이 추가되어 가능해짐:
java// Flink의 KafkaProducer가 내부적으로 TwoPhaseCommitSinkFunction 사용

KafkaConsumer (Source)
    ↓
Flink Processing
    ↓
KafkaProducer (Sink with 2PC)
흐름 정리

체크포인트 시작 → 카프카 트랜잭션 시작
데이터 처리하면서 카프카에 쓰기 (트랜잭션 내에서)
Pre-commit: 트랜잭션 준비 완료
모든 연산자 성공 시 → 카프카 트랜잭션 커밋
실패 시 → 카프카 트랜잭션 abort

핵심 포인트

Flink 내부 exactly-once는 체크포인트로 보장
End-to-end exactly-once는 외부 시스템(카프카)의 트랜잭션 지원 필요
Two-phase commit로 Flink 체크포인트와 외부 시스템 트랜잭션 동기화
장애 발생해도 "모두 성공" 또는 "모두 실패" 보장

이 방식의 장점은 디스크에 중간 결과를 계속 쓰지 않아도 된다는 점임. 배치 처리처럼 매 단계마다 저장하지 않고도 exactly-once를 보장할 수 있음.