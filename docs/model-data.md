# Real Model Data Policy

The default Reproduced path uses `Qwen/Qwen2.5-72B-Instruct` obtained by each evaluator from ModelScope under the evaluator's own accepted model license.

The public artifact repository, CacheFS image, result files, GitHub release, and issue tracker must not contain or redistribute model shards, tokenizer files, model configuration, model manifests, access tokens, or local model paths.

## Private staging procedure

1. Copy `config/model.example.env` to ignored `config/model.env`.
2. Set a private `MODEL_SOURCE_A` with at least 160 GiB free capacity on the source provider.
3. Review and accept the model license, then run:

   ```sh
   I_ACCEPT_MODEL_LICENSE=1 bash scripts/fetch-qwen-modelscope.sh
   ```

4. The downloader writes a private SHA-256 manifest and metadata file outside the public repository. Those files identify the exact locally staged snapshot and are used by the CacheFS tests.

## Model scope

The real-model tests validate byte-for-byte FUSE/P2P access to an immutable model tree. They do not publish model contents, benchmark model quality, compare model outputs, or establish production serving throughput.
