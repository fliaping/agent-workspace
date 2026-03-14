#!/bin/bash
# 检查 GitHub Actions 构建状态

REPO="fliaping/agent-workspace"
WORKFLOW="build-webtop.yml"

echo "=== Checking GitHub Actions Status ==="
echo "Repository: $REPO"
echo "Workflow: $WORKFLOW"
echo "Time: $(date)"
echo ""

# 使用 gh CLI 检查最近的 workflow runs
if command -v gh &> /dev/null; then
    echo "Recent workflow runs:"
    gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit 5
    echo ""
    
    # 获取最新运行的状态
    LATEST_RUN=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit 1 --json conclusion,status,headBranch,createdAt -q '.[0]')
    if [ -n "$LATEST_RUN" ]; then
        echo "Latest run:"
        echo "$LATEST_RUN"
    fi
else
    echo "GitHub CLI (gh) not available"
    echo "Please install gh CLI or check manually at:"
    echo "https://github.com/$REPO/actions/workflows/$WORKFLOW"
fi
