## 0. 시작

- Oracle DB에서 Function, 즉 프로시저를 실행시킬 일이 있었는데,`ORA-01031` 이라는 오류가 나왔습니다.
- 해당 오류는 권한 부족으로 생기는 오류였는데요, 사용하는 계정의 실행 권한들을 정확히 모르고 있어서, 이참에 확인하기로 했습니다.

## 1. 로그인한 계정의 권한 확인

-Oracle db에서 권한을 확인하는 방법은 다음과 같습니다.

### 1.1. 현재 세션이 실제로 사용 가능한 시스템 권한

```sql
SELECT * FROM SESSION_PRIVS ORDER BY privilege;
```

### 1.2. 현재 세션이 사용 가능한 롤

```sql
SELECT * FROM SESSION_ROLES ORDER BY role;
```