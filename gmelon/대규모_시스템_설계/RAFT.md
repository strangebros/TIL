## 1. 개요 (Overview)

* **목적:** 서버 그룹이 일부 장애 상황에서도 동일한 상태(State)를 유지하도록 보장.
* **특징:** Paxos 대비 가독성과 이해도를 높인 설계. Leader 선출과 Log 복제 과정을 명확히 분리하여 관리함.
* **Consistency:** CAP 이론 중 **CP(Consistency & Partition Tolerance)** 시스템 지향.

## 2. 노드 상태 (Node States)

| 상태 | 설명 |
| --- | --- |
| **Follower** | 초기 상태. Leader의 메시지(Heartbeat) 수신 및 대기. 직접 요청 처리 불가. |
| **Candidate** | Election Timeout 발생 시 전환. 새로운 Leader가 되기 위해 투표 요청. |
| **Leader** | 모든 클라이언트 요청 수신 및 Log 복제 주도. 주기적 Heartbeat 전송. |

## 3. 리더 선출 (Leader Election)

### 3.1 Election Timeout

* Follower가 Leader로부터 Heartbeat를 받지 못한 채 대기하는 시간.
* **Randomized Timeout:** 각 노드는 약 150ms ~ 300ms 사이의 랜덤 값을 할당받음.
* **목적:** 여러 노드가 동시에 Candidate가 되어 투표가 갈리는 **Split Vote** 방지.

### 3.2 선출 과정

1. **Term** 증가: 타임아웃 발생 시 Candidate로 상태 전환 후 자신의 **Term** 번호를 높임.
2. 투표 요청: 자신에게 투표 후 타 노드에 `RequestVote RPC` 전송.
3. 승인: 과반수 이상의 찬성표를 얻으면 Leader로 등극.

## 4. 로그 복제 (Log Replication)

1. **로그 생성:** Leader가 클라이언트 명령어를 수신하여 로컬 로그에 추가 (Uncommitted).
2. **복제 요청:** `AppendEntries RPC`를 통해 모든 Follower에게 로그 복제 지시.
3. **Commit:** 과반수 Follower가 복제 성공 응답을 보내면 Leader는 로그를 **Commit**하고 상태 머신에 적용.
4. **전파:** 다음 RPC를 통해 Follower들에게 Commit 여부를 알리고, Follower들도 이를 반영.

## 5. 쿼럼(Quorum) 및 노드 구성

* **합의 조건:** 시스템 전체 노드 수 에 대해 최소 개의 찬성이 필요함.
* **홀수 구성의 이유:**
* 3대(1대 장애 허용)와 4대(1대 장애 허용)는 장애 허용 수준이 동일함.
* 짝수 구성 시 네트워크 파티션 상황에서 과반수를 확보하지 못할 확률이 높아져 가용성이 떨어짐.

## 6. 네트워크 오류 및 고립 노드 복구 시나리오

### 6.1 고립 노드의 Term 증가

* 특정 노드(E)가 고립되면 Leader의 Heartbeat를 받지 못해 지속적으로 **Term**을 높이며 선출을 시도함.

### 6.2 복구 및 기존 Leader 강등

* 고립되었던 노드 E가 복구되어 더 높은 **Term** 정보를 클러스터에 전파함.
* 기존 Leader는 자신보다 높은 **Term**을 확인하는 즉시 권위를 포기하고 **Follower로 강등**됨.

### 6.3 Election Restriction (안전 장치)

* E는 **Term**은 높지만, 고립 기간 동안 최신 로그를 복제받지 못함.
* 타 노드들은 투표 시 로그의 최신성을 비교하며, E의 로그가 자신보다 오래되었으므로 **투표를 거부**함.
* 결과적으로 클러스터는 최신 로그를 가진 노드를 다음 **Term**의 Leader로 선출함.

## 7. 로그 매칭 (Log Matching) 및 충돌 해결

### 7.1 Consistency Check

* Leader는 로그 전송 시 바로 이전 엔트리의 정보(`prevLogIndex`, `prevLogTerm`)를 포함함.
* Follower가 가진 정보와 일치하지 않으면 로그 복제를 거부함.

### 7.2 Conflict Resolution

1. **Backtracking:** 리더는 해당 Follower의 로그가 일치하지 않을 경우 `nextIndex`를 감소시키며 재시도.
2. **Matching Point 탐색:** 리더와 Follower의 로그가 일치하는 지점을 찾을 때까지 반복.
3. **Overwriting:** 일치 지점을 찾으면 그 이후의 Follower 로그를 리더의 로그로 강제 덮어쓰기하여 동기화함.