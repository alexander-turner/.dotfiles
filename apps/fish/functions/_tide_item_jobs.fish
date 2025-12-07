function _tide_item_jobs
    if set -q _tide_jobs
        if test -n "$_tide_jobs" -a "$_tide_jobs" -ge 0 2>/dev/null
            _tide_print_item jobs $tide_jobs_icon
        end
    end
end
