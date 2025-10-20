## 개요

- 제목을 뭐라고 지을지 모르겠습니다...
- 일단, 회사에서 사용하는 서비스의 테스트를 해야 하는데, 로컬에서 테스트를 해야 하는 상황이라서 연계된 서비스에 대해 응답을 받지 못하는 상황입니다.
- 그래서, 인터페이스 명세서를 참고해서, 예상되는 응답을 직접 보내주는 방식을 사용해서 테스트해볼까 합니다.
- 이걸 한 번도 안 해봤기 떄문에, 어떤 방식으로 해야 하는지 공부하면서 기록을 해 보겠습니다.

## 1. hosts 리다이렉트

외부 도메인을 로컬 ip로 보냅니다.

```
127.0.0.1 partner.service.com
```

이제 우리 서비스에서 파트너사의 url로 호출을 때리면, 로컬로 옵니다.

## 2. 순수 자바 단일 파일 HTTP 서버 (JDK 내장 API만)

> JDK 6+에 들어있는 `com.sun.net.httpserver.HttpServer` 사용. Spring/서블릿/톰캣 불필요

`MockPartnerServiceServer.java`
```java
import com.sun.net.httpserver.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class MockResortServer {
    static void sendJson(HttpExchange ex, int status, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        ex.sendResponseHeaders(status, bytes.length);
        try (OutputStream os = ex.getResponseBody()) { os.write(bytes); }
    }

    static String readBody(HttpExchange ex) throws IOException {
        try (InputStream is = ex.getRequestBody()) {
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            byte[] buf = new byte[4096]; int r;
            while ((r = is.read(buf)) != -1) bos.write(buf, 0, r);
            return bos.toString("UTF-8");
        }
    }

    public static void main(String[] args) throws Exception {
        int port = (args.length > 0) ? Integer.parseInt(args[0]) : 8081; // 필요시 80으로
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);

        // GET /api/room/search  (시나리오: ?scenario=empty)
        server.createContext("/api/room/search", ex -> {
            try {
                if (!"GET".equalsIgnoreCase(ex.getRequestMethod())) {
                    sendJson(ex, 405, "{\"error\":\"METHOD_NOT_ALLOWED\"}");
                    return;
                }
                String query = ex.getRequestURI().getQuery();
                boolean empty = (query != null && query.contains("scenario=empty"));
                String json = empty
                        ? "{ \"status\":\"OK\",\"availableRooms\":[],\"message\":\"테스트(빈 결과)\" }"
                        : "{ \"status\":\"OK\",\"availableRooms\":["
                          + "{\"id\":\"R101\",\"name\":\"오션뷰 스위트\",\"price\":200000},"
                          + "{\"id\":\"R102\",\"name\":\"가든뷰 스탠다드\",\"price\":120000}"
                          + "],\"message\":\"테스트(가용 객실)\"}";
                sendJson(ex, 200, json);
            } finally { ex.close(); }
        });

        // POST /api/reservation  (특정 값으로 실패 시뮬레이션)
        server.createContext("/api/reservation", ex -> {
            try {
                if (!"POST".equalsIgnoreCase(ex.getRequestMethod())) {
                    sendJson(ex, 405, "{\"error\":\"METHOD_NOT_ALLOWED\"}");
                    return;
                }
                String body = readBody(ex);
                System.out.println("[예약요청] " + body); // 로깅

                // 단순 분기 예시: body에 "R999" 포함되면 실패
                if (body != null && body.contains("\"roomId\":\"R999\"")) {
                    sendJson(ex, 409, "{ \"status\":\"FAIL\",\"code\":\"ROOM_NOT_AVAILABLE\",\"message\":\"해당 객실은 더 이상 예약 불가(mock)\" }");
                } else {
                    sendJson(ex, 200, "{ \"status\":\"SUCCESS\",\"reservationId\":\"MOCK-RES-12345\",\"message\":\"예약 성공(mock)\" }");
                }
            } finally { ex.close(); }
        });

        // 기본 404
        server.createContext("/", ex -> {
            try { sendJson(ex, 404, "{ \"status\":\"NOT_FOUND\",\"path\":\"" + ex.getRequestURI() + "\" }"); }
            finally { ex.close(); }
        });

        server.setExecutor(null);
        server.start();
        System.out.println("Mock Resort API (HTTP) on port " + port);
        System.out.println("예) http://resort.partner.com:" + port + "/api/room/search");
    }
}
```

### 해당 코드를 컴파일하고 실행하려면 아래와 같이 실행

```bash
javac MockPartnerServiceServer.java
java MockPartnerServiceServer 8081
```

레거시 애플리캐이션이 포트를 못 바꾼다면. 80포트로 실행(`java MockPartnerServiceServer 80`) 하고 관리자 권한으로 띄우기


