#!/usr/bin/env bash

# ==============================================================================
# 常量配置区
# ==============================================================================
TARGET_COMMIT="93e36ad26fdec902b614cff2b5fb404666388c05"
PATCH_FILE="/home/asogii/w/NonGKI_Kernel_Build_2nd/Patches/Patch/susfs_patch_to_4.4.patch"
TEMP_BRANCH="ni_$(date +%y%m%d)"               # 格式: ni_YYMMDD，例如 ni_261031
COMMIT_MSG="susfs patch to 4.4 with rej"       # 有 .rej 变化需要保留分支时的提交信息
# ==============================================================================

set -u

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # 恢复默认颜色

# 打印辅助函数
print_step()    { echo -e "\n${BOLD}${BLUE}==> $1${NC}"; }
print_info()    { echo -e "${CYAN}    $1${NC}"; }
print_success() { echo -e "${BOLD}${GREEN}[✓] $1${NC}"; }
print_warn()    { echo -e "${BOLD}${YELLOW}[!] $1${NC}"; }
print_error()   { echo -e "${BOLD}${RED}[✗] $1${NC}" >&2; }

HAS_STASHED=0
STASH_MSG="auto_stash_by_check_patch_change_$(date +%Y%m%d_%H%M%S)"
ORIG_REF=""
ORIG_COMMIT=""
CLEANED_UP=0

# 异常中断（如 Ctrl+C）时的安全提示函数
on_interrupt() {
    echo ""
    print_error "检测到脚本被中断！"
    if [ "${CLEANED_UP}" -eq 0 ] && [ -n "${ORIG_REF}" ]; then
        print_warn "当前可能处于分离头指针或临时分支状态，如需手动还原请执行："
        if [ "${HAS_STASHED}" -eq 1 ]; then
            print_info "${BOLD}git reset --hard && git clean -fd && git checkout ${ORIG_REF} && git stash pop --index${NC}"
        else
            print_info "${BOLD}git reset --hard && git clean -fd && git checkout ${ORIG_REF}${NC}"
        fi
    fi
    exit 130
}
trap on_interrupt INT TERM

# 1. 检查当前目录是否为有效的 Git 仓库并记录当前状态
print_step "步骤 1/5: 检查当前目录 Git 状态与参数"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_error "错误: 当前目录 ($(pwd)) 不是有效的 Git 仓库"
    exit 1
fi

ORIG_REF=$(git symbolic-ref --short -q HEAD || git rev-parse HEAD)
ORIG_COMMIT=$(git rev-parse HEAD)
if [ -z "${ORIG_REF}" ]; then
    print_error "错误: 无法获取当前 Git HEAD 状态"
    exit 1
fi
print_info "当前工作目录: $(pwd)"
print_info "已记录初始分支/Commit: ${BOLD}${ORIG_REF}${NC} (${ORIG_COMMIT:0:12})"
print_info "预设临时分支名称: ${BOLD}${TEMP_BRANCH}${NC}"

# 校验指定的 TARGET_COMMIT 及其父 commit 是否存在
if ! git rev-parse --verify "${TARGET_COMMIT}~1" >/dev/null 2>&1; then
    print_error "错误: 无法找到指定的 commit (${TARGET_COMMIT}) 或其上一个 commit (${TARGET_COMMIT}~1)"
    exit 1
fi

# 校验 patch 文件是否存在
if [ ! -f "${PATCH_FILE}" ]; then
    print_error "错误: 找不到指定的 patch 文件: ${PATCH_FILE}"
    exit 1
fi

# 2. 保护当前工作区修改并切换到 TARGET_COMMIT~1（分离头指针模式，按需再建分支）
print_step "步骤 2/5: 保护当前工作区修改并切换到 ${TARGET_COMMIT:0:12}~1"
if [ -n "$(git status --porcelain)" ]; then
    print_info "检测到当前存在未提交的修改（staged / 未 add / untracked），正在执行 git stash..."
    git stash push --include-untracked -m "${STASH_MSG}" || {
        print_error "错误: git stash 保存当前修改失败"
        exit 1
    }
    HAS_STASHED=1
    print_success "已将当前修改安全暂存至 stash (${STASH_MSG})"
else
    print_info "当前工作区干净，无需 stash。"
fi

git checkout --detach "${TARGET_COMMIT}~1" || {
    print_error "错误: 切换到 ${TARGET_COMMIT}~1 失败"
    if [ "${HAS_STASHED}" -eq 1 ]; then
        print_warn "注意: 你之前的修改已被暂存在 git stash 中（${STASH_MSG}），可执行 'git stash pop --index' 恢复。"
    fi
    exit 1
}
print_success "已切换到基准父提交: $(git rev-parse --short HEAD) (detached HEAD)"

# 3. 应用指定位置的 patch 并暂存所有修改（强制包含可能被 .gitignore 忽略的 .rej 文件）
print_step "步骤 3/5: 应用 Patch 并暂存到 Stage 区"
git apply --reject -p1 "${PATCH_FILE}"
APPLY_STATUS=$?
if [ ${APPLY_STATUS} -ne 0 ]; then
    print_warn "git apply 返回非零状态码 (${APPLY_STATUS})，已生成 .rej 文件，继续暂存并对比 .rej 差异..."
else
    print_success "Patch 应用顺利完成（无冲突返回码）"
fi

git add -A
# 强制将所有生成的 .rej 文件加入暂存区，防止被仓库 .gitignore 忽略而漏检
REJ_FILES=$(find . -name "*.rej" -not -path "./.git/*")
if [ -n "${REJ_FILES}" ]; then
    # shellcheck disable=SC2086
    git add -f ${REJ_FILES}
fi
print_success "已将所有 Patch 改动及 .rej 文件加入 Stage 暂存区"

# 4. 直接比较暂存区 (staged) 与目标提交 (TARGET_COMMIT)
print_step "步骤 4/5: 比较当前 Stage 暂存区与目标提交 (${TARGET_COMMIT:0:12}) 的差异"
echo -e "${BOLD}------------------------------------------------------------------------------${NC}"
DIFF_OUTPUT=$(git diff --cached --name-status "${TARGET_COMMIT}")
if [ -n "${DIFF_OUTPUT}" ]; then
    while IFS= read -r line; do
        if [[ "${line}" == *.rej ]]; then
            echo -e "${BOLD}${RED}${line}  <-- [.rej 文件变化]${NC}"
        else
            echo -e "${CYAN}${line}${NC}"
        fi
    done <<< "${DIFF_OUTPUT}"
else
    echo -e "${GREEN}（无任何文件差异）${NC}"
fi
echo -e "${BOLD}------------------------------------------------------------------------------${NC}"

# 5. 只检查比较结果中有没有 .rej 文件的变化（忽略普通文件的差异）
print_step "步骤 5/5: 检查 .rej 文件变化并处理分支状态"
if echo "${DIFF_OUTPUT}" | grep -q '\.rej$'; then
    print_warn "检查结果：【有变化】检测到存在 .rej 文件的变化！"

    # 检查临时分支是否已存在，询问用户是否删除 (Y/n)
    if git show-ref --verify --quiet "refs/heads/${TEMP_BRANCH}"; then
        print_warn "检测到同名临时分支 '${TEMP_BRANCH}' 已存在！"
        read -r -p "$(echo -e "${YELLOW}是否删除已存在的分支 '${TEMP_BRANCH}' 并继续创建？(Y/n): ${NC}")" CONFIRM
        CONFIRM=${CONFIRM:-Y}
        case "${CONFIRM}" in
            [Yy]|[Yy][Ee][Ss])
                # 如果初始状态正好在 TEMP_BRANCH 上，将还原参考更新为初始 commit hash
                if [ "${ORIG_REF}" = "${TEMP_BRANCH}" ]; then
                    ORIG_REF="${ORIG_COMMIT}"
                fi
                print_info "正在删除旧的临时分支 '${TEMP_BRANCH}'..."
                git branch -D "${TEMP_BRANCH}" || {
                    print_error "错误: 删除分支 '${TEMP_BRANCH}' 失败"
                    if [ "${HAS_STASHED}" -eq 1 ]; then
                        print_warn "注意: 你之前的修改已被暂存在 git stash 中（${STASH_MSG}）。"
                    fi
                    exit 1
                }
                ;;
            *)
                print_error "用户取消删除已存在的临时分支 '${TEMP_BRANCH}'，脚本终止。"
                print_info "当前改动仍保留在分离头指针 (detached HEAD) 的暂存区中。"
                if [ "${HAS_STASHED}" -eq 1 ]; then
                    print_warn "重要提示：你之前未提交的修改已保存在 git stash 中（${STASH_MSG}）！"
                    print_info "如需放弃当前对比并还原，请执行: ${BOLD}git reset --hard && git clean -fd && git checkout ${ORIG_REF} && git stash pop --index${NC}"
                fi
                exit 1
                ;;
        esac
    fi

    print_info "正在创建并切换到临时分支: ${BOLD}${TEMP_BRANCH}${NC}"
    git checkout -b "${TEMP_BRANCH}" || {
        print_error "错误: 创建临时分支 '${TEMP_BRANCH}' 失败"
        exit 1
    }

    print_info "正在提交当前更改，Commit Message: '${COMMIT_MSG}'"
    git commit --allow-empty -m "${COMMIT_MSG}" || {
        print_error "错误: git commit 失败"
        exit 1
    }
    CLEANED_UP=1
    print_success "已保留临时分支 ${BOLD}${TEMP_BRANCH}${NC} 并完成提交 ($(git rev-parse --short HEAD))，方便直接处理 .rej 变化！"

    if [ "${HAS_STASHED}" -eq 1 ]; then
        echo ""
        print_warn "重要提示：由于保留了临时分支未还原 Git 状态，你之前未提交的修改（含 staged 和未 add 的修改）已保存在 git stash 中！"
        print_info "Stash 标识: ${BOLD}${STASH_MSG}${NC}"
        print_info "后续排查完毕切回 ${BOLD}${ORIG_REF}${NC} 后，请执行以下命令恢复原修改及暂存状态："
        print_info "${BOLD}git checkout ${ORIG_REF} && git stash pop --index${NC}"
    fi
else
    print_success "检查结果：【没变化】未检测到 .rej 文件的变化（普通文件差异已忽略）。"
    print_info "正在清空临时暂存区并切回初始状态 ${BOLD}${ORIG_REF}${NC}（无需创建临时分支）..."
    git reset --hard >/dev/null 2>&1
    git clean -fd >/dev/null 2>&1
    git checkout "${ORIG_REF}" || {
        print_error "错误: 切回 ${ORIG_REF} 失败"
        exit 1
    }
    if [ "${HAS_STASHED}" -eq 1 ]; then
        print_info "正在从 git stash 恢复之前的 staged 及未 add 的文件修改..."
        if git stash pop --index >/dev/null 2>&1; then
            print_success "已完整还原之前的 staged 状态与未 add 的文件修改！"
        else
            print_warn "使用 --index 恢复时遇到冲突，正在尝试直接 git stash pop..."
            git stash pop
        fi
    fi
    CLEANED_UP=1
    print_success "已完全还原 Git 状态。"
fi