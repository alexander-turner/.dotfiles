function _tide_item_jobs
    set -q _tide_jobs || return
    test "$_tide_jobs" -ge "$tide_jobs_number_threshold" 2>/dev/null
    and _tide_print_item jobs $tide_jobs_icon
end
