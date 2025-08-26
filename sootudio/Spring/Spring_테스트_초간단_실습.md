## 개요

Spring의 테스트 기능을 사용해볼 수 있는 실습을 하려고 합니다.
원래는 새로운 프로젝트를 만들어서 시험해 볼 생각이였으나, 워키라는 좋은 교보재(?) 가 있어서 그걸 사용하면 될 것 같다는 생각이 들었습니다.

기본적으로 아래와 같은 항목들에 대해서 테스트 코드를 짜보려고 합니다.

#### 0. 공통 세팅
#### 1. JUnit 단순 메소드 테스트
#### 2. Spring Context 로딩 테스트
#### 3. Repository 계층 테스트(DB 연동)
#### 4. Service 계층 단위 테스
#### 5. Controller 계층 (웹 API) 테스트
#### 6. 통합 테스트

<br />

## 0. 공통 세팅
Spring에서 테스트를 진행하려고 할 경우, 아래와 같은 도구들을 사용합니다.

### 1. JUnit5 (테스트 프레임워크)
- 자바 진영에서 가장 많이 쓰는 단위 테스트 프레임워크
- `@Test`, `@BeforeEach`, `@AfterEach`, `@DisplayName`, `@Nested` 등 제공
- 테스트 실행 엔진 (Jupiter) 기반으로 돌아감
 
### 2. Assertions / AssertJ
- 테스트 결과를 검증하는 라이브러리.
- `assertEquals`, `assertThrows` 같은 JUnit 기본 Assertion 외에, `asserThat(...).isEqalTo(...)` 같은 가독성 좋은 체이닝 문법을 제공.

### 3. Mockito(Mock 라이브러리)
- Service 계층 단위 테스트에서 DB/외부 의존성을 가짜(Mock) 객체로 대체.
- `@Mock`, `@InjectMocks`, `given()...willReturn()`, `verify()` 같은 문법 제공.
- 덕분에 DB 붙이지 않고도 순수 비즈니스 로직만 검증 가능

### 4. MockMvc(Controller 테스트 전용)
- `@WebMvcTest` 환경에서 Controller만 올려놓고 HTTP 요청을 흉내내는 도구
- `mockMvc.perfrom(get("/api/hello"))...` 같은 식으로 GET/POST 요청을 만들어 실제 컨트롤러 메소드 결과를 검증할 수 있음.
- DB나 Service는 `@MockBean`으로 주입해서 가짜로 대체 가능

### 5. WebTestClient(통합 테스트/WebFlux 기반)
- Spring 5부터 추가된 HTTP 클라이언트 테스트 도구
- 원래는 WebFlux(리액티브) 앱 전용이었는데, 이제는 서블릿 기반 MVC 앱에서도 쓸 수 있음.
- `@SpringBootTest(webEnvironment = RANDOM_PORT)`랑 같이 써서, 실제 서버 띄워놓고 API 호출을 시뮬레이션 할 수 있음
- `TestRestTemplate`보다 문법이 더 간결하고 체이닝 가능.

### 6. H2 Database(인메모리 DB)
- Repository 테스트할 때 실제 MySQL 같은 운영 DB 대신 임시로 메모리에 DB를 띄움.
- 테스트 시작 시 `create-drop`으로 테이블 만들어 쓰고, 끝나면 자동 삭제.
- 속도 빠르고 운영 DB 오염 안 됨.
- H2 DB를 사용하는 방법
    - JPA(Hibernate): `@Entity` + `JpaRepository` 기반 테스트(가장 일반적)
    - JdbcTemplate: SQL 직접 실행하면서 검증 가능
    - MyBatis: Mapper XML/어노테이션 기반 테스트 가능
    - 순수 JDBC: `DriverManager.getConnection(...)` 해서 Statement 실행도 가능
    - => 즉, H2는 단순히 "테스트용으로 가볍게 띄울 수 있는 DB". ORM, MyBatis, 생 JDBC 든 전부 붙여서 쓸 수 있음.

`build.gradle`
```java
...
dependencies {
  // JUnit 5, AssertJ, Mockito, MockMvc, WebTestClient 등 테스트 도구 모음
  // Spring Boot Test
  testImplementation 'org.springframework.boot:spring-boot-starter-test'

  // 테스트용 DB
  runtimeOnly 'com.h2datatbase:h2'
}

// Gradle에서 test task를 실행할 때 어떤 테스트 실행 엔진을 쓸지 지정하는 설정
// Gradle은 기본값이 JUnit4 기반 실행 엔진이라서, JUnit5 어노테이션(@Test, @DisplayNmae, @ExtendWith)을 쓰려면 꼭 useJunitPlatform()을 켜줘야 함.
task.name('test') {
 useJUnitPlatform()
}

...
```

코드에서 확인할 수 있듯이, `spring-boot-starter-test`안에 웬만한 테스트 도구의 의존성이 다 들어있습니다.(JUnit5, AssertJ, Mockito, MockMvc, WebTestClient)
