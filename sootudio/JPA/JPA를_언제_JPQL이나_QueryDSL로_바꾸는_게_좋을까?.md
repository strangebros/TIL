## 궁금증

첫 주제를 뭘로 할지 고민하다가, 어제 마침 `walkie` 에서 재준형에게 코드 리뷰를 달다가 궁금해서 찾아본 내용이 있었습니다.
리뷰의 내용은, 재준형이 Repository에 다소 긴 JPA 메서드 (`findTopByMemberIdAndNowDayBeforeOrderByNowDayDesc`)를 생성해 놔서, 가독성을 위해 JPQL이나 QueryDSL을 사용하는게 어떤지 리뷰를 쓰고 있다가, 문득

| 긴 Spring Data JPA 메서드는 무조건 JPQL/QueryDSL로 바꾸는 게 좋은 건가?

라는 의문이 들어서, 관련된 내용을 찾아봤습니다.


## 무조건 바꾸는 게 좋은 건 아니다!

찾아본 결과, JPA 메서드가 길다고 해서 꼭 JPQL이나 QureyDSL로 바꾸는게 좋은 건 아니라고 합니다.
Spring Data JPA에서 제공하는 메서드 이름 기반 쿼리 메서드는 간단한 조회에는 매우 효율적이기 때문에, 단순히 이름이 길다는 이유 하나만으로 바꾸는 것은 권장되지 않는다고 나왔습니다.
대신, 다음과 같은 조건을 기준으로 바꾸는 것을 고려하는 게 좋다고 합니다.

- 메서드 이름이 너무 길어서 가독성이 떨어질 때 (근데 이거면 길어서 수정하는게 맞는거 아닌감...? 하는 생각이 들었습니다)
- 동적 조건이 필요할 때 (조건이 있을 수도 있고 없을 수도 있는 경우)
- 복잡한 조인, 서브쿼리, Group By, Fetch Join 등이 필요할 때
- 리팩터링이나 테스트에서 재사용 가능한 명확한 쿼리 로직이 필요할 때

그래서, 해당 조건을 통해 다시 위에서 만든 메서드를 보니까, 조건과 정렬이 섞여 있어 처음 보는 사람들에게는 이해하기 힘들 수도 있다는 생각이 들었습니다.
해당 메서드를 JPQL이나 QueryDSL로 바꾸면 다음과 같이 된다고 합니다.

기존 메서드

```java
Optional<HealthCurrent> findTopByMemberIdAndNowDayBeforeOrderByNowDayDesc(Long memberId, LocalDate nowDay);
```

🔁 JPQL 형식 (어째 코드가 더 길어진 것 같지만, 자세히 보면 조건과 정렬이 `@Query`로 올라가서, 좀 더 가독성이 좋아진 것을 알 수 있습니다.

```java
@Query("SELECT h FROM HealthCurrent h WHERE h.member.id = :memberId AND h.nowDay < :nowDay ORDER BY h.nowDay DESC")
Optional<HealthCurrent> findLatestBeforeNowDay(@Param("memberId") Long memberId, @Param("nowDay") LocalDate nowDay);
```

🔁 QueryDSL 형식 (특히 동적 조건이 있는 경우 무조건 QueryDSL이 유리하다고 합니다)

```java
QHealthCurrent h = QHealthCurrent.healthCurrent;

return queryFactory
        .selectFrom(h)
        .where(
            h.member.id.eq(memberId),
            h.nowDay.lt(nowDay)
        )
        .orderBy(h.nowDay.desc())
        .limit(1)
        .fetchOne();

```
