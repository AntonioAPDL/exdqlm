"""Compare successive, independently screened posterior budgets on training data.

This certificate cannot authorize forecasts: calibration, mode checks and predictive
Monte Carlo qualification are separate requirements. It never reads test responses.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import norm
from scipy.optimize import brentq

ROOT = Path(__file__).resolve().parent

def verify_validation_inputs(directory,validation):
    """Require complete filenames and exact content identities, including groups."""
    expected={'contract.rds','configuration.json'}
    expected.update(f'{stem}_{k}{suffix}' for k in range(1,5)
                    for stem,suffix in [('chain','.rds'),('chain','_status.json'),('trace','.csv')])
    if (directory/'model_metadata.csv').exists():expected.add('model_metadata.csv')
    files=validation.get('input_files_sha256',{})
    assert expected.issubset(files),'Revalidate all checkpoint/trace/metadata input identities'
    for name,sha in files.items():
        assert Path(name).name==name and hashlib.sha256((directory/name).read_bytes()).hexdigest()==sha


def common_rhs_screen(phase, target_id, family='F1', artifact_root=None,evidence_root=None):
    """Bind every supplementary common-coordinate monitor to the final chains."""
    artifact_root=Path(artifact_root) if artifact_root else ROOT/'artifacts'
    evidence_root=Path(evidence_root) if evidence_root else ROOT/'evidence'
    path=evidence_root/f'{family}_{phase}_common_rhs_diagnostics.json'
    if not path.exists():return dict(phase=phase,available=False,screen_passed=False)
    record=json.loads(path.read_text())
    assert record['complete'] and record['phase']==phase and record['parameters']==270 and record['chains']==4
    assert record.get('family','F1')==family
    directory=artifact_root/'common_rhs_monitors'
    directory=directory/phase if family=='F1' else directory/family/phase
    status_path=directory/'status.json'
    assert hashlib.sha256(status_path.read_bytes()).hexdigest()==record['source_status_sha256']
    status=json.loads(status_path.read_text())
    assert status['complete'] and len(status['source_checkpoints'])==4
    for k,source in enumerate(status['source_checkpoints'],1):
        final=json.loads((artifact_root/family/phase/f'chain_{k}_status.json').read_text())
        assert final['complete'] and source['sha256']==final['checkpoint_sha256'] and source['target_id']==target_id
    for name,sha in record['source_csv_sha256'].items():
        assert Path(name).name==name and hashlib.sha256((directory/name).read_bytes()).hexdigest()==sha
    return dict(phase=phase,available=True,screen_passed=bool(record['screen_passed']),diagnostics_sha256=hashlib.sha256(path.read_bytes()).hexdigest())


def summary(values, kind="mean", noise=None):
    """Independent chain batches and delta-method MCSE for a posterior functional."""
    x = np.asarray(values, dtype=float)
    n = x.shape[1]
    size = int(np.sqrt(n))
    count = n // size
    xb = x[:, :count * size].reshape(-1, size)
    if kind == "mean":
        value = float(x.mean())
        batches = xb.mean(1)
    else:
        assert noise is not None and np.asarray(noise).shape == x.shape
        mean = x.mean()
        second = (x * x + noise).mean()
        value = float(np.sqrt(second - mean * mean))
        nb = np.asarray(noise)[:, :count * size].reshape(-1, size)
        # Influence function of sqrt(E[mu^2 + sigma^2] - E[mu]^2).
        batches = ((xb * xb + nb).mean(1) - 2 * mean * xb.mean(1)) / (2 * value)
    return value, float(batches.std(ddof=1) / np.sqrt(len(batches)))


def quantile_summary(means, variances, probability):
    """Rao-Blackwellized Gaussian-mixture quantile and batch influence MCSE.

    This is a fixed-training-design marginal, not a recursive multi-step
    forecast. Normal CDFs integrate conditional innovations analytically.
    """
    mu=np.asarray(means,dtype=float);variance=np.asarray(variances,dtype=float)
    if mu.ndim!=2 or variance.shape!=mu.shape or not (0<probability<1) or not np.isfinite(mu).all() or not np.isfinite(variance).all() or np.any(variance<=0):
        raise ValueError('Supply finite chain-by-draw means and positive matched variances')
    sd=np.sqrt(variance)
    lower=float(np.min(mu-10*sd));upper=float(np.max(mu+10*sd))
    def equation(q):return float(norm.cdf((q-mu)/sd).mean()-probability)
    q=float(brentq(equation,lower,upper,xtol=1e-12,rtol=1e-12))
    z=(q-mu)/sd;density=float((norm.pdf(z)/sd).mean())
    if not np.isfinite(density) or density<=0:raise ValueError('Unresolved mixture density at the quantile')
    influence=-(norm.cdf(z)-probability)/density
    n=mu.shape[1];size=int(np.sqrt(n));count=n//size
    batches=influence[:,:count*size].reshape(-1,size).mean(1)
    return q,float(batches.std(ddof=1)/np.sqrt(len(batches)))


def compare(family, left_name, right_name, artifact_root=None, evidence_root=None, validation_paths=None):
    names = [left_name, right_name]
    artifact_root=Path(artifact_root) if artifact_root else ROOT/'artifacts'
    evidence_root=Path(evidence_root) if evidence_root else ROOT/'evidence'
    directories = [artifact_root / family / n for n in names]
    configs, qualifications, traces, validations = [], [], [], []
    for directory in directories:
        config = json.loads((directory / "configuration.json").read_text())
        status = json.loads((directory / "status.json").read_text())
        qualification = json.loads((directory / "qualification.json").read_text())
        validation_path = Path(validation_paths[len(configs)]) if validation_paths else evidence_root / f"{family}_{directory.name}_checkpoint_validation.json"
        validation = json.loads(validation_path.read_text())
        assert status["complete"] and validation["complete"]
        assert validation['chain_artifacts_verified']==4
        # A screen over CSVs must be bound to the exact RDS/CSV identities that
        # passed the independent consistency audit, not just a target label.
        verify_validation_inputs(directory,validation)
        assert validation["target_id"] == qualification["target_id"] == status["target_id"]
        assert config["phase"] == "production" and config["chains"] == 4
        for file, sha in qualification["trace_sha256"].items():
            assert hashlib.sha256((directory / file).read_bytes()).hexdigest() == sha
        configs.append(config)
        qualifications.append(qualification)
        validations.append(validation)
        traces.append([pd.read_csv(directory / f"trace_{k}.csv") for k in range(1, 5)])
    assert qualifications[0]["target_id"] == qualifications[1]["target_id"]
    for field in ["proposal_sha256", "local_proposal_sha256", "bank_id", "priors", "beta_prior"]:
        assert configs[0].get(field) == configs[1].get(field), "Cross-budget comparison requires a common frozen target/proposal policy: " + field
    assert configs[0].get("local_scale_proposal", False) == configs[1].get("local_scale_proposal", False)
    registry_path = ROOT / 'development_registry.json'
    ladder = json.loads(registry_path.read_text())['mcmc']['retained_ladder']
    index = ladder.index(configs[0]["retained"])
    assert index + 1 < len(ladder) and configs[1]["retained"] == ladder[index + 1]
    assert not family.startswith("SV"), "SV needs matched latent-variance probe summaries; do not substitute constant noise."
    sd = configs[1].get("training_response_sd", configs[0].get("training_response_sd"))
    assert sd is not None and np.isfinite(sd) and sd > 0
    rows = []

    def add(name, arrays, practical, kind="mean", noises=None, relative=False, probability=None):
        estimates = [quantile_summary(arrays[i],noises[i],probability) if probability is not None else summary(arrays[i], kind, None if noises is None else noises[i]) for i in range(2)]
        difference = abs(estimates[1][0] - estimates[0][0])
        tolerance = practical * np.mean([estimates[0][0], estimates[1][0]]) if relative else practical
        rows.append(dict(quantity=name, left=estimates[0][0], right=estimates[1][0],
                         left_mcse=estimates[0][1], right_mcse=estimates[1][1],
                         difference=difference, practical_tolerance=tolerance,
                         practical_passed=bool(difference <= tolerance),
                         combined_mcse=float(np.hypot(estimates[0][1], estimates[1][1]))))

    probes = [c for c in traces[0][0] if c.startswith("fitted_probe_")]
    assert probes and all(c in traces[1][0] for c in probes)
    noises = [np.array([t.variance.to_numpy() for t in ts]) for ts in traces]
    for probe in probes:
        arrays = [np.array([t[probe].to_numpy() for t in ts]) for ts in traces]
        add(probe + "_mean", arrays, .01 * sd)
        add(probe + "_predictive_sd", arrays, .02, "sd", noises, relative=True)
        for probability in [.05,.25,.5,.75,.95]:
            add(probe+f'_predictive_q{probability:g}',arrays,.02*sd,noises=noises,probability=probability)
    for field in ["model", "period_index"]:
        values = sorted(set(np.concatenate([t[field].to_numpy() for ts in traces for t in ts])))
        for value in values:
            arrays = [np.array([(t[field].to_numpy() == value).astype(float) for t in ts]) for ts in traces]
            if np.mean([x.mean() for x in arrays]) >= .01:
                add(f"{field}_{value}", arrays, .02)
    table = pd.DataFrame(rows)
    critical = float(norm.ppf(1 - .01 / (2 * len(table))))
    table["simultaneous_mc_tolerance"] = critical * table.combined_mcse
    table["mc_consistency_passed"] = table.difference <= table.simultaneous_mc_tolerance + 1e-12
    common_required=configs[0]['beta_prior']=='rhs'
    common_checks=[common_rhs_screen(n,qualifications[0]['target_id'],family,artifact_root,evidence_root) for n in names] if common_required else []
    passed = bool(all(q["screen_passed"] for q in qualifications)
                  and all(q['screen_passed'] for q in common_checks)
                  and table.practical_passed.all() and table.mc_consistency_passed.all())
    label = f"{family}_{left_name}_vs_{right_name}"
    table.to_csv(evidence_root / (label + "_stability.csv"), index=False)
    record = dict(complete=True, cross_budget_passed=passed, family=family, phases=names,
                  computational_registry_sha256=hashlib.sha256(registry_path.read_bytes()).hexdigest(),
                  target_id=qualifications[0]["target_id"],
                  individual_screens_passed=[q["screen_passed"] for q in qualifications],
                  supplementary_common_rhs_required=common_required,supplementary_common_rhs_screens=common_checks,
                  practical_stability_passed=bool(table.practical_passed.all()),
                  mc_consistency_passed=bool(table.mc_consistency_passed.all()),
                  familywise_normal_critical_value=critical, checked_quantities=len(table),
                  response_sd=sd, qualified=False, forecast_allowed=False,
                  validation_contract_ids=[v["contract_id"] for v in validations],
                  scope="Successive fresh posterior budgets; fixed training-probe means, marginal constant-noise predictive SDs and 5/25/50/75/95 percent quantiles, major model/period masses; no held-out outcomes read",
                  pending=["independent calibration/mode review", "predictive Monte Carlo sensitivity", "full scientific promotion"])
    (evidence_root / (label + "_stability.json")).write_text(json.dumps(record, indent=2) + "\n")
    return record


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("family")
    parser.add_argument("left")
    parser.add_argument("right")
    parser.add_argument('--artifact-root',type=Path)
    parser.add_argument('--evidence-root',type=Path)
    parser.add_argument('--validations',type=Path,nargs=2)
    args = parser.parse_args()
    result = compare(args.family, args.left, args.right,args.artifact_root,args.evidence_root,args.validations)
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["cross_budget_passed"] else 2)
