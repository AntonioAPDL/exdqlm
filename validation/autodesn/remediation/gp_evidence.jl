# Gen stores the pre-last-resampling accumulator separately from final weights.
# The pinned AutoGP API returns only that accumulator. Do not use it to pool runs.
function serialized_smc_log_evidence(state)
    lw=Float64.(state["pf_state"]["log_weights"])
    @assert !isempty(lw) && all(isfinite,lw)
    peak=maximum(lw)
    correction=peak+log(sum(exp.(lw.-peak)))-log(length(lw))
    partial=Float64(state["pf_state"]["log_ml_est"])
    @assert isfinite(partial)
    return (log_evidence=partial+correction,pre_resampling_accumulator=partial,terminal_log_mean_weight=correction)
end
