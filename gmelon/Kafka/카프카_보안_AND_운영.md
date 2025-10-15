# 11 보안

## 11.4 암호화

### 개요

- **암호화 목적**: 데이터의 기밀성과 무결성 보장.
- **TLS를 활용한 전송 계층 암호화**:
    - SSL/SASL_SSL 리스너는 TLS를 사용함.
    - 안전하지 않은 네트워크에서 데이터 보호를 위한 암호화 채널 사용 가능.
    - **TLS 스위트 제한**: 보안 강화 또는 FIPS 준수를 위해 제한 가능성 있음.
- **디스크 암호화를 통한 물리적 접근 보호**:
    - 로그 저장 디스크 물리적 접근으로부터 민감 데이터 보호 조치 필요함.
    - 디스크 도난 방지를 위해 전체 디스크 암호화 또는 볼륨 암호화 사용 필요.
- **플랫폼 운영자 접근 통제 및 종단 암호화 필요성**:
    - 전송/저장소 암호화만으로 운영자 자동 접근 권한 부여 문제 해결 어려움.
    - 브로커 메모리 잔존 데이터나 디스크 저장 로그는 운영자가 직접 열람 가능함.
    - 클라우드 환경에서 플랫폼 운영자 접근을 막기 위해 **종단 암호화(E2EE)** 구현 필수.
    - 커스텀 암호화 제공자를 클라이언트에 플러그인 형태로 설정하여 구현 가능.

### 11.4.1 종단 암호화

![image.png](attachment:645be895-51a7-40d9-ab1e-61d8b79f4355:image.png)

- **시리얼라이저/디시리얼라이저를 활용한 암호화/복호화**:
    - 프로듀서 시리얼라이저는 메시지를 바이트 배열로 변환함.
    - 컨슈머 디시리얼라이저는 바이트 배열을 다시 메시지로 변환함.
    - 시리얼라이저/디시리얼라이저 내에서 암호화/복호화 수행 가능.
- **대칭 암호화 알고리즘 및 KMS**:
    - 메시지 암호화는 AES 등 대칭 알고리즘 사용, 키 관리 시스템(KMS)으로 수행됨.
    - KMS에 공유 키 저장으로 프로듀서는 암호화, 컨슈머는 복호화 수행.
    - **클라우드 환경 안전성**: 브로커는 키 접근 불필요, 원본 메시지 미확인으로 안전함.
- **암호화 매개변수 및 디지털 서명**:
    - 복호화에 필요한 매개변수는 메시지 헤더 또는 본체에 저장 가능.
    - 무결성 확인을 위해 디지털 서명 메시지 헤더에 첨부 가능.
- **종단 암호화 데이터 흐름**:
    - **프로듀서**: KMS 키로 메시지 암호화 후 브로커에 저장.
    - **컨슈머**: 브로커서 수신 후 KMS 키로 메시지 복호화.
    - **자격 증명**: 프로듀서/컨슈머는 KMS 공유 키 수신 자격 증명 설정 필요.
- **보안 강화 조치: 키 회전(Key Rotation)**:
    - 주기적 키 회전으로 보안 사고 시 위조 메시지 유입 감소 및 공격 방어 가능.
    - 메시지 보존 기한 동안 이전/새 키 모두 사용 가능하도록 시스템 유지 필요.
    - 대부분 KMS가 이전 키 사용 기간을 기본 제공하므로 클라이언트 특별 처리 불필요.
    - **압축 토픽 처리**: 압축 토픽의 경우, 재암호화 중 프로듀서/컨슈머 연결 차단 필요.

## 11.5 인가

### 개요

- **인가의 정의**: 사용자가 자원에 대해 수행 가능한 작동을 결정하는 절차임.
- **카프카의 접근 제어 방식**:
    - 커스터마이즈 가능한 권한 부여자(authorizer) 사용해 브로커 접근 제어.
    - 클라이언트 연결 시 브로커는 신원(`KafkaPrincipal`)을 결부시킴.
    - 요청 처리 시 연결된 보안 주체의 권한 보유 여부 검증.
- **기본 권한 부여자**:
    - 카프카는 `AclAuthorizer`를 기본 권한 부여자 제공.

### 11.5.1 AclAuthorizer

- **ACL(Access Control List)의 작동 방식**:
    - `AclAuthorizer`는 ACL을 사용해 자원 접근을 세밀하게 제어함.
    - ACL은 주키퍼에 저장되며, 빠른 인가를 위해 브로커 메모리에 캐시됨.
    - ACL은 주키퍼 와처 알림으로 최신값 유지.
- **ACL 설정 요소**: 각 ACL 설정은 다음 요소로 구성됨.
    - **자원 유형**: DelegationToken, Cluster, Topic, Group, TransactionalId.
    - **패턴 유형**: Literal, Prefixed, 와일드카드(*).
    - **작업**: DescribeConfigs, Describe, Create, Delete, Alter, Read, Write, AlterConfigs.
    - **권한 유형**: Allow, Deny (Deny가 Allow보다 우선).
    - **주체**: `<유형>:<이름>` 형태 (예: User:Bob).
    - **호스트**: 클라이언트 IP 주소 또는 와일드카드(\\*).
- **ACL 허가 규칙**:
    - 일치하는 Deny가 없고 1개의 허가 ACL이 설정된 경우 작동 허가됨.
    - **암묵적 부여**: Write/Alter/Read/Delete 부여 시 Describe 권한 암묵적 부여.
    - **와일드카드 ACL**: 와일드카드 자원 이름은 해당 패턴 유형/자원 유형의 모든 이름에 일치 취급.

### 카프카 요청별 ACL 적용 및 권한 관리

- **브로커 및 컨트롤러 요청**:
    - 브로커는 Cluster:ClusterAction 권한 부여 필요.
- **프로듀서 요청**:
    - 토픽 생성 시: Topic:Write 권한 필요. 멱등 사용 시 Cluster:IdempotentWrite 권한 필요.
    - 트랜잭션 사용 시: TransactionalId:Write 권한 필요.
- **컨슈머 요청**:
    - 메시지 읽기: Topic:Read 권한 필요.
    - 그룹 접근/오프셋 커밋: Group:Read 권한 필요.
- **관리 작업 요청**:
    - **토픽 생성**: Cluster:Create 또는 Topic:Create 권한.
    - **ACL/레플리카/파티션 재할당 변경**: Cluster:Alter 또는 AlterConfigs 사용.
    - **조회**: Cluster:Describe 또는 Group:Describe 사용.
    - **토픽 삭제**: Topic:Delete 권한.
    - **파티션 생성/설정 변경**: Topic:Alter 또는 Topic:AlterConfigs 권한.

### 11.5.2 인가 기능 커스터마이즈 및 확장

- **커스텀 인가 관리자 구현**:
    - 인가 기능 커스터마이즈로 RBAC 설정 또는 추가 접근 제한 추가 가능.
    - **예시: 내부 관리자 커스텀 권한 관리자**: 특정 내부 리스너 요청만 제한하는 커스텀 Authorizer 구현 가능.
- **외부 시스템 통합을 통한 접근 제어 지원**:
    - 그룹/역할 기반 접근 제어에 통합 가능.
    - LDAP 등 외부 서버에서 보안 주체/역할 그룹을 주기적으로 가져와 ACL 생성 지원.
    - **예시: RBAC Authorizer 구현**: 사용자가 속한 그룹/역할을 외부 저장소에서 가져와 권한 확인에 활용.
        - Deny 미지원에 주의 필요.
- **그룹/역할 기반 ACL 부여**: 카프카 툴 사용해 그룹이나 역할에 대한 ACL 부여 가능.
    - **예시 1 (그룹 기반 ACL)**: `Group:Sales`에 `customer`로 시작하는 모든 토픽 producer 권한 부여.

### 11.5.3 인가 설정 시 고려사항

- **주키퍼 접근 보안**: `AclAuthorizer`가 ACL을 주키퍼에 저장하므로 주키퍼 접근 제한 필수.
- **PREFIXED 패턴 유형 활용**:
    - 사용자가 많은 조직에서 고유 자원 접두어 사용 시 필요한 ACL 수 감소 가능.
- **최소 권한 원칙**:
    - 사용자에게 최소 접근 권한만 부여해 보안 주체 노출 감소.
    - 필요 없는 ACL은 즉시 제거 필요.
- **자격 증명 유효성 관리**:
    - ACL은 사용되지 않을 경우(퇴사 등) 즉시 제거되어야 함.

## 11.6 감사

### 감사 및 디버깅을 위한 로그 설정

- **카프카 브로커 로깅 설정**:
    - 감사/디버깅 목적으로 상세 로그 생성하도록 브로커 설정 가능.
- **감사 목적의 로거**:
    - `kafka.authorizer.logger`와 `kafka.request.logger` 로거에 대해 레벨/보존 기한 별도 설정 필요.
- **권한 관리자 로그 레벨**:
    - 거부된 접근: INFO 레벨, 성공한 접근: DEBUG 레벨 로그 기록.
    - **예시 (거부된 Describe)**: `Principal User:Mallory is Denied Operation Describe ... (kafka.authorizer.logger)`
- **요청 로깅 상세도**:
    - 요청 로깅을 TRACE 레벨로 설정 시 전체 요청 세부 사항 확인 가능.

### 감사 로그의 활용 및 메타데이터 무결성

- **보안 위협 탐지**: 권한 관리자 및 요청 로그 분석으로 인증 실패 지표나 의심 행동 탐지 가능.
- **메시지 감사 가능성 및 무결성**:
    - 메시지 생성 시 감사 메타데이터를 헤더에 추가해 종단 감사 가능성 및 메타데이터 무결성 보장 가능.

### 동적으로 로깅 레벨 변경하기

- **로그 레벨 동적 변경 필요성**: `log4j` 설정 변경은 브로커 재시작 부담이 있으나, 카프카는 로깅 레벨 동적 변경 기능 제공.
- `kafka-configs.sh` 툴 활용:
    - 툴을 사용해 특정 브로커 로깅 레벨 동적 변경 가능

## 11.7 주키퍼 보안

### 11.7.1 SASL

- **주키퍼의 중요성**: 카프카 클러스터 가용성에 필수적인 메타데이터 저장으로 보안 조치 필요.
- **SASL 인증 메커니즘 지원**:
    - 주키퍼는 SASL/DIGEST-MD5 및 SASL/GSSAPI (케르베로스) 지원.
    - 주키퍼 3.5.0부터 TLS 암호화 지원 추가로, 프로덕션 환경에서는 TLS 암호화와 함께 반드시 사용되어야 함.
- **JAAS 설정**:
    - 주키퍼 SASL 설정은 `java.security.auth.login.config` 속성을 사용해 JAAS 설정 파일 지정.
- **케르베로스 설정 예시 (주키퍼 서버)**:
    - 서버 인증 활성화 시 주키퍼 설정 파일에 SASL 인증 제공자 설정 필요.
    - 주키퍼 인가 활성화 시, 모든 브로커가 동일 보안 주체를 갖도록 특정 설정 필요.

### 11.7.2 SSL

- **SSL 인증 기능**:
    - 주키퍼 SSL은 SASL과 달리 클라이언트 인증 포함하여 어느 쪽에서든 인증 가능.
- **주키퍼 서버 SSL 설정**:
    - 서버에 SSL 설정 시 서버 호스트명으로 키스토어/트러스트스토어 설정 필요.
    - 클라이언트 인증서 검증 시 클라이언트 인증 역시 필요.
- **카프카 브로커 SSL 설정**:
    - 브로커에서 주키퍼 인증서 검증을 위해 카프카에서 주키퍼로의 SSL 설정 필요.

### 11.7.3 인가

- **주키퍼 노드 ACL 설정**:
    - 브로커 설정 노드에 `zookeeper.set.acl=true` 설정으로 주키퍼 노드 ACL 설정 가능.
    - 기본적으로 브로커만 해당 노드 내용 읽기 가능.

## 11.8 플랫폼 보안

### 개요

- **위협 모델 고려**:
    - 보안 설계 시 개별 요소 위협뿐 아니라 전체 시스템 위협 모델 고려 필요.
- **내부 위협의 중요성**: 잠재적 위협 평가 시 외부 위협만큼 내부 위협 고려 중요.
- **네트워크 및 물리적 저장소 보호**:
    - 인증, 인가, 암호화 외에 전체 플랫폼 보호를 위해 방화벽 또는 물리적 저장소 보호 암호화 추가 조치 필요할 수 있음.
- **자격 증명 파일 보호**:
    - 인증에 사용되는 자격 증명 파일은 파일 시스템 권한으로 보호되어야 함.
- **설정 파일 접근 제한**:
    - 보안 중요 정보 저장 설정 파일 접근 제한 필요.

### 11.8.1 비밀번호 보호

- **커스텀 설정 제공자 설정**:
    - 커스터마이즈 가능한 설정 제공자(ConfigProvider) 설정으로 안전한 서드 파티 저장소에서 비밀번호 가져오기 가능.
- **GPGProvider 예시**: 파일 저장된 설정을 GPG 사용해 복호화하는 커스텀 설정 제공자 예시.
    - `get(String path)` 메서드에서 `gpg --decrypt --passphrase` 명령 실행하여 복호화 수행.
- **GPG를 사용한 자격 증명 파일 암호화**:
    - `gpg --symmetric` 명령으로 파일 암호화 후, 클라이언트 설정에서 참조 형식으로 구성 가능.
- **민감한 브로커 설정 옵션 보호**:
    - 민감한 브로커 설정 옵션은 커스텀 제공자 없이 카프카 설정 툴 사용해 주키퍼에 암호화 형태로 저장 가능.
    - **예시 (SSL 키스토어 비밀번호 저장)**:

```bash
$ bin/kafka-configs.sh --zookeeper localhost:2181 --alter \
            --entity-type brokers --entity-name 0 --add-config \
            listener.name.external.ssl.keystore.password=server-kspassword,password.encoder.secret=encoder-secret
```

- 이 값 복호화를 위해 암호화에 사용된 비밀(secret)이 각 브로커 설정 파일에 포함되어야 함.

# 12 카프카 운영하기

## 12.1 토픽 작업

- `kafka-topics.sh` 툴을 통해 토픽 생성, 조회, 변경, 삭제를 쉽게 수행함.
- 토픽 설정 조회 및 변경 기능 일부 제공함.

### 12.1.1 새 토픽 생성하기

- **필수 인수**: 토픽 이름(`-topic`), 레플리카 개수(`-replication-factor`), 파티션 개수(`-partitions`) 지정 필요함.
- **토픽 이름 규칙**:
    - 허용 문자: 영문, 숫자, 마침표(`.`) 사용 가능함.
    - 권장하지 않는 이름: 마침표(`.`) 사용 시 내부 변환으로 충돌 가능성 있음. `_`로 시작하는 이름은 내부 토픽과 혼동 방지를 위해 권장하지 않음.
- **생성 명령 예시**: 8개 파티션, 2개 레플리카 'my-topic' 생성 예시.

```
bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --partitions 8 --topic my-topic --replication-factor 2
```

- 성공 시 `Created topic "my-topic".` 출력됨.
- **인수 주의**: `-if-not-exists`는 자동화에 유용함. `-if-exists --alter` 조합 사용은 토픽 부재 시 문제 인지 불가로 권장하지 않음.

### 12.1.2 토픽 목록 조회하기

- **전체 목록 조회**: `-list` 옵션 사용. 결과는 순서 없이 한 줄에 하나씩 나열됨.

```
bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

- **내부 토픽 제외**: `-exclude-internal` 옵션으로 `_`로 시작하는 내부 토픽 제외 가능함.

### 12.1.3 상세 토픽 내역 조회하기

- **상세 정보 조회**: `-describe` 옵션 사용. 파티션 수, 설정, 레플리카 할당 등 포함됨. 특정 토픽 조회 시 `-topic` 지정.

```
bin/kafka-topics.sh --boostrap-server localhost:9092 --describe --topic my-topic
```

- **출력 필터링 옵션**: 문제 찾기에 유용함.
    - `-list-topics-with-overrides`: 기본값 재정의 토픽 목록 표시.
    - `-exclude-internal`: 내부 토픽 제외.
    - `-under-replicated-partitions`: URP(불완전 복제 파티션) 표시.
    - `-at-min-isr-partitions`: 최소 ISR 레플리카 수를 가진 파티션 표시.
    - `-under-min-isr-partitions`: 최소 ISR 미달 파티션 표시 (사실상 읽기 전용 모드).
    - `-unavailable-partitions`: 오프라인 상태인 심각한 파티션 표시 (리더 없음).

### 12.1.4 파티션 추가하기

- **증가 이유**: 처리량 수평 확장 및 컨슈머 활용 증대를 위함임.
- **증가 명령 예시**: 'my-topic' 파티션 수를 16개로 증가시킴.

```
bin/kafka-topics.sh --bootstrap-server localhost:9092 --alter --topic my-topic --partitions 16
```

- **키 메시지 주의**: 키가 있는 토픽은 파티션 수 변경 시 키 대응 파티션이 달라져 컨슈머에 어려움 발생. 생성 시 파티션 개수 사전 확정 권장.

### 12.1.5 파티션 개수 줄이기

- **감소 불가**: 토픽 파티션 개수는 줄일 수 없음.
- **권장 방법**: 토픽 삭제 후 재 생성하거나, 새 버전 토픽 생성 후 트래픽 이전 권장.

### 12.1.6 토픽 삭제하기

- **필요성**: 불필요한 토픽은 자원 소모 및 성능 하락 유발.
- **설정**: 삭제를 위해 브로커 `delete.topic.enable` 옵션이 `true`여야 함.
- **작업 특성**: 토픽 삭제는 비동기 작업임. 컨트롤러 정리 작업량에 따라 시간 소요됨.
- **주의**: 동시 삭제 지양. 삭제는 되돌릴 수 없는 작업임.
- **삭제 명령 예시**:

```
bin/kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic my-topic
```

- **확인**: `-list` 또는 `-describe`로 토픽 존재 여부 확인.

## 12.2 컨슈머 그룹

- 컨슈머 그룹 관리를 위해 `kafka-consumer-groups.sh` 툴 사용.
- 그룹 목록 조회, 상세 내역 조회, 삭제, 오프셋 초기화 등에 사용됨.

### 12.2.1 그룹 및 컨슈머 목록 상세 내역 조회하기

- **그룹 목록 조회**: `-list` 옵션 사용.

```
bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list
```

- **상세 정보 조회**: `-describe`와 `-group` 매개변수 추가. 컨슈머 위치(오프셋) 정보 포함.

```
bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group my-consumer
```

- **출력 필드**: GROUP, TOPIC, PARTITION, CURRENT-OFFSET (컨슈머 위치), LOG-END-OFFSET (브로커 오프셋), LAG, CONSUMER-ID, HOST, CLIENT-ID 포함.

### 12.2.2 컨슈머 그룹 삭제하기

- **그룹 삭제**: `-delete` 사용 시 그룹 내 모든 오프셋 포함 정보 삭제됨.
- **조건**: 비 활동 중인 멤버가 없는 상태여야 함. 비어있지 않은 그룹 삭제 시 에러 발생.
- **예시**: 'my-consumer' 그룹 삭제.

```
bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --delete --group my-consumer
```

### 12.2.3 오프셋 관리

- 오프셋 조회/삭제 외에, 메시지 재처리를 위해 오프셋 리셋 가능함.

### 오프셋 내보내기

- `-reset-offsets --dry-run --export` 사용 시 현재 오프셋을 CSV 파일로 내보냄.
- **CSV 형식**: `{토픽 이름},{파티션 번호},{오프셋}`.
- **경고**: `-dry-run` 없이 실행 시 오프셋 완전 리셋됨.

### 오프셋 가져오기

- **기능**: 내보내기 작업의 반대로, 현재 오프셋을 설정하는 데 사용됨.
- **주의**: 오프셋 가져오기 전 그룹 내 모든 컨슈머 중단 필수. (컨슈머가 새 오프셋을 덮어쓸 수 있음)
- **예시**: `offsets.csv` 파일로부터 오프셋 가져오기.

```
kafka-consumer-groups.sh --bootstrap-server localhost:9092 --reset-offsets --group my-consumer \
              --execute --from-file offsets.csv
```

## 12.3 동적 설정 변경

- `kafka-configs.sh`로 클러스터 재시작 없이 설정 동적 수정 가능함.
- 재정의 가능한 범주(entity-type)는 토픽, 브로커, 클라이언트 4가지임.

### 12.3.1 토픽 설정 기본값 재정의하기

- **기능**: 클러스터 단위 기본값을 재정의하여 토픽별 동적 설정 변경 가능함.
- **명령 형식**:

```
bin/kafka-configs.sh --bootstrap-server localhost:9092 --alter --entity-type topics \
          --entity-name {토픽 이름} --add-config {key}={value}[,{key}={value}...]
```

- **예시**: `my-topic` 보존 기한 1시간 설정.

```
bin/kafka-configs.sh --bootstrap-server localhost:9092 --entity-type topics \
          --entity-name my-topic --alter --add-config retention.ms=3600000
```

- **동적 토픽 키**: `cleanup.policy`, `compression.type`, `retention.ms` 등 다수 존재함.

### 12.3.2 사용자/클라이언트 설정 기본값 재정의하기

- **설정 항목**: 주로 쿼터 관련 설정(예: `bytes/sec` 속도)이 일반적임.
- **스로틀링 주의**: 파티션 리더 역할 불균등 시 브로커 단위 스로틀링으로 인해 전체 속도가 제한될 수 있음.
- **클라이언트 ID**: 컨슈머 그룹 ID와 같을 필요 없으나, 그룹 식별 값으로 설정 시 쿼터 공유 및 로그 추적 용이함.

### 12.3.3 브로커 설정 기본값 재정의하기

- **기능**: 클러스터 설정 파일 외에 브로커에 대해 재정의 가능한 항목 80개 이상 존재함.
- **주요 설정**: `min.insync.replicas`, `unclean.leader.election.enable` (데이터 유실 가능성 고려), `max.connections` 등.

### 12.3.4 재정의된 설정 상세 조회하기

- **조회**: `-describe` 명령으로 재설정된 설정값 확인 가능함.

```
bin/kafka-configs.sh --bootstrap-server localhost:9092 \
                  --entity-name my-topic --describe --entity-type topics
```

- **주의**: 재정의된 값만 보여주며, 기본값은 포함하지 않음.

### 12.3.5 재정의된 설정 삭제하기

- **삭제**: `-delete-config`와 `-alter` 사용 시 설정이 클러스터 기본값으로 복귀됨.
- **예시**: `my-topic`의 `retention.ms` 재정의 삭제.

```
bin/kafka-configs.sh --bootstrap-server localhost:9092 --entity-type topics \
          --alter --entity-name my-topic --delete-config retention.ms
```

## 12.4 쓰기 작업과 읽기 작업

- 두 유틸리티는 자바 클라이언트 라이브러리를 감싸 애플리케이션 없이 토픽과 상호작용 가능하게 함.

### 12.4.1 콘솔 프로듀서

- **기본 작동**: 토픽에 메시지 쓰기 가능함. 메시지는 줄 단위, 키/밸류는 탭 문자 기준으로 구분됨. 기본 시리얼라이저 사용.
- **필수 인수**: `-bootstrap-server`와 `-topic` 지정 필요함.
- **종료**: Ctrl + D (EOF)로 종료 가능함.
- **설정 옵션**: `-producer.config` 또는 `-producer-property` 사용.
    - 자주 쓰이는 옵션: `-batch-size`, `-request-timeout-ms`, `-compression-codec`, `-sync`.
- **읽기 옵션**: `LineMessageReader` 클래스 옵션 사용 가능함.
    - `key.separator` (기본 탭 문자), `parse.key` 등 설정 가능.
- **작동 변경**: `-line-reader` 옵션으로 커스텀 `MessageReader` 클래스 지정 가능함.

### 12.4.2 콘솔 컨슈머

- **기본 작동**: 1개 이상 토픽에서 메시지 읽어와 표준 출력에 한 줄씩 출력함.
- **필수 인수**: 읽을 토픽, 연결 정보 지정 필요함.
- **버전 확인**: 오래된 버전 컨슈머 사용 시 클러스터 피해 가능성 있어 버전 확인 중요함.
- **연결**: `-bootstrap-server` 사용. 토픽 지정은 `-topic` 또는 정규식 `-whitelist` 중 하나만 사용.

```
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
                  --whitelist 'my.*' --from-beginning
```

- **설정 옵션**: `-consumer.config` 또는 `-consumer-property` 사용.
    - 자주 쓰이는 옵션: `-formatter`, `-from-beginning`, `-max-messages`, `-offset` 등.
- **포매터**: 기본값 외 `LoggingMessageFormatter`, `ChecksumMessageFormatter`, `NoOpMessageFormatter` 사용 가능.
- **DefaultMessageFormatter 옵션**: 타임스탬프, 키, 오프셋, 파티션 표시 여부 설정 가능.
- **디시리얼라이저**: `Deserializer` 구현 클래스를 지정하여 키/밸류 변환 가능함.
- **내부 토픽 확인**: 컨슈머 오프셋 확인 시 내부 토픽(`__consumer_offsets`)을 `-formatter "kafka.coordinator.group.GroupMetadataManager$OffsetsMessageFormatter"`와 함께 읽어옴.

## 12.5 파티션 관리

- 파티션 관리를 위한 스크립트 기본 탑재되어 있음.
- 브로커 간 메시지 트래픽 균형 맞출 때 유용

### 12.5.1 선호 레플리카 선출

- **리더 중요성**: 각 파티션은 리더 레플리카를 통해 쓰기/읽기 작업 수행함.
- **부하 분산**: 모든 브로커에 리더 레플리카를 고르게 분산할 필요 있음.
- **리더 인계**: 리더 장애 시 다른 ISR이 인계받으나, 복구된 브로커로 자동 복구되지는 않음.
- **자동 밸런싱**: `automatic.leader.balancing` 기능이 꺼져 있으면 불균형 발생 가능. 해당 기능 켜거나 외부 툴 사용 권장.
- **선출**: 불균형 시 선호 레플리카 선출 실행 가능함. 클러스터에 영향 미미한 가벼운 작업임.
- **툴 사용**: 구버전 `kafka-preferred-replica-election.sh` 대신 `kafka-leader-election.sh` 사용 권장됨.
- **명령 예시 (전체)**:

```
bin/kafka-leader-election.sh --bootstrap-server localhost:9092 --election-type PREFERRED --all-topic-partitions
```

- **명령 예시 (특정)**: `-topic` 또는 JSON 파일(`partitions.json`)로 파티션 목록 지정 가능함.

### 12.5.2 파티션 레플리카 변경하기

- **필요 경우**: 브로커 간 부하 불균등, 불완전 복제 시, 신규 브로커 분산 시, 복제 팩터 변경 시 사용됨.
- **툴 단계**: 파티션 목록 생성, 재할당 실행, 진행 상황 확인 3단계로 나뉨.
- **목록 생성**: 토픽 목록 JSON 파일(`topics.json`)을 `-broker-list`와 함께 `-generate` 실행하여 재할당 안 파일(`expand-cluster-reassignment.json`) 생성.
- **재할당 실행**: `-execute` 옵션으로 재할당 안 실행. 컨트롤러가 새 레플리카에 데이터 복사 후 오래된 레플리카 제거함.
- **추가 옵션**: `-throttle <bytes_per_second>`로 디스크/네트워크 I/O 제한 가능함.
- **브로커 격하 권장**: 브로커 해제 전 수동으로 리더 역할 해제 권장됨.
- **진행 상태 확인**: `-verify` 옵션으로 재할당 진행 상태 확인 가능함.

### 복제 팩터 변경하기

- `kafka-reassign-partitions.sh`로 RF 증가/감소 가능함.
- **예시 (RF 증가)**: JSON 파일에 원하는 레플리카 목록을 명시하여 RF를 2에서 3으로 증가시킴.

```json
{
                  "version": 1,
                  "partitions": [
                    { "topic": "foo1", "partition": 1, "replicas": [5, 6, 4] },
                    // ...
                  ]
                }
```

- `-describe`로 RF 증가 확인 가능함.

### 레플리카 재할당 취소하기

- **개선**: 현재 스크립트는 `-cancel` 옵션을 지원함.
- **기능**: 진행 중인 파티션 이동 중단시킴. 취소 시 원치 않는 상태에 빠질 수 있음.

### 12.5.3 로그 세그먼트 덤프 뜨기

- **기능**: 컨슈머가 처리 못하는 오염된 메시지(포이즌 필) 확인 시 유용함. 로그 파일 직접 열어봄.
- **위치**: `/tmp/kafka-logs/<topic-name>-<partition>` 디렉토리에 저장됨.
- **메타데이터 출력 예시**:

```
bin/kafka-dump-log.sh --files /tmp/kafka-logs/my-topic-0/00000000000000000000.log
```

- **실제 데이터 포함 출력**: `-print-data-log` 옵션 추가 시 payload, `keysize`, `valuesize` 등 포함 출력됨.
- **인덱스 검증**: `-index-sanity-check` 또는 `-verify-index-only` 사용 가능함.

### 12.5.4 레플리카 검증

- **기능**: 모든 레플리카 메시지 읽어와 내용 동일성 확인 및 최대 랙 값 출력함. 취소될 때까지 루프 실행됨.
- **사용**: `-broker-list`로 브로커 목록 지정 필요함.
- **주의**: 레플리카 검증은 클러스터에 영향을 주므로 주의해서 사용해야 함.

## 12.6 기타 툴

- 배포판에 포함된 기타 툴들 존재함. 공식 웹사이트에서 상세 정보 확인 가능함.
- `kafka-acls.sh`: 클라이언트 접근 제어 관리 툴.
- `kafka-mirror-maker.sh`: 경량 데이터 미러링용 스크립트.
- **테스트 툴**: API 호환성 확인(`kafka-broker-api-versions.sh`), 벤치마크, 주키퍼 관리, `trogdor` 수행 스크립트 포함.

## 12.7 안전하지 않은 작업

- 극단적 상황 외 시도되지 말아야 할 안전하지 않은 작업들 존재함.
- 이 작업들은 주키퍼 메타데이터 직접 다루는 경우가 많아 극도로 주의 필요함.

### 12.7.1 클러스터 컨트롤러 이전하기

- **컨트롤러 역할**: 클러스터 감독하며 주키퍼 Ephemeral 노드로 자동 선출됨.
- **강제 이전**: 오작동 시 유용하며, 주키퍼 `/admin/controller` 노드 수동 삭제로 기존 컨트롤러 역할 해제 가능함. 특정 브로커 지정 이전은 불가능함.

### 12.7.2 삭제될 토픽 제거하기

- **정상 삭제**: 주키퍼 노드 생성 후 레플리카 삭제 완료 시 노드 삭제됨.
- **멈춤 상황**: 삭제 기능 꺼짐 토픽 시도 또는 레플리카 장애로 삭제 작업 미완료 시 발생.
- **멈춤 해제**: 주키퍼에서 `/admin/delete_topic/{topic}` 노드 삭제.

### 12.7.3 수동으로 토픽 삭제하기

- **필요성**: 삭제 기능 꺼짐 클러스터 운영 시 수동 삭제 가능함.
- **위험**: 클러스터 작동 중 주키퍼 메타데이터 수정은 매우 위험함.
- **단계**: 모든 브로커 내림 -> 주키퍼 `/brokers/topics/{topic}` 자식 노드 삭제 -> 각 브로커 로그 디렉토리 파티션 디렉토리 삭제 -> 모든 브로커 재시작.