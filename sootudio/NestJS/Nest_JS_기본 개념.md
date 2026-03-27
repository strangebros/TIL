## 0. 개요

- 회사 프로젝트로 nestjs를 공부하기로 해서, 공부한 내용을 정리합니다.

## 1. 프로젝트 생성

```bash
npm i -g @nestjs/cli
nest new nest-study
```

패키지 매니저는 **npm 선택 (안정성 기준)**

---

## 2. 기본 구조 생성 (CLI 활용)

```bash
nest g controller users
nest g service users
```

생성 결과:

```
src/
 └── users/
      ├── users.controller.ts
      ├── users.service.ts
      ├── users.controller.spec.ts
      └── users.service.spec.ts
```

추가로 `AppModule`에 자동 등록됨

---

## 3. Controller ↔ Service 연결

### users.controller.ts

```ts
import { Controller, Get } from '@nestjs/common';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  getUsers() {
    return this.usersService.getUsers();
  }
}
```

---

### users.service.ts

```ts
import { Injectable } from '@nestjs/common';

@Injectable()
export class UsersService {
  getUsers() {
    return ['user1', 'user2'];
  }
}
```

---

## 4. 실행 및 확인

```bash
npm run start:dev
```

요청:

```bash
http://localhost:3000/users
```

응답:

```json
["user1", "user2"]
```

---

## 5. 요청 흐름 정리

```
Client → Controller → Service → Response
```

* Controller: 요청을 받는 계층
* Service: 비즈니스 로직 수행

---

## 6. 핵심 관찰 포인트

### 1) Service를 new 하지 않음

```ts
constructor(private readonly usersService: UsersService) {}
```

* 직접 생성하지 않았는데 사용 가능
* NestJS가 객체를 대신 생성 및 주입

👉 **Dependency Injection (DI)**

---

### 2) CLI가 자동으로 해준 것

* Controller 생성
* Service 생성
* AppModule 등록

→ 하지만 **연결 로직은 직접 구현해야 함**

---

## 7. 현재 단계에서 반드시 가져가야 할 질문

* 왜 `new UsersService()`를 안 쓰는가?
* `usersService`는 누가 생성하는가?
* Controller와 Service는 어떻게 연결되는가?
* `AppModule`은 어떤 역할을 하는가?

