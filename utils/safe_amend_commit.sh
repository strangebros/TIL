#!/bin/bash

# 색상 코드 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 사용법 출력 함수
usage() {
    echo "사용법: $0 \"커밋 메시지\" [날짜/시간]"
    echo ""
    echo "예시:"
    echo "  $0 \"feat: 새로운 기능 추가\""
    echo "  $0 \"fix: 버그 수정\" \"2024-01-15 14:30:00\""
    echo "  $0 \"docs: README 업데이트\" \"yesterday\""
    echo "  $0 \"refactor: 코드 정리\" \"2 days ago\""
    echo ""
    echo "날짜 형식:"
    echo "  - YYYY-MM-DD HH:MM:SS"
    echo "  - yesterday, today"
    echo "  - 2 days ago, 3 hours ago"
    exit 1
}

# 인자 체크
if [ $# -lt 1 ]; then
    usage
fi

COMMIT_MSG="$1"
COMMIT_DATE="${2:-$(date '+%Y-%m-%d %H:%M:%S')}"  # 날짜가 없으면 현재 시간 사용

echo -e "${GREEN}=== 안전한 커밋 프로세스 시작 ===${NC}"
echo -e "커밋 메시지: ${YELLOW}$COMMIT_MSG${NC}"
echo -e "커밋 날짜: ${YELLOW}$COMMIT_DATE${NC}"
echo ""

# 1. 현재 브랜치 확인
CURRENT_BRANCH=$(git branch --show-current)
echo -e "${GREEN}[1/7]${NC} 현재 브랜치: ${YELLOW}$CURRENT_BRANCH${NC}"

# 2. 변경사항이 있는지 확인
if [ -z "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}⚠️  변경사항이 없습니다. 종료합니다.${NC}"
    exit 0
fi

# 3. 현재 작업 내용 stash
echo -e "${GREEN}[2/7]${NC} 현재 작업 내용을 임시 저장합니다..."
STASH_MSG="auto-stash-$(date +%s)"
git stash push -m "$STASH_MSG" --include-untracked

# stash가 실제로 생성되었는지 확인
STASH_CREATED=$?
if [ $STASH_CREATED -eq 0 ]; then
    echo -e "  ✓ 작업 내용이 stash에 저장되었습니다."
else
    echo -e "${RED}  ✗ Stash 실패. 이미 커밋된 상태일 수 있습니다.${NC}"
fi

# 4. 최신 변경사항 pull
echo -e "${GREEN}[3/7]${NC} 원격 저장소에서 최신 변경사항을 가져옵니다..."
git pull --rebase

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Pull 실패! Conflict가 발생했을 수 있습니다.${NC}"
    
    # stash가 생성되었었다면 복원
    if [ $STASH_CREATED -eq 0 ]; then
        echo -e "${YELLOW}작업 내용을 복원합니다...${NC}"
        git stash pop
    fi
    
    echo -e "${RED}수동으로 conflict를 해결한 후 다시 시도해주세요.${NC}"
    exit 1
fi

echo -e "  ✓ Pull 완료"

# 5. Stash pop (stash가 생성되었었다면)
if [ $STASH_CREATED -eq 0 ]; then
    echo -e "${GREEN}[4/7]${NC} 저장된 작업 내용을 복원합니다..."
    git stash pop
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Stash pop 실패! Conflict가 발생했을 수 있습니다.${NC}"
        echo -e "${YELLOW}수동으로 conflict를 해결한 후 다음 명령어를 실행하세요:${NC}"
        echo -e "  git add ."
        echo -e "  git commit -m \"$COMMIT_MSG\""
        echo -e "  git commit --amend --date=\"$COMMIT_DATE\" --no-edit"
        echo -e "  git push --force-with-lease"
        exit 1
    fi
    echo -e "  ✓ 작업 내용 복원 완료"
else
    echo -e "${GREEN}[4/7]${NC} Stash할 내용이 없어 건너뜁니다."
fi

# 6. 모든 변경사항 스테이징
echo -e "${GREEN}[5/7]${NC} 변경사항을 스테이징합니다..."
git add .
echo -e "  ✓ 스테이징 완료"

# 7. 커밋
echo -e "${GREEN}[6/7]${NC} 커밋을 생성합니다..."
git commit -m "$COMMIT_MSG"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 커밋 실패!${NC}"
    exit 1
fi
echo -e "  ✓ 커밋 생성 완료"

# 8. 날짜 수정 (amend)
echo -e "${GREEN}[7/7]${NC} 커밋 날짜를 수정합니다..."
GIT_COMMITTER_DATE="$COMMIT_DATE" git commit --amend --date="$COMMIT_DATE" --no-edit

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 날짜 수정 실패!${NC}"
    exit 1
fi
echo -e "  ✓ 날짜 수정 완료"

# 9. Push (force-with-lease 사용으로 더 안전하게)
echo -e "${GREEN}[8/8]${NC} 원격 저장소에 푸시합니다..."
echo -e "${YELLOW}  ⚠️  force-with-lease를 사용하여 안전하게 푸시합니다...${NC}"

git push --force-with-lease

if [ $? -eq 0 ]; then
    echo -e "  ✓ 푸시 완료!"
    echo ""
    echo -e "${GREEN}=== ✨ 모든 작업이 성공적으로 완료되었습니다! ===${NC}"
    
    # 최종 커밋 정보 표시
    echo ""
    echo -e "${GREEN}커밋 정보:${NC}"
    git log -1 --pretty=format:"  해시: %H%n  작성자: %an <%ae>%n  날짜: %ad%n  메시지: %s" --date=format:"%Y-%m-%d %H:%M:%S"
else
    echo -e "${RED}✗ 푸시 실패!${NC}"
    echo -e "${YELLOW}원격 저장소가 변경되었을 수 있습니다. 다시 pull 후 시도해주세요.${NC}"
    exit 1
fi