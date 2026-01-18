## 개요

운영하고 있는 서비스의 인증서가 만료되는 일이 있었다.
수동으로 갱신을 해서 해결한 뒤에, 이전에도 이런 일이 있어 수동 갱신을 했던 기억이 있어서 원인을 찾아보려고 했다.

HTTPS 인증서 만료 시점을 확인하던 중,
외부에서 `openssl s_client`로 인증서 정보를 조회하려 하자 다음과 같은 오류가 발생했다.

```text
Could not read certificate from <stdin>
Unable to load certificate
```

처음에는 **인증서 갱신 실패** 또는 **nginx 설정 문제**로 의심했으나,
실제 원인은 인증서 자체가 아니라 **네트워크 경로와 certbot 자동 갱신 구조**에 있었다.

이 글은

* 인증서가 실제로 갱신되었는지 확인하는 과정
* 외부/내부에서 결과가 달랐던 이유
* certbot 스케줄러가 “돌고는 있지만 실패하고 있던 구조적 문제”
  를 순서대로 정리한 기록이다.

---

## 문제를 파악하기 위해 한 것

### 1. openssl로 인증서 만료일 확인 시도

```bash
echo | openssl s_client -servername my-domain.com -connect my-domain.com:443 \
| openssl x509 -noout -dates
```

→ 결과:

```text
Could not read certificate from <stdin>
```

이 시점에서는

* 인증서 파일이 깨졌는지
* nginx가 인증서를 못 물고 있는지
* HTTPS 자체가 죽어 있는지
  판단이 불가능한 상태였다.

---

### 2. 에러 원인 분리를 위해 네트워크 단계부터 확인

#### (1) DNS 확인

```bash
dig +short my-domain.com
```

→ 단일 IP(`61.98.244.12`)로 정상 해석됨.

#### (2) 443 포트 리스닝 여부 확인

```bash
sudo ss -lntp | grep ':443'
```

→ nginx가 `0.0.0.0:443` 에서 정상 LISTEN 중임을 확인.

이로써:

* nginx 다운 ❌
* 443 미오픈 ❌
  은 배제.

---

### 3. 내부/외부 접속 경로 분리 테스트

#### (1) localhost 기준

```bash
echo | openssl s_client -connect 127.0.0.1:443 -servername my-domain.com \
| openssl x509 -noout -dates
```

→ 정상 출력

```text
notBefore=Jan 15 03:55:17 2026 GMT
notAfter=Apr 15 03:55:16 2026 GMT
```

👉 **인증서는 이미 갱신되어 있고, nginx에도 정상 적용됨**이 확인됨.

---

#### (2) 공인 IP 기준 (같은 서버에서)

```bash
echo | openssl s_client -connect 61.98.244.12:443 -servername my-domain.com \
| openssl x509 -noout -dates
```

→ 다시 실패

```text
Could not read certificate from <stdin>
```

이 시점에서 핵심 결론:

* 인증서 문제 ❌
* nginx 문제 ❌
* **네트워크 레벨 문제** ⭕

---

### 4. Hairpin NAT(Loopback) 이슈 확인

같은 서버에서

* `127.0.0.1` → 성공
* `공인 IP` → 실패

이는 많은 IDC/호스팅 환경에서 **정상적인 정책**인
**Hairpin NAT(자기 공인 IP로 되돌아오는 트래픽 차단)** 패턴과 일치했다.

즉,

> “외부 사용자는 정상 접근 가능하지만,
> 서버 자신은 공인 IP로 다시 접근하지 못하는 구조”

---

### 5. 그럼에도 불안 요소: “다음 갱신은 자동으로 되나?”

인증서는 갱신돼 있었지만,
**자동 갱신 스케줄러가 제대로 동작하는지는 별도 문제**였다.

---

### 6. certbot 스케줄러 상태 확인

```bash
systemctl status certbot.service
systemctl status certbot.timer
```

#### 확인 결과

* `certbot.timer`: active (정상)
* `certbot.service`: **failed**

실패 로그:

```text
Could not bind TCP port 80 because it is already in use
```

---

## 문제 원인

### 1. certbot이 standalone 방식으로 설정돼 있었음

certbot이 갱신 시:

* HTTP-01 챌린지를 위해 **직접 80 포트를 bind**
* 그러나 nginx가 이미 80 포트를 사용 중
* → **갱신 시마다 실패**

즉,

> 스케줄러는 실행되지만
> 구조적으로 성공할 수 없는 상태

---

### 2. 왜 이번에는 인증서가 갱신돼 있었나?

가능성:

* 과거에 **수동으로 certbot을 실행**했거나
* nginx가 내려간 상태에서 **우연히 갱신 성공**

하지만 **자동 갱신 경로는 여전히 실패 상태**였다.

👉 다음 만료 시점에는 100% 재발 가능.

---

# 해결 방안

### 1. certbot 갱신 방식을 nginx 기반으로 전환

standalone 방식 제거 → nginx 플러그인 사용

```bash
sudo certbot renew --nginx --dry-run
```

dry-run 성공 후:

```bash
sudo certbot renew --nginx
```

---

### 2. nginx reload 자동 반영 설정

갱신 후 인증서가 반영되지 않는 상황을 방지하기 위해 deploy hook 추가.

```bash
sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
sudo vi /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
```

```bash
#!/bin/sh
systemctl reload nginx
```

```bash
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
```

---

### 3. 최종 확인

```bash
sudo certbot renew --nginx --dry-run
systemctl list-timers --all | grep certbot
```

→ **자동 갱신 + 반영 경로 정상화**

---

## 정리하며

* 인증서 문제처럼 보이는 이슈의 상당수는 **네트워크/운영 문제**다.
* `certbot.timer`가 active라고 해서 **갱신이 보장되는 것은 아니다**.
* localhost / public IP 테스트는 **문제 범위를 절반 이하로 줄이는 핵심 도구**다.
* 운영 환경에서는 “지금 되는지”보다 **다음에도 자동으로 될지**를 반드시 확인해야 한다.

