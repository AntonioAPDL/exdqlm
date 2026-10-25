"""Recheck immutable GitHub numerical exports after local-workspace loss.

This standard-library audit validates transport, targets, files and exported
summary arithmetic. It does not deserialize Julia states or replace the
independent Gen audit in gp_cohort_evidence.jl, and cannot qualify forecasts.
"""
import argparse
import csv
import gzip
import hashlib
import io
import json
import math
from pathlib import Path, PurePosixPath
import tomllib

import zipfile


PIN = '2ad372db2b8bea176e3b32a769bfb5d6cff80866'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inspect(bundle_path, expected):
    data = bundle_path.read_bytes()
    assert len(data) == expected['bytes']
    assert digest(data) == expected['sha256']
    with zipfile.ZipFile(io.BytesIO(data)) as bundle:
        manifest = json.loads(bundle.read('remote_execution_manifest.json'))
        assert manifest['seed'] == expected['seed']
        assert manifest['checkout_sha'] == expected['checkout_sha']
        assert manifest['native_pin'] == PIN
        members = manifest['members']
        assert sum(m['bytes'] for m in members) <= 20_000_000
        names = {m['path'] for m in members} | {'remote_execution_manifest.json'}
        assert len(bundle.namelist()) == len(names)
        assert set(bundle.namelist()) == names
        for m in members:
            p = PurePosixPath(m['path'])
            assert not p.is_absolute() and '..' not in p.parts
            assert p.parts[:3] == ('validation', 'autodesn', 'remediation')
            raw = bundle.read(m['path'])  # Also verifies each ZIP CRC.
            assert len(raw) == m['bytes'] and digest(raw) == m['sha256']
            if m['path'].endswith('.gz'):
                gzip.decompress(raw)  # Validate the inference log's gzip CRC.
        suffix = '_native' if expected['period_moves'] == 0 else ''
        prefix = ('validation/autodesn/remediation/artifacts/'
                  f"gp_n2000_p{expected['particles']}_s{expected['seed']}{suffix}/")
        status = tomllib.loads(bundle.read(prefix + 'status.toml').decode())
        config = tomllib.loads(bundle.read(prefix + 'configuration.toml').decode())
        assert status['complete'] is True and status['posterior_qualified'] is False
        assert status['training_only'] and not status['forecast_issued']
        assert status['native_target_unchanged'] and config['native_target_unchanged']
        assert config['heldout_data_read'] is False
        assert status['autogp_revision'] == PIN
        assert status['seed'] == config['seed'] == expected['seed']
        assert status['particles'] == config['particles'] == expected['particles']
        assert status['training_rows'] == config['training_rows'] == 2000
        assert status['period_moves_per_particle_per_stage'] == expected['period_moves']
        assert config['period_moves_per_particle_per_stage'] == expected['period_moves']
        assert status['evidence_includes_terminal_particle_weights'] is True
        assert config['max_depth'] == 4
        assert config['schedule'] == [32, 64, 128, 256, 512, 1000, 1500, 2000]
        assert config['n_mcmc'] == [40, 40, 40, 30, 20, 15, 10, 10]
        assert config['n_hmc'] == [4, 4, 4, 3, 3, 2, 2, 2]
        raw_input = bundle.read(prefix + 'training_input.csv')
        assert digest(raw_input) == status['training_input_sha256'] == config['training_input_sha256']
        rows = list(csv.DictReader(io.StringIO(raw_input.decode())))
        assert len(rows) == 2000
        assert [float(row['time']) for row in rows] == list(range(501, 2501))
        assert all(math.isfinite(float(row['y'])) for row in rows)
        progress = list(csv.DictReader(io.StringIO(bundle.read(prefix + 'progress.csv').decode())))
        assert [int(row['step']) for row in progress] == [0] + config['schedule']
        final = progress[-1]
        log_evidence = status['log_marginal_likelihood_estimate']
        assert math.isfinite(log_evidence)
        assert math.isclose(float(final['log_marginal_likelihood']), log_evidence, abs_tol=1e-10, rel_tol=0)
        assert math.isclose(float(final['native_api_pre_resampling_accumulator']),
                            status['native_api_pre_resampling_accumulator'], abs_tol=1e-10, rel_tol=0)
        particles = list(csv.DictReader(io.StringIO(bundle.read(prefix + 'particles.csv').decode())))
        weights = [float(row['weight']) for row in particles]
        assert len(weights) == expected['particles']
        assert all(math.isfinite(w) and w >= 0 for w in weights)
        assert math.isclose(math.fsum(weights), 1.0, abs_tol=1e-10, rel_tol=0)
        ess = 1 / math.fsum(w*w for w in weights)
        assert math.isclose(ess, float(final['ess']), abs_tol=1e-8, rel_tol=1e-10)
        resources = json.loads(bundle.read('validation/autodesn/remediation/evidence/'
                                         f"gp_n2000_p{expected['particles']}_s{expected['seed']}{suffix}_resources.json"))
        assert resources['exit_code'] == 0 and resources['cap_trigger'] is None
        assert resources['max_seconds'] == 14400
        assert resources['max_cgroup_anon_bytes'] == 6100000000
        # Bind the actual immutable runner sources, independently of their paths
        # on GitHub's machine. Frozen package dependency hashes remain recorded.
        source_hashes = status['source_sha256']
        for name, sha in source_hashes.items():
            candidates = [n for n in names if n.endswith('/' + PurePosixPath(name).name)
                          and '/gp_sources/' in n]
            if candidates:
                assert len(candidates) == 1 and digest(bundle.read(candidates[0])) == sha
        return dict(seed=expected['seed'], run_id=expected['run_id'], job_id=expected['job_id'],
                    particles=expected['particles'], period_moves=expected['period_moves'],
                    bundle_sha256=digest(data), verified_members=len(members),
                    training_input_sha256=digest(raw_input),
                    posterior_sha256=digest(bundle.read(prefix + 'posterior.jls')),
                    log_evidence_export=log_evidence,
                    pre_resampling_accumulator=status['native_api_pre_resampling_accumulator'],
                    final_particle_ess=ess, wall_seconds=resources['elapsed_seconds'],
                    inference_seconds=status['inference_seconds_including_stage_checkpoints'],
                    sampled_peak_process_tree_pss_kib=resources['sampled_peak_process_tree_pss_kib'],
                    source_sha256=source_hashes, posterior_qualified=False)


def summarize(rows):
    values = [row['log_evidence_export'] for row in rows]
    top = max(values)
    total = math.fsum(math.exp(v-top) for v in values)
    weights = [math.exp(v-top)/total for v in values]
    return dict(seeds=[r['seed'] for r in rows], log_evidence_range=max(values)-min(values),
                log_mean_evidence=top+math.log(total/len(values)),
                evidence_replica_weights=weights,
                effective_evidence_replicas=1/math.fsum(w*w for w in weights),
                minimum_final_particle_ess=min(r['final_particle_ess'] for r in rows),
                summed_process_wall_seconds=math.fsum(r['wall_seconds'] for r in rows),
                posterior_qualified=False)


def main(index_path, output):
    index = json.loads(index_path.read_text())
    rows = [inspect(index_path.parent/item['file'], item) for item in index['bundles']]
    assert len(rows) == 8 and len({r['seed'] for r in rows}) == 8
    assert len({r['training_input_sha256'] for r in rows}) == 1
    cohorts = {}
    for name, n, policy in [('native64', 64, 0), ('additional_period32', 32, 10)]:
        selected = [r for r in rows if (r['particles'], r['period_moves']) == (n, policy)]
        assert len(selected) == 4
        cohorts[name] = summarize(selected)
    result = dict(transport_target_and_export_arithmetic_verified=True,
                  julia_serialized_state_gen_reaudit=False,
                  scientific_study_complete=False, forecasts_issued=False,
                  full_new_forecast_comparison_complete=False,
                  scope='Exported full-Gen estimates and final CSV weights; not a fresh Julia/Gen replay or posterior qualification.',
                  verifier_sha256=digest(Path(__file__).read_bytes()),
                  index_sha256=digest(index_path.read_bytes()), cohorts=cohorts, runs=rows)
    assert not output.exists(), 'Do not overwrite an earlier audit result'
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(cohorts, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('index', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    main(args.index, args.output)
