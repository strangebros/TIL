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
> 1. [[Spring] 캐시(Cache) 추상화와 사용법(@Cacheable, @CachePut, @CacheEvict)](https://mangkyu.tistory.com/179)
> 2. [[Spring] 스프링이 제공하는 Cache와 CacheManager 쉽고 완벽하게 이해하기](https://mangkyu.tistory.com/370)

### AOP와 추상화

### @Cacheable, @CachePut, @CacheEvict

### Cache 와 CacheManager 의 차이점

### Cache

### CacheManager

