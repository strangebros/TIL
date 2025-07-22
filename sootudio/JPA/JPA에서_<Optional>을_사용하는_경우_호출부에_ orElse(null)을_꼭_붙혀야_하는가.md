## 궁금증

오늘의 주제 역시 `walkie` 프로젝트에서 재준형의 코드를 리뷰하다가 궁금해서 찾아 본 것이 있어서, 그 내용을 정리하고자 합니다.
PR에 올라온 코드에는 아래와 같은 JPA메서드가 있었습니다.

```java
Optional<HealthCurrent> findTopByMemberIdAndNowDayBeforeOrderByNowDayDesc(Long memberId, LocalDate nowDay);
```

참고로 어제 `JPA` vs `JPQL/QueryDSL` 내용에서 나온 그 메서드 맞습니다. (뿌듯하게도 재준형은 제 리뷰를 보고 해당 메서드를 `QueryDSL` 형식으로 수정했습니다.)
그리고, 해당 메서드를 호출하는 부분은 다음과 같이 작성되어 있었습니다.

```java
HealthCurrent healthCurrent = healthCurrentRepository.findTopByMemberIdAndNowDayBeforeOrderByNowDayDesc(memberId,nowDate).orElse(null);
```

여기서 호출부의 마지막에 `.orElse(null)`이 들어간 것을 보고, 한 가지 의문이 생겼습니다.

</br>

> 어차피 `Optional`을 사용하면 null 값이 나와도 안전하게 값이 담기는 거 아닌가?
> `.orElse(null)`은 값이 있으면 값을 반환하고, 값이 없으면 null을 반환하는 것이므로, 어차피 똑같은 처리를 `Optional` 을 통해서 하는 것 아닌가?

## `Optional<T>`와 `.orElse(null)` 정확하게 이해하기

결론부터 말하자면, `.orElse(null)`은 항상 반드시 필요한 건 아니지만, 사용하는 목적에 따라 명확한 의미 차이가 있습니다.

### `Optional<T>`를 사용하는 이유
- `Optional<T>`는 null 값을 안전하게 감싸는 래퍼 클래스입니다.
- JPA에서 쿼리 메서드가 `Optional<T>` 를 리턴하는 이뉴는, **null 방지** 및 **명시적인 값 유무 표현** 을 위해서라고 합니다.

### `orElse(null)`을 사용하는 이유
- `orElse(null)`은 Optional에서 값을 꺼내는 방법 중 하나라고 합니다.
- 값이 존재하면 해당 값을 반환하고, 값이 없으면 null을 반환하는 방식을 사용합니다.
- 즉, orElse(null)을 사용하면, `Optional<T>` 형식이던 반환값이 `T` 형식으로 바뀌는 것입니다.

### 그래서 언제 사용하나요?

사실 이렇게 개념 봐도 와닿지가 않아서, 각각 다른 상황 별로 `.orElse(null)`을 사용해야 하는 상황과, 필요하지 않은 상황을 정리해 봤습니다.

| 상황 | 설명 | 예시 | `.orElse(null)` 필요 여부 |
| --- | --- | --- | --- |
| Optional 값을 그대로 다룰 때 | 값 존재 여부를 직접 체크하거나, isPresent() 등을 사용 | `Optional<Healthcurrent> opt = repo.find...()` | 불필요 |
| 값을 바로 꺼내서 쓸 때 | null을 허용하면서 바로 사용할 때 (위에서 궁금증이 생긴 상황) | `HealthCurrent current = repo.find...().orElse(null);` | 필요 |
| 값이 없으면 예외를 발생시키고 싶을 때 | 강제로 오류 발생 | `repo.find...().orElseThrow();` | 불필요한 대신, 따로 예외 처리를 해야 함 |

핵심은
- Optional 자체를 다루는 코드에서는 `orElse(null)` 이 필요하지 않고,
- Optional을 받지 않고 바로 값만 받으려는 코드는 `orElse(null)`이 필요하다는 것이였습니다.

## 또 다른 궁금증과 결론

이렇게 끝날 줄 알았지만...
저는 여기서 한 가지 더 의문이 생겼습니다.

> 아니 그러면 반대로 `.orElse(null)`을 사용한다면, `Optional<T>` 를 안 써도 되는 거 아닌가? 어차피 null을 받을 거면, Optional을 왜 써?

### 기능상으로는 없어도 되지만, 명시적 표현을 위해 사용한다.

그래서 더 찾아보니, `orElse(null)`을 사용하면 `Optional`을 리턴받는 의미가 사실상 사라지는건 맞다고 합니다.
다만, 실무에서는 `Optional<T>`과 `orElse(null)`을 같이 사용하기도 하는데, 다음과 같은 이유 때문이였습니다.

#### 1. 명시적인 설계(API의 의도 전달)
- `Optional<T>`를 사용하면, 값을 못 찾을 수도 있다는 걸 타입으로 강제합니다.
- 이렇게 되면, 호출하는 개발자에게 "무조건 null 체크해" 라는 의미를 전달할 수 있습니다.
- 즉, 리턴 타입에 Optional을 쓰는 건 Repository를 설계하는 사람의 책임이고, `orElse(null)`을 사용하는 것은 호출자의 선택이라고 볼 수 있습니다.
- Repository를 만드는 사람과, 호출을 하는 사람이 각각 다른 사람이라고 생각하니 바로 이해됐습니다.

#### 2. null보다 안전하고 명확함
- Optional은 `null`보다 훨씬 안전하고 IDE 친화적이라고 합니다.
  - `ifPresent`, `map`, `filter`, `orElseThrow` 같은 체이닝 메서드(메서드 호출 결과로 객체 자신이나 또 다른 객체를 반환해서, 메서드를 연속해서 호출할 수 있게 하는 패턴)을 제공합니다.
- 또한, 예외 방지(`NullPointerException`)도 사용이 가능합니다.

#### 3. 호출자에게 선택지를 줌
- 1번이랑 비슷한 내용이긴 한데, `Optional`을 받은 쪽은 다음과 같은 선택지가 생깁니다.
  - ifPresent(...) → 값 있을 때만 실행
  - orElse(...) → 기본값 제공
  - orElse(null) → null 허용
  - orElseThrow() → 예외 발생
 
이렇게 다양한 장점들이 있으나, 항상 `orElse(null)`을 써서 `Optional`을 무시하면 의미가 없다는 주의점도 있습니다.
그럼에도 불구하고 공식 JPA 스펫이나 Spring Data 규칙상, `Optional<T>` 리턴이 의미 있고, 타입 안정적인 방식으로 자리잡고 있기 때문에, 업무 시 잘 조정해서 쓰는 게 좋을 것 같습니다.

정리하자면,
> `Optional`은 설계자의 의도를 명시하는 도구이고.
> `.orElse(null)`은 호출자가 책임지고 null을 받아들이는 선언입니다.
> 둘은 함께 쓰일 수도 있지만, 함부로 Optional을 null처럼 쓰면 안됩니다.

일단은 오늘은 여기까지 정리하고, 추가적인 내용이 있다면 수정하겠습니다!!
