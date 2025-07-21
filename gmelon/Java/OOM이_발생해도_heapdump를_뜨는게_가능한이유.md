## 🤔 의문
* OOM 이 발생해서 자바 애플리케이션이 죽었는데 어떻게 heapdump 를 저장할 수 있는걸까?
## heapdump 란
* 실행 중인 JVM의 힙 메모리 상태를 `.hprof` 파일로 저장한 스냅샷
* 메모리 누수, GC 동작, 객체 분석 등에 활용 가능
### java heapdump 방법
* 자바 애플리케이션 실행 시 아래 옵션과 함께 실행
```
-XX:HeapDumpPath=/var/logs/heapdump
```
