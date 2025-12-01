### 개요

- 네, 오늘도 회사에서 모르는 게 생겼습니다.
- HTTP/Servlet 기준으로 IP의 포트가 어떻게 전달 되는가?
- 뭔가 단순 생각으로는 안 적으면 기본값, 적으면 해당 값? 정도로 생각했는데, 확신은 없었습니다.
- 그러면... 공부해야겠죠?

### 공식 문서

- HTTP 통신의 규약에 대한 내용은 해당 문서에서 찾아볼 수 있습니다.

> RFC 3986 - Uniform Resource Identifier (URI): Generic Syntax)

- 해당 문서는 IETF(인터넷 표준 만드는 집단)에서 만든 표준 문서(Standards Track) 입니다.
    - HTTPClient, 브라우저, 서버 프레임워크들은 "우리는 RFC 3986을 따른다"를 전제로 URL/URI 파서를 구현합니다.
- 해당 문서의 **Section 3.2: Authority** 의 **Section 3.2.3: Port** 에 보면 다음과 같은 내용이 나와 있습니다.

> ... A scheme may define a default port.  For example, the "http" scheme
   defines a default port of "80", corresponding to its reserved TCP
   port number.  ...

- 해당 내용은
    1. 각 스킴(HTTP, HTTPS)는 자신만의 기본 포트(80, 443)을 정의할 수 있고
    2. 포트를 안 쓰면(생략하면) 그 스킴의 기본 포트를 사용한다.

- 이를 통해, 역으로 포트를 쓰면, 기본 포트가 아닌 쓰여진 포트를 사용하는 것을 알 수 있습니다.
- 추가적으로, 포트를 안 쓰면 해당 스킴의 기본 포트가 적용되기 때문에, 스킴의 기본 포트를 기재하여 사용하는 것은 권장히지 않는다고 나와 있습니다.
