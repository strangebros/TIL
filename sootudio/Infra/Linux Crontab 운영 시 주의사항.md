## 1. 개요

* **Crontab**은 리눅스에서 특정 작업을 **시간 기반으로 자동 실행**하기 위한 스케줄러
* 주로 다음 용도로 사용됨

  * 배치 작업
  * 로그/파일 정리
  * DB 백업
  * 외부 시스템 연계 호출
* 운영 서버 장애의 **주요 원인 중 하나**이며, 특히 특정 시간대 반복 장애와 강하게 연관됨

---

## 2. Crontab 스케줄 형식

```
분  시  일  월  요일
```

예시:

```
0 8 * * *
```

* 매일 오전 8시 0분에 실행
* 서버 시간대(KST/UTC)에 따라 실제 실행 시각이 달라질 수 있음

---

## 3. Crontab 확인 위치 (전수 조사 기준)

### 3.1 사용자 크론탭

```bash
crontab -l
sudo crontab -u root -l
sudo crontab -u <username> -l
```

* 현재 계정 외에도 `root`, 서비스 계정에 크론이 존재하는 경우가 많음

---

### 3.2 시스템 크론탭

#### `/etc/crontab`

```bash
cat /etc/crontab
```

* 사용자 필드가 포함된 시스템 전역 크론

---

#### `/etc/cron.d/`

```bash
ls -l /etc/cron.d/
cat /etc/cron.d/<file>
```

* 패키지 설치 시 자동 등록되는 크론이 위치
* 보안 점검, 백업, 로그 정리 작업이 주로 포함됨

---

### 3.3 주기 디렉토리 기반 크론

```bash
ls -l /etc/cron.hourly/
ls -l /etc/cron.daily/
ls -l /etc/cron.weekly/
ls -l /etc/cron.monthly/
```

* 시간은 `/etc/anacrontab`에 의해 관리됨
* 명시적인 실행 시간이 보이지 않아 추적이 어려움

---

## 4. 실행 스크립트 분석 절차

1. 스크립트 존재 여부 확인

```bash
ls -l /path/to/script.sh
```

2. 내용 확인

```bash
cat /path/to/script.sh
```

3. 실행 권한 확인

```bash
chmod +x script.sh
```

---

## 5. Crontab 실행 환경의 특징 (중요)

### 5.1 PATH 제한

* 크론은 로그인 쉘 환경을 로드하지 않음
* `.bashrc`, `.profile` 등이 적용되지 않음
* **모든 명령은 절대경로 사용 필요**

```bash
/usr/bin/java
/usr/bin/mysql
```

---

### 5.2 권한 및 계정

* 크론은 **등록된 사용자 권한으로 실행**
* 파일/디렉토리 접근 권한 불일치 시 조용히 실패할 수 있음

---

## 6. Crontab 로그 확인

```bash
grep CRON /var/log/syslog
```

---

## 7. 문제 발생 시 점검 체크리스트

* 사용자 크론탭만 확인하고 종료하지 않았는가
* `/etc/cron.d`, `/etc/cron.*` 디렉토리를 확인했는가
* 스크립트가 실제로 존재하는가
* 절대경로를 사용하고 있는가
* 실행 로그가 남는 구조인가
* 서버 시간대(KST/UTC)를 확인했는가

---

## 8. 정리

* `crontab -l`만 확인하는 것은 불충분
* 운영 서버에서는 **크론 전수 조사가 기본 작업**
* 특정 시간대 반복 장애 발생 시, 크론은 최우선 점검 대상
