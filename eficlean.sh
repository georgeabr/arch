#!/bin/bash
#
# eficlean - Interactive EFI boot entry management
# Queue-based deletion with multi-item queuing, undo, preview, and confirmation
#
# SPDX-License-Identifier: NC-SA-BIN-CL-1.2
# Contact: support@georgetech.co.uk
#

readonly VERSION="1.5.2"

set -o pipefail

# Colour codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Colour

# State
declare -A entries       # boot_num -> "label|path|active"
declare -a boot_order    # Current boot order from BootOrder line
declare -A delete_queue  # boot_num -> 1 if queued for deletion
declare -a undo_stack    # Stack of serialized delete_queue states
declare -a line_to_num   # line_number (1-based) -> boot_num mapping
declare current_boot=""
declare -i total_entries=0

# ==============================================================================
# Utility functions
# ==============================================================================

die() {
    printf '%b\n' "${RED}Error: $*${NC}" >&2
    exit 1
}

info() {
    printf '%b\n' "${BLUE}ℹ $*${NC}"
}

warn() {
    printf '%b\n' "${YELLOW} $*${NC}"
}

success() {
    printf '%b\n' "${GREEN} $*${NC}"
}

check_efi_access() {
    if [[ ! -d /sys/firmware/efi ]]; then
        die "EFI firmware not detected. This script requires EFI."
    fi
    if ! command -v efibootmgr &>/dev/null; then
        die "efibootmgr not found. Install efibootmgr package."
    fi
    if [[ $EUID -ne 0 ]]; then
        die "This script requires root. Run with sudo."
    fi
}

# ==============================================================================
# Parsing
# ==============================================================================

parse_efi_entries() {
    local line boot_num label active rest
    
    entries=()
    boot_order=()
    current_boot=""
    total_entries=0
    
    while IFS= read -r line; do
        if [[ $line =~ ^BootCurrent:\ ([0-9A-Fa-f]{4}) ]]; then
            current_boot="${BASH_REMATCH[1]}"
        elif [[ $line =~ ^BootOrder:\ (.+)$ ]]; then
            IFS=',' read -ra boot_order <<<"${BASH_REMATCH[1]}"
        elif [[ $line =~ ^Boot([0-9A-Fa-f]{4})(\*)?\ (.+)$ ]]; then
            boot_num="${BASH_REMATCH[1]}"
            active="${BASH_REMATCH[2]}"
            
            # Extract portion before tab, then trim leading and trailing spaces natively
            rest="${BASH_REMATCH[3]}"
            label="${rest%%$'\t'*}"
            label="${label#"${label%%[![:space:]]*}"}"
            label="${label%"${label##*[![:space:]]}"}"
            
            local path=""
            if [[ $line =~ $'\t'(.+)$ ]]; then
                path="${BASH_REMATCH[1]}"
            fi
            
            entries[$boot_num]="${label}|${path}|${active:+1}"
            ((total_entries++))
        fi
    done < <(efibootmgr -v 2>/dev/null)
    
    if [[ $total_entries -eq 0 ]]; then
        die "No EFI boot entries found or efibootmgr failed."
    fi
}

# ==============================================================================
# Display
# ==============================================================================

list_entries() {
    local i=1 boot_num
    
    line_to_num=()
    
    clear
    printf '%bEFI Boot Entries%b (v%s)\n' "${BLUE}" "${NC}" "$VERSION"
    printf '%s\n' "$(printf '%.0s-' {1..60})"
    
    if [[ -n $current_boot ]]; then
        printf 'Current boot: %b%s%b\n' "${YELLOW}" "$current_boot" "${NC}"
    fi
    
    printf '\n'
    
    for boot_num in $(printf '%s\n' "${!entries[@]}" | sort); do
        line_to_num[$i]="$boot_num"
        local entry="${entries[$boot_num]}"
        IFS='|' read -r label path active <<<"$entry"
        
        local marker=' '
        local status_colour="${NC}"
        
        if [[ $boot_num == "$current_boot" ]]; then
            marker='*'
            status_colour="${YELLOW}"
        fi
        
        if [[ -n ${delete_queue[$boot_num]} ]]; then
            marker='D'
            status_colour="${RED}"
        fi
        
        printf '%2d. [%b%s%b] Boot%s  %s\n' \
            "$i" "$status_colour" "$marker" "${NC}" \
            "$boot_num" "$label"
        
        ((i++))
    done
    
    printf '\n%bQueued for deletion: %d%b\n' "${YELLOW}" "${#delete_queue[@]}" "${NC}"
    
    if [[ ${#delete_queue[@]} -gt 0 ]]; then
        for boot_num in $(printf '%s\n' "${!delete_queue[@]}" | sort); do
            local entry="${entries[$boot_num]}"
            IFS='|' read -r label _ <<<"$entry"
            printf '  %b→%b Boot%s | %s\n' "${RED}" "${NC}" "$boot_num" "$label"
        done
    fi
}

preview_changes() {
    if [[ ${#delete_queue[@]} -eq 0 ]]; then
        warn "No pending changes."
        return
    fi
    
    printf '\n%bPending deletions (%d item/s):%b\n' "${RED}" "${#delete_queue[@]}" "${NC}"
    for boot_num in $(printf '%s\n' "${!delete_queue[@]}" | sort); do
        local entry="${entries[$boot_num]}"
        IFS='|' read -r label _ <<<"$entry"
        
        if [[ $boot_num == "$current_boot" ]]; then
            printf '  Boot%s | %s %b[CURRENT BOOT]%b\n' \
                "$boot_num" "$label" "${YELLOW}" "${NC}"
        else
            printf '  Boot%s | %s\n' "$boot_num" "$label"
        fi
    done
    printf '\n'
}

# ==============================================================================
# Queue operations
# ==============================================================================

save_state() {
    local state=""
    for boot_num in "${!delete_queue[@]}"; do
        state+="$boot_num "
    done
    undo_stack+=("$state")
}

queue_deletion() {
    local raw_input
    
    printf '\nEnter entry number(s) to delete (e.g. 1, 1-3, or 1,3,5): '
    read -r raw_input
    
    if [[ -z $raw_input ]]; then
        warn "No selection provided."
        return
    fi
    
    save_state
    
    IFS=',' read -ra tokens <<< "$raw_input"
    local added=0
    
    for token in "${tokens[@]}"; do
        token="${token#"${token%%[![:space:]]*}"}"
        token="${token%"${token##*[![:space:]]}"}"
        
        if [[ $token =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"
            if (( start > end )); then
                local tmp=$start; start=$end; end=$tmp
            fi
            
            for (( line_num=start; line_num<=end; line_num++ )); do
                if (( line_num >= 1 && line_num <= total_entries )); then
                    local boot_num="${line_to_num[$line_num]}"
                    if [[ -n $boot_num && -z ${delete_queue[$boot_num]} ]]; then
                        delete_queue[$boot_num]=1
                        ((added++))
                    fi
                fi
            done
        elif [[ $token =~ ^[0-9]+$ ]]; then
            local line_num="$token"
            if (( line_num >= 1 && line_num <= total_entries )); then
                local boot_num="${line_to_num[$line_num]}"
                if [[ -n $boot_num && -z ${delete_queue[$boot_num]} ]]; then
                    if [[ $boot_num == "$current_boot" ]]; then
                        warn "Boot$boot_num is currently active. Use caution."
                    fi
                    delete_queue[$boot_num]=1
                    ((added++))
                fi
            else
                warn "Item $line_num out of range (1-$total_entries)."
            fi
        else
            warn "Ignoring invalid token: $token"
        fi
    done
    
    if (( added > 0 )); then
        success "Queued $added item(s) for deletion."
    else
        unset 'undo_stack[-1]'
        warn "No new items added to deletion queue."
    fi
}

reset_queue() {
    if [[ ${#delete_queue[@]} -eq 0 ]]; then
        warn "Queue is already empty."
        return
    fi
    save_state
    delete_queue=()
    success "Queue cleared."
}

undo_last() {
    if [[ ${#undo_stack[@]} -eq 0 ]]; then
        warn "Nothing to undo."
        return
    fi
    
    local state="${undo_stack[-1]}"
    unset 'undo_stack[-1]'
    
    delete_queue=()
    for boot_num in $state; do
        delete_queue[$boot_num]=1
    done
    
    success "Undo completed. Restored previous queue state."
}

# ==============================================================================
# Apply changes
# ==============================================================================

apply_changes() {
    if [[ ${#delete_queue[@]} -eq 0 ]]; then
        warn "No pending changes to apply."
        return
    fi
    
    preview_changes
    
    printf '%bConfirm deletion of %d entry/entries? [y/N]: %b' "${RED}" "${#delete_queue[@]}" "${NC}"
    read -r confirm
    
    if [[ "$confirm" != 'y' && "$confirm" != 'Y' ]]; then
        warn "Cancelled."
        return
    fi
    
    printf '\n'
    local failed=0
    
    for boot_num in $(printf '%s\n' "${!delete_queue[@]}" | sort -r); do
        local entry="${entries[$boot_num]}"
        IFS='|' read -r label _ <<<"$entry"
        
        if efibootmgr -b "$boot_num" -B &>/dev/null; then
            success "Deleted Boot$boot_num ($label)"
        else
            warn "Failed to delete Boot$boot_num ($label)"
            ((failed++))
        fi
    done
    
    delete_queue=()
    undo_stack=()
    parse_efi_entries
    
    printf '\n'
    if [[ $failed -eq 0 ]]; then
        success "All deletions applied successfully."
    else
        warn "$failed deletion(s) failed. See above."
    fi
}

# ==============================================================================
# Main loop
# ==============================================================================

main() {
    check_efi_access
    parse_efi_entries
    
    while true; do
        list_entries
        
        printf '%b[l]ist [d]elete [u]ndo [r]eset [p]review [c]onfirm [q]uit: %b' \
            "${GREEN}" "${NC}"
        
        read -r -n 1 cmd
        if [[ "$cmd" != "" ]]; then
            read -r -t 0.1 -d '' _ || true
        fi
        
        printf '\n'
        
        case "${cmd,,}" in
            l|"") continue ;;
            d) queue_deletion ;;
            u) undo_last ;;
            r) reset_queue ;;
            p) preview_changes ;;
            c) apply_changes ;;
            q) printf '\nExiting without changes.\n'; exit 0 ;;
            *) warn "Unknown command: $cmd" ;;
        esac
        
        printf '\nPress Enter to continue...'
        read -r
    done
}

main "$@"
