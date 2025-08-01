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

### RedisCacheManager
#### 개요
`CacheManager` 의 구현체 중 하나로, 마찬가지로 `Cache` 의 구현체 중 하나인 `RedisCache` 를 지원하는 캐시 매니저이다.
스프링이 추상화된 인터페이스를 제공하기 때문에 사용하는 입장에서는 다른 캐시 매니저를 사용할 때처럼 `@CachePut` 등의 어노테이션으로 조작하거나, `CacheManager.get()` 와 같은 메서드를 동일하게 사용할 수 있다.

#### RedisCacheWriter
Redis 서버와 직접 통신하여 캐시를 읽고 쓰는 역할을 담당

아래와 같은 메서드로 redis 에서 캐시를 읽거나 쓴다.
•	put(String cacheName, byte[] key, byte[] value, Duration ttl): 캐시 저장 및 TTL 지정
•	get(String cacheName, byte[] key): 캐시 조회
•	remove(String cacheName, byte[] key): 단일 키 삭제 (evict)
•	clean(String cacheName, byte[] pattern): 패턴 매칭 전체 삭제

#### RedisCacheConfiguration
RedisCacheConfiguration 라는 구성 클래스를 통해 캐시가 동작하는 방식을 설정해줄 수도 있다.

주요 설정 옵션은 아래와 같다.
•	entryTtl(Duration ttl): 캐시 유효기간 설정
•	computePrefixWith(CacheKeyPrefix prefix): 캐시 키 네임스페이스 지정
•	serializeKeysWith(SerializationPair), serializeValuesWith(SerializationPair): 직렬화 전략 지정
•	disableCachingNullValues(): null 값 캐싱 비활성화

기본 설정을 적용할 수도 있다.
```java
RedisCacheConfiguration.defaultCacheConfig() (무제한 TTL, 키 프리픽스 없음, Jdk 직렬화)
```

#### 설정 예제
```java
RedisCacheConfiguration config = RedisCacheConfiguration.defaultCacheConfig()
    .entryTtl(Duration.ofHours(1))
    .computePrefixWith(CacheKeyPrefix.simple())
    .serializeValuesWith(RedisSerializationContext.SerializationPair
        .fromSerializer(new GenericJackson2JsonRedisSerializer()))
    .disableCachingNullValues();

RedisCacheManager cacheManager = RedisCacheManager.builder(connectionFactory)
    .cacheDefaults(config)
    .build();
```

## Redis 캐시 실전!
### 먼저 설정
#### compose.yml
```yml
name: redis_cache
services:
  cache:
    container_name: redis
    image: redis:6.2.6
    ports:
      - '127.0.0.1:6379:6379'
  # db 는 hashMap 으로 대체
```

#### application.yml
```yml
spring:
  cache:
    type: redis
  data.redis:
    host: localhost
    port: 6379
```

#### RedisCacheConfig
```java
@Configuration
@EnableCaching // 캐싱 기능 활성화
public class RedisCacheConfig {

    @Bean
    public RedisConnectionFactory redisConnectionFactory() {
        return new LettuceConnectionFactory();
    }

    @Bean
    public RedisCacheManager cacheManager(RedisConnectionFactory factory) {
        RedisCacheConfiguration config = RedisCacheConfiguration.defaultCacheConfig()
                .serializeValuesWith(RedisSerializationContext.SerializationPair
                        .fromSerializer(new GenericJackson2JsonRedisSerializer())) // jaskson 을 사용해 value 를 직렬화 할 수 있도록 해준다
                .entryTtl(Duration.ofMinutes(10)) // TTL은 10분으로 설정
                .disableCachingNullValues();

        return RedisCacheManager.builder(factory)
                .cacheDefaults(config)
                .build();
    }
}
```

### Controller
```java
@RequiredArgsConstructor
@RequestMapping("/api/v1/users")
@RestController
public class UserController {

    private final UserService userService;

    @GetMapping("/{id}")
    public UserDto getUser(@PathVariable Long id) {
        return userService.getUser(id);
    }

    @PutMapping("/{id}")
    public void updateUser(@PathVariable Long id, @RequestBody UserDto user) {
        userService.updateUser(id, user);
    }

    public record UserDto(Long id, String name) {

        public User toEntity() {
            User user = new User();
            user.setId(id);
            user.setName(name);
            return user;
        }

        public static UserDto from(User user) {
            return new UserDto(user.getId(), user.getName());
        }

    }

}
```

### Service
```java
@RequiredArgsConstructor
@Service
public class UserService {

    private final UserRepository userRepository;

    @Cacheable(value = "users", key = "#id") // 캐싱
    public UserDto getUser(Long id) {
        User user = userRepository.findById(id);
        if (user == null) {
            throw new ResponseStatusException(NOT_FOUND);
        }
        return UserDto.from(user);
    }

    @CacheEvict(value = "users", key = "#id") // 유저 정보 수정 시 캐시 삭제
    public void updateUser(Long id, UserDto user) {
        if (user.id() == null || !user.id().equals(id)) {
            throw new ResponseStatusException(BAD_REQUEST, "User ID mismatch");
        }
        userRepository.save(user.toEntity());
    }

}
```

### Repository
레포지토리는 간단하게 HashMap 을 사용해서 구현한 것을 사용했다.
```java
@Repository
public class UserRepository {

    private final ConcurrentHashMap<Long, User> store = new ConcurrentHashMap<>();

    @SneakyThrows
    public User findById(Long id) {
        Thread.sleep(500); // db 접근 오버헤드를 모사
        return store.get(id);
    }

    public void save(User user) {
        store.put(user.getId(), user);
    }

}
```

### 응답 테스트
자 그럼 이제 테스트를 해보자!

먼저 유저 정보를 저장하고 최초 조회를 해보자

#### 유저 저장
<img width="650" height="286" alt="Image" src="https://github.com/user-attachments/assets/f60492ca-0006-419a-9f53-b28914cbb5fb" />

#### 최초 조회
`Thread.sleep()` 을 설정해둔 만큼 지연 시간이 걸린 것을 확인할 수 있다.
<img width="1112" height="511" alt="Image" src="https://github.com/user-attachments/assets/4c841750-d1de-487f-9746-b321aaeb90e2" />

#### 다시 조회
하지만 다시 동일한 유저에 대해 조회를 해보면?

<img width="1113" height="509" alt="Image" src="https://github.com/user-attachments/assets/46dca88e-e433-4a70-8809-237c0d814849" />

레포지토리를 타지 않고 레디스에서 바로 값을 꺼내오기 때문에 `Thread.sleep()` 가 수행되지 않고 굉장히 빠르게 응답되는 것을 확인할 수 있다.

#### 유저 정보 수정
그럼 이제 유저 정보를 수정해서 캐시를 무효화 시켜보자.
<img width="1112" height="279" alt="Image" src="https://github.com/user-attachments/assets/ede2a3ba-8167-430e-8a0b-a18975c4fafe" />

#### 수정 후 재조회
예상할 수 있는 것처럼, 이제 캐싱된 값이 사라졌기 때문에 다시 500ms 가 추가로 소요되는 것을 확인할 수 있다.
<img width="1115" height="508" alt="Image" src="https://github.com/user-attachments/assets/fefafdd5-6511-47e5-bbbd-966d5f8a857e" />

#### redis 조회
redis cli 를 통해 조회해보면 애플리케이션에서 저장한 캐시가 로컬에서 실행한 redis 에 잘 저장되어 있는 것을 확인할 수 있다.

```bash
localhost:6379> KEYS *
1) "users::1"

localhost:6379> TYPE users::1
string

localhost:6379> GET users::1
"{\"@class\":\"com.redis.sample.redis_cache.controller.UserController$UserDto\",\"id\":1,\"name\":\"\xeb\x82\x98\xeb\x8a\x94 \xeb\xb3\x80\xea\xb2\xbd\xeb\x90\x9c 1\xeb\xb2\x88 \xec\x9c\xa0\xec\xa0\x80\"}"
```

redis 의 기본 설정을 사용하면 `cacheName::key` 형식으로 저장되기 때문에, 실제 데이터도 `users::1` 의 형식으로 저장된 것을 확인할 수 있다.
해당 key 에 대한 value 는 jackson 을 통해 직렬화된 UserDto 객체임도 확인할 수 있다.

<img width="717" height="442" alt="Image" src="https://github.com/user-attachments/assets/82598e84-f096-4da4-af6d-c1a09935b7ed" />

#### null value
위의 설정을 통해, 현재는 null value 에 대한 캐싱을 허용하지 않았기 때문에 저장되지 않은 유저에 대한 조회 시 계속해서 500ms 이상이 소요되는 것도 확인할 수 있었다.
<img width="1120" height="516" alt="Image" src="https://github.com/user-attachments/assets/93443c16-8a7f-4e95-952a-17d2e53ae4a7" />

## 느낀점
간단하게 스프링에서 제공하는 캐시와 구현체에 대해 살펴보았다. 실전에서 캐시를 사용하려면 캐시를 어떻게 저장하고 불러올지 보다는, 어떻게 기존 캐시를 무효화할지가 훨씬 중요하겠다는 생각이 들었다. 또한 키 값을 유일한 식별자로 잘 지정하지 않으면, 다른 유저의 정보를 조회하기가 너무 쉬운 구조인 것 같아서 이 부분에 유의해서 사용해야 할 것 같다.

실제로 사용하게 된다면, 생각보다 캐시를 무효화해야 하는 지점들이 되게 많아질 것 같아서 이 부분을 고도화하고 잘 관리하는 게 관건일 것 같다.