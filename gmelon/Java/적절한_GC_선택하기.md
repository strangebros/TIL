## 컬렉터들 간 비교 및 취사 선택

### 선택 기준 3가지

1. 애플리케이션 주목적
    - 처리량(Throughput) 중시: 배치·과학 계산 등 → 최대 처리 성능
    - 지연 시간(Latency) 중시: SLA 서비스 등 → 짧은 일시 정지
    - 메모리 사용량 중시: 클라이언트·임베디드 애플리케이션
2. 구동 서브시스템 환경
    - 하드웨어 아키텍처(x86, ARM 등)
    - CPU 코어 수, 가용 메모리 용량
    - 운영체제(리눅스, 윈도우, macOS 등)
3. JDK 제공자·버전
    - Azul Zing, Oracle JDK, OpenJDK, OpenJ9 등
    - 지원하는 JVM 스펙(가비지 컬렉터 종류)

### 지연 시간 최우선 예제
- 예산이 여유있고, 최적화 경험이 부족하다면 → Azul Zing VM + C4 컬렉터 권장
- 상용 제품을 사용할 수 없고, SW/HW 를 직접 제어할 수 있다면 → 최신 Oracle/OpenJDK 버전 사용, 지연 시간 중요 시 ZGC 시도 가능
- 레거시 시스템을 사용하고 있는 경우
    - 힙 메모리 4~6 GB 이하 → CMS
    - 힙 메모리 6 GB 이상 → G1

### Oracle/OpenJDK 기본 권장 가이드라인
- 작은 메모리(<100 MB) 및 단일 프로세서 사용, 일시 정지에는 큰 제약이 없는 경우= → Serial 컬렉터
- 최대 처리량을 중시하고, 일시 정지가 1 초 이상 허용된다면 → Parallel 컬렉터
- 일시 정지를 최대한 짧게 가져가고, 응답 시간을 중시한다면 → G1 컬렉터
- 지연 시간 → ZGC 컬렉터

```
위 내용은 이론적인 내용이므로, 여기에만 의존하지 말고 실제 환경에서 벤치마크, 테스트를 통해 최적 컬렉터를 선정해야 함
```

## 가비지 컬렉터 로그
> GC 로그를 통해 가비지 컬렉터 벤치마크를 해볼 수 있을듯
### 개요

- JDK 8 이전: 가비지 컬렉터 로그 설정을 위한 매개변수들이 컬렉터별로 분산(-XX:+PrintGC, -XX:+PrintGCDetails 등)
- JDK 9 이후: 모든 핫스팟 기능 로그를 하나의 통합 프레임워크로 관리 (-Xlog 하나로 모든 로그 제어 가능)
    
    ```sql
    -Xlog[:[selector][:output][:decorators][:output-options]]
    ```
    
    - **selector**: 태그(gc, heap, safepoint, ergo, age 등)와 레벨(trace, debug, info, warning, error, off)
    - **decorators** (기본: uptime, level, tags)
        - time, uptime, timemillis, uptimemillis, timenanos, uptimenanos, pid, tid, level, tags

### 예시 1: 기존 GC 정보

```sql
java -Xlog:gc GCTest
```

```sql
// 가비지 컬렉터로 G1 사용
[0.222s] [info] [gc] Using G1
// 첫 번째 Young GC(0) 시작, Evacuation 후 힙 사용량 26M->5M(총 256M)
// 일시정지 시간: 355.623ms
[2.825s] [info] [gc] GC(0) Pause Young (G1 Evacuation Pause) 26M->5M(256M)
355.623ms
// 두 번째 Young GC(1) 시작, Evacuation 후 힙 사용량 14M->7M(총 256M)
// 일시정지 시간: 50.030ms
[3.096s] [info] [gc] GC(1) Pause Young (G1 Evacuation Pause) 14M->7M(256M)
50.030ms
// 세 번째 Young GC(2) 시작, Evacuation 후 힙 사용량 17M->10M(총 256M)
// 일시정지 시간: 40.576ms
[3.385s] [info] [gc] GC(2) Pause Young (G1 Evacuation Pause) 17M-10M(256M)
40.576ms
```

### 예시 2: 상세 GC 정보

- 와일드카드(*) 문자는 gc 태그의 모든 하위 프로세스를 포함한다는 뜻

```sql
java -Xlog:gc* GCTest
```

```java
// 힙 region 크기를 1MB 단위로 설정
[0.233s] [info] [gc, heap] Heap region size: 1M
// 가비지 컬렉터로 G1 사용
[0.383s] [info] [gc] Using G1
// 힙 coops 정보: 시작 주소
[0.383s] [info] [gc, heap, coops] Heap address: 0xfffffffe50400000,
// 힙 크기 및 압축 포인터 정보
size: 4064 MB, Compressed Oops mode: Non-zero based:
// 압축 Oops 기반 주소 및 shift amount
0xfffffffe50000000, Oop shift amount: 3
// 첫 번째 Young GC(0) 시작 (G1 Evacuation Pause)
[3.064s] [info] [gc, start ] GC(0) Pause Young (G1 Evacuation Pause)
// Evacuation 작업에 23 스레드 사용
gc, task GC (0) Using 23 workers of 23 for evacuation
// Pre Evacuate 단계 소요 시간 0.2ms
[3.420s] [info] [gc, phases ] GC (0) Pre Evacuate Collection Set: 0.2ms
// Evacuate 단계 소요 시간 348.0ms
[3.421s] [info] [gc, phases ] GC (0) Evacuate Collection Set: 348.0ms
// Post Evacuate 단계 소요 시간 6.2ms
gc, phases GC (0) Post Evacuate Collection Set: 6.2ms
// 기타 단계 소요 시간 2.8ms
[3.421s] [info] [gc, phases ] GC (0) Other: 2.8ms
// Eden 영역 24->0, 최대 9개
gc,heap GC (0) Eden regions: 24->0(9)
// Survivor 영역 0->3, 최대 3개
[3.421s] [info] [gc, heap ] GC (0) Survivor regions: 0->3(3)
// Old 영역 0->2
[3.421s] [info] [gc, heap ] GC (0) Old regions: 0->2
// Humongous 영역 2->1
[3.421s] [info] [gc, heap ] GC (0) Humongous regions: 2->1
// Metaspace 사용량 변화 없음 (4719K)
[3.421s] [info] [gc, metaspace ] GC (0) Metaspace: 4719K->4719K (1056768K)
// GC(0) Real 일시정지 시간만 표시
357.743ms
// User CPU 0.70s, Sys CPU 5.13s, Real 0.36s
[3.422s] [info] [gc, cpu ] GC (0) User-0.70s Sys-5.13s Real-0.36s
// 두 번째 Young GC(1) 시작 (G1 Evacuation Pause)
[3.648s] [info] [gc, start] GC (1) Pause Young (G1 Evacuation Pause)
// Evacuation 작업에 23 스레드 사용
[3.648s] [info] [gc, task] GC (1) Using 23 workers of 23 for evacuation
// Pre Evacuate 단계 소요 시간 0.3ms
[3.699s] [info] [gc, phases ] GC (1) Pre Evacuate Collection Set: 0.3ms
// Evacuate 단계 소요 시간 45.6ms
gc, phases GC (1) Evacuate Collection Set: 45.6ms
// Post Evacuate 단계 소요 시간 3.4ms
gc, phases GC (1) Post Evacuate Collection Set: 3.4ms
// 기타 단계 소요 시간 1.7ms
gc, phases GC (1) Other: 1.7ms
// Eden 영역 9->0, 최대 10개
gc, heap GC (1) Eden regions: 9->0(10)
// Survivor 영역 3->2, 최대 2개
[3.699s] [info] [gc, heap ] GC (1) Survivor regions: 3->2(2)
// Old 영역 2->5
[3.699s] [info] [gc, heap ] GC (1) Old regions: 2->5
// Humongous 영역 변동 없음 (1)
[3.700s] [info] [gc, heap] GC (1) Humongous regions: 1->1
// Metaspace 사용량 변화 없음 (4726K)
[3.700s] [info] [gc, metaspace ] GC (1) Metaspace: 4726K->4726K (1056768K)
// 컬렉션 전/후 힙 사용량 및 일시정지 시간 (14M->7M, 51.872ms)
[3.700s] [info] [gc] GC (1) Pause Young (G1 Evacuation Pause) 14M->7M(256M)
51.872ms
// User CPU 0.56s, Sys CPU 0.46s, Real 0.05s
[3.700s] [info] [gc, cpu ] GC (1) User-0.56s Sys-0.46s Real=0.05s
```

### 예시 3: 가비지 컬렉션 전후로 가용한 힙과 메서드 영역의 용량 변화를 확인

```sql
java -Xlog:gc+heap=debug GCTest
```

```sql
// 힙 region 크기를 1MB로 설정
[0.113s] [info] [gc, heap] Heap region size: 1M
// 힙 최소 및 초기 크기 설정 (8MB, 256MB)
[0.113s] [debug] [gc, heap] Minimum heap 8388608 Initial heap 268435456
// 힙 최대 크기 설정 (≈4GB)
Maximum heap 4261412864
// GC(0) 이전 상태: invocation=0, full GC=0
[2.529s] [debug] [gc, heap] GC (0) Heap before GC invocations=0 (full 0):
// GC(0) garbage-first heap 총 256MB 중 26MB 사용 중
[2.529s] [debug] [gc, heap] GC (0) garbage-first heap total 262144K, used 26624K
// GC(0) Humongous 영역 주소 범위
[2.529s] [debug] [gc, heap] [0xfffffffe50400000, 0xfffffffe50500800, 0xffffffff4e400000)
// GC(0) region 크기 1MB, Young 24개(24MB), Survivor 0개
[2.529s] [debug] [gc, heap] GC (0) region size 1024K, 24 young (24576K), 0 survivors (OK)
// Metaspace 사용량: 4.6MB/4.8MB(combined committed 5MB, reserved ~1GB)
[2.530s] [debug] [gc, heap] GC (0) Metaspace used 4719K, capacity 4844K, committed 5120K, reserved 1056768K
// Class space 사용량: 413K/464K(committed 512K, reserved ~1GB)
[2.530s] [debug] [gc, heap] GC (0) class space used 413K, capacity 464K, committed 512K, reserved 1048576K
// GC(0) 이후 Eden regions 24->0(9)
[2.892s] [info] [gc, heap] GC (0) Eden regions: 24->0(9)
// GC(0) 이후 Survivor regions 0->3(3)
[2.892s] [info] [gc, heap] GC (0) Survivor regions: 0->3(3)
// GC(0) 이후 Old regions 0->2
[2.892s] [info] [gc, heap] GC (0) Old regions: 0->2
// GC(0) 이후 Humongous regions 2->1
[2.892s] [info] [gc, heap] GC (0) Humongous regions: 2->1
// GC(0) 완료 후 상태: invocation=1, full GC=0
[2.893s] [debug] [gc, heap] GC (0) Heap after GC invocations=1 (full 0):
// GC(0) garbage-first heap 총 256MB 중 5.7MB 사용 중
[2.893s] [debug] [gc, heap] GC (0) garbage-first heap total 262144K, used 5850K
// GC(0) Humongous 영역 주소 범위 유지
[2.893s] [debug] [gc, heap] [0xfffffffe50400000, 0xfffffffe50500800, 0xffffffff4e400000)
// GC(0) region 크기 1MB, Young 3개(3MB), Survivor 3개(3MB)
[2.893s] [debug] [gc, heap] GC (0) region size 1024K, 3 young (3072K), 3 survivors (3072K)
// Metaspace 사용량 변화 없음
[2.893s] [debug] [gc, heap] GC (0) Metaspace used 4719K, capacity 4844K, committed 5120K, reserved 1056768K
// Class space 사용량 변화 없음
[2.893s] [debug] [gc, heap] GC (0) class space used 413K, capacity 464K, committed 512K, reserved 1048576K
```

### 예시 4: GC 중 사용자 스레드의 동시 실행 시간과 일시 정지 시간을 확인

```sql
java -Xlog:safepoint GCTest
```

```sql
[1.376s] [info] [safepoint] Application time: 0.3091519 seconds
[1.377s] [info] [safepoint] Total time for which application threads were
stopped: 0.0004600 seconds, Stopping threads took:
0.0002648 seconds
[2.386s] [info] [safepoint] Application time: 1.0091637 seconds
[2.387s] [info] [safepoint] Total time for which application threads were
stopped: 0.0005217 seconds, Stopping threads took:
0.0002297 seconds
```

### 예시 5: 컬렉터에서 제공하는 인간 공학 메커니즘의 자동 조절 관련 정보 확인

```sql
java -Xlog:gc+ergo*=trace GCTest
```

```sql
// 초기 Refine Zones 정보: green, yellow, red 영역 개수 및 최소 yellow size
[0.122s] [debug] [gc, ergo, refine] Initial Refinement Zones: green: 23, yellow: 69, red: 115, min yellow size: 46
// 힙 확장 요청: 요청된 크기 및 실제 확장된 크기
[0.142s] [debug] [gc, ergo, heap ] Expand the heap. requested expansion amount: 268435456B expansion amount: 2684354568
// GC(0) CSet 선택 시작: 대기 카드 수, 예측 기본 시간, 남은 시간, 목표 일시정지 시간
[2.475s] [trace] [gc,ergo,cset] GC (0) Start choosing CSet. pending cards: predicted base time: 10.00ms remaining time: 190.00ms target pause time: 200.00ms
// GC(0) Young 영역을 CSet에 추가: eden, survivor 개수 및 예측 시간
[2.476s] [trace] [gc,ergo,cset ] GC (0) Add young regions to CSet. eden: 24 regions, survivors: 0 regions, predicted young region time: 367.19ms, target pause time: 200.00ms
// GC(0) CSet 선택 완료: old 영역 개수, 예측 old 처리 시간, 남은 시간
[2.476s] [debug] [gc,ergo, cset ] GC (0) Finish choosing CSet. old: 0 regions, predicted old region time: 0.00ms, time remaining: 0.00
// GC(0) Clear Card Table Task 실행: 워커 수 및 처리 대상 영역 수
[2.826s] [debug] [gc, ergo ] GC (0) Running G1 Clear Card Table Task using 1 workers for 1 units of work for 24 regions.
// GC(0) Free Collection Set Task 실행: 워커 수 및 collection set 크기
[2.827s] [debug] [gc,ergo ] GC (0) Running G1 Free Collection Set using 1 workers for collection set length 24
// Refinement Zones 업데이트: 소요 시간, 버퍼 개수, 목표 시간
[2.828s] [trace] [gc, ergo, refine] GC (0) Updating Refinement Zones: update_rs time: 0.004ms, update_rs buffers: 0, update_rs goal time: 19.999ms
```

### 예시 6: 회수 후 남은 객체들의 나이 분포 확인

```sql
java -Xlog:gc+age=trace GCTest
```

```sql
// Desired survivor size: 1.5MB, new age threshold: 15 (최대 15)
[2.406s] [debug] [gc,age] GC (0) Desired survivor size 1572864 bytes, new threshold 15 (max threshold 15)
// Age table 설정 시점, threshold: 15 (max 15)
[2.745s] [trace] [gc,age] GC (0) Age table with threshold 15 (max threshold 15)
// age=1 세대 live 객체: 3.1MB (총 3.1MB)
[2.745s] [trace] [gc,age] GC (0) age 1: 3100640 bytes, 3100640 total
// Desired survivor size for GC(5): 2MB, age threshold 유지 15
[4.700s] [debug] [gc,age] GC (5) Desired survivor size 2097152 bytes, new threshold 15 (max threshold 15)
// GC(5) Age table 설정, threshold: 15 (max 15)
[4.810s] [trace] [gc,age] GC (5) Age table with threshold 15 (max threshold 15)
// GC(5) age=1 세대 live 객체: ~2.66MB (총 2.66MB)
[4.810s] [trace] [gc, age] GC (5) age 1: 2658280 bytes, 2658280 total
// GC(5) age=2 세대 live 객체: ~1.53MB, 누적 총 4.19MB
[4.810s] [trace] [gc,age] GC (5) age 2: 1527360 bytes, 4185640 total
```