#!/bin/bash
# bake_deps.sh — Interactive script to add all custom node dependencies to pyproject.toml
# Usage: bash bake_deps.sh

set -e

CUSTOM_NODES_DIR="custom_nodes"
FAILED=()
SUCCEEDED=()
SKIPPED=()

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  ComfyUI Dependency Baker${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Collect all nodes with requirements.txt
NODES=()
for dir in "$CUSTOM_NODES_DIR"/*/; do
    [ ! -d "$dir" ] && continue
    node_name=$(basename "$dir")
    [ "$node_name" = "__pycache__" ] && continue
    if [ -f "$dir/requirements.txt" ]; then
        NODES+=("$node_name")
    fi
done

TOTAL=${#NODES[@]}
echo -e "Found ${CYAN}${TOTAL}${NC} custom nodes with requirements.txt"
echo ""

i=0
for node_name in "${NODES[@]}"; do
    i=$((i + 1))
    req_file="$CUSTOM_NODES_DIR/$node_name/requirements.txt"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "[${i}/${TOTAL}] ${YELLOW}${node_name}${NC}"
    echo -e "  File: ${req_file}"
    echo -e "  Contents:"
    # Show requirements (stripped of blank/comment lines)
    grep -v '^\s*$\|^\s*#' "$req_file" 2>/dev/null | sed 's/^/    /' || echo "    (empty)"
    echo ""

    while true; do
        echo -en "  ${GREEN}[a]${NC}dd deps  ${YELLOW}[s]${NC}kip  ${RED}[q]${NC}uit → "
        read -r choice

        case "$choice" in
            a|A)
                echo -e "  Running: ${CYAN}uv add -r ${req_file}${NC}"
                if uv add -r "$req_file" 2>&1 | sed 's/^/    /'; then
                    echo -e "  ${GREEN}✓ Success${NC}"
                    SUCCEEDED+=("$node_name")
                else
                    echo ""
                    echo -e "  ${RED}✗ Failed!${NC}"
                    echo ""
                    while true; do
                        echo -en "  ${GREEN}[r]${NC}etry  ${YELLOW}[s]${NC}kip  ${RED}[m]${NC}anual fix (opens shell)  → "
                        read -r fix_choice
                        case "$fix_choice" in
                            r|R)
                                if uv add -r "$req_file" 2>&1 | sed 's/^/    /'; then
                                    echo -e "  ${GREEN}✓ Success on retry${NC}"
                                    SUCCEEDED+=("$node_name")
                                else
                                    echo -e "  ${RED}✗ Still failing${NC}"
                                    continue
                                fi
                                ;;
                            s|S)
                                echo -e "  ${YELLOW}⊘ Skipped${NC}"
                                SKIPPED+=("$node_name")
                                ;;
                            m|M)
                                echo -e "  ${CYAN}Opening subshell. Fix the issue, then type 'exit' to return.${NC}"
                                echo -e "  ${CYAN}Tip: You can manually edit pyproject.toml or run uv add <pkg>${NC}"
                                bash
                                echo -e "  ${CYAN}Returned from subshell.${NC}"
                                continue
                                ;;
                            *)
                                echo "  Invalid choice"
                                continue
                                ;;
                        esac
                        break
                    done
                fi
                break
                ;;
            s|S)
                echo -e "  ${YELLOW}⊘ Skipped${NC}"
                SKIPPED+=("$node_name")
                break
                ;;
            q|Q)
                echo -e "\n${RED}Aborted.${NC}"
                exit 1
                ;;
            *)
                echo "  Invalid choice. Use a/s/q."
                ;;
        esac
    done
    echo ""
done

# Summary
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}Succeeded (${#SUCCEEDED[@]}):${NC}"
for n in "${SUCCEEDED[@]}"; do echo "  ✓ $n"; done
echo -e "${YELLOW}Skipped (${#SKIPPED[@]}):${NC}"
for n in "${SKIPPED[@]}"; do echo "  ⊘ $n"; done
echo ""

if [ ${#SUCCEEDED[@]} -gt 0 ]; then
    echo -en "Commit uv.lock and pyproject.toml now? [y/n] → "
    read -r commit_choice
    if [ "$commit_choice" = "y" ] || [ "$commit_choice" = "Y" ]; then
        git add -f uv.lock pyproject.toml
        git commit -m "Bake custom node dependencies into pyproject.toml"
        echo -e "${GREEN}✓ Committed!${NC}"
    else
        echo "Skipped commit. You can run later:"
        echo "  git add -f uv.lock pyproject.toml"
        echo "  git commit -m 'Bake custom node dependencies'"
    fi
fi

echo -e "\n${GREEN}Done!${NC}"
