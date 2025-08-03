## 궁금증

저는 백엔드 개발자이지만, 트랜잭션에 대해서 피상적으로만 알고 있습니다.

부끄럽지만 아직 쿼리를 짤 때 트랜젝션을 제대로 짜서 실행해 본 적이 없습니다. 
하지만 현업에 들어오니, 트랜잭션, 롤백 등에 대한 개념을 잘 알고 있어야 개발할 때 실수를 줄이고, 실수에 대한 대응을 잘 할수 있겠다는 생각이 들었습니다.

그래서, DB 사용을 좀 더 잘하는 개발자가 될 수 있도록, 이 기회를 통해 DB에서의 트랜잭션에 대해서 한번 정리해 보려고 합니다.

</br>

## 트랜잭션의 전형적인 구조

DB 트랜잭션의 전형적인 구조는 다음과 같습니다. 

```sql
BEGIN;

-- 여러 작업 수행
UPDATE ...
INSERT ...
DELETE ...

-- 모든 작업이 성공하면
COMMIT;

-- 중간에 문제가 생기면
ROLLBACK;
```

기본적인 개념만 설명해 보자면, 아래와 같습니다.

| 키워드 | 의미 |
| --- | --- |
| BEGIN | 트랜잭션을 시작한다 (이후의 작업은 묶어서 처리됨) |
| COMMIT | 지금까지의 작업을 확정한다. |
| ROLLBACK | 지금까지의 작업을 취소한다. |

각 키워드들과 트랜잭션의 세부적인 특성에 대해서는, 아래에 하나하나 자세히 설명하며 공부해 보겠습니다.

</br>

## `BEGIN` 키워드

시작은 이전 커밋에서 제가 궁금증이 생겼었던 `BEGIN` 키워드 부터 시작하겠습니다.
놀랍게도 이 개발자는 `BEGIN` 키워드를 사용해 본 적이 없어서, 어떠한 역할을 하는지를 제대로 모르고 있었습니다.

나중에 제가 유명해졌을때(?) 이 글이 파묘당해서 사람들에게 충격을 주지 않을까... 하는 상상을 한번 해보며 일단 지금은 저를 아무도 모르니 그냥 공부하는 기분으로 시작하겠습니다.

### `BEGIN`의 의미

SQL에서 `BEGIN` 키워드는 트랜잭션(Transaction)을 시작한다는 의미입니다.

```sql
BEGIN;
```

-> 트랜잭션 블록 시작
이후에 수행하는 작업들은 **묶음(하나의 트랜잭션)** 으로 처리됩니다.

### `BEGIN`이 필요한 이유

#### 1. 여러 작업을 하나의 단위로 묶기 위해
- 위에도 말했듯이, 하나의 트랜잭션으로 설정을 하면 중간에 한 작업이 실패하면 전체 취소할 수 있도록 합니다.
- 이는 DB 트랜잭션이 안전하게 수행된다는 것을 보장하기 위한 성질을 가리키는 ACID 중 **Atomicity, 즉 원자성을 지키기 위해서입니다.**

#### 2. 자동 커밋(autocommit)을 끄기 위해
- 대부분의 DB는 기본적으로 한 줄을 실행하면 자동으로 커밋이 된다고 합니다. 이렇게 되면 중간 실패 시 롤백을 할 수 없게 됩니다.
- `BEGIN`을 사용하면 이런 자동 커밋 기능을 해제할 수 있습니다.

### `BEGIN`이 트랜잭션에 포함시키는 것.

이쯤 되면, BEGIN 키워드로 묶이는 것들에는 어떤 구문들이 있는지 궁금해 질 수 밖에 없습니다. ~안궁금하셨다구요? 그래도 계속 읽어주세요~

| 구문 예시 | 포함 여부 | 설명 |
| --- | --- | --- |
| `INSERT`, `UPDATE`, `DELETE` | O | 데이터 변경 작업들 |
| `SELECT ... FOR UPDATE` | O | 동시성 제어용 SELECT |
| `CREATE TABLE`, `DROP TABLE` | X (MySQL 기준) | 대부분 트랜잭션과 별개로 처리됨 (DDL은 예외) |

- *참고로, DDL은 DBMS마다 다르며, PostgreSQL은 일부 DDL도 트랜잭션 내에서 사용 가능하다고 합니다.

### DBMS별 트랜잭션 관련 키워드 차이

| DBMS | 트랜잭션 시작 키워드 | 비고 |
| --- | --- | --- |
| MySQL | `START TRANSACTION` 또는 `BEGIN` | 동일 기능 |
| PostgreSQL | `BEGIN` | 표준 |
| Oracle | 트랜잭션은 DML 실행 시 자동 시작 | `BEGIN` 키워드 없음 (PL/SQL에서는 블록 시작용으로 사용) |
| SQL Server | `BEGIN TRANSACTION` | 명확하게 명시해야 함 |

### `PL/SQL` / `T-SQL` / 프로시저 / 블록 정의

`BEGIN` 키워드에 대한 설명에서 다음과 같은 문장이 나왔습니다.

> 프로시저 안에서 `BEGIN`은 블록 정의로 사용되기도 함(주의: PL/SQL, T-SQL에서는 다르게 해석됨)

한 문장에 모르는 단어들이 4개나 나와서 정리하고 가려고 합니다.

#### 1. PL/SQL

> Procedural Language / SQL의 약어로, Oracle에서 사용하는 절차형(논리 흐름이 있는) SQL 언어입니다.
- 일반적인 SQL은 `SELECT`, `INSERT` 같은 정적인 명령 위주이지만,
- PL/SQL은 `IF`, `FOR`, `LOOP`, `변수`, `예외처리`, `BEGIN~END` 블록 등을 포함하는 프로그래밍 언어 스타일입니다.
- (주의) Oracle에서만 사용됩니다.

사용 예시
```sql
DECLARE
  v_name VARCHAR2(50);
BEGIN
  SELECT name INTO v_name FROM users WHERE id = 1;
  DBMS_OUTPUT.PUT_LINE(v_name);
END;
```

#### 2. 블록 정의

> '블록'은 프로그래밍 언어의 `{}` 블록처럼 어떤 코드를 실행하는 단위라고 생각하면 좋을 것 같습니다.

> '블록 정의'는 PL/SQL에서 블록의 구조를 정의하는 것을 의미합니다. `BEGIN`키워드가 여기에서 사용되어서 위에서 언급이 된 것입니다.

PL/SQL은 다음과 같은 세 부분 구조를 가집니다.

| 구역 | 의미 |
| --- | --- |
| DECLARE[선언부] | 변수/상수fmf 선언합니다.(선택) |
| BEGIN[실행부] | 제어, 반복문, 함수 등 다양한 로직 기술을 실행합니다. |
| EXCEPTION | 오류 발생 시 처리 로직입니다.(선택) |
| END[종료부] | 실행된 로직의 종료를 선언합니다. |

이렇게 실행한 결과는 `DBMS_OUTPUT`에서 확인할 수 있습니다. 

#### 3. 프로시저(Procedure)

> 프로시저란, 여러 SQL문을 묶어서 만든, **함수처럼 쓰이는 하나의 실행 단위** 입니다.

프로시저는 다음과 같은 특징을 가지고 있습니다.
- 이름이 있는 "미리 정의된 작업"
- 나중에 호출만 하면 반복 실행 가능
- Oracle에서는 PL/SQL 기반으로 작성

다른 SQL 언어에서 어떻게 사용하는지는 추후에 정리하겠습니다!

#### 4. T-SQL

> T-SQL은 `Transact-SQL`의 약자로, MS-SQL에서 사용하는 SQL 확장 언어입니다.

Oracle의 PL/SQL과 비슷한 개념이지만, 문법과 동작이 다르다고 합니다.

#### 결론

> 프로시저 안에서 `BEGIN`은 블록 정의로 사용되기도 함(주의: PL/SQL, T-SQL에서는 다르게 해석됨) 이라는 문장은

같은 `BEGIN` 키워드라도 **어떤 SQL에서 쓰였는지**에 따라 완전히 다른 의미가 된다는 뜻입니다.

| SQL 종류 | 키워드 | 의미 |
| --- | --- | --- |
| 일반 SQL(MySQL 등) | `BEGIN;` | 트랜잭션 시작 |
| PL/SQL, T-SQL | `BEGIN` | 코드 블록 시작 (프로그래밍적 의미) |

<br />

## `COMMIT`과 `ROLLBACK` 키워드

이어서, 트랜잭션의 핵심 동작인 `COMMIT`과 `ROLLBACK`에 대해서 알아보려고 합니다.

### `COMMIT`의 정의

- `COMMIT`은 지금까지 수행한 모든 변경 작업을 **DB에 영구적으로 반영(저장)** 하는 명령어입니다.
- 즉, `COMMIT`을 하면 DB는 "진짜로 바뀐 것"으로 인정합니다.

#### 사용 예시

```sql
BEGIN;

UPDATE users SET balance = balance - 100 WHERE id = 1;

COMMIT;
-- 이 시점 부터는 다시 돌릴 수 없음
```

### `ROLLBACK`의 정의

- `ROLLBACK`은 지금까지 수행한 변경 작업을 **모두 취소**하고, 트랜잭션 시작 전 상태로 **되돌리는** 명령어입니다.
- 즉, DB에 "없던 일로" 만든다고 생각하면 됩니다.

#### 사용 예시

```sql
BEGIN;

UPDATE users SET balance - 100 WHERE id = 1;

ROLLBACK;
-- 이 작업은 무효 처리됨(balance 변화 없음)
```

### `COMMIT` / `ROLLBACK` 작동 흐름

- 아래와 같은 잔액 이체 sql문이 있다고 가정해 봅시다.

```sql
BEGIN;

UPDATE account SET balance = balance - 100 WHERE name = 'A';
UPDATE account SET balance = balance + 100 WHERE name = 'B';

-- 모두 성공하면
COMMIT;
-- 또는 중간에 오류가 나면
-- ROLLBACK;
```

- 해당 sql문의 시점 별 상황은 다음과 같습니다.

| 시점 | A잔액 | B잔액 | 설명 |
| --- | --- | --- | --- |
| 트랜잭션 이전 | 1000 | 500 | 초기 상태 |
| A에서 빼고 -> B에게 추가 | 900 | 600 | 변경 완료(아직 COMMIT 안됨) |
| ROLLBACK | 1000 | 500 | 변경 사항 모두 취소됨 |
| COMMIT | 900 | 600 | 변경 사항 DB에 저장됨 |

### `COMMIT` 과 `ROLLBACK`이 필요한 이유

1. 데이터 무결성 보장
  -> 여러 변경이 있을 때 일부만 반영되면 DB가 망가짐
  -> 예: A잔액 빠졌는데 B한테 입금 실패하는 경우가 생기면, DB의 무결성이 깨짐
2. 테스트 후 반영 또는 취소 가능
  -> 예: `UPDATE`로 10만 건 수정해보고, 조건 이상하면 `ROLLBACK`으로 되돌리기
3. 에러 발생 시 자동 복구
  -> 예: 중간에 네트워크 오류, 키 충돌 등 생겼을 때 전체 취소 가능

### 실무에서 `COMMIT`과 `ROLLBACK`을 사용하는 대표적인 경우

| 상황 | 처리 방식 |
| --- | --- |
| 여러 테이블이 관련된 변경(위의 계좌이체 예시 같은...) | 한꺼번에 COMMIT, 실패 시 ROLLBACK |
| 파일 업로드 + DB 반영 같이 처리할 때 | DB 트랜잭션은 ROLLBACK으로 취소 |
| 운영에서 대량 UPDATE 할 때 | `BEGIN -> UPDATE -> SELECT -> 확인 -> COMMIT or ROLLBACK` |
| 테스트용 임시 작업 | `ROLLBACK`으로 되돌림 |

### `AUTO-COMMIT`에 대하여

> 일부 DB는 `BEGIN`을 쓰지 않아도 각 쿼리마다 **자동으로 COMMIT**이 된다고 합니다.

> 이것을 `AUTO-COMMIT`이라고 부릅니다.

| DBMS 종류 | AUTO-COMMIT 기본값 |
| --- | --- |
| MySQL | 1(켜짐) |
| PostgreSQL | 1(켜짐) |
| Oracle | 1(켜짐, 단 DML 시작 시 트랜잭션 시작됨) |

이러한 `AUTO-COMMIT`은 작업을 하나하나 `COMMIT` 하지 않아도 된다는 편리함이 있지만, 위험한 경우도 있다고 합니다.

```sql
UPDATE salaries SET amount = amount * 10;
-- 잘못 실행하면 바로 COMMIT 됨
-- WHERE 절도 없어서 모든 데이터에 대해서 적용됨
```

- 위의 상황과 같은 경우에서, `AUTO-COMMIT`이 적용된다면, 되돌릴 수 없습니다.
- 그래서 실무에서는 명시적으로 `BEGIN;`으로 시작하고, 꼭 수동으로 `COMMIT` 또는 `ROLLBACK` 처리하는 습관이 중요합니다.

`AUTO-COMMIT`을 해제하는 방법은 크게 두 가지가 있다고 알고 있습니다.
1. DB의 세션을 키고, 직접 `AUTO-COMMIT` 설정을 0으로 바꿔주는 방법.(단, 이렇게 하면 새로운 세션에는 적용이 되지 않습니다.)
2. DB IDE등의 '시작 스크립트'기능(프로그램마다 명칭 다를 수 있음)을 통해 프로그램을 실행시킬 때마다 자동으로 `AUTO-COMMIT` 기능을 적용시키는 방법.

## SAVEPOINT

### 개념

- `SAVEPOINT`는 트랜잭션 도중에 일부 작업만 되돌리고, 나머지는 유지하고 싶을 때 사용합니다.
- 게임에서의 중간 저장 지점(보통 그냥 세이브포인트라고 부르죠? ㅋㅋ)를 생각하면 이해하기 쉽습니다.

#### 기본 구조

- 아래는 `SAVEPOINT`를 사용하는 기본 구조입니다.

```sql
BEGIN;

-- 트랜잭션 작업 1
UPDATE account SET balance = balance - 100 WHERE name = 'A';

SAVEPOINT sp1; -- 여기까지 저장

-- 트랜잭션 작업 2
UPDATE account SET balance = balance + 100 WHERE name = 'B';

ROLLBACK TO sp1; -- 두 번째 작업은 취소, 첫 번째는 유지

COMMIT; -- 트랜잭션 작업 1만 DB에 반영

```

#### 주요 키워드 정리 

| 키워드 | 설명 |
| --- | --- |
| `SAVEPOINT 세이브포인트명` | 트랜잭션 중간 지점 설정 |
| `ROLLBACK TO 세이브포인트명` | 해당 지점까지만 되돌림(`SAVEPOINT` 이후 작업만 취소됨)
| `RELEASE SAVEPOINT 세이브포인트명` | 저장했던 지점을 명시적으로 제거 |
| `COMMIT` | 전체 트랜잭션을 확정(SAVEPOINT도 함께 사라짐) |

### 실전 사용

#### SAVEPOINT가 있을 때 동작 순서 예시

- 위의 '기본 구조' 코드와 유사한 부분이 있지만, 여러개의 `SAVEPOINT`를 사용할 수 있는 예시 정도로 보면 될 것 같습니다.

```sql
BEGIN;

INSERT INTO orders VALUES(1, '상품'); -- 장바구니 추가
SAVEPOINT s1;

INSERT INTO payments VALUES(1, '카드', 100); -- 결재 내역
SAVEPOINT s2;

UPDATE inventory SET stock = stock - 1 -- 재고 차감 실패
  WHERE item = '상품1';
-- 예: 재고 부족 오류 발생

ROLLBACK TO s1; -- 결제 내역과 재고 차감만 취소됨
COMMIT;         -- 장바구니 내역은 DB에 반영
```

<br />

## 트랜잭션의 생애주기

- 트랜잭션은 단순히 `BEGIN` -> `COMMIT/ROLLBACK`의 형태만 있는 것이 아닙니다.
- 때문에, 트랜잭션의 전체 흐름을 명확하게 파악하는 것이 중요합니다.

### 트랜잭션의 상태 흐름 요약

| 상태 | 설명 |
| --- | --- |
| IDLE 상태 | DB와 연결되어 있음. 트랜잭션 미시작 |
| ACTIVE 상태 | 쿼리 수행 중 |
| COMMITTED 상태 | 트랜잭션 작업이 DB에 확정 저장됨 |
| ROLLED BACK 상태 | 트랜잭션 작업이 되돌려짐 |

- 아래에 각 상태에 대해서 자세히 알아보겠습니다.

### IDLE 상태

- 트랜잭션이 없는 상태
- DB 연결은 되어 있지만, 아직 트랜잭션은 시작하지 않음
- 또는, 이전 트랜잭션이 끝나도 IDLE 상태로 복귀합니다.
- 이 상태에서는 SELECT 같은 읽기 작업만 가능 (쓰기 작업을 하려고 하면 자동으로 트랜잭션이 시작된다고 합니다.)

### ACTIVE 상태

- IDLE 상태에서 `BEGIN` 또는 `START TRANSACTION`으로 트랜잭션이 활성화된 상태입니다.
- 이때부터는 `INSERT`, `UPDATE`, `DELETE` 등의 작업이 트랜잭션 안에 포함됩니다.
- `SAVEPOINT`도 이 시점부터 가능합니다.
- 단, 이 상태에서 DB에 변경된 내용은 아직 확정되지 않는다고 합니다.

### COMMITTED 상태

- ACTIVE 상태에서 `COMMIT`으로 트랜잭션 내의 모든 작업이 BD에 확정 저장된 상태입니다.
- 이후 되돌릴 수 없습니다.

### ROLLED BACK 상태

- ACTIVE 상태에서 `ROLLBACK`으로 트랜잭션 내의 모든 작업이 되돌려진 상태입니다.
- DB는 BEGIN 이전의 상태로 복구됩니다.


<br />

## JDBC / Spring에서의 트랜잭션 처리

- 이제는 실무에서 Java 기반 애플리케이션이 DB 트랜잭션을 어떻게 제어하는지 알아보겠습니다.

### JDBC에서의 트랜잭션 처리

- JDBC는 트랜잭션을 수동으로 제어해야 합니다.
- 따라서, 자동으로 COMMIT 되지 않도록 `setAutoCommit(false)`를 통해 먼저 꺼야 합니다.

```java

Connection conn = dataSource.getConnection();
try(
  conn.setAutoCommit(false); // 트랜잭션 시작

  PreparedStatement stmt1 = conn.prepareStatement("UPDATE account SET balance = balance - 100 WHERE id = ?");
  stmt1.setInt(1, 1);
  stmt1.excuteUpdate();

  PreparedStatement stmt2 = conn.prepareStatement("UPDATE account SET balance = balance + 100 WHERE id = ?");
  stmt2.setInt(1, 2);
  stmt2.executeUpdate();

  conn.commit(); // 트랜잭션 확정
} catch (Exception e) {
  conn.rollback(); // 트랜잭션 되돌림
} finally {
  conn.close(); // 커넥션 정리
}
```

---

### Spring에서의 트랜잭션 처리: `@Transactional`

- Spring에서는 트랜잭션을 직접 다루지 않아도 됨.
  - 대신 메서드에 `@Transactional`만 붙이면 자동으로 BEGIN -> COMMIT/ROLLBACK이 실행된다고 합니다.

```java
@Service
public class TransferService {

  @Transactional
  public void transferMoney(Long fromId, Long toId, int amount) {
    accountRepository.decreaseBalance(fromId, amout); // UPDATE
    accountRepository.increaseBalance(toId, amount); // UPDATE
    // 예외 발생 시 자동 ROLLBACK
  }
}
```

- JDBC 방식을 보다가 Spring 방식을 보니까 참 간단하고 편하게 느껴집니다.
- 이래서 Spring 쓰는구나 싶다가도, JDBC처럼 작동의 원리를 제대로 알아야 한다는 생각이 동시에 들었습니다.

#### Spring 트랜잭션의 핵심 동작 방식

| 시점 | 동작 |
| --- | --- |
| `@Transactional` 메서드 진입 | 트랜잭션 시작(`BEGIN`) |
| 예외 없이 매서드 끝남 | `COMMIT` 자동 호출 |
| 예외 발생 | `ROLLBACK` 자동 호출 |
| 커넥션 | `DataSource`에서 커넥션을 가져와 바인딩 |

- 이때, 내부적으로는 `TransactionInterceptor`가 처리한다고 합니다. 이 친구는 나중에 따로 다뤄보겠습니다.

---

### 롤백이 되는 조건: 예외 타입

- 롤백이 되는 조건은, 예외 타입에 따라 결정된다고 합니다.

| 예외 | 롤백 여부(기본) |
| --- | --- |
| `RuntimeException` / `Error` | 롤백됨 |
| `Checked Exception` (예: `IOException`) | 롤백 안됨. 기본은 커밋됨 |

- 뭔가 이상합니다. 예외가 나면 롤백이 되는 게 기본이라고 생각했는데 말이죠.
- Spring에서는 이것을 아래와 같은 방법으로 보완할 수 있습니다.

```java
@Transactional(rollbackfor = IOEXceptiuoin.class)
public void uploadFile() throws IOException {
  ...
}
```

---

### 트랜잭션 전파 속성(`Propagation`)

- 만약 메서드 안에서 또 다른 메서드를 호출한다고 하면, 트랜잭션은 어떻게 영향을 받을까요?
- 이것은 트랜잭션의 전파 속성에 따라 결정됩니다.

| 속성 | 설명 |
| --- | --- |
| `REQUIRED` | 기본값. 기존 트랜잭션 있으면 참여, 없으면 새로 시작. |
| `REQUIRES_NEW` | 기존 트랜잭션을 중단하고 새로운 트랜잭션 시작. |
| `NESTED` | 내부 트랜잭션 (`SAVEPOINT` 기반처럼 작동 ) |

- 이것을 응용하면 다음과 같이 처리를 할 수 있습니다.
- 로깅을 실패해도 메인 작업에 영향을 끼치지 않고 처리하고 싶을 때

```java
@Transactional(propagation = Propagation.REQUIRES_NEW)
public void logTransfer(...) {
  ...
}
```

---

### 커넥션 풀 & 오토커밋 주의점

- JDBC의 기본값은 `autoCommit = true` 입니다.
- 때문에, 커넥션 풀에서 꺼낸 커넥션이 autoCommit 상태로 되어 있으면
  - `@Transactional`이 작동하더라고 중간에 커밋되는 일이 생길 수 있다고 합니다.

#### 실무 팁
- HikariCP, Tomcat JDBC Pool 등 커넥션 풀 설정에서 `defaultAutoCommit = false` 설정을 확인할 필요가 있습니다.
- SpringBoot에서는 자동으로 적절하게 조정한다고 합니다.

---

### 실무에서 자주 발생할 수 있는 문제 사례

| 상황 | 원인 |
| --- | --- |
| 트랜잭션 안 썼는데 데이터가 반영됨 | autoCommit=true 상태 |
| 예외가 발생했는데 ROLLBACK 안 됨 | checked exception (rollbackFor 누락) |
| 트랜잭션 안에 여러 메서드 있는데 rollback 안됨 | 내부 메서드가 같은 클래스에서 직접 호출됨(프록시 적용 안됨) |

이 세 가지의 해결 방안에 대해서는 내일 다시 정리하도록 하겠습니다~~~




