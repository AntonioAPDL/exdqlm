list(schema = "autodesn_500_500_100_v1", washout = 500L, conditioning = 500L,
    n_train = 500L, H = 100L, repetitions = 3L, kinds = c("dynamic_seasonal",
    "linear", "nonlinear"), chains = 3L, n_burn = 1500L, n_mcmc = 4000L,
    outer_draws = 192L, inner_paths = 64L, max_inner_paths = 128L,
    quantile_type = 8L, fixed_index = 17L, specifications = list(
        desn_001 = list(D = 1L, n = 20L, n_tilde = integer(0),
            m = 5L, alpha = 0.6, rho = 0.6, seed = 11L, washout = 500L,
            act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
            input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 1,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_002 = list(D = 2L,
            n = c(20L, 20L), n_tilde = 20L, m = 5L, alpha = 0.6,
            rho = c(0.6, 0.6), seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_003 = list(D = 3L,
            n = c(20L, 20L, 20L), n_tilde = c(20L, 20L), m = 5L,
            alpha = 0.6, rho = c(0.6, 0.6, 0.6), seed = 11L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_004 = list(D = 1L,
            n = 50L, n_tilde = integer(0), m = 5L, alpha = 0.6,
            rho = 0.6, seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_005 = list(D = 2L,
            n = c(50L, 50L), n_tilde = 50L, m = 5L, alpha = 0.6,
            rho = c(0.6, 0.6), seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_006 = list(D = 3L,
            n = c(50L, 50L, 50L), n_tilde = c(50L, 50L), m = 5L,
            alpha = 0.6, rho = c(0.6, 0.6, 0.6), seed = 11L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_007 = list(D = 1L,
            n = 20L, n_tilde = integer(0), m = 30L, alpha = 0.6,
            rho = 0.6, seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_008 = list(D = 2L,
            n = c(20L, 20L), n_tilde = 20L, m = 30L, alpha = 0.6,
            rho = c(0.6, 0.6), seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_009 = list(D = 3L,
            n = c(20L, 20L, 20L), n_tilde = c(20L, 20L), m = 30L,
            alpha = 0.6, rho = c(0.6, 0.6, 0.6), seed = 11L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_010 = list(D = 1L,
            n = 50L, n_tilde = integer(0), m = 30L, alpha = 0.6,
            rho = 0.6, seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_011 = list(D = 2L,
            n = c(50L, 50L), n_tilde = 50L, m = 30L, alpha = 0.6,
            rho = c(0.6, 0.6), seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_012 = list(D = 3L,
            n = c(50L, 50L, 50L), n_tilde = c(50L, 50L), m = 30L,
            alpha = 0.6, rho = c(0.6, 0.6, 0.6), seed = 11L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_013 = list(D = 1L,
            n = 20L, n_tilde = integer(0), m = 90L, alpha = 0.6,
            rho = 0.6, seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_014 = list(D = 2L,
            n = c(20L, 20L), n_tilde = 20L, m = 90L, alpha = 0.6,
            rho = c(0.6, 0.6), seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_015 = list(D = 3L,
            n = c(20L, 20L, 20L), n_tilde = c(20L, 20L), m = 90L,
            alpha = 0.6, rho = c(0.6, 0.6, 0.6), seed = 11L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_016 = list(D = 1L,
            n = 50L, n_tilde = integer(0), m = 90L, alpha = 0.6,
            rho = 0.6, seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_017 = list(D = 2L,
            n = c(50L, 50L), n_tilde = 50L, m = 90L, alpha = 0.6,
            rho = c(0.6, 0.6), seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_018 = list(D = 3L,
            n = c(50L, 50L, 50L), n_tilde = c(50L, 50L), m = 90L,
            alpha = 0.6, rho = c(0.6, 0.6, 0.6), seed = 11L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_019 = list(D = 1L,
            n = 20L, n_tilde = integer(0), m = 5L, alpha = 0.15,
            rho = 0.95, seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_020 = list(D = 2L,
            n = c(20L, 20L), n_tilde = 20L, m = 5L, alpha = 0.15,
            rho = c(0.95, 0.95), seed = 11L, washout = 500L,
            act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
            input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_021 = list(D = 3L,
            n = c(20L, 20L, 20L), n_tilde = c(20L, 20L), m = 5L,
            alpha = 0.15, rho = c(0.95, 0.95, 0.95), seed = 11L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_022 = list(D = 1L,
            n = 50L, n_tilde = integer(0), m = 5L, alpha = 0.15,
            rho = 0.95, seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_023 = list(D = 2L,
            n = c(50L, 50L), n_tilde = 50L, m = 5L, alpha = 0.15,
            rho = c(0.95, 0.95), seed = 11L, washout = 500L,
            act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
            input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_024 = list(D = 3L,
            n = c(50L, 50L, 50L), n_tilde = c(50L, 50L), m = 5L,
            alpha = 0.15, rho = c(0.95, 0.95, 0.95), seed = 11L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_025 = list(D = 1L,
            n = 20L, n_tilde = integer(0), m = 30L, alpha = 0.15,
            rho = 0.95, seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_026 = list(D = 2L,
            n = c(20L, 20L), n_tilde = 20L, m = 30L, alpha = 0.15,
            rho = c(0.95, 0.95), seed = 11L, washout = 500L,
            act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
            input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_027 = list(D = 3L,
            n = c(20L, 20L, 20L), n_tilde = c(20L, 20L), m = 30L,
            alpha = 0.15, rho = c(0.95, 0.95, 0.95), seed = 11L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_028 = list(D = 1L,
            n = 50L, n_tilde = integer(0), m = 30L, alpha = 0.15,
            rho = 0.95, seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_029 = list(D = 2L,
            n = c(50L, 50L), n_tilde = 50L, m = 30L, alpha = 0.15,
            rho = c(0.95, 0.95), seed = 11L, washout = 500L,
            act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
            input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_030 = list(D = 3L,
            n = c(50L, 50L, 50L), n_tilde = c(50L, 50L), m = 30L,
            alpha = 0.15, rho = c(0.95, 0.95, 0.95), seed = 11L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_031 = list(D = 1L,
            n = 20L, n_tilde = integer(0), m = 90L, alpha = 0.15,
            rho = 0.95, seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_032 = list(D = 2L,
            n = c(20L, 20L), n_tilde = 20L, m = 90L, alpha = 0.15,
            rho = c(0.95, 0.95), seed = 11L, washout = 500L,
            act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
            input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_033 = list(D = 3L,
            n = c(20L, 20L, 20L), n_tilde = c(20L, 20L), m = 90L,
            alpha = 0.15, rho = c(0.95, 0.95, 0.95), seed = 11L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_034 = list(D = 1L,
            n = 50L, n_tilde = integer(0), m = 90L, alpha = 0.15,
            rho = 0.95, seed = 11L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_035 = list(D = 2L,
            n = c(50L, 50L), n_tilde = 50L, m = 90L, alpha = 0.15,
            rho = c(0.95, 0.95), seed = 11L, washout = 500L,
            act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
            input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_036 = list(D = 3L,
            n = c(50L, 50L, 50L), n_tilde = c(50L, 50L), m = 90L,
            alpha = 0.15, rho = c(0.95, 0.95, 0.95), seed = 11L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_037 = list(D = 1L,
            n = 20L, n_tilde = integer(0), m = 5L, alpha = 0.6,
            rho = 0.6, seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_038 = list(D = 2L,
            n = c(20L, 20L), n_tilde = 20L, m = 5L, alpha = 0.6,
            rho = c(0.6, 0.6), seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_039 = list(D = 3L,
            n = c(20L, 20L, 20L), n_tilde = c(20L, 20L), m = 5L,
            alpha = 0.6, rho = c(0.6, 0.6, 0.6), seed = 29L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_040 = list(D = 1L,
            n = 50L, n_tilde = integer(0), m = 5L, alpha = 0.6,
            rho = 0.6, seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_041 = list(D = 2L,
            n = c(50L, 50L), n_tilde = 50L, m = 5L, alpha = 0.6,
            rho = c(0.6, 0.6), seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_042 = list(D = 3L,
            n = c(50L, 50L, 50L), n_tilde = c(50L, 50L), m = 5L,
            alpha = 0.6, rho = c(0.6, 0.6, 0.6), seed = 29L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_043 = list(D = 1L,
            n = 20L, n_tilde = integer(0), m = 30L, alpha = 0.6,
            rho = 0.6, seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_044 = list(D = 2L,
            n = c(20L, 20L), n_tilde = 20L, m = 30L, alpha = 0.6,
            rho = c(0.6, 0.6), seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_045 = list(D = 3L,
            n = c(20L, 20L, 20L), n_tilde = c(20L, 20L), m = 30L,
            alpha = 0.6, rho = c(0.6, 0.6, 0.6), seed = 29L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_046 = list(D = 1L,
            n = 50L, n_tilde = integer(0), m = 30L, alpha = 0.6,
            rho = 0.6, seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_047 = list(D = 2L,
            n = c(50L, 50L), n_tilde = 50L, m = 30L, alpha = 0.6,
            rho = c(0.6, 0.6), seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_048 = list(D = 3L,
            n = c(50L, 50L, 50L), n_tilde = c(50L, 50L), m = 30L,
            alpha = 0.6, rho = c(0.6, 0.6, 0.6), seed = 29L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_049 = list(D = 1L,
            n = 20L, n_tilde = integer(0), m = 90L, alpha = 0.6,
            rho = 0.6, seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_050 = list(D = 2L,
            n = c(20L, 20L), n_tilde = 20L, m = 90L, alpha = 0.6,
            rho = c(0.6, 0.6), seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_051 = list(D = 3L,
            n = c(20L, 20L, 20L), n_tilde = c(20L, 20L), m = 90L,
            alpha = 0.6, rho = c(0.6, 0.6, 0.6), seed = 29L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_052 = list(D = 1L,
            n = 50L, n_tilde = integer(0), m = 90L, alpha = 0.6,
            rho = 0.6, seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_053 = list(D = 2L,
            n = c(50L, 50L), n_tilde = 50L, m = 90L, alpha = 0.6,
            rho = c(0.6, 0.6), seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_054 = list(D = 3L,
            n = c(50L, 50L, 50L), n_tilde = c(50L, 50L), m = 90L,
            alpha = 0.6, rho = c(0.6, 0.6, 0.6), seed = 29L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 1, topology = list(
                mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_055 = list(D = 1L,
            n = 20L, n_tilde = integer(0), m = 5L, alpha = 0.15,
            rho = 0.95, seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_056 = list(D = 2L,
            n = c(20L, 20L), n_tilde = 20L, m = 5L, alpha = 0.15,
            rho = c(0.95, 0.95), seed = 29L, washout = 500L,
            act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
            input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_057 = list(D = 3L,
            n = c(20L, 20L, 20L), n_tilde = c(20L, 20L), m = 5L,
            alpha = 0.15, rho = c(0.95, 0.95, 0.95), seed = 29L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_058 = list(D = 1L,
            n = 50L, n_tilde = integer(0), m = 5L, alpha = 0.15,
            rho = 0.95, seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_059 = list(D = 2L,
            n = c(50L, 50L), n_tilde = 50L, m = 5L, alpha = 0.15,
            rho = c(0.95, 0.95), seed = 29L, washout = 500L,
            act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
            input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_060 = list(D = 3L,
            n = c(50L, 50L, 50L), n_tilde = c(50L, 50L), m = 5L,
            alpha = 0.15, rho = c(0.95, 0.95, 0.95), seed = 29L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 2, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_061 = list(D = 1L,
            n = 20L, n_tilde = integer(0), m = 30L, alpha = 0.15,
            rho = 0.95, seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_062 = list(D = 2L,
            n = c(20L, 20L), n_tilde = 20L, m = 30L, alpha = 0.15,
            rho = c(0.95, 0.95), seed = 29L, washout = 500L,
            act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
            input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_063 = list(D = 3L,
            n = c(20L, 20L, 20L), n_tilde = c(20L, 20L), m = 30L,
            alpha = 0.15, rho = c(0.95, 0.95, 0.95), seed = 29L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_064 = list(D = 1L,
            n = 50L, n_tilde = integer(0), m = 30L, alpha = 0.15,
            rho = 0.95, seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_065 = list(D = 2L,
            n = c(50L, 50L), n_tilde = 50L, m = 30L, alpha = 0.15,
            rho = c(0.95, 0.95), seed = 29L, washout = 500L,
            act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
            input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_066 = list(D = 3L,
            n = c(50L, 50L, 50L), n_tilde = c(50L, 50L), m = 30L,
            alpha = 0.15, rho = c(0.95, 0.95, 0.95), seed = 29L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 10, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_067 = list(D = 1L,
            n = 20L, n_tilde = integer(0), m = 90L, alpha = 0.15,
            rho = 0.95, seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_068 = list(D = 2L,
            n = c(20L, 20L), n_tilde = 20L, m = 90L, alpha = 0.15,
            rho = c(0.95, 0.95), seed = 29L, washout = 500L,
            act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
            input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_069 = list(D = 3L,
            n = c(20L, 20L, 20L), n_tilde = c(20L, 20L), m = 90L,
            alpha = 0.15, rho = c(0.95, 0.95, 0.95), seed = 29L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_070 = list(D = 1L,
            n = 50L, n_tilde = integer(0), m = 90L, alpha = 0.15,
            rho = 0.95, seed = 29L, washout = 500L, act_f = "tanh",
            act_k = "identity", standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_071 = list(D = 2L,
            n = c(50L, 50L), n_tilde = 50L, m = 90L, alpha = 0.15,
            rho = c(0.95, 0.95), seed = 29L, washout = 500L,
            act_f = "tanh", act_k = "identity", standardize_inputs = TRUE,
            input_bound = "tanh", input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1)), desn_072 = list(D = 3L,
            n = c(50L, 50L, 50L), n_tilde = c(50L, 50L), m = 90L,
            alpha = 0.15, rho = c(0.95, 0.95, 0.95), seed = 29L,
            washout = 500L, act_f = "tanh", act_k = "identity",
            standardize_inputs = TRUE, input_bound = "tanh",
            input_bound_divisor = 3, win_scale_global = 0.3,
            topology = list(mode = "exact_fanin", recurrent_indegree = 5L,
                input_fanin = 28, interlayer_fanin = 5L, row_normalize_inputs = TRUE),
            w_dist = function (n)
            stats::runif(n, -1, 1), in_dist = function (n)
            stats::runif(n, -1, 1))), retry_rule = "Before forecast evaluation only: one retry at burn=3000 and retained=8000 if Rhat>1.01, ESS<400 or max model chain range>.05.",
    source_revision_at_launch = "1b4c7595089ae0506fe7dc4a318fc054db2e2ec6",
    scope = "Fresh fixed-origin forecasts; no fitting, tuning or teacher forcing inside the 100 held-out observations.")
