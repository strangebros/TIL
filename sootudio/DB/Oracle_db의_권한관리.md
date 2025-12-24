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

## 2. 계정별 '함수/프로시저 생성 수정' 권한 확인

- 함수는 권한 관점에서 `PROCEDURE` 카테고리로 묶입니다. (Oracle에서 `CREATE PROCEDURE` 권한이 function/procedure/package 생성에 사용됨)

### 2-1. 시스템 권한(직접 grant)

```sql
SELECT grantee, privilege, admin_option
FROM   DBA_SYS_PRIVS
WHERE  grantee IN ('계정A','계정B')
AND    privilege IN (
  'CREATE PROCEDURE',
  'CREATE ANY PROCEDURE',
  'ALTER ANY PROCEDURE',
  'DROP ANY PROCEDURE',
  'EXECUTE ANY PROCEDURE'
)
ORDER BY grantee, privilege;
```

### 2-2. 롤을 통해 부여된 시스템 권한 

```sql
SELECT rp.grantee, rp.granted_role, sp.privilege
FROM   DBA_ROLE_PRIVS rp
JOIN   ROLE_SYS_PRIVS sp
       ON rp.granted_role = sp.role
WHERE  rp.grantee IN ('계정A','계정B')
AND    sp.privilege IN (
  'CREATE PROCEDURE',
  'CREATE ANY PROCEDURE',
  'ALTER ANY PROCEDURE',
  'DROP ANY PROCEDURE',
  'EXECUTE ANY PROCEDURE'
)
ORDER BY rp.grantee, rp.granted_role, sp.privilege;
```

해석 기준

- 자기 스키마에 함수/프로시저 생성: `CREATE PROCEDURE`
- 다른 스키마에 생성/수정: 보통 `CREATE ANY PROCEDURE`, `ALTER ANY PROCEDURE`같은 "ANY" 권한 필요
- 수정(ALTER): 보통 자기 스키마 객체는 소유자가 ALTER 가능하지만, 타 스키마는 `ALTER ANY PROCEDURE` 필요
- 실행: `EXECUTE` (오브젝트 권한) 또는 `EXECUTE ANY PROCEDURE`(시스템 권한)
