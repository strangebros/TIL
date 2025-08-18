## ❓ 궁금증

이제 Nextstep의 `ATDD in Legacy Code` 강좌 시작이 열흘 정도 남았습니다.

그 동안, 테스트에 대해 경험이 없는 제가 조금이라도 테스트 코드나 방식에 익숙해 질 수 있도록, 개념과 실습을 통해 공부를 진행해보려고 합니다.

우선 해당 문서에는 테스트에 대한 개념부터 정리하고 가겠습니다.

<br />

## Spring 테스트 개념 정리

### 테스트의 목적

- 안전망(Safety Net): 코드 변경 시 기존 기능이 깨지지 않았는지 확인
- 리팩토링 자신감: 코드 구조 개선할 때 불안감 최소와
- 문서화 역할: 테스트 메서드 이름이 곧 명세 -> "이 메서드는 이렇게 동작해야 한다"라는 문서 역할

<br />

### Spring에서 사용하는 테스트 종류

1. 단위(Unit) 테스트
    - 특정 클래스/메서드만 검증
    - 일부 의존성(Mock) 제거
    - 빠르고 간단
    - 예: `UserService.register()`에서 "중복 이름이면 예외 발생" 확인
2. 통합(Integration) 테스트
    - Spring Context(Bean, DB 등)까지 띄움
    - 실제 환경에 가까움
    - 느리지만, 레이어 간 연결 검증
    - 예: Controller -> Service -> Repository 흐름이 정상 동작하는지 확인

<br />

### JUnit과 Spring Test

- JUnit5: 기본적인 자바 테스트 프레임워크
    - `@Test`, `@BeforeEach`, `@AfterEach`
    - Assertions (`assertEquals`, `assetThrows`, `assertThat`)
- Spring Boot Test 지원
    - `@SpringBootTest`: 애플리케이션 전체 구동 (통합 테스트)
    - `@WebMvcTest`: Controller 레이어만 테스트
    - `@DataJpaTest`: Repository(JPA)만 테스트
    - `@MockBean`: 스프링 컨텍스트에 등록된 Bean을 Mock으로 교체

<br />

### 테스트에서 자주 쓰는 도구

| 도구명 | 설명 |
| --- | --- |
| Mockito | 가짜 객체(Mock)를 만들어 의존성 대체 |
| MockMvc | HTTP 요청/응답 시뮬레이션 |
| AssertJ | 읽기 좋은 단언문(`assertThat(xx).isEqualTo(yy)`)
| H2 DB | 내장형 데이터베이스, Repository 테스트용 |

<br />

### 좋은 테스트의 조건

- 독립적: 테스트까리 서로 의존하지 않음.(순서 무관)
- 빠름: 실행이 느림녀 작성/유지보수 부담 증가
- 명확한 이름: `회원가입_성공()`이 `test1()`보다 나음
- Given-When-Then 구조: Given(준비) -> When(실행) -> Then(검증)

<br />

### Spring Test가 제공하는 이점

- 스프링 컨텍스트 자동 관리 -> 필요한 Bean 로딩/주입
- DB 자동 롤백(`@DataJpaTest` 기본) -> 테스트 후 데이터 깨끗
- MockMvc -> 실제 서버 띄우지 않고 API 테스트 가능
