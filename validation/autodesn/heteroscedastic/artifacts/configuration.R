list(schema = "autodesn_500_2000_100_heteroscedastic_v1", washout = 500L,
    conditioning = 500L, n_train = 2000L, H = 100L, repetitions = 3L,
    kinds = c("smooth_scale", "threshold_gjr", "switching_seasonal"
    ), chains = 3L, outer_draws = 192L, inner_paths = 64L, max_inner_paths = 128L,
    quantile_type = 8L, cores = 1L, diagnostic_attempts = structure(list(
        n_burn = c(2000L, 4000L, 6000L), n_mcmc = c(6000L, 16000L,
        32000L)), class = "data.frame", row.names = c(NA, -3L
    )), retry_rule = "Before any future forecast scoring: retry only if Rhat>1.01, spectral ESS<400 or model chain range>.05. Record every attempt; never tune on scores.",
    specifications = list(desn_001 = list(D = 1L, n = 20L, n_tilde = integer(0),
        m = 5L, alpha = 0.6, rho = 0.6, seed = 11L, washout = 500L,
        act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
        input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 1,
        topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
            input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
        w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_002 = list(D = 2L, n = c(20L,
    20L), n_tilde = 20L, m = 5L, alpha = 0.6, rho = c(0.6, 0.6
    ), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_003 = list(D = 3L, n = c(20L,
    20L, 20L), n_tilde = c(20L, 20L), m = 5L, alpha = 0.6, rho = c(0.6,
    0.6, 0.6), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_004 = list(D = 1L, n = 50L,
        n_tilde = integer(0), m = 5L, alpha = 0.6, rho = 0.6,
        seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_005 = list(D = 2L, n = c(50L,
    50L), n_tilde = 50L, m = 5L, alpha = 0.6, rho = c(0.6, 0.6
    ), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_006 = list(D = 3L, n = c(50L,
    50L, 50L), n_tilde = c(50L, 50L), m = 5L, alpha = 0.6, rho = c(0.6,
    0.6, 0.6), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_007 = list(D = 1L, n = 20L,
        n_tilde = integer(0), m = 30L, alpha = 0.6, rho = 0.6,
        seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_008 = list(D = 2L, n = c(20L,
    20L), n_tilde = 20L, m = 30L, alpha = 0.6, rho = c(0.6, 0.6
    ), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_009 = list(D = 3L, n = c(20L,
    20L, 20L), n_tilde = c(20L, 20L), m = 30L, alpha = 0.6, rho = c(0.6,
    0.6, 0.6), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_010 = list(D = 1L, n = 50L,
        n_tilde = integer(0), m = 30L, alpha = 0.6, rho = 0.6,
        seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_011 = list(D = 2L, n = c(50L,
    50L), n_tilde = 50L, m = 30L, alpha = 0.6, rho = c(0.6, 0.6
    ), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_012 = list(D = 3L, n = c(50L,
    50L, 50L), n_tilde = c(50L, 50L), m = 30L, alpha = 0.6, rho = c(0.6,
    0.6, 0.6), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_013 = list(D = 1L, n = 20L,
        n_tilde = integer(0), m = 90L, alpha = 0.6, rho = 0.6,
        seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_014 = list(D = 2L, n = c(20L,
    20L), n_tilde = 20L, m = 90L, alpha = 0.6, rho = c(0.6, 0.6
    ), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_015 = list(D = 3L, n = c(20L,
    20L, 20L), n_tilde = c(20L, 20L), m = 90L, alpha = 0.6, rho = c(0.6,
    0.6, 0.6), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_016 = list(D = 1L, n = 50L,
        n_tilde = integer(0), m = 90L, alpha = 0.6, rho = 0.6,
        seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_017 = list(D = 2L, n = c(50L,
    50L), n_tilde = 50L, m = 90L, alpha = 0.6, rho = c(0.6, 0.6
    ), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_018 = list(D = 3L, n = c(50L,
    50L, 50L), n_tilde = c(50L, 50L), m = 90L, alpha = 0.6, rho = c(0.6,
    0.6, 0.6), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_019 = list(D = 1L, n = 20L,
        n_tilde = integer(0), m = 5L, alpha = 0.15, rho = 0.95,
        seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_020 = list(D = 2L, n = c(20L,
    20L), n_tilde = 20L, m = 5L, alpha = 0.15, rho = c(0.95,
    0.95), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_021 = list(D = 3L, n = c(20L,
    20L, 20L), n_tilde = c(20L, 20L), m = 5L, alpha = 0.15, rho = c(0.95,
    0.95, 0.95), seed = 11L, washout = 500L, act_f = "tanh",
        act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
        input_bound_divisor = 3, win_scale_global = 0.3, topology = list(
            mode = "exact_fanin", recurrent_indegree = 5L, input_fanin = 2,
            interlayer_fanin = 5L, row_normalize_inputs = TRUE),
        w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_022 = list(D = 1L, n = 50L,
        n_tilde = integer(0), m = 5L, alpha = 0.15, rho = 0.95,
        seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_023 = list(D = 2L, n = c(50L,
    50L), n_tilde = 50L, m = 5L, alpha = 0.15, rho = c(0.95,
    0.95), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_024 = list(D = 3L, n = c(50L,
    50L, 50L), n_tilde = c(50L, 50L), m = 5L, alpha = 0.15, rho = c(0.95,
    0.95, 0.95), seed = 11L, washout = 500L, act_f = "tanh",
        act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
        input_bound_divisor = 3, win_scale_global = 0.3, topology = list(
            mode = "exact_fanin", recurrent_indegree = 5L, input_fanin = 2,
            interlayer_fanin = 5L, row_normalize_inputs = TRUE),
        w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_025 = list(D = 1L, n = 20L,
        n_tilde = integer(0), m = 30L, alpha = 0.15, rho = 0.95,
        seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_026 = list(D = 2L, n = c(20L,
    20L), n_tilde = 20L, m = 30L, alpha = 0.15, rho = c(0.95,
    0.95), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_027 = list(D = 3L, n = c(20L,
    20L, 20L), n_tilde = c(20L, 20L), m = 30L, alpha = 0.15,
        rho = c(0.95, 0.95, 0.95), seed = 11L, washout = 500L,
        act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
        input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
        topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
            input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
        w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_028 = list(D = 1L, n = 50L,
        n_tilde = integer(0), m = 30L, alpha = 0.15, rho = 0.95,
        seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_029 = list(D = 2L, n = c(50L,
    50L), n_tilde = 50L, m = 30L, alpha = 0.15, rho = c(0.95,
    0.95), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_030 = list(D = 3L, n = c(50L,
    50L, 50L), n_tilde = c(50L, 50L), m = 30L, alpha = 0.15,
        rho = c(0.95, 0.95, 0.95), seed = 11L, washout = 500L,
        act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
        input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
        topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
            input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
        w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_031 = list(D = 1L, n = 20L,
        n_tilde = integer(0), m = 90L, alpha = 0.15, rho = 0.95,
        seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_032 = list(D = 2L, n = c(20L,
    20L), n_tilde = 20L, m = 90L, alpha = 0.15, rho = c(0.95,
    0.95), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_033 = list(D = 3L, n = c(20L,
    20L, 20L), n_tilde = c(20L, 20L), m = 90L, alpha = 0.15,
        rho = c(0.95, 0.95, 0.95), seed = 11L, washout = 500L,
        act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
        input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
        topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
            input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
        w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_034 = list(D = 1L, n = 50L,
        n_tilde = integer(0), m = 90L, alpha = 0.15, rho = 0.95,
        seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_035 = list(D = 2L, n = c(50L,
    50L), n_tilde = 50L, m = 90L, alpha = 0.15, rho = c(0.95,
    0.95), seed = 11L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_036 = list(D = 3L, n = c(50L,
    50L, 50L), n_tilde = c(50L, 50L), m = 90L, alpha = 0.15,
        rho = c(0.95, 0.95, 0.95), seed = 11L, washout = 500L,
        act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
        input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
        topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
            input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
        w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_037 = list(D = 1L, n = 20L,
        n_tilde = integer(0), m = 5L, alpha = 0.6, rho = 0.6,
        seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_038 = list(D = 2L, n = c(20L,
    20L), n_tilde = 20L, m = 5L, alpha = 0.6, rho = c(0.6, 0.6
    ), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_039 = list(D = 3L, n = c(20L,
    20L, 20L), n_tilde = c(20L, 20L), m = 5L, alpha = 0.6, rho = c(0.6,
    0.6, 0.6), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_040 = list(D = 1L, n = 50L,
        n_tilde = integer(0), m = 5L, alpha = 0.6, rho = 0.6,
        seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_041 = list(D = 2L, n = c(50L,
    50L), n_tilde = 50L, m = 5L, alpha = 0.6, rho = c(0.6, 0.6
    ), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_042 = list(D = 3L, n = c(50L,
    50L, 50L), n_tilde = c(50L, 50L), m = 5L, alpha = 0.6, rho = c(0.6,
    0.6, 0.6), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_043 = list(D = 1L, n = 20L,
        n_tilde = integer(0), m = 30L, alpha = 0.6, rho = 0.6,
        seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_044 = list(D = 2L, n = c(20L,
    20L), n_tilde = 20L, m = 30L, alpha = 0.6, rho = c(0.6, 0.6
    ), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_045 = list(D = 3L, n = c(20L,
    20L, 20L), n_tilde = c(20L, 20L), m = 30L, alpha = 0.6, rho = c(0.6,
    0.6, 0.6), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_046 = list(D = 1L, n = 50L,
        n_tilde = integer(0), m = 30L, alpha = 0.6, rho = 0.6,
        seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_047 = list(D = 2L, n = c(50L,
    50L), n_tilde = 50L, m = 30L, alpha = 0.6, rho = c(0.6, 0.6
    ), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_048 = list(D = 3L, n = c(50L,
    50L, 50L), n_tilde = c(50L, 50L), m = 30L, alpha = 0.6, rho = c(0.6,
    0.6, 0.6), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_049 = list(D = 1L, n = 20L,
        n_tilde = integer(0), m = 90L, alpha = 0.6, rho = 0.6,
        seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_050 = list(D = 2L, n = c(20L,
    20L), n_tilde = 20L, m = 90L, alpha = 0.6, rho = c(0.6, 0.6
    ), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_051 = list(D = 3L, n = c(20L,
    20L, 20L), n_tilde = c(20L, 20L), m = 90L, alpha = 0.6, rho = c(0.6,
    0.6, 0.6), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_052 = list(D = 1L, n = 50L,
        n_tilde = integer(0), m = 90L, alpha = 0.6, rho = 0.6,
        seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_053 = list(D = 2L, n = c(50L,
    50L), n_tilde = 50L, m = 90L, alpha = 0.6, rho = c(0.6, 0.6
    ), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_054 = list(D = 3L, n = c(50L,
    50L, 50L), n_tilde = c(50L, 50L), m = 90L, alpha = 0.6, rho = c(0.6,
    0.6, 0.6), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 1, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_055 = list(D = 1L, n = 20L,
        n_tilde = integer(0), m = 5L, alpha = 0.15, rho = 0.95,
        seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_056 = list(D = 2L, n = c(20L,
    20L), n_tilde = 20L, m = 5L, alpha = 0.15, rho = c(0.95,
    0.95), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_057 = list(D = 3L, n = c(20L,
    20L, 20L), n_tilde = c(20L, 20L), m = 5L, alpha = 0.15, rho = c(0.95,
    0.95, 0.95), seed = 29L, washout = 500L, act_f = "tanh",
        act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
        input_bound_divisor = 3, win_scale_global = 0.3, topology = list(
            mode = "exact_fanin", recurrent_indegree = 5L, input_fanin = 2,
            interlayer_fanin = 5L, row_normalize_inputs = TRUE),
        w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_058 = list(D = 1L, n = 50L,
        n_tilde = integer(0), m = 5L, alpha = 0.15, rho = 0.95,
        seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_059 = list(D = 2L, n = c(50L,
    50L), n_tilde = 50L, m = 5L, alpha = 0.15, rho = c(0.95,
    0.95), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 2, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_060 = list(D = 3L, n = c(50L,
    50L, 50L), n_tilde = c(50L, 50L), m = 5L, alpha = 0.15, rho = c(0.95,
    0.95, 0.95), seed = 29L, washout = 500L, act_f = "tanh",
        act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
        input_bound_divisor = 3, win_scale_global = 0.3, topology = list(
            mode = "exact_fanin", recurrent_indegree = 5L, input_fanin = 2,
            interlayer_fanin = 5L, row_normalize_inputs = TRUE),
        w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_061 = list(D = 1L, n = 20L,
        n_tilde = integer(0), m = 30L, alpha = 0.15, rho = 0.95,
        seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_062 = list(D = 2L, n = c(20L,
    20L), n_tilde = 20L, m = 30L, alpha = 0.15, rho = c(0.95,
    0.95), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_063 = list(D = 3L, n = c(20L,
    20L, 20L), n_tilde = c(20L, 20L), m = 30L, alpha = 0.15,
        rho = c(0.95, 0.95, 0.95), seed = 29L, washout = 500L,
        act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
        input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
        topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
            input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
        w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_064 = list(D = 1L, n = 50L,
        n_tilde = integer(0), m = 30L, alpha = 0.15, rho = 0.95,
        seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_065 = list(D = 2L, n = c(50L,
    50L), n_tilde = 50L, m = 30L, alpha = 0.15, rho = c(0.95,
    0.95), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 10, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_066 = list(D = 3L, n = c(50L,
    50L, 50L), n_tilde = c(50L, 50L), m = 30L, alpha = 0.15,
        rho = c(0.95, 0.95, 0.95), seed = 29L, washout = 500L,
        act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
        input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
        topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
            input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
        w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_067 = list(D = 1L, n = 20L,
        n_tilde = integer(0), m = 90L, alpha = 0.15, rho = 0.95,
        seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_068 = list(D = 2L, n = c(20L,
    20L), n_tilde = 20L, m = 90L, alpha = 0.15, rho = c(0.95,
    0.95), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_069 = list(D = 3L, n = c(20L,
    20L, 20L), n_tilde = c(20L, 20L), m = 90L, alpha = 0.15,
        rho = c(0.95, 0.95, 0.95), seed = 29L, washout = 500L,
        act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
        input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
        topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
            input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
        w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_070 = list(D = 1L, n = 50L,
        n_tilde = integer(0), m = 90L, alpha = 0.15, rho = 0.95,
        seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_071 = list(D = 2L, n = c(50L,
    50L), n_tilde = 50L, m = 90L, alpha = 0.15, rho = c(0.95,
    0.95), seed = 29L, washout = 500L, act_f = "tanh", act_k = "identity",
        standardize_inputs = TRUE, input_bound = "tanh", input_bound_divisor = 3,
        win_scale_global = 0.3, topology = list(mode = "exact_fanin",
            recurrent_indegree = 5L, input_fanin = 28, interlayer_fanin = 5L,
            row_normalize_inputs = TRUE), w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1)), desn_072 = list(D = 3L, n = c(50L,
    50L, 50L), n_tilde = c(50L, 50L), m = 90L, alpha = 0.15,
        rho = c(0.95, 0.95, 0.95), seed = 29L, washout = 500L,
        act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
        input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
        topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
            input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
        w_dist = function (n)
        stats::runif(n, -1, 1), in_dist = function (n)
        stats::runif(n, -1, 1))), fixed_index = 17L, source_revision_at_launch = "c718a620a24f1dec9a65b9bf29ad19c654a9bfcd",
    fixed_origin = "Issue once at 2500; simulated response feedback only.",
    prequential = "Issue each one-step forecast before observing its target. Feed observed target back afterwards; no refitting or posterior/model-weight updates.",
    likelihood = "AutoDESN Gaussian constant innovation variance; independent Gaussian ridge prior, no RHS.",
    gjr_reference = "AR(1)-GJR(1,1) plugin conditional Gaussian maximum likelihood; 3 fixed optimization starts; no parameter uncertainty.",
    oracle_reference = "Known parameters; observation-filtered hidden regime, never simulated latent states.")
