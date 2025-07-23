## 🤔 의문
* 회사 서비스에서 OOM이 발생하면 자동으로 힙덤프를 생성하고, 슬랙 알림을 전송하도록 되어있다.
* 문득 OOM 이 발생해서 자바 애플리케이션이 죽었는데 어떻게 heapdump 를 저장할 수 있는건지 궁금해졌다
## heapdump 란
* 실행 중인 JVM의 힙 메모리 상태를 `.hprof` 파일로 저장한 스냅샷
* 메모리 누수, GC 동작, 객체 분석 등에 활용 가능
### java heapdump 방법
1. 자바 애플리케이션 실행 시 아래 옵션과 함께 실행
```bash
-XX:HeapDumpPath=/var/logs/heapdump
```

2. 또는 아래와 같은 명령어로 실행 중인 자바 프로세스의 heapdump 를 생성할 수 있다.
```bash
jmap -dump:format=b,file=testdump.hprof ${pid}
```

## 자바의 메모리 영역과 영역별 OOM 발생 원인
jvm 메모리는 아래와 같이 구성되어 있다.

![jvm 메모리 구조](https://github.com/user-attachments/assets/bd8ed59a-9dd4-4d59-afc0-05ce4f856242)

### 1. 자바 힙 오버플로
* 자바 힙: 객체 인스턴스를 저장하는 공간
    * 객체를 계속 생성하고 해당 객체들에 대한 접근 경로가 살아있다면 언젠가는 힙의 최대 용량을 넘어서게 됨
    * 실제로 자바 애플리케이션에서 OOM이 가장 많이 발생하는 영역이 자바 힙

* heap OOM 유발 코드
```java
// VM 매개 변수: -Xms20m -Xmx20m -XX:+HeapDumpOnOutOfMemoryError
// (heap size 를 20m 로 제한)
public class HeapOOM {
    static class OOMObject {
    }

    public static void main(String args[]) {
        List<OOMObject> list = new ArrayList<OOMObject>();
        while (true) {
            list.add(new OOMObject());
        }
    }
}
```
* 실행 결과
```
Exception in thread "main" java.lang.OutOfMemoryError: Java heap space
	at com.dwhale.clap.HeapOOM.main(HeapOOM.java:13)

FAILURE: Build failed with an exception.
```

### 2. 가상 머신 스택 & 네이티브 메서드 스택 오버플로


### 3. 메서드 영역 & 런타임 상수 풀 오버플로

### 4. 네이티브 다이렉트 메모리 오버플로
* 다이렉트 메모리의 용량은 `-XX:MaxDirectMemorySize` 매개변수로 설정
  * 따로 설정하지 않으면, `-Xmx` 로 설정한 자바 힙의 최댓값과 같음
* `Unsafe` 를 이용하면 할당할 수 없는 크기를 계산해 오버플로를 수동으로 일으킬 수 있음

* 예제 코드
  * (리플렉션을 통해 Unsafe 인스턴스를 직접 얻어 메모리를 할당받는다)
```java
public class DirectMemoryOOM {
    private static final int _1MB = 1024 * 1024;

    public static void main(String[] args) throws Exception {
        Field unsafeField = Unsafe.class.getDeclaredFields()[0];
        unsafeField.setAccessible(true);
        Unsafe unsafe = (Unsafe) unsafeField.get(null);
        while (true) {
            unsafe.allocateMemory(_1MB);
        }
    }
}
```

* 실행 결과
```bash
Exception in thread "main" java.lang.OutOfMemoryError: Unable to allocate 1048576 bytes
    at java.base/jdk....
    ...
```

* 다이렉트 메모리에서 발생한 OOM의 특징으로는, 힙 덤프에서는 이상한 점을 찾기가 어렵다는 것.
  * 만약 OOM이 발생했는데 힙 덤프 파일이 매우 작거나, 특히 NIO 등을 통해 다이렉트 메모리를 사용한 경우에는, 이 유형의 OOM을 의심해볼 수 있다.

## heapdump 파일 분석 방법