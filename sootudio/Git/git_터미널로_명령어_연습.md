## 개요

**ATDD in Legacy Code**과정에 대한 메일을 받았는데, 다음과 같은 내용이 있었습니다.

```text
교육 참가하기 전에 경험해 봤으면 하는 내용은 다음과 같습니다.
1. github에 계정 만들고, 저장소 만들어 보기
2. 저장소 clone 하고 소스 코드를 변경 후 add, commit, push, pull 해보기
3. branch를 만들고 merge 하고, reset 해보기
4. merge, reset, rebase는 대략적인 개념만 알면 됨. 필수는 아님
```

일단 이미 다 해본거긴 하지만, 한 가지 더 권장 사항이 있었습니다

```
git 연습은 가능하면 터미널에서 직접 명령어를 실행해 연습할 것을 추천합니다.
```

제가 사실 그 동안 git을 쓸때, 브랜치 이동이나 push 작업 말고는, 전부 IDE에서 제공하는 인터페이스를 쓰거나, 깃헙 인터페이스로 작업을 했기 때문에, 이 부분에 있어 추가적인 학습이 필요하다고 느꼈습니다.
TIL Repository로 연습할까 하다가, 저 혼자 사용하는 곳이 아니기에...ㅎㅎㅎ 그냥 테스트용 Repo를 하나 만들어서 해보려고 합니다.

## 1. github에 계정 만들고, 저장소 만들어 보기

당연히 github 계정은 이미 되어 있습니다. 테스트용 Repository를 하나 만들어 보겠습니다
<img width="359" height="168" alt="image" src="https://github.com/user-attachments/assets/1d539eba-9183-43b3-8fcb-e8bb01c97b95" />

이름은 git_local_practice로 하겠습니다.


## 2. 저장소 clone 하고 소스 코드를 변경 후 add, commit, push, pull 해보기

그냥 git 연습만 하려고 하면 md 파일 등으로 하면 되지만, 그래도 Spring을 사용해서 해보려고, 간단하게라도 프로젝트를 만들었습니다.

<img width="770" height="880" alt="image" src="https://github.com/user-attachments/assets/af4e4a4b-c9de-49c6-8f99-1a8cd9d7ff0d" />

아래처럼 Spring Web만 의존성을 넣어서, 최소한의 기능만 돌아가는 프로젝트로 만들었습니다.


## 3. branch를 만들고 merge 하고, reset 해보기

## 4. merge, reset, rebase는 대략적인 개념만 알면 됨. 필수는 아님

### merge

### reset

### rebase