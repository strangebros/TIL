### 1) 상황
레거시 톰캣 기반 서비스에서 `context.xml`에 아래와 같은 `<Manager .../>` 설정이 존재했다.  
이 설정은 **Tomcat 세션을 로컬 메모리가 아닌 Redis(AWS ElastiCache)에 저장**하기 위한 구성이다.

- 즉, 다중 서버에서 같은 Tomcat 세션을 사용하기 위해 Redis에 저장해놓았다는 뜻이다.

### 2) 핵심 요약
- Tomcat은 기본적으로 세션을 **WAS 메모리(인스턴스 로컬)** 에 저장한다.
- 서버가 여러 대(로드밸런싱)거나 재기동/장애 시 세션 유지가 필요하면 **공유 세션 저장소**가 필요하다.
- 그래서 Tomcat의 Session Manager를 커스텀 구현체로 교체하여 **Redis에 세션을 저장/조회**하도록 한다.

### 3) 설정 코드 (요약)
- `className="com.crimsonhexagon.rsm.redisson.ElasticacheSessionManager"`
  - Tomcat 기본 세션 매니저 대신 **Redisson 기반 ElastiCache SessionManager** 사용
- `nodes="...:6379 ...:6379"`
  - Redis(ElastiCache) 접속 노드 목록

### 4) 주요 옵션 의미 (실무 관점)
- `sessionKeyPrefix="_www_"`
  - Redis에 저장되는 세션 키 prefix (다른 서비스와 충돌 방지)
- `ignorePattern=".*www\.(ico|png|gif|jpg|jpeg|swf|css|js)$"`
  - 정적 리소스 요청은 세션 접근/갱신 제외 → Redis I/O 감소, 성능 최적화
- `saveOnChange="false"`, `forceSaveAfterRequest="false"`, `dirtyOnMutation="false"`
  - “매 요청마다 세션 저장하지 말고 변경 시에만 저장” 성격의 튜닝 옵션  
  - 목적: Redis write/lock/네트워크 비용 감소
- `timeout="60000"`, `pingTimeout="1000"`, `retryAttempts="20"`, `retryInterval="1000"`
  - Redis 연결 장애/지연 대비 설정 (타임아웃 및 재시도)
- `masterConnectionPoolSize="100"`, `slaveConnectionPoolSize="100"`
  - Redisson 커넥션 풀 사이즈 (동시 요청 처리량 대응)
- `database="0"`
  - Redis 0번 DB 사용

### 5) 운영/장애 관점 체크 포인트 (중요)
- **세션 직렬화(Serialization)**: Redis에 저장하려면 세션 attribute가 직렬화 가능해야 함  
  - `NotSerializableException`류 에러가 흔함
- **Redis 연결 장애 시 영향**: 로그인/세션 조회가 Redis에 의존 → Redis 장애는 곧 서비스 장애로 이어질 수 있음
- **TTL/만료 정책**: 세션 만료가 Tomcat 설정과 Redis TTL이 일치하는지 확인 필요
- **LB Sticky Session 여부**: Redis 세션 공유면 Sticky를 꼭 쓰지 않아도 되지만, 정책 혼재 시 디버깅이 어려움

### 6) 결론
이 `context.xml` 설정은 **Tomcat 다중 인스턴스/운영 환경에서 세션 공유 및 유지**를 위해  
**Redis(AWS ElastiCache) 기반 세션 스토어**를 사용하도록 세션 매니저를 교체한 구성이다.
``
