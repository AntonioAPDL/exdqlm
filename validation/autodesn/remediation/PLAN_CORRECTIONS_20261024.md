# Corrections from inspection of the executed builder

The approved plan's references to fitting reservoir PCA describe an operation
that the executed bank does not perform. All456 frozen candidate definitions
have fixed seeds. All336 deep definitions set each bridge dimension equal to
the preceding layer width, so those bridges are identities. The shared Q-DESN
builder can alternatively draw row-normalized Gaussian reducer matrices when
dimensions differ; these are seeded random maps, not fitted PCA. See
`evidence/reducer_definition_audit.json` for the definition/source hashes.

This correction changes no likelihood, normalized RHS prior, architecture
mass, hyperparameter, completed inference result or forecast. The original
plan remains preserved. Chronological folds still rebuild the prefix bank and
refit readout, lag and calendar scalers inside their own scored training rows.
Response/input scaling remains fixed on the same first500 observations.
Validation observations cannot enter those scalers. A future data-derived
projection would require a separately identified model and prefix fitting.

The small prefix reconstruction test includes a reduced-layer example and
exposed a limitation of the historical validation adapter: it inferred raw
layer states from a readout that only preserves every raw layer coordinate
for identity bridges. The new prefix helper reads raw states directly from
the existing shared deterministic transition engine. It reproduces the old
identity-bridge warmup error exactly. It changes neither the reservoir builder
nor inference. The old unsuccessful fixture logs and immutable sources remain
preserved; the successful fixture verifies future perturbation invariance,
raw feature prefix equality, unchanged maps and refitted readout scalers.

These checks do not count as executed full456-candidate fold studies,
qualified posterior inference or a new forecast comparison. Calibration with
independently frozen readout geometry also retains its conditional scope;
correcting the PCA description does not establish unconditional calibration
of a workflow that estimates readout scalers from the response series.
