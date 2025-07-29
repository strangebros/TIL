## 학습 계기
서비스를 개발하면서 아래와 같은 케이스가 있었다.

1. 값을 생성하는데 많은 리소스가 필요
2. 값이 자주 변경되지는 않음
3. 해당 값을 갖는 DTO 가 굉장히 여러 곳에서 (또는 다른 DTO 내부에서) 사용됨 (e.g. `UserDto.비싼필드`)
4. 모든 응답에 해당 값이 포함되어야 함

이러한 상황에서 응답 속도를 줄이기 위해서 어떻게 할 수 있을까 고민하다가,
캐싱을 해볼 수 있겠다는 피드백을 듣고 스프링에서 제공하는 캐시 추상화에 대해 공부해야겠다는 생각이 들었다.

## 스프링과 캐시
> 출처
> 1. https://docs.spring.io/spring-boot/reference/io/caching.html
> 2. [[Spring] 캐시(Cache) 추상화와 사용법(@Cacheable, @CachePut, @CacheEvict)](https://mangkyu.tistory.com/179)
> 3. [[Spring] 스프링이 제공하는 Cache와 CacheManager 쉽고 완벽하게 이해하기](https://mangkyu.tistory.com/370)

### AOP와 추상화
스프링 답게, 스프링 캐시도 AOP 와 추상화 기술이 적용되어 있다.

때문에 비지니스 로직에 영향을 최소화할 수 있고,
사용하는 캐시 구현체가 변경되어도 설정을 제외한 나머지 코드 수정이 불필요하다.

### @Cacheable
```java
@Component
public class MyMathService {

	@Cacheable("piDecimals")
	public int computePiDecimal(int precision) {
		...
	}

}
```

위와 같이 메서드에 `@Cacheable("piDecimals")` 을 선언해주면 해당 메서드의 반환 값이 `piDecimals` 라는 이름으로 캐싱된다.
`precision` 이라는 파라미터에 동일한 값으로 요청이 들어오면, `piDecimals` 이름을 가진 캐시에서 해당 파라미터 값을 key 로 갖는 value 가 있는지 검사 후 있으면 캐시를 반환하게 된다.

스프링은 별다른 설정을 하지 않으면 ConcurrentHashMap 을 사용하는 CacheManager 를 사용한다고 한다. (프로덕션에서는 당연히 사용하면 안 된다)

### Cache 와 CacheManager

