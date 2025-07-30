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
계속 보다보니 Cache 와 CacheManager 가 되게 헷갈렸다.

둘다 스프링에서 만들어둔 인터페이스인데,
먼저 Cache 는
```java
public interface Cache {

	@Nullable
	ValueWrapper get(Object key);

    void put(Object key, @Nullable Object value);

    void evict(Object key);

    ...

}
```

와 같이 되어있고, CacheManager 는

```java
public interface CacheManager {

	@Nullable
	Cache getCache(String name);

	Collection<String> getCacheNames();

}
```

와 같이 되어 있다.

개념만 들었을 때는 되게 헷갈렸는데, 인터페이스를 보면 구조가 명확해진다. 앞서 `@Cacheable("piDecimals")` 와 같이 간단하게 캐시의 이름을 지정할 수 있다고 했는데 여기서 `piDecimals` 가 하나의 `Cache` 가 된다. 그 안에 어떠한 방식으로든 `key-value` 의 데이터 쌍이 저장되는 구조이다.

반면 CacheManager 는 이러한 캐시들의 집합을 '어떠한 방식으로든' 관리해주는 매니저에 대한 인터페이스이다. 따라서 위 예시의 경우 `piDecimals` 라는 이름의 캐시를 얻고자 하면 `CacheManager.getCache("piDecimals")` 과 같이 하면 될 것이다.

CacheManager 는 아래와 같은 구현체들을 갖고,

<img width="459" height="296" alt="Image" src="https://github.com/user-attachments/assets/078e18b6-e98f-4aad-96be-5acdf4537fb8" />

Cache 는 아래와 같은 구현체들을 갖는다.

<img width="357" height="236" alt="Image" src="https://github.com/user-attachments/assets/0bb94526-1a3b-47c3-ad8a-c970fc72c693" />

### ConcurrentMapCache
아무런 동작을 하지 않는 NoOpCache 를 제외하고 가장 단순해 보이는 ConcurrentMapCache 의 코드 일부를 확인해보자.

```java
public class ConcurrentMapCache extends AbstractValueAdaptingCache {

	private final String name;

	private final ConcurrentMap<Object, Object> store;

    @SuppressWarnings("unchecked")
    @Override
    @Nullable
    public <T> T get(Object key, Callable<T> valueLoader) {
        return (T) fromStoreValue(this.store.computeIfAbsent(key, k -> {
            try {
                return toStoreValue(valueLoader.call());
            }
            catch (Throwable ex) {
                throw new ValueRetrievalException(key, valueLoader, ex);
            }
        }));
    }

    ...

}
```

먼저 `name` 필드를 통해 캐시의 이름을 표현한다. 또한 내부에 `store` 이란 이름의 ConcurrentMap 을 가져 이를 통해 `key-value` 꼴의 데이터를 관리하는 것을 알 수 있다.

```java
@Override
public void evict(Object key) {
    this.store.remove(key);
}
```

캐시를 무효화하는 `evict()` 메소드의 경우도 살펴보면 `store` 맵에 주어진 key 에 해당하는 값을 삭제하는 것을 확인할 수 있다.