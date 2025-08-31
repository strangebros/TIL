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

당연히 github 계정은 이미 되어 있습니다. 테스트용 Repository를 하나 만들어 보겠습니다.

<img width="359" height="168" alt="image" src="https://github.com/user-attachments/assets/1d539eba-9183-43b3-8fcb-e8bb01c97b95" />

이름은 git_local_practice로 하겠습니다.


## 2. 저장소 clone 하고 소스 코드를 변경 후 add, commit, push, pull 해보기

그냥 git 연습만 하려고 하면 md 파일 등으로 하면 되지만, 그래도 Spring을 사용해서 해보려고, 간단하게라도 프로젝트를 만들었습니다.

<img width="770" height="880" alt="image" src="https://github.com/user-attachments/assets/af4e4a4b-c9de-49c6-8f99-1a8cd9d7ff0d" />

아래처럼 Spring Web만 의존성을 넣어서, 최소한의 기능만 돌아가는 프로젝트로 만들었습니다.

그리고, 만들어둔 git저장소를 clone 합니다.

<img width="505" height="91" alt="image" src="https://github.com/user-attachments/assets/cb33cd6f-cb97-4199-8be6-13f5954da25b" />

여기에 Spring initializr로 만든 프로젝트를 넣어 주겠습니다.

프로젝트를 처음 올릴 때는, 그냥 `git add .` 명령어로 전부 추가해서 올려 줬습니다.

<img width="686" height="459" alt="image" src="https://github.com/user-attachments/assets/b52e106b-f166-4f15-b761-ea2a136df600" />

main 브랜치에다 바로 만들었기 때문에, github을 보면 코드들이 바로 올라와 있습니다.

<img width="893" height="429" alt="image" src="https://github.com/user-attachments/assets/d0fb358e-a694-4fea-be19-876359e5691c" />


## 3. branch를 만들고 merge 하고, reset 해보기

터미널에서 브랜치를 만들려면, 다음과 같은 명령어를 입력하면 됩니다.

<img width="322" height="30" alt="image" src="https://github.com/user-attachments/assets/288b47e1-16aa-4596-a98a-19f8a0571477" />

이렇게 하면, 브랜치 생성과 동시에 이동까지 합니다.
물론 아래와 같이 해도 됩니다.

```bash
# 1. 브랜치 생성
git branch test/#1-gitCommandTest

# 2. 브랜치 목록 확인
git branch
# => main
# => test/#1-gitCommandTest   (별표 * 표시된 게 현재 위치 브랜치)

# 3. 새 브랜치로 이동
git checkout test/#1-gitCommandTest

```

파일을 수정한 뒤, add commit을 하고, main 브랜치에 merge 하려면, 아래와 같은 과정을 거치면 됩니다.

<img width="318" height="264" alt="image" src="https://github.com/user-attachments/assets/5726cecc-a613-4494-9a32-29e64a040900" />



## 4. merge, reset, rebase는 대략적인 개념만 알면 됨. 필수는 아님

### git merge

#### 개념
- 두 갈래로 나뉜 브랜치를 합치는 것
- 비유: 두 개의 길(브랜치)을 하나의 길로 합친다 -> 새로운 합류 지점(commit)이 생김

#### 사용 방법

```bash
# main 브랜치에 feature 브랜치를 합치고 싶을 때
git checkout main
git merge feature
```

#### 사용하는 이유
- 여러 사람이 각자 만든 기능(feature 브랜치)을 한 데 모을 때.
- 원래 있던 commit 기록을 그대로 보존하면서 합칠 수 있음.

#### 주의점
- merge commit이 생겨서 히스토리가 복잡해질 수 있음. (특히 작은 수정에도 merge commit이 계속 생김)
- 충돌(conflict)이 발생하면 직접 수정해야 함.

### git reset

#### 개념
- 현재 브랜치의 HEAD(포인터)를 과거 특정 시점으로 되돌리는 것
- 비유: 타임머신 타고 과거로 돌라가기
- 하지만 옵션에 따라 파일 상태가 다르게 됨 (`--soft`, `--mixed`, `--hard`)

#### 사용 방법

```bash
# 바로 전 커밋으로 되돌리기
git reset --hard HEAD~1

# 특정 커밋으로 되돌리기
git reset --hard <commit-id>
```

#### 사용하는 이유

- 잘못된 커밋을 없었던 일로 하고 싶을 때
- 예: 민감한 정보(password 등)를 실수로 commit 했을 때

#### 주의점

- `--hard`는 작업 내용까지 다 날려버리므로 매우 위험!
- 이미 push 한 커밋을 reset하면 절대 안됨(협업 중이면 히스토리가 꼬여버림)
- reset은 로컬 실험용으로만 사용한다고 생각하면 됨

### git rebase

#### 개념

- 내 브랜치의 시작점을 다른 브랜치의 최신 커밋 위로 옮기는 것
- 비유: 줄을 다시 서는 것
- merge가 두 길을 합치는 거라면, rebase는 내 길을 최신 길 뒤에 붙이는 것

#### 사용 방법

```bash
# feature 브랜치를 main 최신 커밋 뒤로 옮기기
git checkout feature
git rebase main
```

#### 사용하는 이유

- commit 기록을 일자로 깔끔하게 만들고 싶을 때
- 마치 혼자 작업한 것처럼 히스토리가 정리됨.

#### 주의점
- 이미 공유된 브랜치에서 rebase 하면 안 됨 (동료들과 commit ID가 달라서 충돌 대참사 가능)
- 내 로컬 feature 브랜치에서만 안전하게 사용해야 함.
- 충돌이 나면 commit 마다 직접 해결해야 해서 번거로움.
